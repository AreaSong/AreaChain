import Foundation
import SwiftData

/// 仅显式装配的单目标适配；参数仍由 Plan/Run 独占，接受不是长期确认开关。
@MainActor final class TaskTitleCommandAdapter {
    let coordinator: CommandHandoffCoordinator
    let environment: TaskTitleCommandEnvironment?

    init(coordinator: CommandHandoffCoordinator, environment: TaskTitleCommandEnvironment? = nil) {
        self.coordinator = coordinator
        self.environment = environment
    }

    func supports(_ command: CommandID) -> Bool { environment != nil && command.rawValue == "todo.title" }

    func assembled() throws -> TaskTitleCommandEnvironment {
        guard let environment else { throw TaskTitleCommandIssue.unassembled }
        try environment.validateClean()
        return environment
    }

    func prepare(plan: CommandPlanStamp, expecting lease: CommandHostLease,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskTitlePreview {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        return try coordinator.withTaskTitlePreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard host.session.plan.stamp == plan else { throw TaskTitleCommandIssue.stale }
            let input = try CommandTaskTitlePreview.input(in: host)
            let preview = try environment.reading(target: input.target.id) { try environment.reader.prepare(in: host) }
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
            return preview
        }
    }

    /// 展示只核对已有证据，不建立新基线、不推进 prepare 或接受。
    func validatePreview(_ preview: CommandTaskTitlePreview, expecting lease: CommandHostLease,
                         displaySession: ContentQueryReadSession? = nil) throws {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        try coordinator.withTaskTitlePreparation(expecting: lease) {
            guard preview.binding.lease == lease else { throw TaskTitleCommandIssue.stale }
            _ = try environment.reading(target: preview.impact.target.id) {
                if let chain = preview.binding.chain {
                    guard try coordinator.taskChainBinding(expecting: lease) == chain,
                          let run = try coordinator.host(lease.ownership.hostID).session.execution else { throw TaskTitleCommandIssue.stale }
                    return try environment.reader.validateFrozen(preview, run: run, lease: lease)
                }
                return try environment.reader.validateAccepted(preview, in: coordinator.host(lease.ownership.hostID))
            }
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
        }
    }

    func accept(_ preview: CommandTaskTitlePreview, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskTitleAcceptance {
        try validatePreview(preview, expecting: lease, displaySession: displaySession)
        return try coordinator.taskTitles.accept(preview)
    }

    func submit(accepted: CommandTaskTitleAcceptance, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskTitleFacts {
        guard accepted.preview.binding.chain == nil else { throw CommandTaskTitlePreviewIssue.unsupportedPlan }
        try validatePreview(accepted.preview, expecting: lease, displaySession: displaySession)
        guard coordinator.taskTitles.acceptances[accepted.preview.binding.draft.draftID] == accepted,
              !coordinator.taskTitles.wasInvoked(accepted.id) else { throw TaskTitleCommandIssue.stale }
        try coordinator.send(.sealPlan(accepted.preview.binding.plan, runID: UUID()), expecting: lease)
        var host = try coordinator.host(lease.ownership.hostID)
        guard let run = host.session.execution else { throw TaskTitleCommandIssue.stale }
        let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
        guard case .attempt(let attempt) = effect, let operation = run.operation(accepted.preview.binding.item.id) else {
            throw TaskTitleCommandIssue.stale
        }
        host = try coordinator.host(lease.ownership.hostID)
        return try execute(.init(lease: host.lease, operation: operation, attempt: attempt), displaySession: displaySession)
    }

    func execute(_ request: TaskTitleCommandRequest,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskTitleFacts {
        let environment = try assembled()
        let accepted = try coordinator.taskTitleAcceptance(request)
        let invocation = try coordinator.claimTaskTitle(request)
        let effects = TaskTitleCommandEnvironment.Effects()
        let current: TaskTitleCommandPreviewReader.Observation
        let dependencies: TaskMutationService.TitleDependencies
        do {
            current = try revalidate(accepted, invocation: invocation, environment: environment)
            dependencies = invocationDependencies(invocation, accepted: accepted, environment: environment,
                                                  effects: effects, displaySession: displaySession)
            // 依赖工厂也可重入；noChange 和实际写入都必须经过最后门禁。
            try dependencies.validateBeforeTransaction()
        } catch {
            let facts = CommandTaskTitleFacts(targetID: accepted.preview.impact.target.id, state: .notSubmitted,
                                              conflict: error as? TaskTitleCommandIssue)
            try coordinator.recordTaskTitle(invocation, facts: facts)
            try coordinator.finishTaskTitle(invocation, external: [:])
            throw error
        }
        let impact = accepted.preview.impact
        if impact.changedFields.isEmpty && impact.tags.sideEffects.isEmpty {
            let facts = CommandTaskTitleFacts(targetID: impact.target.id, state: .noChange)
            try coordinator.recordTaskTitle(invocation, facts: facts)
            try coordinator.finishTaskTitle(invocation, external: [:])
            return facts
        }
        let modification = TaskMutationService.editTitle(current.todo, verified: impact,
            tagCreationIDs: accepted.tagCreationIDs, in: environment.context, dependencies: dependencies)
        var facts = Self.facts(modification)
        if modification.saved {
            facts.savedTagEffects = modification.savedTagEffects
            facts.followUpContext = effects.followUp
            facts.authorizationRequest = Self.call(modification.reminderRequest)
            facts.authorizationResult = effects.authorizationResult
            facts.refreshRequested = effects.refreshRequested
            facts.notificationRequested = effects.observed?.notificationRequested
            facts.calendarRequested = effects.observed?.calendarRequested
        }
        facts.conflict = effects.validationIssue
        try coordinator.recordTaskTitle(invocation, facts: facts)
        if facts.state != .pending {
            try coordinator.finishTaskTitle(invocation, external: [
                .taskPublication: facts.publication == .returned && !facts.publicationFailed ? .succeeded : .unknown,
                .notification: effects.notification, .calendar: effects.calendar
            ])
        }
        return facts
    }

    private func invocationDependencies(_ invocation: CommandRuntimeInvocation, accepted: CommandTaskTitleAcceptance,
                                        environment: TaskTitleCommandEnvironment,
                                        effects: TaskTitleCommandEnvironment.Effects,
                                        displaySession: ContentQueryReadSession?) -> TaskMutationService.TitleDependencies {
        var dependencies = environment.dependencies
        let repository = dependencies.repository(environment.context)
        let validation = dependencies.validateBeforeTransaction
        let registration = dependencies.registerLocalModification
        dependencies.repository = { _ in repository }
        dependencies.transaction.publish = { try environment.publish(effects) }
        dependencies.requestReminderAccessIfNeeded = { minutes in
            guard let minutes else { return }
            effects.authorizationRequest = .called
            effects.authorizationResult = environment.requestAuthorization(minutes)
            effects.authorizationRequest = .returned
        }
        dependencies.registerLocalModification = { [coordinator] id in
            guard id == accepted.preview.impact.target.id else { throw TaskTitleCommandIssue.stale }
            try coordinator.recordTaskTitle(invocation, facts: .init(targetID: id, state: .saved, save: .returned))
            try registration(id)
        }
        dependencies.validateBeforeTransaction = { [self] in
            do {
                try validation()
                let latest = try revalidate(accepted, invocation: invocation, environment: environment)
                try displaySession?.validateDisplayHost(expecting: invocation.lease)
                effects.followUp = latest.followUp
            } catch {
                effects.validationIssue = error as? TaskTitleCommandIssue
                throw error
            }
        }
        return dependencies
    }

    private func revalidate(_ accepted: CommandTaskTitleAcceptance, invocation: CommandRuntimeInvocation,
                            environment: TaskTitleCommandEnvironment) throws -> TaskTitleCommandPreviewReader.Observation {
        try coordinator.validateRuntimeInvocation(invocation)
        let host = try coordinator.host(invocation.lease.ownership.hostID)
        guard let run = host.session.execution else { throw TaskTitleCommandIssue.stale }
        if let chain = accepted.preview.binding.chain {
            guard try coordinator.taskChainBinding(expecting: invocation.lease) == chain else { throw TaskTitleCommandIssue.stale }
        }
        let current = try environment.reading(target: accepted.preview.impact.target.id) {
            try environment.reader.validateFrozen(accepted.preview, run: run, lease: invocation.lease)
        }
        try coordinator.validateRuntimeInvocation(invocation)
        try environment.validateClean()
        return current
    }

    private static func facts(_ modification: TaskMutationService.TitleModification) -> CommandTaskTitleFacts {
        var facts = CommandTaskTitleFacts(targetID: modification.targetID)
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
