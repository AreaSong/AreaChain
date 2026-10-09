import Foundation

/// 显式文件后端适配。旧 LocalSettingCommandAdapter 对此后端拒绝，二者不能执行同一操作。
@MainActor
final class FileLocalSettingCommandAdapter {
    private let coordinator: CommandHandoffCoordinator
    private let preferences: AppPreferences
    private let issuerID = UUID()
    private var isOperating = false
    private var preparedPlans: [UUID: CommandPlanStamp] = [:]
    private var issued: [UUID: (CommandPreferenceGroupBaseline, LocalPreferenceRecord)] = [:]
    private var reports: [CommandPreferenceGroupIdentity: FileLocalSettingCommandReport] = [:]
    private var commits: [CommandPreferenceGroupIdentity: LocalPreferenceFileCommit] = [:]
    private var multiPreviews: [UUID: FileMultiPlanPreview] = [:]
    private var confirmations: [UUID: (FileLocalSettingConflictConfirmation, LocalPreferenceRecord)] = [:]

    init(coordinator: CommandHandoffCoordinator, filePreferences: AppPreferences) throws {
        guard !filePreferences.usesLegacyLocalPreferences else { throw FileLocalSettingCommandIssue.unsupportedBackend }
        self.coordinator = coordinator
        preferences = filePreferences
    }

    func isAssembled(for coordinator: CommandHandoffCoordinator) -> Bool { self.coordinator === coordinator }

    /// 仅验证原计划事件的候选值；不建组、不读取或签发基线。
    func groupingEvent(plan stamp: CommandPlanStamp, expecting lease: CommandHostLease) throws -> CommandPlanEvent? {
        var candidate = try editablePlan(stamp, lease: lease)
        if candidate.items.count > 1, candidate.items.allSatisfy({ $0.atomicGroup == nil }) {
            let event = CommandPlanEvent.atomicGroup(UUID(), members: candidate.items.map(\.id))
            try candidate.apply(event, expecting: candidate.stamp)
            _ = try FileLocalSettingCommandMapping.values(candidate.items)
            return event
        }
        _ = try FileLocalSettingCommandMapping.values(candidate.items)
        return nil
    }

    func readiness(draft stamp: CommandDraftStamp, expecting lease: CommandHostLease) throws {
        try enter()
        defer { isOperating = false }
        try coordinator.validate(lease)
        let state = try coordinator.host(lease.ownership.hostID).session
        guard state.execution == nil, state.plan.items.isEmpty, state.operations.pending == nil,
              let draft = state.operations.active, draft.stamp == stamp else { throw FileLocalSettingCommandIssue.busy }
        let value = try LocalSettingCommandMapping.value(for: draft)
        try check(draft, current: readReady(), field: value.field)
    }

    /// 活动单项也签发完整记录，但不预建组、不移交草稿。旧基线只能显式解决冲突。
    @discardableResult
    func prepare(_ stamp: CommandDraftStamp, expecting lease: CommandHostLease) throws -> CommandPreferenceGroupBaseline {
        try enter()
        defer { isOperating = false }
        try coordinator.validate(lease)
        let session = try coordinator.host(lease.ownership.hostID).session
        guard session.execution == nil, session.operations.pending == nil, session.plan.editing == nil,
              let draft = session.allDrafts.first(where: { $0.stamp == stamp }),
              session.operations.active?.stamp == stamp || session.plan.items.contains(where: { $0.draft.stamp == stamp }) else {
            throw FileLocalSettingCommandIssue.stale
        }
        let value = try LocalSettingCommandMapping.value(for: draft)
        let current = try readReady()
        if draft.baseline.preferenceGroup != nil {
            try check(draft, current: current, field: value.field)
            return draft.baseline.preferenceGroup!
        }
        guard draft.baseline.preference == nil else { throw FileLocalSettingCommandIssue.untrustedBaseline }
        let evidence = try makeEvidence(current, group: nil, members: [], drafts: [draft])
        let baseline = baseline(evidence, for: value.field)
        try coordinator.replacePreferenceBaseline(baseline, arguments: draft.arguments, draft: stamp, expecting: lease)
        issued[evidence.captureID] = (evidence, current)
        return evidence
    }

    /// 调用方须先在原 Plan 明确建立连续原子组；全部检查后只发布一次计划。
    @discardableResult
    func prepareGroup(plan stamp: CommandPlanStamp, expecting lease: CommandHostLease) throws -> CommandPreferenceGroupBaseline {
        try enter()
        defer { isOperating = false }
        let plan = try editablePlan(stamp, lease: lease)
        let values = try FileLocalSettingCommandMapping.values(plan.items)
        let current = try readReady()
        var conflicts: [LocalPreferenceField] = []
        for (item, value) in zip(plan.items, values) {
            guard item.draft.baseline.preference == nil else { throw FileLocalSettingCommandIssue.untrustedBaseline }
            guard item.draft.baseline.preferenceGroup != nil else { continue }
            do { try check(item.draft, current: current, field: value.field) }
            catch FileLocalSettingCommandIssue.conflict(let fields) { conflicts += fields }
        }
        guard conflicts.isEmpty else { throw FileLocalSettingCommandIssue.conflict(conflicts) }
        return try install(current, plan: plan, lease: lease)
    }

    func readiness(plan stamp: CommandPlanStamp, expecting lease: CommandHostLease) throws {
        try enter()
        defer { isOperating = false }
        let plan = try editablePlan(stamp, lease: lease)
        _ = try qualifiedBaseline(plan.items, current: readReady(), plan: stamp)
        try coordinator.validate(lease)
    }

    func submit(plan stamp: CommandPlanStamp, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> FileLocalSettingCommandReport {
        try displaySession?.validateDisplayHost(expecting: lease)
        try readiness(plan: stamp, expecting: lease)
        try coordinator.send(.sealPlan(stamp, runID: UUID()), expecting: lease)
        var host = try coordinator.host(lease.ownership.hostID)
        guard let run = host.session.execution else { throw FileLocalSettingCommandIssue.stale }
        let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
        host = try coordinator.host(lease.ownership.hostID)
        guard case .attempt(let attempt) = effect, let identity = host.session.execution?.preferenceGroupIdentity() else {
            throw FileLocalSettingCommandIssue.stale
        }
        return try execute(.init(lease: host.lease, identity: identity, attempt: attempt), displaySession: displaySession)
    }

    func execute(_ request: FileLocalSettingCommandRequest, multi: FileMultiPlanPreview? = nil,
                 displaySession: ContentQueryReadSession? = nil) throws -> FileLocalSettingCommandReport {
        try enter()
        defer { isOperating = false }
        let items = try executingItems(request)
        let values = try FileLocalSettingCommandMapping.values(items, allowingDependencies: multi != nil)
        let invocation = try coordinator.claimPreferenceGroup(request.identity, attempt: request.attempt, expecting: request.lease)
        let baseline: LocalPreferenceRecord
        do {
            let snapshot = try coordinator.host(request.lease.ownership.hostID).session.execution!.snapshot
            baseline = try multi.map { try validateMulti($0, request: request, items: items) }
                ?? qualifiedBaseline(items, current: readReady(), plan: snapshot.stamp)
            try coordinator.validatePreferenceGroup(invocation)
            try displaySession?.validateDisplayHost(expecting: request.lease)
        } catch {
            let facts: CommandPreferenceGroupCommit
            if case FileLocalSettingCommandIssue.conflict(let fields) = error {
                facts = .conflict(FileLocalSettingCommandMapping.diagnostics(fields, items: items))
            } else if error as? FileLocalSettingCommandIssue == .backendNotReady { facts = .recoveryRequired }
            else { facts = .notCommitted }
            return try reject(facts, request: request, invocation: invocation)
        }
        var recorded = false
        var recordingError: Error?
        let result = preferences.applyLocalPreferences(basedOn: baseline, changes: values, validateBeforeCommit: {
            try self.coordinator.validatePreferenceGroup(invocation)
            try displaySession?.validateDisplayHost(expecting: request.lease)
        }, recordCommit: { result in
            do {
                try self.record(result, baseline: baseline, items: items, request: request, invocation: invocation)
                recorded = true
            } catch { recordingError = error }
        })
        if let recordingError { throw recordingError }
        if !recorded { try record(result, baseline: baseline, items: items, request: request, invocation: invocation) }
        return try finish(invocation, execution: request.identity.execution)
    }

    private func record(_ result: LocalPreferenceFileCommit, baseline: LocalPreferenceRecord, items: [CommandPlanItem],
                        request: FileLocalSettingCommandRequest, invocation: CommandPreferenceGroupInvocation) throws {
        commits[request.identity] = result
        let facts = try FileLocalSettingCommandMapping.facts(result, baseline: baseline, items: items)
        let values = try FileLocalSettingCommandMapping.values(items, allowingDependencies: true)
        reports[request.identity] = .init(identity: request.identity,
            localReceipt: .init(attempt: request.attempt, result: .preferenceGroupCommit(facts)),
            changedFields: Set(values.filter { baseline.values.value(for: $0.field) != $0 }.map(\.field)))
        try coordinator.recordPreferenceGroup(invocation, result: facts)
    }

    private func reject(_ facts: CommandPreferenceGroupCommit, request: FileLocalSettingCommandRequest,
                        invocation: CommandPreferenceGroupInvocation) throws -> FileLocalSettingCommandReport {
        reports[request.identity] = .init(identity: request.identity,
            localReceipt: .init(attempt: request.attempt, result: .preferenceGroupCommit(facts)), changedFields: [])
        try coordinator.recordPreferenceGroup(invocation, result: facts)
        return try finish(invocation, execution: request.identity.execution)
    }

    private func finish(_ invocation: CommandPreferenceGroupInvocation,
                        execution: CommandExecutionStamp) throws -> FileLocalSettingCommandReport {
        guard var report = reports[invocation.identity] else { throw FileLocalSettingCommandIssue.stale }
        let run = try coordinator.host(invocation.lease.ownership.hostID).session.execution
        var presentation: CommandPreferenceGroupPresentation?
        if case .committed(let identity, _) = run?.units.first(where: { $0.id == invocation.identity.unitID })?.preferenceGroupCommit {
            presentation = FileLocalSettingCommandMapping.presentation(preferences.localPreferencePresentation(for: identity.commitID))
        }
        report.presentationReceipt = try coordinator.finishPreferenceGroup(invocation, presentation: presentation)
        reports[invocation.identity] = report
        return report
    }

    func report(for execution: CommandExecutionStamp, unitID: UUID? = nil,
                expecting lease: CommandHostLease) throws -> FileLocalSettingCommandReport? {
        try coordinator.validate(lease)
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution,
              run.stamp == execution, let identity = run.preferenceGroupIdentity(unitID: unitID),
              let report = reports[identity], run.attempt(identity.unitID) == report.latestAttempt,
              run.units.first(where: { $0.id == identity.unitID })?.receipt == (report.presentationReceipt ?? report.localReceipt) else { return nil }
        return report
    }

    func returnUnsubmittedToPlan(_ attempt: CommandAttemptStamp, expecting lease: CommandHostLease) throws {
        try enter()
        defer { isOperating = false }
        guard let report = try report(for: attempt.execution, unitID: attempt.unitID, expecting: lease), report.localReceipt.attempt == attempt else {
            throw FileLocalSettingCommandIssue.notRetryable
        }
        switch report.localReceipt.result {
        case .preferenceGroupCommit(.notCommitted), .preferenceGroupCommit(.conflict), .preferenceGroupCommit(.recoveryRequired): break
        default: throw FileLocalSettingCommandIssue.notRetryable
        }
        let plan = try coordinator.host(lease.ownership.hostID).session.plan
        try coordinator.returnUnsubmittedPreference(attempt, plan: plan.stamp, expecting: lease)
    }

    func rereadConflict(plan stamp: CommandPlanStamp, expecting lease: CommandHostLease) throws -> FileLocalSettingConflictConfirmation {
        try enter()
        defer { isOperating = false }
        let plan = try editablePlan(stamp, lease: lease)
        let values = try FileLocalSettingCommandMapping.values(plan.items)
        let current = try readReady()
        var fields: Set<LocalPreferenceField> = []
        for (item, value) in zip(plan.items, values) {
            guard item.draft.baseline.preference == nil else { throw FileLocalSettingCommandIssue.untrustedBaseline }
            guard item.draft.baseline.preferenceGroup != nil else { continue }
            let old = try signedRecord(item.draft)
            fields.formUnion(FileLocalSettingCommandMapping.conflicts(old, current: current, fields: [value.field]))
        }
        guard !fields.isEmpty else { throw FileLocalSettingCommandIssue.missingBaseline }
        let differences = try plan.items.compactMap { item -> FileLocalSettingConflictDifference? in
            let field = try LocalSettingCommandMapping.field(for: item.draft)
            guard fields.contains(field) else { return nil }
            let old = try signedRecord(item.draft)
            return .init(command: item.draft.commandID,
                baseline: LocalSettingCommandMapping.commandValue(old.values.value(for: field)),
                current: LocalSettingCommandMapping.commandValue(current.values.value(for: field)))
        }
        let confirmation = FileLocalSettingConflictConfirmation(id: UUID(), lease: lease, plan: stamp,
            members: plan.items.map(\.stamp), affectedFields: fields, differences: differences)
        confirmations = [confirmation.id: (confirmation, current)]
        return confirmation
    }

    func resolveConflict(_ confirmation: FileLocalSettingConflictConfirmation, choice: LocalSettingConflictChoice) throws {
        try enter()
        defer { isOperating = false }
        guard let registered = confirmations.removeValue(forKey: confirmation.id), registered.0 == confirmation else {
            throw FileLocalSettingCommandIssue.stale
        }
        let plan = try editablePlan(confirmation.plan, lease: confirmation.lease)
        guard plan.items.map(\.stamp) == confirmation.members else { throw FileLocalSettingCommandIssue.stale }
        if choice == .continueEditing { return }
        let current = try readReady()
        guard current == registered.1 else { throw FileLocalSettingCommandIssue.stale }
        _ = try install(current, plan: plan, lease: confirmation.lease, adoptCurrent: choice == .adoptCurrent)
    }

    /// 核验只复用 AppPreferences 恢复；原 pending 目标摘要与原 attempt 必须精确对应。
    func verifyCommit(_ attempt: CommandAttemptStamp, expecting lease: CommandHostLease) throws -> FileLocalSettingCommandReport {
        try enter()
        defer { isOperating = false }
        guard var report = try report(for: attempt.execution, unitID: attempt.unitID, expecting: lease), report.latestAttempt == attempt,
              report.localReceipt.attempt == attempt, report.verificationReceipt == nil,
              case .unknown(let pending, _) = commits[report.identity] else { throw FileLocalSettingCommandIssue.notRetryable }
        let invocation = try coordinator.claimPreferenceGroup(report.identity, attempt: attempt, expecting: lease, verification: true)
        try coordinator.validatePreferenceGroup(invocation)
        var recordingError: Error?
        let recovery = preferences.verifyAndReloadLocalPreferences { candidate, cleanup in
            guard (try? pending.target.matches(candidate)) == true, candidate.parentCommitID == pending.base?.commitID else { return }
            do {
                let facts = CommandPreferenceGroupCommit.committed(try FileLocalSettingCommandMapping.identity(candidate), cleanupPending: cleanup)
                try self.coordinator.recordPreferenceGroup(invocation, result: facts)
                report.verificationReceipt = .init(attempt: attempt, result: .preferenceGroupCommit(facts))
            } catch { recordingError = error }
        }
        if let recordingError { throw recordingError }
        report.recovery = recovery
        reports[report.identity] = report
        return try finish(invocation, execution: attempt.execution)
    }

    func retryPresentation(_ attempt: CommandAttemptStamp, expecting lease: CommandHostLease,
                           displaySession: ContentQueryReadSession? = nil) throws -> FileLocalSettingCommandReport {
        try enter()
        defer { isOperating = false }
        try displaySession?.validateDisplayHost(expecting: lease)
        guard let report = try report(for: attempt.execution, unitID: attempt.unitID, expecting: lease), report.latestAttempt == attempt,
              let run = try coordinator.host(lease.ownership.hostID).session.execution,
              case .committed(let identity, _) = run.units.first(where: { $0.id == attempt.unitID })?.preferenceGroupCommit else {
            throw FileLocalSettingCommandIssue.notRetryable
        }
        try coordinator.send(.retry(attempt, .idempotentExternal([.preferencePresentation])), expecting: lease)
        var host = try coordinator.host(lease.ownership.hostID)
        let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
        host = try coordinator.host(lease.ownership.hostID)
        guard case .attempt(let next) = effect else { throw FileLocalSettingCommandIssue.stale }
        let invocation = try coordinator.claimPreferenceGroup(report.identity, attempt: next, expecting: host.lease)
        try coordinator.validatePreferenceGroup(invocation)
        preferences.retryLocalPreferencePresentation(for: identity.commitID)
        return try finish(invocation, execution: attempt.execution)
    }

    var multiBackendNeedsRecovery: Bool { preferences.localPreferenceBackend != .ready }

    func recoverMultiBackend(_ attempt: CommandAttemptStamp, expecting lease: CommandHostLease) throws {
        try enter()
        defer { isOperating = false }
        try coordinator.validate(lease)
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution, run.multiPlan != nil,
              !run.hasUnknownCommit, run.attempt(attempt.unitID) == attempt,
              let unit = run.units.first(where: { $0.id == attempt.unitID }), unit.local == .notSubmitted,
              unit.preferenceGroupCommit != nil else { throw FileLocalSettingCommandIssue.notRetryable }
        try coordinator.withMultiPlanPreparation(expecting: lease) {
            _ = preferences.verifyAndReloadLocalPreferences()
        }
    }

    func canRetryMultiPresentation(_ attempt: CommandAttemptStamp, expecting lease: CommandHostLease) -> Bool {
        guard !isOperating, let run = try? coordinator.host(lease.ownership.hostID).session.execution,
              run.retryAssessment(attempt, assurance: .idempotentExternal([.preferencePresentation])) == .external([.preferencePresentation])
        else { return false }
        return (try? report(for: attempt.execution, unitID: attempt.unitID, expecting: lease)) != nil
    }

    func prepareMulti(_ items: [CommandPlanItem], lease: CommandHostLease,
                      plan: CommandPlanStamp) throws -> FileMultiPlanPreview {
        try enter()
        defer { isOperating = false }
        let values = try FileLocalSettingCommandMapping.values(items, allowingDependencies: true)
        let record = try readReady()
        let unitID = items[0].atomicGroup ?? items[0].id
        if let old = multiPreviews[unitID], old.lease == lease, old.plan == plan,
           old.members == items.map(\.stamp), old.values == values, old.record == record { return old }
        let result = FileMultiPlanPreview(id: UUID(), lease: lease, plan: plan, members: items.map(\.stamp),
                                         unitID: unitID, values: values, record: record)
        multiPreviews[unitID] = result
        return result
    }

    private func validateMulti(_ preview: FileMultiPlanPreview, request: FileLocalSettingCommandRequest,
                               items: [CommandPlanItem]) throws -> LocalPreferenceRecord {
        guard multiPreviews[preview.unitID] == preview, preview.plan == request.identity.execution.plan,
              preview.unitID == request.identity.unitID, preview.members == request.identity.members,
              preview.lease.ownership == request.lease.ownership,
              let authorization = coordinator.multiPlans.authorizations[request.attempt],
              authorization.acceptanceID == preview.id, authorization.previewLease == preview.lease else {
            throw FileLocalSettingCommandIssue.stale
        }
        let values = try FileLocalSettingCommandMapping.values(items, allowingDependencies: true)
        guard values == preview.values else { throw FileLocalSettingCommandIssue.stale }
        let conflicts = FileLocalSettingCommandMapping.conflicts(preview.record, current: try readReady(), fields: values.map(\.field))
        guard conflicts.isEmpty else { throw FileLocalSettingCommandIssue.conflict(conflicts) }
        return preview.record
    }

    private func enter() throws {
        guard !isOperating else { throw FileLocalSettingCommandIssue.busy }
        isOperating = true
    }

    private func readReady() throws -> LocalPreferenceRecord {
        guard preferences.localPreferenceBackend == .ready,
              case .record(let record) = preferences.readLocalPreferenceRecord(),
              let published = preferences.committedLocalPreferenceRecord,
              LocalPreferencePublishedState.committed(published).acceptsReload(record) else {
            throw FileLocalSettingCommandIssue.backendNotReady
        }
        return record
    }

    private func editablePlan(_ stamp: CommandPlanStamp, lease: CommandHostLease) throws -> CommandPlan {
        try coordinator.validate(lease)
        let session = try coordinator.host(lease.ownership.hostID).session
        guard session.plan.stamp == stamp else { throw FileLocalSettingCommandIssue.stale }
        guard session.execution == nil, session.plan.editing == nil, session.operations.pending == nil,
              session.operations.active == nil else { throw FileLocalSettingCommandIssue.busy }
        return session.plan
    }

    private func executingItems(_ request: FileLocalSettingCommandRequest) throws -> [CommandPlanItem] {
        try coordinator.validate(request.lease)
        let session = try coordinator.host(request.lease.ownership.hostID).session
        guard let run = session.execution, run.preferenceGroupIdentity(unitID: request.identity.unitID) == request.identity,
              run.attempt(request.attempt.unitID) == request.attempt, request.attempt.phase == .local,
              let unit = run.units.first(where: { $0.id == request.identity.unitID }), unit.state == .running,
              unit.local == .notSubmitted, !run.hasUnknownCommit,
              session.plan.items.isEmpty, session.operations.active == nil, session.operations.pending == nil else {
            throw FileLocalSettingCommandIssue.stale
        }
        let items = run.snapshot.items.filter { unit.members.contains($0.id) }
        guard items.allSatisfy({ run.outputs[$0.id] == nil
            && run.resolvedInput($0.id)?.arguments == $0.draft.arguments
            && run.resolvedInput($0.id)?.targets == CommandDraftTargets.none }) else { throw FileLocalSettingCommandIssue.stale }
        return items
    }

    private func signedRecord(_ draft: CommandDraft) throws -> LocalPreferenceRecord {
        guard let evidence = draft.baseline.preferenceGroup else { throw FileLocalSettingCommandIssue.missingBaseline }
        guard let signed = issued[evidence.captureID], signed.0 == evidence, evidence.issuerID == issuerID,
              evidence.instanceID == preferences.localPreferenceSource.instanceID,
              evidence.storageID == preferences.localPreferenceSource.storageID,
              let index = evidence.drafts.firstIndex(where: { $0.draftID == draft.id && $0.hostID == draft.hostID && $0.version <= draft.version }),
              evidence.commands[index] == draft.commandID,
              let field = LocalSettingCommandMapping.field(for: draft.commandID),
              draft.baseline == baseline(evidence, for: field) else { throw FileLocalSettingCommandIssue.untrustedBaseline }
        return signed.1
    }

    private func check(_ draft: CommandDraft, current: LocalPreferenceRecord, field: LocalPreferenceField) throws {
        let fields = FileLocalSettingCommandMapping.conflicts(try signedRecord(draft), current: current, fields: [field])
        guard fields.isEmpty else { throw FileLocalSettingCommandIssue.conflict(fields) }
    }

    private func qualifiedBaseline(_ items: [CommandPlanItem], current: LocalPreferenceRecord, plan: CommandPlanStamp) throws -> LocalPreferenceRecord {
        let values = try FileLocalSettingCommandMapping.values(items)
        var conflicts: [LocalPreferenceField] = []
        for (item, value) in zip(items, values) {
            do { try check(item.draft, current: current, field: value.field) }
            catch FileLocalSettingCommandIssue.conflict(let fields) { conflicts += fields }
        }
        guard conflicts.isEmpty else { throw FileLocalSettingCommandIssue.conflict(conflicts) }
        let record = try signedRecord(items[0].draft)
        if items.count > 1 {
            guard let evidence = items[0].draft.baseline.preferenceGroup,
                  preparedPlans[evidence.captureID] == plan,
                  evidence.groupID == items[0].atomicGroup, evidence.members == items.map(\.stamp),
                  evidence.drafts == items.map({ $0.draft.stamp }),
                  items.allSatisfy({ $0.draft.baseline.preferenceGroup == evidence }) else { throw FileLocalSettingCommandIssue.missingBaseline }
        }
        return record
    }

    private func makeEvidence(_ record: LocalPreferenceRecord, group: UUID?, members: [CommandPlanItemStamp],
                              drafts: [CommandDraft]) throws -> CommandPreferenceGroupBaseline {
        let commands = FileLocalSettingCommandMapping.commands
        return try .init(captureID: UUID(), issuerID: issuerID, instanceID: preferences.localPreferenceSource.instanceID,
            storageID: preferences.localPreferenceSource.storageID, record: FileLocalSettingCommandMapping.identity(record),
            migrationID: record.migrationID,
            fieldRevisions: Dictionary(uniqueKeysWithValues: commands.map { ($0, record.fieldRevisions[LocalSettingCommandMapping.field(for: $0)!]) }),
            values: Dictionary(uniqueKeysWithValues: commands.map {
                ($0, LocalSettingCommandMapping.commandValue(record.values.value(for: LocalSettingCommandMapping.field(for: $0)!)))
            }), groupID: group, members: members,
            drafts: drafts.map { .init(hostID: $0.hostID, draftID: $0.id, version: $0.version + 1) }, commands: drafts.map(\.commandID))
    }

    private func baseline(_ evidence: CommandPreferenceGroupBaseline, for field: LocalPreferenceField) -> CommandDraftBaseline {
        let command = FileLocalSettingCommandMapping.commands.first { LocalSettingCommandMapping.field(for: $0) == field }!
        return .init([.init(subject: .ambient, parameter: field == .stampCaptureApp ? .enabled : .value):
            .uniform(evidence.values[command]!)], preferenceGroup: evidence)
    }

    private func install(_ current: LocalPreferenceRecord, plan: CommandPlan, lease: CommandHostLease,
                         adoptCurrent: Bool = false) throws -> CommandPreferenceGroupBaseline {
        let evidence = try makeEvidence(current, group: plan.items[0].atomicGroup,
            members: plan.items.map { .init(id: $0.id, version: $0.version + 1) }, drafts: plan.items.map(\.draft))
        let updates = try plan.items.map { item in
            let field = try LocalSettingCommandMapping.field(for: item.draft)
            let value = current.values.value(for: field)
            let arguments = adoptCurrent ? [CommandArgument(parameter: LocalSettingCommandMapping.parameter(value),
                operation: .assign, value: LocalSettingCommandMapping.commandValue(value))] : item.draft.arguments
            return CommandPreferenceBaselineUpdate(draft: item.draft.stamp, baseline: baseline(evidence, for: field), arguments: arguments)
        }
        try coordinator.replacePreferenceGroupBaselines(updates, plan: plan.stamp, expecting: lease)
        issued[evidence.captureID] = (evidence, current)
        preparedPlans[evidence.captureID] = try coordinator.host(lease.ownership.hostID).session.plan.stamp
        return evidence
    }
}
