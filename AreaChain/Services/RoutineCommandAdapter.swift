import Foundation
import SwiftData

/// 仅显式装配的五类习惯定义修改；占用、接受和事实仍由原 Coordinator/Run 持有。
@MainActor final class RoutineCommandAdapter {
    let coordinator: CommandHandoffCoordinator
    let environment: RoutineCommandEnvironment?

    init(coordinator: CommandHandoffCoordinator, environment: RoutineCommandEnvironment? = nil) {
        self.coordinator = coordinator
        self.environment = environment
    }
    func supports(_ command: CommandID) -> Bool {
        environment != nil && CommandRoutineEdit.commands.contains(command.rawValue)
    }
    func assembled() throws -> RoutineCommandEnvironment {
        guard let environment else { throw RoutineCommandIssue.unassembled }
        try environment.validateClean()
        return environment
    }

    func prepare(plan: CommandPlanStamp, expecting lease: CommandHostLease,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandRoutinePreview {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        return try coordinator.withRoutinePreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard host.session.plan.stamp == plan else { throw RoutineCommandIssue.stale }
            try validateCapability(host)
            let preview = try environment.reader.prepare(in: host)
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
            return preview
        }
    }

    func validatePreview(_ preview: CommandRoutinePreview, expecting lease: CommandHostLease,
                         displaySession: ContentQueryReadSession? = nil) throws {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        try coordinator.withRoutinePreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard preview.lease == lease, host.session.plan.stamp == preview.plan else { throw RoutineCommandIssue.stale }
            try validateCapability(host)
            _ = try environment.reader.validate(preview, item: CommandRoutinePreview.input(in: host))
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
        }
    }

    func accept(_ preview: CommandRoutinePreview, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandRoutineAcceptance {
        try validatePreview(preview, expecting: lease, displaySession: displaySession)
        return try coordinator.routines.accept(preview)
    }

    func submit(accepted: CommandRoutineAcceptance, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandRoutineFacts {
        try validatePreview(accepted.preview, expecting: lease, displaySession: displaySession)
        guard coordinator.routines.acceptances[accepted.preview.draft.draftID] == accepted,
              !coordinator.routines.wasInvoked(accepted.id) else { throw RoutineCommandIssue.stale }
        try coordinator.send(.sealPlan(accepted.preview.plan, runID: UUID()), expecting: lease)
        var host = try coordinator.host(lease.ownership.hostID)
        guard let run = host.session.execution else { throw RoutineCommandIssue.stale }
        let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
        guard case .attempt(let attempt) = effect, let operation = run.operation(accepted.preview.item.id) else {
            throw RoutineCommandIssue.stale
        }
        host = try coordinator.host(lease.ownership.hostID)
        return try execute(.init(lease: host.lease, operation: operation, attempt: attempt), displaySession: displaySession)
    }

    func execute(_ request: RoutineCommandRequest,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandRoutineFacts {
        let environment = try assembled()
        let accepted = try coordinator.routineAcceptance(request)
        let invocation = try coordinator.claimRoutine(request)
        let effects = TaskTitleCommandEnvironment.Effects()
        let current: DailyRoutine
        let dependencies: RoutineMutationService.Dependencies
        do {
            current = try revalidate(accepted.preview, invocation: invocation, environment: environment)
            dependencies = try invocationDependencies(invocation, preview: accepted.preview, environment: environment,
                                                  effects: effects, displaySession: displaySession)
            try dependencies.validateBeforeTransaction()
        } catch {
            try coordinator.recordRoutine(invocation, facts: .init(object: accepted.object,
                                                                     state: .notSubmitted, conflict: Self.isFieldConflict(error)))
            try coordinator.finishRoutine(invocation, external: [:])
            throw error
        }
        if accepted.preview.noChange {
            let facts = CommandRoutineFacts(object: accepted.object, state: .noChange)
            try coordinator.recordRoutine(invocation, facts: facts)
            try coordinator.finishRoutine(invocation, external: [:])
            return facts
        }
        let modification = RoutineMutationService.edit(current, accepted: accepted,
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
        try coordinator.recordRoutine(invocation, facts: facts)
        if facts.state != .pending {
            try coordinator.finishRoutine(invocation, external: [
                .taskPublication: facts.publication == .returned && !facts.publicationFailed ? .succeeded : .unknown,
                .notification: effects.notification, .calendar: effects.calendar
            ])
        }
        return facts
    }

    private func invocationDependencies(_ invocation: CommandRuntimeInvocation, preview: CommandRoutinePreview,
                                        environment: RoutineCommandEnvironment, effects: TaskTitleCommandEnvironment.Effects,
                                        displaySession: ContentQueryReadSession?) throws -> RoutineMutationService.Dependencies {
        var dependencies = environment.dependencies
        let repository = dependencies.repository(environment.context)
        guard repository.routineMutationContext === environment.context else { throw RoutineCommandIssue.invalidRepository }
        let validation = dependencies.validateBeforeTransaction
        let registration = dependencies.registerLocalModification
        dependencies.repository = { _ in repository }
        dependencies.transaction.publish = { try environment.publish(effects, target: preview.target) }
        dependencies.requestReminderAccessIfNeeded = { minutes in
            guard let minutes else { return }
            effects.authorizationResult = environment.requestAuthorization(minutes)
        }
        dependencies.registerLocalModification = { [coordinator] id in
            guard id == preview.target.id else { throw RoutineCommandIssue.stale }
            try coordinator.recordRoutine(invocation, facts: .init(object: preview.target, state: .saved, save: .returned))
            try registration(id)
        }
        dependencies.validateBeforeTransaction = { [self] in
            do {
                try validation()
                _ = try revalidate(preview, invocation: invocation, environment: environment)
                try displaySession?.validateDisplayHost(expecting: invocation.lease)
            } catch {
                effects.fieldConflict = Self.isFieldConflict(error)
                throw error
            }
        }
        return dependencies
    }

    private func revalidate(_ preview: CommandRoutinePreview, invocation: CommandRuntimeInvocation,
                            environment: RoutineCommandEnvironment) throws -> DailyRoutine {
        try coordinator.validateRuntimeInvocation(invocation)
        guard let run = try coordinator.host(invocation.lease.ownership.hostID).session.execution else { throw RoutineCommandIssue.stale }
        let item = try preview.frozenItem(in: run, lease: invocation.lease)
        let current = try environment.reader.validate(preview, item: item)
        try coordinator.validateRuntimeInvocation(invocation)
        try environment.validateClean()
        return current
    }

    private static func facts(_ modification: RoutineMutationService.Modification) -> CommandRoutineFacts {
        var facts = CommandRoutineFacts(object: modification.object)
        facts.state = modification.state
        facts.save = call(modification.transaction?.save)
        facts.rollback = call(modification.transaction?.rollback)
        facts.publication = call(modification.transaction?.publication)
        facts.publicationFailed = modification.transaction?.publicationFailed == true
        facts.registrationFailed = modification.registrationFailed
        facts.savedTagEffects = modification.savedTagEffects
        facts.savedTagIDs = modification.savedTagIDs
        facts.savedValues = modification.savedValues
        if case .text(let title) = modification.savedValues?[.title] { facts.savedTitle = title }
        return facts
    }
    private func validateCapability(_ host: CommandOwnedHost) throws {
        let item = try CommandRoutinePreview.input(in: host)
        guard supports(item.draft.commandID) else { throw RoutineCommandIssue.unassembled }
    }
    private static func isFieldConflict(_ error: Error) -> Bool {
        (error as? RoutineCommandIssue) == .fieldsChanged
    }
    private static func call(_ fact: ModelChanges.CallFact?) -> CommandTaskTitleFacts.Call {
        switch fact {
        case .called: return .called
        case .returned: return .returned
        default: return .notCalled
        }
    }
}
