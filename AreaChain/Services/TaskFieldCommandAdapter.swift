import Foundation
import SwiftData

/// 普通字段共用窄适配；T-M2 必须额外声明能力，单项守卫不开放任意计划。
@MainActor final class TaskFieldCommandAdapter {
    enum Capability { case basic, milestone2 }
    let coordinator: CommandHandoffCoordinator
    let environment: TaskTitleCommandEnvironment?
    let capability: Capability

    init(coordinator: CommandHandoffCoordinator, environment: TaskTitleCommandEnvironment? = nil,
         capability: Capability = .basic) {
        self.coordinator = coordinator
        self.environment = environment
        self.capability = capability
    }
    func supports(_ command: CommandID) -> Bool {
        environment != nil && (TaskFieldEdit.basicCommands.contains(command.rawValue)
            || capability == .milestone2 && TaskFieldEdit.milestone2Commands.contains(command.rawValue))
    }
    func assembled() throws -> TaskTitleCommandEnvironment {
        guard let environment else { throw TaskFieldCommandIssue.unassembled }
        try environment.validateClean()
        return environment
    }

    func prepare(plan: CommandPlanStamp, expecting lease: CommandHostLease,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskFieldPreview {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        return try coordinator.withTaskFieldPreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard host.session.plan.stamp == plan else { throw TaskFieldCommandIssue.stale }
            try validateCapability(host)
            let preview = try environment.fieldReader.prepare(in: host)
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
            return preview
        }
    }

    func validatePreview(_ preview: CommandTaskFieldPreview, expecting lease: CommandHostLease,
                         displaySession: ContentQueryReadSession? = nil) throws {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        try coordinator.withTaskFieldPreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard preview.lease == lease, host.session.plan.stamp == preview.plan else { throw TaskFieldCommandIssue.stale }
            try validateCapability(host)
            _ = try environment.fieldReader.validate(preview, item: CommandTaskFieldPreview.input(in: host))
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
        }
    }

    func accept(_ preview: CommandTaskFieldPreview, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskFieldAcceptance {
        try validatePreview(preview, expecting: lease, displaySession: displaySession)
        return try coordinator.taskFields.accept(preview)
    }

    func submit(accepted: CommandTaskFieldAcceptance, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskFieldFacts {
        try validatePreview(accepted.preview, expecting: lease, displaySession: displaySession)
        guard coordinator.taskFields.acceptances[accepted.preview.draft.draftID] == accepted,
              !coordinator.taskFields.wasInvoked(accepted.id) else { throw TaskFieldCommandIssue.stale }
        try coordinator.send(.sealPlan(accepted.preview.plan, runID: UUID()), expecting: lease)
        var host = try coordinator.host(lease.ownership.hostID)
        guard let run = host.session.execution else { throw TaskFieldCommandIssue.stale }
        let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
        guard case .attempt(let attempt) = effect, let operation = run.operation(accepted.preview.item.id) else {
            throw TaskFieldCommandIssue.stale
        }
        host = try coordinator.host(lease.ownership.hostID)
        return try execute(.init(lease: host.lease, operation: operation, attempt: attempt), displaySession: displaySession)
    }

    func execute(_ request: TaskTitleCommandRequest,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskFieldFacts {
        let environment = try assembled()
        let accepted = try coordinator.taskFieldAcceptance(request)
        guard supports(accepted.preview.edit.commandID) else { throw TaskFieldCommandIssue.unassembled }
        let invocation = try coordinator.claimTaskField(request)
        let effects = TaskTitleCommandEnvironment.Effects()
        let current: TaskFieldCommandReader.Observation
        let dependencies: TaskMutationService.TitleDependencies
        do {
            current = try revalidate(accepted.preview, invocation: invocation, environment: environment)
            dependencies = invocationDependencies(invocation, preview: accepted.preview, environment: environment,
                                                  effects: effects, displaySession: displaySession)
            try dependencies.validateBeforeTransaction()
        } catch {
            try coordinator.recordTaskField(invocation, facts: .init(targetID: accepted.preview.target.id,
                                                                     state: .notSubmitted, conflict: Self.isFieldConflict(error)))
            try coordinator.finishTaskField(invocation, external: [:])
            throw error
        }
        if accepted.preview.noChange {
            let facts = CommandTaskFieldFacts(targetID: current.target.id, state: .noChange)
            try coordinator.recordTaskField(invocation, facts: facts)
            try coordinator.finishTaskField(invocation, external: [:])
            return facts
        }
        let modification = TaskMutationService.editField(current.todo, accepted: accepted,
                                                         in: environment.context, dependencies: dependencies)
        var facts = Self.facts(modification)
        facts.conflict = effects.fieldConflict
        if facts.state == .saved {
            facts.authorizationRequest = Self.call(modification.reminderRequest)
            facts.authorizationResult = effects.authorizationResult
            facts.refreshRequested = effects.refreshRequested
            facts.notificationRequested = effects.observed?.notificationRequested
            facts.calendarRequested = effects.observed?.calendarRequested
        }
        try coordinator.recordTaskField(invocation, facts: facts)
        if facts.state != .pending {
            try coordinator.finishTaskField(invocation, external: [
                .taskPublication: facts.publication == .returned && !facts.publicationFailed ? .succeeded : .unknown,
                .notification: effects.notification, .calendar: effects.calendar
            ])
        }
        return facts
    }

    private func invocationDependencies(_ invocation: CommandRuntimeInvocation, preview: CommandTaskFieldPreview,
                                        environment: TaskTitleCommandEnvironment, effects: TaskTitleCommandEnvironment.Effects,
                                        displaySession: ContentQueryReadSession?) -> TaskMutationService.TitleDependencies {
        var dependencies = environment.dependencies
        let repository = dependencies.repository(environment.context)
        let validation = dependencies.validateBeforeTransaction
        let registration = dependencies.registerLocalModification
        dependencies.repository = { _ in repository }
        dependencies.transaction.publish = { try environment.publish(effects) }
        dependencies.requestReminderAccessIfNeeded = { minutes in
            guard let minutes else { return }
            effects.authorizationResult = environment.requestAuthorization(minutes)
        }
        dependencies.registerLocalModification = { [coordinator] id in
            guard id == preview.target.id else { throw TaskFieldCommandIssue.stale }
            try coordinator.recordTaskField(invocation, facts: .init(targetID: id, state: .saved, save: .returned))
            try registration(id)
        }
        dependencies.validateBeforeTransaction = { [self] in
            do {
                try validation()
                let latest = try revalidate(preview, invocation: invocation, environment: environment)
                try displaySession?.validateDisplayHost(expecting: invocation.lease)
                effects.followUp = latest.followUp
                if case .move(let day) = preview.edit {
                    effects.followUp = .init(dayKey: day, isDone: latest.todo.isDone, calendarEventID: latest.todo.calendarEventID)
                }
                if case .completion(let done) = preview.edit {
                    effects.followUp = .init(dayKey: latest.todo.dayKey, isDone: done, calendarEventID: latest.todo.calendarEventID)
                }
            } catch {
                effects.fieldConflict = Self.isFieldConflict(error)
                throw error
            }
        }
        return dependencies
    }

    private func revalidate(_ preview: CommandTaskFieldPreview, invocation: CommandRuntimeInvocation,
                            environment: TaskTitleCommandEnvironment) throws -> TaskFieldCommandReader.Observation {
        try coordinator.validateRuntimeInvocation(invocation)
        guard let run = try coordinator.host(invocation.lease.ownership.hostID).session.execution else { throw TaskFieldCommandIssue.stale }
        let item = try preview.frozenItem(in: run, lease: invocation.lease)
        let current = try environment.fieldReader.validate(preview, item: item)
        try coordinator.validateRuntimeInvocation(invocation)
        try environment.validateClean()
        return current
    }

    func verifyUnknown(_ operation: CommandOperationIdentity, expecting lease: CommandHostLease,
                       displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskCreateVerification {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        try coordinator.validate(lease)
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution,
              run.operation(operation.operationID) == operation, run.snapshot.items.count == 1,
              let facts = run.units.first?.taskField, facts.state == .unknown,
              let accepted = coordinator.taskFields.acceptances[run.snapshot.items[0].draft.id],
              environment.fieldReader.owns(accepted.preview.source),
              coordinator.taskFields.wasInvoked(accepted.id) else { throw TaskFieldCommandIssue.stale }
        let reader = ModelContext(environment.context.container)
        reader.autosaveEnabled = false
        do {
            let eligible = try environment.fieldReader.verifyQualification(accepted.preview)
            try coordinator.validate(lease)
            try displaySession?.validateDisplayHost(expecting: lease)
            guard eligible else { return .unreadable }
            let rows = try SwiftDataTaskRepository(context: reader).fetchTodos(withID: facts.targetID)
            if rows.isEmpty { return .absent }
            if rows.count != 1 { return .ambiguous }
            try environment.fieldReader.verifyOrdinaryTags(rows[0].tagIDs)
            return rows[0].deletedAt == nil ? .singleLive : .tombstone
        } catch { return .unreadable }
    }

    private static func facts(_ modification: TaskMutationService.FieldModification) -> CommandTaskFieldFacts {
        var facts = CommandTaskFieldFacts(targetID: modification.targetID)
        switch modification.state {
        case .emptyInput, .notSubmitted: facts.state = .notSubmitted
        case .pending: facts.state = .pending
        case .commitUnknown: facts.state = .unknown
        case .saved: facts.state = .saved
        }
        facts.save = call(modification.transaction?.save)
        facts.rollback = call(modification.transaction?.rollback)
        facts.publication = call(modification.transaction?.publication)
        facts.publicationFailed = modification.transaction?.publicationFailed == true
        facts.registrationFailed = modification.registrationFailed
        facts.savedTagEffects = modification.savedTagEffects
        facts.savedTagIDs = modification.savedTagIDs
        facts.completedSubtaskIDs = modification.completedSubtaskIDs
        return facts
    }
    private func validateCapability(_ host: CommandOwnedHost) throws {
        let item = try CommandTaskFieldPreview.input(in: host)
        guard supports(item.draft.commandID) else { throw TaskFieldCommandIssue.unassembled }
    }
    private static func isFieldConflict(_ error: Error) -> Bool {
        (error as? TaskFieldCommandIssue) == .fieldsChanged
    }
    private static func call(_ fact: ModelChanges.CallFact?) -> CommandTaskTitleFacts.Call {
        switch fact {
        case .called: return .called
        case .returned: return .returned
        default: return .notCalled
        }
    }
}
