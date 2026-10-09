import Foundation

extension MultiPlanCommandAdapter {
    func read(_ item: CommandPlanItem, family: CommandMultiPlanFamily,
              lease: CommandHostLease, plan: CommandPlanStamp) throws -> MultiPlanCommandMemberPreview {
        let current = try coordinator.host(lease.ownership.hostID)
        guard current.lease.ownership == lease.ownership else { throw CommandMultiPlanIssue.stale }
        return try coordinator.withMultiPlanPreparation(expecting: current.lease) {
            let result = try readMember(item, family: family, lease: lease, plan: plan)
            try validateEnvironment(family)
            return result
        }
    }

    private func readMember(_ item: CommandPlanItem, family: CommandMultiPlanFamily,
                            lease: CommandHostLease, plan: CommandPlanStamp) throws -> MultiPlanCommandMemberPreview {
        let consumption = try consumption(for: item, lease: lease)
        if !item.links.results.isEmpty && consumption == nil {
            try validateWaitingInput(item)
            return .output(lease, item.links.results.values.first!)
        }
        switch family {
        case .localSetting:
            guard let localSettings else { throw CommandMultiPlanIssue.unassembled }
            return try .localSetting(localSettings.prepareMulti(item, lease: lease, plan: plan))
        case .fileSettings:
            guard let fileSettings else { throw CommandMultiPlanIssue.unassembled }
            let session = try coordinator.host(lease.ownership.hostID).session
            let items = session.execution?.snapshot.items ?? session.plan.items
            let members = items.filter { item.atomicGroup != nil ? $0.atomicGroup == item.atomicGroup : $0.id == item.id }
            return try .fileSettings(fileSettings.prepareMulti(members, lease: lease, plan: plan))
        case .taskCreate: return try readTaskCreation(item, lease: lease, plan: plan)
        case .taskTitle: return try readTaskTitle(item, lease: lease, plan: plan, consumption: consumption)
        case .taskField:
            guard let adapter = taskField else { throw CommandMultiPlanIssue.unassembled }
            let environment = try adapter.assembled()
            return try .taskField(environment.fieldReader.prepare(item: item, lease: lease, plan: plan,
                                                                   catalog: environment.fieldReader.catalogReader.current(),
                                                                   consumption: consumption))
        case .subtask:
            guard let adapter = subtask else { throw CommandMultiPlanIssue.unassembled }
            let environment = try adapter.assembled()
            return try .subtask(environment.reader.read(item, lease: lease, plan: plan,
                                                        catalog: environment.reader.catalogReader.current(),
                                                        consumption: consumption).preview)
        case .routine:
            guard let adapter = routine else { throw CommandMultiPlanIssue.unassembled }
            let environment = try adapter.assembled()
            return try .routine(environment.reader.read(item, lease: lease, plan: plan,
                                                        catalog: environment.reader.catalogReader.current(), consumption: consumption))
        case .routineCreate:
            guard let adapter = routine else { throw CommandMultiPlanIssue.unassembled }
            let environment = try adapter.assembled()
            return try .routineCreate(environment.creationReader.read(item, lease: lease, plan: plan,
                                                                       catalog: environment.reader.catalogReader.current()))
        case .batch:
            guard let adapter = batch else { throw CommandMultiPlanIssue.unassembled }
            let environment = try adapter.assembled()
            return try .batch(environment.reader.read(item, lease: lease, plan: plan,
                                                      catalog: environment.reader.catalogReader.current()))
        default: throw CommandMultiPlanIssue.unsupported
        }
    }

    func accept(_ preview: MultiPlanCommandMemberPreview, retry: CommandMultiPlanRetryPermit? = nil) throws -> UUID {
        switch preview {
        case .localSetting(let value): return value.evidence.captureID
        case .fileSettings(let value): return value.id
        case .taskCreate(let value):
            let session = try coordinator.host(value.lease.ownership.hostID).session
            guard let item = (session.execution?.snapshot.items ?? session.plan.items).first(where: { $0.stamp == value.item }) else {
                throw CommandMultiPlanIssue.stale
            }
            let prepared = try coordinator.taskCreations.reserveMulti(item: item, plan: value.plan, lease: value.lease,
                                                                      evidence: value.evidence, retry: retry)
            guard let taskCreate else { throw CommandMultiPlanIssue.unassembled }
            let environment = try taskCreate.assembled()
            try taskCreate.requireAbsent(prepared.creationID, environment: environment)
            try taskCreate.requireTagIDsAbsent(prepared, catalog: environment.tagCatalog.current())
            return prepared.id
        case .taskTitle(let value): return try coordinator.taskTitles.accept(value, retry: retry).id
        case .output: throw CommandMultiPlanIssue.confirmationRequired
        case .taskField(let value): return try coordinator.taskFields.accept(value, retry: retry).id
        case .subtask(let value):
            let accepted = try coordinator.subtasks.accept(value, retry: retry)
            guard let subtask else { throw CommandMultiPlanIssue.unassembled }
            try subtask.assembled().reader.ensureCreationAvailable(accepted)
            return accepted.id
        case .routine(let value): return try coordinator.routines.accept(value, retry: retry).id
        case .routineCreate(let value):
            let accepted = try coordinator.taskCreations.acceptRoutineCreation(value, retry: retry)
            guard let routine else { throw CommandMultiPlanIssue.unassembled }
            try routine.assembled().creationReader.requireAbsent(accepted)
            return accepted.id
        case .batch(let value): return try coordinator.batches.accept(value, retry: retry).id
        }
    }

    func execute(_ preview: MultiPlanCommandMemberPreview, operation: CommandOperationIdentity,
                 attempt: CommandAttemptStamp, lease: CommandHostLease,
                 displaySession: ContentQueryReadSession?) throws {
        switch preview {
        case .localSetting(let value):
            _ = try localSettings!.execute(.init(lease: lease, operation: operation, attempt: attempt), multi: value, displaySession: displaySession)
        case .fileSettings(let value):
            guard let run = try coordinator.host(lease.ownership.hostID).session.execution,
                  let identity = run.preferenceGroupIdentity(unitID: attempt.unitID) else { throw CommandMultiPlanIssue.stale }
            _ = try fileSettings!.execute(.init(lease: lease, identity: identity, attempt: attempt), multi: value, displaySession: displaySession)
        case .taskCreate:
            _ = try taskCreate!.execute(.init(lease: lease, operation: operation, attempt: attempt), displaySession: displaySession)
        case .taskTitle:
            _ = try taskTitle!.execute(.init(lease: lease, operation: operation, attempt: attempt), displaySession: displaySession)
        case .output: throw CommandMultiPlanIssue.confirmationRequired
        case .taskField:
            _ = try taskField!.execute(.init(lease: lease, operation: operation, attempt: attempt), displaySession: displaySession)
        case .subtask:
            _ = try subtask!.execute(.init(lease: lease, operation: operation, attempt: attempt), displaySession: displaySession)
        case .routine:
            _ = try routine!.execute(.init(lease: lease, operation: operation, attempt: attempt), displaySession: displaySession)
        case .routineCreate:
            _ = try routine!.executeCreation(.init(lease: lease, operation: operation, attempt: attempt), displaySession: displaySession)
        case .batch:
            _ = try batch!.execute(.init(lease: lease, operation: operation, attempt: attempt), displaySession: displaySession)
        }
    }
}

extension MultiPlanCommandMemberPreview {
    /// 只忽略原 Reader 明确不当作修改影响的展示名／后续上下文；来源和目录仍严格匹配。
    func isCovered(by original: Self) -> Bool {
        if self == original { return true }
        switch (self, original) {
        case (.taskField(var current), .taskField(let previous)):
            current.targetTitle = previous.targetTitle
            return current == previous
        case (.taskTitle(let current), .taskTitle(let previous)):
            return (try? previous.validateCurrent(current)) != nil
        default: return false
        }
    }
}
