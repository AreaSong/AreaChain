import Foundation

extension RoutineCommandAdapter {
    var supportsCreation: Bool { environment?.creation != nil }

    func prepareCreation(plan: CommandPlanStamp, expecting lease: CommandHostLease,
                         displaySession: ContentQueryReadSession? = nil) throws -> CommandRoutineCreatePreview {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembledCreation()
        return try coordinator.withTaskCreatePreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard host.session.plan.stamp == plan else { throw RoutineCreateIssue.stale }
            let item = try CommandRoutineCreatePreview.item(in: host)
            let catalog = try environment.reader.catalogReader.prepare()
            let preview = try environment.creationReader.read(item, lease: lease, plan: plan, catalog: catalog)
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
            return preview
        }
    }

    func validateCreationPreview(_ preview: CommandRoutineCreatePreview, expecting lease: CommandHostLease,
                                 displaySession: ContentQueryReadSession? = nil) throws {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembledCreation()
        try coordinator.withTaskCreatePreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard preview.lease == lease, host.session.plan.stamp == preview.plan else { throw RoutineCreateIssue.stale }
            try environment.creationReader.validate(preview, item: CommandRoutineCreatePreview.item(in: host))
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
        }
    }

    func acceptCreation(_ preview: CommandRoutineCreatePreview, expecting lease: CommandHostLease,
                        displaySession: ContentQueryReadSession? = nil) throws -> CommandRoutineCreateAcceptance {
        try validateCreationPreview(preview, expecting: lease, displaySession: displaySession)
        let environment = try assembledCreation()
        return try coordinator.withTaskCreatePreparation(expecting: lease) {
            let accepted = try coordinator.taskCreations.acceptRoutineCreation(preview)
            try environment.creationReader.requireAbsent(accepted)
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
            return accepted
        }
    }

    func submitCreation(accepted: CommandRoutineCreateAcceptance, expecting lease: CommandHostLease,
                        displaySession: ContentQueryReadSession? = nil) throws -> CommandRoutineCreateFacts {
        try validateCreationPreview(accepted.preview, expecting: lease, displaySession: displaySession)
        guard coordinator.taskCreations.routinePreparations[accepted.preview.draft.draftID] == accepted,
              !coordinator.taskCreations.wasInvoked(accepted.id) else { throw RoutineCreateIssue.stale }
        try coordinator.send(.sealPlan(accepted.preview.plan, runID: UUID()), expecting: lease)
        var host = try coordinator.host(lease.ownership.hostID)
        guard let run = host.session.execution else { throw RoutineCreateIssue.stale }
        let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
        guard case .attempt(let attempt) = effect, let operation = run.operation(accepted.preview.item.id) else {
            throw RoutineCreateIssue.stale
        }
        host = try coordinator.host(lease.ownership.hostID)
        return try executeCreation(.init(lease: host.lease, operation: operation, attempt: attempt), displaySession: displaySession)
    }

    func executeCreation(_ request: RoutineCommandRequest,
                         displaySession: ContentQueryReadSession? = nil) throws -> CommandRoutineCreateFacts {
        let environment = try assembledCreation()
        let accepted = try coordinator.routineCreationAcceptance(request)
        let invocation = try coordinator.claimRoutineCreation(request)
        let effects = TaskTitleCommandEnvironment.Effects()
        let dependencies: RoutineMutationService.Dependencies
        do {
            try revalidateCreation(accepted, invocation: invocation, environment: environment)
            dependencies = try creationDependencies(invocation, accepted: accepted, effects: effects,
                                                      displaySession: displaySession)
            try dependencies.validateBeforeTransaction()
        } catch {
            try coordinator.recordRoutineCreation(invocation, facts: .init(creationID: accepted.creationID, state: .notSubmitted))
            try coordinator.finishTaskMutation(invocation, external: [:])
            throw error
        }
        guard let clock = environment.creation else { throw RoutineCreateIssue.unassembled }
        let creation = RoutineMutationService.create(accepted, in: environment.context, clock: clock, dependencies: dependencies)
        var facts = Self.creationFacts(creation)
        if facts.state == .saved {
            facts.authorizationResult = effects.authorizationResult
            facts.refreshRequested = effects.refreshRequested
            facts.notificationRequested = effects.observed?.notificationRequested
            facts.calendarRequested = effects.observed?.calendarRequested
        }
        try coordinator.recordRoutineCreation(invocation, facts: facts)
        if facts.state != .pending {
            try coordinator.finishTaskMutation(invocation, external: [
                .taskPublication: facts.publication == .returned && !facts.publicationFailed ? .succeeded : .unknown,
                .notification: effects.notification, .calendar: effects.calendar
            ])
        }
        return facts
    }

    private func creationDependencies(_ invocation: CommandRuntimeInvocation, accepted: CommandRoutineCreateAcceptance,
                                      effects: TaskTitleCommandEnvironment.Effects,
                                      displaySession: ContentQueryReadSession?) throws -> RoutineMutationService.Dependencies {
        let environment = try assembledCreation()
        var dependencies = environment.dependencies
        let repository = dependencies.repository(environment.context)
        guard repository.routineMutationContext === environment.context else { throw RoutineCommandIssue.invalidRepository }
        let validation = dependencies.validateBeforeTransaction
        let registration = dependencies.registerLocalModification
        dependencies.repository = { _ in repository }
        dependencies.transaction.publish = { try environment.publish(effects, target: accepted.object) }
        dependencies.requestReminderAccessIfNeeded = { minutes in
            if let minutes { effects.authorizationResult = environment.requestAuthorization(minutes) }
        }
        dependencies.registerLocalModification = { [coordinator] id in
            guard id == accepted.creationID else { throw RoutineCreateIssue.identityCollision }
            try coordinator.recordRoutineCreation(invocation, facts: .init(creationID: id, candidateID: id, savedID: id,
                                                                           state: .saved, save: .returned))
            try registration(id)
        }
        dependencies.validateBeforeTransaction = { [self] in
            try validation()
            try revalidateCreation(accepted, invocation: invocation, environment: environment)
            try displaySession?.validateDisplayHost(expecting: invocation.lease)
        }
        return dependencies
    }

    private func revalidateCreation(_ accepted: CommandRoutineCreateAcceptance, invocation: CommandRuntimeInvocation,
                                    environment: RoutineCommandEnvironment) throws {
        try coordinator.validateRuntimeInvocation(invocation)
        guard let run = try coordinator.host(invocation.lease.ownership.hostID).session.execution else { throw RoutineCreateIssue.stale }
        let item = try accepted.preview.frozenItem(in: run, lease: invocation.lease)
        try environment.creationReader.validate(accepted.preview, item: item)
        try environment.creationReader.requireAbsent(accepted)
        try coordinator.validateRuntimeInvocation(invocation)
        try environment.validateClean()
    }

    func assembledCreation() throws -> RoutineCommandEnvironment {
        guard supportsCreation else { throw RoutineCreateIssue.unassembled }
        return try assembled()
    }

    private static func creationFacts(_ result: RoutineMutationService.CreationResult) -> CommandRoutineCreateFacts {
        var facts = CommandRoutineCreateFacts(creationID: result.creationID, candidateID: result.candidateID,
                                              savedID: result.savedID, state: result.state)
        facts.save = creationCall(result.transaction?.save)
        facts.rollback = creationCall(result.transaction?.rollback)
        facts.publication = creationCall(result.transaction?.publication)
        facts.publicationFailed = result.transaction?.publicationFailed == true
        facts.registrationFailed = result.registrationFailed
        facts.savedRecord = result.savedRecord
        facts.savedRoutine = result.savedRoutine
        facts.savedTagEffects = result.savedTagEffects
        facts.authorizationRequest = creationCall(result.reminderRequest)
        return facts
    }

    private static func creationCall(_ fact: ModelChanges.CallFact?) -> CommandTaskTitleFacts.Call {
        switch fact {
        case .called: return .called
        case .returned: return .returned
        default: return .notCalled
        }
    }
}
