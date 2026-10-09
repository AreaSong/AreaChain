import Foundation
import SwiftData

/// 四种普通子项命令共用单项适配，调用占用仍由原协调者持有。
@MainActor final class SubtaskCommandAdapter {
    let coordinator: CommandHandoffCoordinator
    let environment: SubtaskCommandEnvironment?
    init(coordinator: CommandHandoffCoordinator, environment: SubtaskCommandEnvironment? = nil) {
        self.coordinator = coordinator
        self.environment = environment
    }
    func supports(_ command: CommandID) -> Bool { environment != nil && CommandSubtaskEdit.commands.contains(command.rawValue) }
    func assembled() throws -> SubtaskCommandEnvironment {
        guard let environment else { throw SubtaskCommandIssue.unassembled }
        try environment.validateClean()
        return environment
    }

    func prepare(plan: CommandPlanStamp, expecting lease: CommandHostLease,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandSubtaskPreview {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        return try coordinator.withSubtaskPreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard host.session.plan.stamp == plan else { throw SubtaskCommandIssue.stale }
            let preview = try environment.reader.prepare(in: host)
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
            return preview
        }
    }

    func validatePreview(_ preview: CommandSubtaskPreview, expecting lease: CommandHostLease,
                         displaySession: ContentQueryReadSession? = nil) throws {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        try coordinator.withSubtaskPreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard preview.lease == lease, host.session.plan.stamp == preview.plan else { throw SubtaskCommandIssue.stale }
            _ = try environment.reader.validate(preview, item: CommandSubtaskPreview.item(in: host))
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
        }
    }

    func accept(_ preview: CommandSubtaskPreview, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandSubtaskAcceptance {
        try validatePreview(preview, expecting: lease, displaySession: displaySession)
        return try coordinator.subtasks.accept(preview)
    }

    func submit(accepted: CommandSubtaskAcceptance, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandSubtaskFacts {
        try validatePreview(accepted.preview, expecting: lease, displaySession: displaySession)
        guard coordinator.subtasks.acceptances[accepted.preview.draft.draftID] == accepted,
              !coordinator.subtasks.wasInvoked(accepted.id) else { throw SubtaskCommandIssue.stale }
        try coordinator.send(.sealPlan(accepted.preview.plan, runID: UUID()), expecting: lease)
        var host = try coordinator.host(lease.ownership.hostID)
        guard let run = host.session.execution else { throw SubtaskCommandIssue.stale }
        let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
        guard case .attempt(let attempt) = effect, let operation = run.operation(accepted.preview.item.id) else {
            throw SubtaskCommandIssue.stale
        }
        host = try coordinator.host(lease.ownership.hostID)
        return try execute(.init(lease: host.lease, operation: operation, attempt: attempt), displaySession: displaySession)
    }

    func execute(_ request: TaskTitleCommandRequest,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandSubtaskFacts {
        let environment = try assembled()
        let accepted = try coordinator.subtaskAcceptance(request)
        let invocation = try coordinator.claimSubtask(request)
        let effects = TaskTitleCommandEnvironment.Effects()
        let dependencies: TaskMutationService.SubtaskDependencies
        do {
            dependencies = try invocationDependencies(invocation, accepted: accepted, environment: environment,
                                                       effects: effects, displaySession: displaySession)
            try dependencies.validateBeforeTransaction()
        } catch {
            var facts = Self.initialFacts(accepted, state: .notSubmitted)
            facts.conflict = Self.isConflict(error)
            try coordinator.recordSubtask(invocation, facts: facts)
            try coordinator.finishTaskMutation(invocation, external: [:])
            throw error
        }
        if accepted.preview.noChange {
            let facts = Self.initialFacts(accepted, state: .noChange)
            try coordinator.recordSubtask(invocation, facts: facts)
            try coordinator.finishTaskMutation(invocation, external: [:])
            return facts
        }
        let modification = TaskMutationService.mutateSubtask(accepted, in: environment.context, dependencies: dependencies)
        var facts = Self.facts(modification)
        facts.conflict = effects.fieldConflict
        if facts.state == .saved {
            facts.refreshRequested = effects.refreshRequested
            facts.notificationRequested = effects.observed?.notificationRequested
            facts.calendarRequested = effects.observed?.calendarRequested
        }
        try coordinator.recordSubtask(invocation, facts: facts)
        if facts.state != .pending {
            try coordinator.finishTaskMutation(invocation, external: [
                .taskPublication: facts.publication == .returned && !facts.publicationFailed ? .succeeded : .unknown,
                .notification: effects.notification, .calendar: effects.calendar
            ])
        }
        return facts
    }

    private func invocationDependencies(_ invocation: CommandRuntimeInvocation, accepted: CommandSubtaskAcceptance,
                                        environment: SubtaskCommandEnvironment, effects: TaskTitleCommandEnvironment.Effects,
                                        displaySession: ContentQueryReadSession?) throws -> TaskMutationService.SubtaskDependencies {
        var dependencies = environment.dependencies
        let repository = dependencies.repository(environment.context)
        guard repository.subtaskMutationContext === environment.context else { throw SubtaskCommandIssue.invalidFamily }
        let validation = dependencies.validateBeforeTransaction
        let registration = dependencies.registerLocalModification
        dependencies.repository = { _ in repository }
        dependencies.transaction.publish = { try environment.publish(effects) }
        dependencies.registerLocalModification = { [coordinator] id in
            guard id == accepted.object.id else { throw SubtaskCommandIssue.stale }
            var facts = Self.initialFacts(accepted, state: .saved)
            facts.save = .returned
            try coordinator.recordSubtask(invocation, facts: facts)
            try registration(id)
        }
        dependencies.validateBeforeTransaction = { [self] in
            do {
                try validation()
                try coordinator.validateRuntimeInvocation(invocation)
                guard let run = try coordinator.host(invocation.lease.ownership.hostID).session.execution else {
                    throw SubtaskCommandIssue.stale
                }
                let item = try accepted.preview.frozenItem(in: run, lease: invocation.lease)
                let latest = try environment.reader.validate(accepted.preview, item: item)
                try environment.reader.ensureCreationAvailable(accepted)
                try coordinator.validateRuntimeInvocation(invocation)
                try environment.validateClean()
                try displaySession?.validateDisplayHost(expecting: invocation.lease)
                effects.followUp = latest.followUp
            } catch {
                effects.fieldConflict = Self.isConflict(error)
                throw error
            }
        }
        return dependencies
    }

    private static func initialFacts(_ accepted: CommandSubtaskAcceptance, state: CommandSubtaskFacts.State) -> CommandSubtaskFacts {
        .init(object: accepted.object, parentID: accepted.preview.parent.id, isCreation: accepted.preview.input.edit.isCreation, state: state)
    }
    private static func isConflict(_ error: Error) -> Bool {
        guard let issue = error as? SubtaskCommandIssue else { return false }
        return [.fieldsChanged, .invalidFamily, .identityCollision, .stale].contains(issue)
    }
    private static func facts(_ modification: TaskMutationService.SubtaskModification) -> CommandSubtaskFacts {
        var facts = initialFacts(modification.accepted, state: modification.state)
        facts.save = call(modification.transaction?.save)
        facts.rollback = call(modification.transaction?.rollback)
        facts.publication = call(modification.transaction?.publication)
        facts.publicationFailed = modification.transaction?.publicationFailed == true
        facts.registrationFailed = modification.registrationFailed
        facts.savedRecord = modification.savedRecord
        facts.savedTagEffects = modification.savedTagEffects
        facts.savedTagIDs = modification.savedTagIDs
        facts.savedTitle = modification.savedTitle
        facts.savedCompletion = modification.savedCompletion
        return facts
    }
    private static func call(_ fact: ModelChanges.CallFact?) -> CommandTaskTitleFacts.Call {
        switch fact {
        case .called: return .called
        case .returned: return .returned
        default: return .notCalled
        }
    }
}
