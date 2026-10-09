import Foundation
import SwiftData

/// 唯一可编辑参数仍在 Draft/Plan/Run；适配只借用冻结普通输入并调用共享捕获服务。
@MainActor final class TaskCreateCommandAdapter {
    let coordinator: CommandHandoffCoordinator
    private let environment: TaskCreateCommandEnvironment?
    enum Capability { case minimal, ordinaryComposition }
    let capability: Capability

    init(coordinator: CommandHandoffCoordinator, environment: TaskCreateCommandEnvironment? = nil,
         capability: Capability = .minimal) {
        self.coordinator = coordinator
        self.environment = environment
        self.capability = capability
    }

    func supports(_ command: CommandID) -> Bool {
        environment != nil && command.rawValue == "todo.create"
    }

    func assembled() throws -> TaskCreateCommandEnvironment {
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
        return try submitPrepared(prepared, expecting: lease, displaySession: displaySession)
    }

    func submitPrepared(_ prepared: CommandTaskCreatePreparation, expecting lease: CommandHostLease,
                        displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskCreateFacts {
        try coordinator.send(.sealPlan(prepared.plan, runID: UUID()), expecting: lease)
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
        guard prepared.preview == nil || capability == .ordinaryComposition else { throw TaskCreateCommandIssue.unassembled }
        let invocation = try coordinator.claimTaskCreate(request)
        environment.beginInvocation()
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
        let creation = create(prepared, environment: environment, dependencies: dependencies)
        var facts = Self.facts(creation, reserved: prepared.creationID)
        if facts.state == .saved {
            facts.refreshRequested = environment.refreshRequested
            facts.notificationRequested = environment.observedRefresh?.notificationRequested
            facts.calendarRequested = environment.observedRefresh?.calendarRequested
            facts.authorizationRequest = environment.authorizationRequest
            facts.authorizationResult = environment.authorizationResult
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
        dependencies.requestReminderAccessIfNeeded = { environment.requestReminderAccessIfNeeded($0) }
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

    func revalidate(_ prepared: CommandTaskCreatePreparation,
                            environment: TaskCreateCommandEnvironment) throws {
        guard prepared.environmentID == environment.id,
              prepared.contextID == ObjectIdentifier(environment.context),
              prepared.storageID == ObjectIdentifier(environment.context.container) else { throw TaskCreateCommandIssue.stale }
        let source = try readSource(environment)
        try validateSource(source)
        guard source == prepared.source else { throw TaskCreateCommandIssue.sourceChanged }
        if let preview = prepared.preview {
            let catalog = try environment.tagCatalog.validate(preview.binding.catalog)
            let host = try coordinator.host(prepared.lease.ownership.hostID)
            let item = host.session.execution?.snapshot.items.first(where: { $0.stamp == prepared.item })
                ?? host.session.plan.items.first(where: { $0.stamp == prepared.item })
            guard let item, item.stamp == prepared.item else { throw TaskCreateCommandIssue.stale }
            try preview.validateCurrent(draft: item.draft, source: source, catalog: catalog)
            try requireTagIDsAbsent(prepared, catalog: catalog)
        }
        try requireAbsent(prepared.creationID, environment: environment)
        try environment.validateClean()
    }

    func requireAbsent(_ id: UUID, environment: TaskCreateCommandEnvironment) throws {
        let rows: [TodoItem]
        do { rows = try SwiftDataTaskRepository(context: environment.context).fetchTodos(withID: id) }
        catch { throw TaskCreateCommandIssue.storageUnavailable }
        guard rows.isEmpty else { throw TaskCreateCommandIssue.identityCollision }
    }

    func readSource(_ environment: TaskCreateCommandEnvironment) throws -> CommandTaskCreateSource {
        do { return try environment.source() }
        catch {
            // 注入者的原始异常可能包含来源/正文，指令边界只输出固定错误类别。
            throw TaskCreateCommandIssue.sourceUnavailable
        }
    }

    func validateSource(_ source: CommandTaskCreateSource) throws {
        guard source.protection == .ordinary, source.stampEnabled || source.bundleID.isEmpty else {
            throw TaskCreateCommandIssue.protectedContent
        }
    }

    private func create(_ prepared: CommandTaskCreatePreparation, environment: TaskCreateCommandEnvironment,
                        dependencies: TaskMutationService.Dependencies) -> TaskMutationService.Creation {
        if let composition = prepared.preview?.transactionPlan {
            return TaskMutationService.createComposed(.init(composition: composition, creationID: prepared.creationID,
                tagCreationIDs: prepared.tagCreationIDs, source: prepared.source),
                in: environment.context, dependencies: dependencies)
        }
        let input = prepared.input!
        return TaskMutationService.createCaptured(.init(text: input.parsed.rawInput, dayKey: input.day,
            creationID: prepared.creationID), in: environment.context, dependencies: dependencies)
    }

    /// 只查原 unknown 调用的精确 ID；不按标题匹配、不升格为已提交、不恢复可重放资格。
    func verifyUnknown(_ operation: CommandOperationIdentity, expecting lease: CommandHostLease) throws -> CommandTaskCreateVerification {
        guard let environment else { throw TaskCreateCommandIssue.unassembled }
        try environment.validate()
        try coordinator.validate(lease)
        let run = try coordinator.host(lease.ownership.hostID).session.execution
        guard run?.operation(operation.operationID) == operation,
              let unit = run?.units.first(where: { $0.members.contains(operation.operationID) }),
              let facts = unit.taskCreation, facts.state == .unknown,
              let item = run?.snapshot.items.first(where: { $0.id == operation.operationID }),
              let prepared = coordinator.taskCreations.preparations[item.draft.id], prepared.item == operation.item,
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
        facts.savedRecord = creation.savedRecord
        if creation.state == .saved { facts.savedTagEffects = creation.savedTagEffects }
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
