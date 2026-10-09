import Foundation

/// 历史边保留真实完成来源；它不是当前计划中的可执行占位项。
struct CommandCompletedPredecessor: Equatable {
    let execution: CommandExecutionStamp
    let item: CommandPlanItemStamp
}

/// 来源标记只通过协调者登记产生；静态匹配不代替本次装配与宿主核验。
struct CommandPlanExecutionOrigin: Equatable {
    let id: UUID
    let returnID: UUID?
    let itemID: UUID
    let draftID: UUID
    let command: CommandID
    let merged: [CommandDraftStamp]
    let returned: [CommandAttemptStamp]
    fileprivate init(item: CommandPlanItem, returnID: UUID?) {
        id = UUID()
        self.returnID = returnID
        itemID = item.id
        draftID = item.draft.id
        command = item.draft.commandID
        merged = item.mergedOrigins
        returned = item.returnedAttempts
    }
    func matches(_ item: CommandPlanItem) -> Bool {
        item.id == itemID && item.draft.id == draftID && item.draft.commandID == command
            && item.mergedOrigins == merged && item.returnedAttempts == returned
    }
}

extension CommandPlanItem {
    var hasSupportedOrigins: Bool {
        if let executionOrigin { return executionOrigin.matches(self) }
        return mergedOrigins.isEmpty && returnedAttempts.isEmpty && links.completedPredecessors.isEmpty
            && links.results.values.allSatisfy { $0.history == nil }
    }
}

struct CommandPlanReturnTicket: Equatable {
    let id: UUID
    let lease: CommandHostLease
    let execution: CommandExecutionStamp
    let plan: CommandPlanStamp
    let members: [[UUID]]
    fileprivate init(lease: CommandHostLease, run: CommandExecutionRun, plan: CommandPlanStamp) {
        id = UUID()
        self.lease = lease
        execution = run.stamp
        self.plan = plan
        members = run.units.filter { $0.state != .succeeded }.map(\.members)
    }
}

enum CommandAssignmentMergeSource: Equatable {
    case task(CommandTaskFieldPreview)
    case routine(CommandRoutinePreview)
    case local(CommandPreferenceBaseline)
    case file(CommandPreferenceRecordIdentity)
}

/// 合并提议独立于出处数组：绑定完整原计划、真实读取证据及当时的宿主版本。
struct CommandAssignmentMergeProof: Equatable {
    let id: UUID
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let items: [CommandPlanItem]
    let earlier: CommandPlanItemStamp
    let later: CommandPlanItemStamp
    let baseline: CommandDraftBaseline
    let sources: [CommandAssignmentMergeSource]
    fileprivate init(lease: CommandHostLease, plan: CommandPlan, earlier: CommandPlanItemStamp, later: CommandPlanItemStamp,
                     baseline: CommandDraftBaseline, sources: [CommandAssignmentMergeSource]) {
        id = UUID()
        self.lease = lease
        self.plan = plan.stamp
        items = plan.items
        self.earlier = earlier
        self.later = later
        self.baseline = baseline
        self.sources = sources
    }
}

/// 每次返回只存一份不可变原 Run；后续修订经 parent 连接，不清洗或改写失败历史。
struct CommandPlanRevisionRecord {
    let id: UUID
    let parent: UUID?
    let owner: CommandHostOwnership
    let assemblyID: UUID
    let run: CommandExecutionRun
    let outputs: [UUID: CommandCreationOutput]
}

@MainActor final class CommandPlanRevisionRegistry {
    struct OriginRecord {
        let origin: CommandPlanExecutionOrigin
        let owner: CommandHostOwnership
        let assemblyID: UUID
        let planID: UUID
    }
    fileprivate var origins: [UUID: OriginRecord] = [:]
    fileprivate var tickets: [UUID: CommandPlanReturnTicket] = [:]
    fileprivate var records: [UUID: CommandPlanRevisionRecord] = [:]
    fileprivate var heads: [String: UUID] = [:]
    fileprivate var mergeProofs: [UUID: CommandAssignmentMergeProof] = [:]
    fileprivate var mergeAssemblies: [UUID: UUID] = [:]
    fileprivate var mergedEvidence: [UUID: CommandAssignmentMergeProof] = [:]
}

extension CommandHandoffCoordinator {
    func validatePlanOrigins(_ items: [CommandPlanItem], plan: CommandPlanStamp,
                             assemblyID: UUID, owner: CommandHostOwnership) throws {
        for item in items {
            guard item.hasSupportedOrigins else { throw CommandMultiPlanIssue.unsupported }
            if let origin = item.executionOrigin {
                guard let record = planRevisions.origins[origin.id], record.origin == origin,
                      record.owner == owner, record.assemblyID == assemblyID, record.planID == plan.planID,
                      origin.returnID == nil || revisionChain(owner.hostID).contains(where: { $0.id == origin.returnID }) else {
                    throw CommandMultiPlanIssue.stale
                }
                if !origin.merged.isEmpty, planRevisions.mergedEvidence[origin.id] == nil {
                    guard let returned = origin.returnID.flatMap({ planRevisions.records[$0] }),
                          returned.run.snapshot.items.contains(where: { $0.id == item.id && $0.mergedOrigins == origin.merged }) else {
                        throw CommandMultiPlanIssue.stale
                    }
                }
            }
            for completion in item.links.completedPredecessors.values {
                guard revisionChain(owner.hostID).contains(where: { record in
                    record.owner == owner && record.assemblyID == assemblyID && record.run.stamp == completion.execution
                        && record.run.snapshot.items.contains { $0.stamp == completion.item }
                        && record.run.units.contains { $0.members.contains(completion.item.id) && $0.state == .succeeded }
                }) else { throw CommandMultiPlanIssue.stale }
            }
            for reference in item.links.results.values where reference.history != nil {
                _ = try historicalOutput(reference, owner: owner, assemblyID: assemblyID)
            }
        }
    }

    func revisionChain(_ hostID: String) -> [CommandPlanRevisionRecord] {
        var records: [CommandPlanRevisionRecord] = []
        var cursor = planRevisions.heads[hostID]
        while let id = cursor, let record = planRevisions.records[id] {
            records.append(record)
            cursor = record.parent
        }
        return records
    }

    func historicalOutput(_ reference: CommandCreationReference, owner: CommandHostOwnership,
                          assemblyID: UUID) throws -> CommandCreationOutput {
        guard let output = reference.history, output.producer == reference.producer, output.object.type == reference.outputType,
              revisionChain(owner.hostID).contains(where: {
                  $0.owner == owner && $0.assemblyID == assemblyID && $0.run.stamp == output.execution
                      && $0.outputs[reference.producer.id] == output
              }) else { throw CommandMultiPlanIssue.stale }
        return output
    }

    func preparePlanReturn(assemblyID: UUID, expecting lease: CommandHostLease) throws -> CommandPlanReturnTicket {
        let run = try returnableRun(assemblyID: assemblyID, expecting: lease)
        let ticket = CommandPlanReturnTicket(lease: lease, run: run, plan: try host(lease.ownership.hostID).session.plan.stamp)
        planRevisions.tickets = planRevisions.tickets.filter { $0.value.lease.ownership != lease.ownership }
        planRevisions.tickets[ticket.id] = ticket
        return ticket
    }

    /// 同步、无回调：全部候选构造成功后才登记历史并单次发布新的唯一编辑所有者。
    func returnPlan(_ ticket: CommandPlanReturnTicket, assemblyID: UUID, expecting lease: CommandHostLease) throws {
        guard ticket.lease == lease, planRevisions.tickets[ticket.id] == ticket else { throw CommandMultiPlanIssue.stale }
        let run = try returnableRun(assemblyID: assemblyID, expecting: lease)
        var session = try host(lease.ownership.hostID).session
        guard run.stamp == ticket.execution, session.plan.stamp == ticket.plan,
              run.units.filter({ $0.state != .succeeded }).map(\.members) == ticket.members else { throw CommandMultiPlanIssue.stale }
        var outputs: [UUID: CommandCreationOutput] = [:]
        for item in run.snapshot.items where run.units.contains(where: { $0.members.contains(item.id) && $0.state == .succeeded }) {
            if let type = CommandCatalog.standard.command(id: item.draft.commandID)?.createdObjectType {
                outputs[item.id] = try multiPlanOutput(.init(producer: item.stamp, outputType: type), in: run)
            }
        }
        let items = try returnedItems(run, outputs: outputs, returnID: ticket.id)
        try session.restorePlanRevision(items, from: run)
        let record = CommandPlanRevisionRecord(id: ticket.id, parent: planRevisions.heads[lease.ownership.hostID],
            owner: lease.ownership, assemblyID: assemblyID, run: run, outputs: outputs)
        for item in items { registerOrigin(item.executionOrigin!, plan: session.plan.stamp, assemblyID: assemblyID, owner: lease.ownership) }
        planRevisions.records[record.id] = record
        planRevisions.heads[lease.ownership.hostID] = record.id
        planRevisions.tickets[ticket.id] = nil
        publishPreferenceSession(session, from: lease)
    }

    private func returnableRun(assemblyID: UUID, expecting lease: CommandHostLease) throws -> CommandExecutionRun {
        try validate(lease)
        let session = try host(lease.ownership.hostID).session
        if session.execution?.hasUnknownCommit == true { throw CommandExecutionError.requiresVerification }
        if session.execution?.units.contains(where: { $0.local == .committed && $0.state != .succeeded }) == true {
            throw CommandMultiPlanIssue.externalPending
        }
        guard let run = session.execution, run.multiPlan != nil, multiPlans.assemblies[run.stamp] == assemblyID,
              !run.hasUnknownCommit, !run.isBusy, !hasInvocation(lease.ownership),
              session.plan.items.isEmpty, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              run.units.contains(where: { $0.state != .succeeded }), CommandPlanValidation.structure(run.snapshot.items).isEmpty else {
            throw CommandMultiPlanIssue.recoveryUnavailable
        }
        for unit in run.units {
            if unit.state == .succeeded {
                guard unit.hasConfirmedLocalSuccess, multiPlans.authorizations.values.contains(where: {
                    $0.attempt.execution == run.stamp && $0.attempt.unitID == unit.id && $0.attempt.phase == .local
                        && $0.assemblyID == assemblyID && wasAttemptInvoked($0.attempt)
                }) else { throw CommandMultiPlanIssue.recoveryUnavailable }
                continue
            }
            guard unit.local == .notSubmitted, unit.effects.isEmpty else { throw CommandMultiPlanIssue.recoveryUnavailable }
            if unit.attempt == 0 {
                guard unit.history.isEmpty, unit.receipt == nil,
                      !multiPlans.authorizations.keys.contains(where: { $0.execution == run.stamp && $0.unitID == unit.id }) else {
                    throw CommandMultiPlanIssue.recoveryUnavailable
                }
            } else {
                guard let attempt = run.attempt(unit.id) else { throw CommandMultiPlanIssue.stale }
                _ = try multiPlanRetryPermit(attempt, assemblyID: assemblyID, expecting: lease)
            }
        }
        return run
    }

    private func returnedItems(_ run: CommandExecutionRun, outputs: [UUID: CommandCreationOutput],
                               returnID: UUID) throws -> [CommandPlanItem] {
        let remaining = Set(run.units.filter { $0.state != .succeeded }.flatMap(\.members))
        let stamps = Dictionary(uniqueKeysWithValues: run.snapshot.items.filter { remaining.contains($0.id) }.map {
            ($0.stamp, CommandPlanItemStamp(id: $0.id, version: $0.version + 1))
        })
        return try run.snapshot.items.filter { remaining.contains($0.id) }.map { original in
            var item = original
            item.version += 1
            item.draft.reload(.init(), arguments: item.draft.arguments, expecting: item.draft.stamp)
            if let unit = run.units.first(where: { $0.members.contains(item.id) }), let attempt = run.attempt(unit.id), unit.attempt > 0 {
                item.returnedAttempts.append(attempt)
            }
            for predecessor in original.links.predecessors where !remaining.contains(predecessor) {
                guard let old = run.snapshot.items.first(where: { $0.id == predecessor }) else { throw CommandMultiPlanIssue.stale }
                item.links.predecessors.remove(predecessor)
                item.links.completedPredecessors[predecessor] = .init(execution: run.stamp, item: old.stamp)
            }
            for (parameter, reference) in original.links.results where reference.history == nil {
                if let stamp = stamps[reference.producer] {
                    item.links.results[parameter] = .init(producer: stamp, outputType: reference.outputType)
                } else {
                    guard let output = outputs[reference.producer.id] else { throw CommandMultiPlanIssue.stale }
                    item.links.results[parameter] = .init(producer: reference.producer, outputType: reference.outputType, history: output)
                }
            }
            item.executionOrigin = .init(item: item, returnID: returnID)
            return item
        }
    }

    private func registerOrigin(_ origin: CommandPlanExecutionOrigin, plan: CommandPlanStamp,
                                assemblyID: UUID, owner: CommandHostOwnership) {
        planRevisions.origins[origin.id] = .init(origin: origin, owner: owner, assemblyID: assemblyID, planID: plan.planID)
    }

    func prepareAssignmentMerge(_ earlier: CommandPlanItemStamp, _ later: CommandPlanItemStamp, baseline: CommandDraftBaseline,
                                sources: [CommandAssignmentMergeSource], assemblyID: UUID,
                                expecting lease: CommandHostLease) throws -> CommandAssignmentMergeProof {
        try validate(lease)
        let session = try host(lease.ownership.hostID).session
        guard session.execution == nil, session.plan.editing == nil, sources.count == 2, !baseline.values.isEmpty else {
            throw CommandMultiPlanIssue.stale
        }
        let proof = CommandAssignmentMergeProof(lease: lease, plan: session.plan, earlier: earlier, later: later, baseline: baseline, sources: sources)
        planRevisions.mergeProofs[proof.id] = proof
        planRevisions.mergeAssemblies[proof.id] = assemblyID
        return proof
    }

    func mergePlan(_ proof: CommandAssignmentMergeProof, assemblyID: UUID, expecting lease: CommandHostLease) throws {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        var session = try host(lease.ownership.hostID).session
        guard planRevisions.mergeProofs[proof.id] == proof, planRevisions.mergeAssemblies[proof.id] == assemblyID,
              proof.lease == lease, proof.plan == session.plan.stamp, proof.items == session.plan.items,
              session.execution == nil, var item = session.plan.items.first(where: { $0.stamp == proof.earlier }),
              let incoming = session.plan.items.first(where: { $0.stamp == proof.later }) else { throw CommandMultiPlanIssue.stale }
        try validatePlanOrigins(session.plan.items, plan: session.plan.stamp, assemblyID: assemblyID, owner: lease.ownership)
        item.mergedOrigins += [incoming.draft.stamp] + incoming.mergedOrigins
        let origin = CommandPlanExecutionOrigin(item: item, returnID: item.executionOrigin?.returnID)
        try session.mergePlanRevision(proof.earlier, proof.later, baseline: proof.baseline, origin: origin)
        registerOrigin(origin, plan: session.plan.stamp, assemblyID: assemblyID, owner: lease.ownership)
        planRevisions.mergedEvidence[origin.id] = proof
        planRevisions.mergeProofs[proof.id] = nil
        planRevisions.mergeAssemblies[proof.id] = nil
        publishPreferenceSession(session, from: lease)
    }
}
