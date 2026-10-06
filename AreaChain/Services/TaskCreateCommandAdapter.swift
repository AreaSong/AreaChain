import Foundation
import SwiftData

/// 唯一可编辑参数仍在 Draft/Plan/Run；适配只借用冻结普通输入并调用共享捕获服务。
@MainActor final class TaskCreateCommandAdapter {
    private let coordinator: CommandHandoffCoordinator
    private let environment: TaskCreateCommandEnvironment?

    init(coordinator: CommandHandoffCoordinator, environment: TaskCreateCommandEnvironment? = nil) {
        self.coordinator = coordinator
        self.environment = environment
    }

    func supports(_ command: CommandID) -> Bool {
        environment != nil && command.rawValue == "todo.create"
    }

    private func assembled() throws -> TaskCreateCommandEnvironment {
        guard let environment else { throw TaskCreateCommandIssue.unassembled }
        try environment.validateClean()
        return environment
    }

    @discardableResult
    func prepare(plan: CommandPlanStamp, expecting lease: CommandHostLease) throws -> CommandTaskCreatePreparation {
        let environment = try assembled()
        return try coordinator.withTaskCreatePreparation(expecting: lease) {
            let item = try coordinator.taskCreatePlan(plan, expecting: lease)
            let input = try CommandTaskCreateInput(item.draft)
            let source = try readSource(environment)
            try validateSource(source)
            let evidence = CommandTaskCreateEvidence(environmentID: environment.id,
                contextID: ObjectIdentifier(environment.context), storageID: ObjectIdentifier(environment.context.container),
                source: source, input: input)
            // 所有可注入读取之后再核对原版本与脏编辑；不保存，也不回滚。
            _ = try coordinator.taskCreatePlan(plan, expecting: lease)
            try environment.validateClean()
            let prepared = try coordinator.taskCreations.reserve(item: item, plan: plan, lease: lease, evidence: evidence)
            try requireAbsent(prepared.creationID, environment: environment)
            return prepared
        }
    }

    func submit(plan: CommandPlanStamp, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskCreateFacts {
        try displaySession?.validateDisplayHost(expecting: lease)
        let prepared = try prepare(plan: plan, expecting: lease)
        try displaySession?.validateDisplayHost(expecting: lease)
        try coordinator.send(.sealPlan(plan, runID: UUID()), expecting: lease)
        var host = try coordinator.host(lease.ownership.hostID)
        guard let run = host.session.execution else { throw TaskCreateCommandIssue.stale }
        let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
        guard case .attempt(let attempt) = effect, let operation = run.operation(prepared.item.id) else {
            throw TaskCreateCommandIssue.stale
        }
        host = try coordinator.host(lease.ownership.hostID)
        return try execute(.init(lease: host.lease, operation: operation, attempt: attempt), displaySession: displaySession)
    }

    func execute(_ request: TaskCreateCommandRequest,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskCreateFacts {
        let environment = try assembled()
        let prepared = try coordinator.taskCreatePreparation(request)
        let invocation = try coordinator.claimTaskCreate(request)
        let dependencies: TaskMutationService.Dependencies
        do {
            try revalidate(prepared, environment: environment)
            try displaySession?.validateDisplayHost(expecting: request.lease)
            dependencies = try invocationDependencies(invocation, prepared: prepared, environment: environment,
                                                       displaySession: displaySession)
        } catch {
            let facts = CommandTaskCreateFacts(creationID: prepared.creationID, state: .notSubmitted)
            try coordinator.recordTaskCreation(invocation, facts: facts)
            try coordinator.finishTaskCreation(invocation, external: [:])
            throw error
        }
        let input = TaskMutationService.CaptureInput(text: prepared.input.parsed.rawInput,
            dayKey: prepared.input.day, creationID: prepared.creationID)
        let creation = TaskMutationService.createCaptured(input, in: environment.context, dependencies: dependencies)
        var facts = Self.facts(creation, reserved: prepared.creationID)
        if facts.state == .saved {
            facts.refreshRequested = environment.refreshRequested
            facts.notificationRequested = environment.observedRefresh?.notificationRequested
            facts.calendarRequested = environment.observedRefresh?.calendarRequested
        }
        // 从业务调用开始不再把错误降级成未创建；Creation 是本地事实的唯一来源。
        try coordinator.recordTaskCreation(invocation, facts: facts)
        if facts.state != .pending {
            try coordinator.finishTaskCreation(invocation, external: [
                .taskPublication: facts.publication == .returned && !facts.publicationFailed ? .succeeded : .unknown,
                .notification: environment.notification, .calendar: environment.calendar
            ])
        }
        return facts
    }

    private func invocationDependencies(_ invocation: CommandRuntimeInvocation, prepared: CommandTaskCreatePreparation,
                                        environment: TaskCreateCommandEnvironment,
                                        displaySession: ContentQueryReadSession?) throws -> TaskMutationService.Dependencies {
        var dependencies = environment.dependencies
        let repository = dependencies.repository(environment.context)
        let originalValidation = dependencies.validateBeforeTransaction
        let originalRegistration = dependencies.registerLocalCreation
        dependencies.repository = { _ in repository }
        dependencies.sourceBundleID = { prepared.source.bundleID }
        dependencies.transaction.publish = { try environment.publish() }
        dependencies.registerLocalCreation = { [coordinator] id in
            guard id == prepared.creationID else { throw TaskCreateCommandIssue.identityCollision }
            let facts = CommandTaskCreateFacts(creationID: id, candidateID: id, savedID: id,
                                              state: .saved, save: .returned)
            try coordinator.recordTaskCreation(invocation, facts: facts)
            try originalRegistration(id)
        }
        dependencies.validateBeforeTransaction = { [self] in
            try originalValidation()
            try revalidate(prepared, environment: environment)
            try coordinator.validateRuntimeInvocation(invocation)
            try displaySession?.validateDisplayHost(expecting: invocation.lease)
            try environment.validateClean()
        }
        return dependencies
    }

    private func revalidate(_ prepared: CommandTaskCreatePreparation,
                            environment: TaskCreateCommandEnvironment) throws {
        guard prepared.environmentID == environment.id,
              prepared.contextID == ObjectIdentifier(environment.context),
              prepared.storageID == ObjectIdentifier(environment.context.container) else { throw TaskCreateCommandIssue.stale }
        let source = try readSource(environment)
        try validateSource(source)
        guard source == prepared.source else { throw TaskCreateCommandIssue.sourceChanged }
        try requireAbsent(prepared.creationID, environment: environment)
        try environment.validateClean()
    }

    private func requireAbsent(_ id: UUID, environment: TaskCreateCommandEnvironment) throws {
        let rows: [TodoItem]
        do { rows = try SwiftDataTaskRepository(context: environment.context).fetchTodos(withID: id) }
        catch { throw TaskCreateCommandIssue.storageUnavailable }
        guard rows.isEmpty else { throw TaskCreateCommandIssue.identityCollision }
    }

    private func readSource(_ environment: TaskCreateCommandEnvironment) throws -> CommandTaskCreateSource {
        do { return try environment.source() }
        catch {
            // 注入者的原始异常可能包含来源/正文，指令边界只输出固定错误类别。
            throw TaskCreateCommandIssue.sourceUnavailable
        }
    }

    private func validateSource(_ source: CommandTaskCreateSource) throws {
        guard source.protection == .ordinary, source.stampEnabled || source.bundleID.isEmpty else {
            throw TaskCreateCommandIssue.protectedContent
        }
    }

    /// 只查原 unknown 调用的精确 ID；不按标题匹配、不升格为已提交、不恢复可重放资格。
    func verifyUnknown(_ operation: CommandOperationIdentity, expecting lease: CommandHostLease) throws -> CommandTaskCreateVerification {
        guard let environment else { throw TaskCreateCommandIssue.unassembled }
        try environment.validate()
        try coordinator.validate(lease)
        let run = try coordinator.host(lease.ownership.hostID).session.execution
        guard run?.operation(operation.operationID) == operation,
              let facts = run?.units.first?.taskCreation, facts.state == .unknown,
              let prepared = coordinator.taskCreations.preparations[run!.snapshot.items[0].draft.id],
              prepared.environmentID == environment.id, prepared.creationID == facts.creationID,
              coordinator.taskCreations.wasInvoked(prepared.id) else { throw TaskCreateCommandIssue.stale }
        let reader = ModelContext(environment.context.container)
        reader.autosaveEnabled = false
        do {
            let rows = try SwiftDataTaskRepository(context: reader).fetchTodos(withID: facts.creationID)
            if rows.isEmpty { return .absent }
            if rows.count != 1 { return .ambiguous }
            return rows[0].deletedAt == nil ? .singleLive : .tombstone
        } catch { return .unreadable }
    }

    private static func facts(_ creation: TaskMutationService.Creation, reserved: UUID) -> CommandTaskCreateFacts {
        var facts = CommandTaskCreateFacts(creationID: reserved, candidateID: creation.candidateID, savedID: creation.savedID)
        switch creation.state {
        case .emptyInput, .notSubmitted: facts.state = .notSubmitted
        case .pending: facts.state = .pending
        case .commitUnknown: facts.state = .unknown
        case .saved: facts.state = .saved
        }
        facts.save = call(creation.transaction?.save)
        facts.rollback = call(creation.transaction?.rollback)
        facts.publication = call(creation.transaction?.publication)
        facts.publicationFailed = creation.transaction?.publicationFailed == true
        facts.registrationFailed = creation.registrationFailed
        return facts
    }

    private static func call(_ fact: ModelChanges.CallFact?) -> CommandTaskCreateFacts.Call {
        switch fact {
        case .called: return .called
        case .returned: return .returned
        default: return .notCalled
        }
    }
}
