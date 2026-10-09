import Foundation

struct MultiPlanMergeProposal: Equatable {
    let id: UUID
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let earlier: CommandPlanItemStamp
    let later: CommandPlanItemStamp
    let baseline: CommandDraftBaseline
    let reads: [MultiPlanCommandMemberPreview]
    let proof: CommandAssignmentMergeProof
}

extension MultiPlanCommandAdapter {
    func proposeMerge(_ earlier: CommandPlanItemStamp, _ later: CommandPlanItemStamp,
                      expecting lease: CommandHostLease) throws -> MultiPlanMergeProposal {
        try enter()
        defer { finishOperation() }
        guard supportsRevisions else { throw CommandMultiPlanIssue.unsupported }
        try coordinator.validate(lease)
        let session = try coordinator.host(lease.ownership.hostID).session
        guard session.execution == nil, session.plan.editing == nil,
              let first = session.plan.items.firstIndex(where: { $0.stamp == earlier }),
              let last = session.plan.items.firstIndex(where: { $0.stamp == later }), last == first + 1 else {
            throw CommandMultiPlanIssue.stale
        }
        try coordinator.validatePlanOrigins(session.plan.items, plan: session.plan.stamp, assemblyID: id, owner: lease.ownership)
        let items = [session.plan.items[first], session.plan.items[last]]
        let reads = try items.map { try read($0, family: family(for: $0.draft.commandID), lease: lease, plan: session.plan.stamp) }
        let baseline = try mergeBaseline(reads, items: items)
        var projected = session.plan.items
        for index in [first, last] {
            projected[index].draft.reload(baseline, arguments: projected[index].draft.arguments, expecting: projected[index].draft.stamp)
        }
        if let issue = CommandPlanSemantics.mergeConflict(projected, earlier: first, later: last) {
            throw CommandPlanError.mergeConflict(issue)
        }
        try coordinator.validate(lease)
        let proof = try coordinator.prepareAssignmentMerge(earlier, later, baseline: baseline,
            sources: reads.map(mergeSource), assemblyID: id, expecting: lease)
        let proposal = MultiPlanMergeProposal(id: UUID(), lease: lease, plan: session.plan.stamp,
            earlier: earlier, later: later, baseline: baseline, reads: reads, proof: proof)
        mergeProposal = proposal
        return proposal
    }

    func acceptMerge(_ proposal: MultiPlanMergeProposal, expecting lease: CommandHostLease) throws {
        try enter()
        defer { finishOperation() }
        guard supportsRevisions, mergeProposal == proposal, proposal.lease == lease else { throw CommandMultiPlanIssue.stale }
        try coordinator.validate(lease)
        let session = try coordinator.host(lease.ownership.hostID).session
        guard session.execution == nil, session.plan.stamp == proposal.plan else { throw CommandMultiPlanIssue.stale }
        let items = try [proposal.earlier, proposal.later].map { stamp in
            guard let item = session.plan.items.first(where: { $0.stamp == stamp }) else { throw CommandMultiPlanIssue.stale }
            return item
        }
        let reads = try items.map { try read($0, family: family(for: $0.draft.commandID), lease: lease, plan: session.plan.stamp) }
        guard reads == proposal.reads, try mergeBaseline(reads, items: items) == proposal.baseline else {
            mergeProposal = nil
            throw CommandMultiPlanIssue.stale
        }
        try coordinator.mergePlan(proposal.proof, assemblyID: id, expecting: lease)
        mergeProposal = nil
        invalidatePresentation()
    }

    private func mergeSource(_ preview: MultiPlanCommandMemberPreview) throws -> CommandAssignmentMergeSource {
        switch preview {
        case .taskField(let value): .task(value)
        case .routine(let value): .routine(value)
        case .localSetting(let value): .local(value.evidence)
        case .fileSettings(let value): try .file(FileLocalSettingCommandMapping.identity(value.record))
        default: throw CommandMultiPlanIssue.unsupported
        }
    }

    private func mergeBaseline(_ reads: [MultiPlanCommandMemberPreview], items: [CommandPlanItem]) throws -> CommandDraftBaseline {
        guard items[0].draft.commandID == items[1].draft.commandID,
              items[0].draft.targets == items[1].draft.targets,
              let parameter = items[0].draft.arguments.first?.parameter else { throw CommandMultiPlanIssue.unsupported }
        let value: CommandValue
        switch (reads[0], reads[1]) {
        case (.taskField(let first), .taskField(let last)):
            guard first.source == last.source, first.catalog == last.catalog, first.target == last.target,
                  first.record != nil, first.record == last.record, first.original == last.original,
                  first.tagIDs == last.tagIDs, let original = first.original.value else { throw CommandMultiPlanIssue.stale }
            value = original
        case (.routine(let first), .routine(let last)):
            guard first.source == last.source, first.catalog == last.catalog, first.record == last.record,
                  first.target == last.target, first.original == last.original, first.tagIDs == last.tagIDs,
                  case .flag(let important) = first.original[.isImportant],
                  case .flag(let urgent) = first.original[.isUrgent] else { throw CommandMultiPlanIssue.stale }
            value = .choice(important ? (urgent ? "p1" : "p2") : (urgent ? "p3" : "p4"))
        case (.localSetting(let first), .localSetting(let last)):
            guard first.current == last.current, first.value.field == last.value.field else { throw CommandMultiPlanIssue.stale }
            value = LocalSettingCommandMapping.commandValue(first.current.value)
        case (.fileSettings(let first), .fileSettings(let last)):
            guard first.record == last.record, first.values.count == 1, last.values.count == 1,
                  first.values[0].field == last.values[0].field else { throw CommandMultiPlanIssue.stale }
            value = LocalSettingCommandMapping.commandValue(first.record.values.value(for: first.values[0].field))
        default: throw CommandMultiPlanIssue.unsupported
        }
        let targets = items[0].draft.targets.objects
        let subjects: [CommandDraftBaseline.Subject] = targets.isEmpty ? [.ambient] : targets.map(CommandDraftBaseline.Subject.object)
        return .init(Dictionary(uniqueKeysWithValues: subjects.map { (.init(subject: $0, parameter: parameter), .uniform(value)) }))
    }
}
