import Foundation

/// 具体装配只持有原偏好与协调者。没有默认共享实例，也不持有可编辑设置或第二份计划。
@MainActor
final class LocalSettingCommandAdapter {
    private let coordinator: CommandHandoffCoordinator
    private let preferences: AppPreferences?
    private var isOperating = false
    private var issuedBaselines: [UUID: CommandPreferenceBaseline] = [:]
    private var reports: [CommandAttemptStamp: LocalSettingCommandReport] = [:]
    private var writes: [CommandExecutionStamp: LocalPreferenceWriteResult] = [:]
    private var confirmations: [UUID: LocalSettingConflictConfirmation] = [:]

    init(coordinator: CommandHandoffCoordinator, preferences: AppPreferences? = nil) {
        self.coordinator = coordinator
        self.preferences = preferences
    }

    func isAssembled(for coordinator: CommandHandoffCoordinator) -> Bool {
        self.coordinator === coordinator && preferences?.usesLegacyLocalPreferences == true
    }

    func supports(_ command: CommandID) -> Bool {
        preferences?.usesLegacyLocalPreferences != false && LocalSettingCommandMapping.field(for: command) != nil
    }

    /// 活动草稿预检不移交所有权；只有显式提交才由宿主 enqueue。
    func readiness(draft stamp: CommandDraftStamp, expecting lease: CommandHostLease) throws {
        guard !isOperating else { throw LocalSettingCommandIssue.busy }
        isOperating = true
        defer { isOperating = false }
        _ = try assembledPreferences()
        try coordinator.validate(lease)
        let session = try coordinator.host(lease.ownership.hostID).session
        guard session.execution == nil, session.plan.editing == nil, session.operations.pending == nil else {
            throw LocalSettingCommandIssue.busy
        }
        guard session.plan.items.isEmpty else { throw LocalSettingCommandIssue.multipleOperations }
        guard let draft = session.operations.active, draft.stamp == stamp else { throw LocalSettingCommandIssue.stale }
        let value = try LocalSettingCommandMapping.value(for: draft)
        try checkCurrent(baseline(for: draft), value: value)
        try coordinator.validate(lease)
    }

    private func assembledPreferences() throws -> AppPreferences {
        guard let preferences else { throw LocalSettingCommandIssue.unwired }
        // 文件模式由显式 FileLocalSettingCommandAdapter 接线；不可伪造旧键读回证据。
        guard preferences.usesLegacyLocalPreferences else { throw LocalSettingCommandIssue.unsupported }
        return preferences
    }

    /// 只读资格独立于目录；最终 execute 仍全部复核，不能凭这个报告直接调用 setter。
    func readiness(plan stamp: CommandPlanStamp, expecting lease: CommandHostLease) throws {
        guard !isOperating else { throw LocalSettingCommandIssue.busy }
        isOperating = true
        defer { isOperating = false }
        _ = try assembledPreferences()
        try coordinator.validate(lease)
        let session = try coordinator.host(lease.ownership.hostID).session
        guard session.plan.stamp == stamp else { throw LocalSettingCommandIssue.stale }
        guard session.execution == nil, session.plan.editing == nil, session.operations.pending == nil else {
            throw LocalSettingCommandIssue.busy
        }
        guard session.operations.active == nil, session.plan.items.count == 1 else {
            throw LocalSettingCommandIssue.multipleOperations
        }
        let item = session.plan.items[0]
        let value = try validateItem(item)
        let evidence = try baseline(for: item.draft)
        try checkCurrent(evidence, value: value)
        try coordinator.validate(lease)
    }

    /// 提交范围就是整个当前计划；绝不挑一项、拆原子组或循环单项写入。
    func submit(plan: CommandPlanStamp, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> LocalSettingCommandReport {
        guard !isOperating else { throw LocalSettingCommandIssue.busy }
        try displaySession?.validateDisplayHost(expecting: lease)
        try readiness(plan: plan, expecting: lease)
        try displaySession?.validateDisplayHost(expecting: lease)
        try coordinator.send(.sealPlan(plan, runID: UUID()), expecting: lease)
        var host = try coordinator.host(lease.ownership.hostID)
        guard let run = host.session.execution else { throw LocalSettingCommandIssue.stale }
        let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
        guard case .attempt(let attempt) = effect, let operation = run.operation(attempt.unitID) else {
            throw LocalSettingCommandIssue.stale
        }
        host = try coordinator.host(lease.ownership.hostID)
        return try execute(.init(lease: host.lease, operation: operation, attempt: attempt), displaySession: displaySession)
    }

    func execute(_ request: LocalSettingCommandRequest,
                 displaySession: ContentQueryReadSession? = nil) throws -> LocalSettingCommandReport {
        guard !isOperating else { throw LocalSettingCommandIssue.busy }
        isOperating = true
        defer { isOperating = false }
        let preferences = try assembledPreferences()
        let item = try executingItem(request)
        let value = try validateItem(item)
        let invocation = try coordinator.claimPreferenceInvocation(request.operation, attempt: request.attempt, expecting: request.lease)
        let evidence: CommandPreferenceBaseline
        do { evidence = try baseline(for: item.draft) } catch let issue as LocalSettingCommandIssue {
            return try finishRejection(issue, request: request, invocation: invocation, item: item)
        }
        let current = preferences.readLocalSetting(value.field)
        if let issue = currentIssue(evidence, current: current) {
            return try finishRejection(issue, request: request, invocation: invocation, item: item)
        }
        do {
            try coordinator.validatePreferenceInvocation(invocation)
            try displaySession?.validateDisplayHost(expecting: request.lease)
        } catch {
            return try finish(.failedWithoutCommit, outcome: .rejected(.stale), request: request, invocation: invocation)
        }
        if current.value == value {
            return try finish(.noChange, outcome: .noChange, request: request, invocation: invocation)
        }
        let result = preferences.applyLocalSetting(value, expecting: current) {
            try self.coordinator.validatePreferenceInvocation(invocation)
            try displaySession?.validateDisplayHost(expecting: request.lease)
        }
        return try finishWrite(result, request: request, invocation: invocation, item: item, evidence: evidence)
    }

    private func executingItem(_ request: LocalSettingCommandRequest) throws -> CommandPlanItem {
        try coordinator.validate(request.lease)
        let session = try coordinator.host(request.lease.ownership.hostID).session
        guard let run = session.execution, run.stamp == request.attempt.execution,
              run.operation(request.operation.operationID) == request.operation,
              run.attempt(request.attempt.unitID) == request.attempt else { throw LocalSettingCommandIssue.stale }
        guard run.snapshot.items.count == 1, run.units.count == 1, session.plan.items.isEmpty,
              session.operations.active == nil, session.operations.pending == nil else {
            throw LocalSettingCommandIssue.multipleOperations
        }
        guard request.attempt.phase == .local, run.units[0].state == .running,
              run.units[0].local == .notSubmitted, run.outputs.isEmpty,
              run.resolvedInput(request.operation.operationID)?.arguments == run.snapshot.items[0].draft.arguments,
              run.resolvedInput(request.operation.operationID)?.targets == CommandDraftTargets.none else {
            throw LocalSettingCommandIssue.stale
        }
        return run.snapshot.items[0]
    }

    private func validateItem(_ item: CommandPlanItem) throws -> LocalPreferenceValue {
        guard item.atomicGroup == nil, item.links.predecessors.isEmpty, item.links.results.isEmpty,
              CommandCatalog.standard.command(id: item.draft.commandID)?.createdObjectType == nil else {
            throw LocalSettingCommandIssue.unsupportedLinks
        }
        return try LocalSettingCommandMapping.value(for: item.draft)
    }

    private func baseline(for draft: CommandDraft) throws -> CommandPreferenceBaseline {
        guard let evidence = draft.baseline.preference else { throw LocalSettingCommandIssue.missingBaseline }
        let field = try LocalSettingCommandMapping.field(for: draft)
        let parameter: CommandParameterID = field == .stampCaptureApp ? .enabled : .value
        guard evidence.draftID == draft.id, evidence.commandID == draft.commandID,
              evidence.capturedVersion <= draft.version,
              draft.baseline.values == [.init(subject: .ambient, parameter: parameter): .uniform(evidence.memory)] else {
            throw LocalSettingCommandIssue.untrustedBaseline
        }
        let preferences = try assembledPreferences()
        if evidence.instanceID != preferences.localPreferenceSource.instanceID
            || evidence.storageID != preferences.localPreferenceSource.storageID {
            throw LocalSettingCommandIssue.conflict(.init(baseline: evidence, current: preferences.readLocalSetting(field)))
        }
        guard issuedBaselines[evidence.captureID] == evidence else {
            throw LocalSettingCommandIssue.untrustedBaseline
        }
        return evidence
    }

    private func checkCurrent(_ evidence: CommandPreferenceBaseline, value: LocalPreferenceValue) throws {
        let snapshot = try assembledPreferences().readLocalSetting(value.field)
        if let issue = currentIssue(evidence, current: snapshot) { throw issue }
    }

    private func currentIssue(_ evidence: CommandPreferenceBaseline, current: LocalPreferenceSnapshot) -> LocalSettingCommandIssue? {
        guard LocalSettingCommandMapping.matches(evidence, current) else {
            return .conflict(.init(baseline: evidence, current: current))
        }
        guard current.storedValue == current.value else { return .unreliableOriginal(current) }
        return nil
    }

    private func finish(_ result: CommandExecutionResult, outcome: LocalSettingCommandReport.Outcome,
                request: LocalSettingCommandRequest, invocation: CommandRuntimeInvocation) throws -> LocalSettingCommandReport {
        let report = LocalSettingCommandReport(operation: request.operation,
            receipt: .init(attempt: request.attempt, result: result), outcome: outcome)
        reports[request.attempt] = report
        try coordinator.completePreferenceInvocation(invocation, result: result)
        return report
    }

    private func finishRejection(_ issue: LocalSettingCommandIssue, request: LocalSettingCommandRequest,
                         invocation: CommandRuntimeInvocation, item: CommandPlanItem) throws -> LocalSettingCommandReport {
        if case .conflict(let conflict) = issue {
            let diagnostic = CommandFieldConflict(item: item.stamp,
                field: .init(subject: .ambient, parameter: item.draft.arguments[0].parameter), reason: .valueChanged)
            return try finish(.conflict([diagnostic]), outcome: .conflict(conflict), request: request, invocation: invocation)
        }
        return try finish(.failedWithoutCommit, outcome: .rejected(issue), request: request, invocation: invocation)
    }

    private func finishWrite(_ result: LocalPreferenceWriteResult, request: LocalSettingCommandRequest,
                     invocation: CommandRuntimeInvocation, item: CommandPlanItem,
                     evidence: CommandPreferenceBaseline) throws -> LocalSettingCommandReport {
        writes[request.attempt.execution] = result
        if result.rejection == .snapshotChanged, let current = result.before {
            return try finishRejection(.conflict(.init(baseline: evidence, current: current)),
                request: request, invocation: invocation, item: item)
        }
        let facts = CommandPreferenceWriteFacts(write: result.write, readback: result.readback,
            appearance: result.appearance, event: result.event)
        return try finish(.preferenceWrite(facts), outcome: .write(result), request: request, invocation: invocation)
    }
}

/// 确认绑定一次读取、宿主版本和草稿版本；不是可以长期保存的 force/authorized 开关。
struct LocalSettingConflictConfirmation: Equatable {
    let id: UUID
    let lease: CommandHostLease
    let draft: CommandDraftStamp
    let conflict: LocalSettingCommandConflict
    fileprivate init(lease: CommandHostLease, draft: CommandDraftStamp, conflict: LocalSettingCommandConflict) {
        id = UUID()
        self.lease = lease
        self.draft = draft
        self.conflict = conflict
    }
}

enum LocalSettingConflictChoice { case adoptCurrent, confirmOverwrite, continueEditing }

extension LocalSettingCommandAdapter {
    /// 为原 active/plan 草稿采集真实证据；已采集证据不因再次预览而静默刷新。
    @discardableResult
    func prepare(_ stamp: CommandDraftStamp, expecting lease: CommandHostLease) throws -> LocalPreferenceSnapshot {
        guard !isOperating else { throw LocalSettingCommandIssue.busy }
        isOperating = true
        defer { isOperating = false }
        let preferences = try assembledPreferences()
        let draft = try editableDraft(stamp, lease: lease)
        let field = try LocalSettingCommandMapping.field(for: draft)
        if !draft.arguments.isEmpty { _ = try LocalSettingCommandMapping.value(for: draft) }
        let current = preferences.readLocalSetting(field)
        guard current.storedValue == current.value else { throw LocalSettingCommandIssue.unreliableOriginal(current) }
        if draft.baseline.preference != nil {
            let evidence = try baseline(for: draft)
            if let issue = currentIssue(evidence, current: current) { throw issue }
            try coordinator.validate(lease)
        } else {
            try installBaseline(current, draft: draft, arguments: draft.arguments, lease: lease)
        }
        return current
    }

    func rereadConflict(_ stamp: CommandDraftStamp, expecting lease: CommandHostLease) throws -> LocalSettingConflictConfirmation {
        guard !isOperating else { throw LocalSettingCommandIssue.busy }
        isOperating = true
        defer { isOperating = false }
        let draft = try editableDraft(stamp, lease: lease)
        let value = try LocalSettingCommandMapping.value(for: draft)
        guard let evidence = draft.baseline.preference else { throw LocalSettingCommandIssue.missingBaseline }
        let current = try assembledPreferences().readLocalSetting(value.field)
        guard current.storedValue == current.value else { throw LocalSettingCommandIssue.unreliableOriginal(current) }
        try coordinator.validate(lease)
        let confirmation = LocalSettingConflictConfirmation(lease: lease, draft: stamp,
            conflict: .init(baseline: evidence, current: current))
        confirmations = [confirmation.id: confirmation]
        return confirmation
    }

    func resolveConflict(_ confirmation: LocalSettingConflictConfirmation, choice: LocalSettingConflictChoice) throws {
        guard !isOperating else { throw LocalSettingCommandIssue.busy }
        isOperating = true
        defer { isOperating = false }
        guard confirmations.removeValue(forKey: confirmation.id) == confirmation else { throw LocalSettingCommandIssue.stale }
        let draft = try editableDraft(confirmation.draft, lease: confirmation.lease)
        guard draft.baseline.preference == confirmation.conflict.baseline else { throw LocalSettingCommandIssue.stale }
        if choice == .continueEditing { return }
        let current = try assembledPreferences().readLocalSetting(confirmation.conflict.current.field)
        guard current == confirmation.conflict.current, current.storedValue == current.value else {
            throw LocalSettingCommandIssue.conflict(.init(baseline: confirmation.conflict.baseline, current: current))
        }
        let arguments = choice == .adoptCurrent
            ? [CommandArgument(parameter: LocalSettingCommandMapping.parameter(current.value), operation: .assign,
                               value: LocalSettingCommandMapping.commandValue(current.value))] : draft.arguments
        try installBaseline(current, draft: draft, arguments: arguments, lease: confirmation.lease)
    }

    func returnUnsubmittedToPlan(_ attempt: CommandAttemptStamp, expecting lease: CommandHostLease) throws {
        guard !isOperating else { throw LocalSettingCommandIssue.busy }
        try checkReturnToPlan(attempt, lease: lease)
        let host = try coordinator.host(lease.ownership.hostID)
        try coordinator.returnUnsubmittedPreference(attempt, plan: host.session.plan.stamp, expecting: lease)
    }

    func canReturnToPlan(_ attempt: CommandAttemptStamp, expecting lease: CommandHostLease) -> Bool {
        !isOperating && (try? checkReturnToPlan(attempt, lease: lease)) != nil
    }

    private func checkReturnToPlan(_ attempt: CommandAttemptStamp, lease: CommandHostLease) throws {
        guard let report = try report(for: attempt, expecting: lease) else { throw LocalSettingCommandIssue.notRetryable }
        switch report.outcome {
        case .rejected, .conflict: break
        case .write(let result) where result.write == .notCalled: break
        default: throw LocalSettingCommandIssue.notRetryable
        }
        // 在值快照上复用原转移校验，只读资格不发布候选状态。
        var candidate = try coordinator.host(lease.ownership.hostID).session
        try candidate.returnUnsubmittedPreference(attempt, expecting: candidate.plan.stamp)
    }

    private func editableDraft(_ stamp: CommandDraftStamp, lease: CommandHostLease) throws -> CommandDraft {
        try coordinator.validate(lease)
        let session = try coordinator.host(lease.ownership.hostID).session
        guard session.execution == nil, session.operations.pending == nil,
              let draft = session.allDrafts.first(where: { $0.stamp == stamp }),
              session.operations.active?.stamp == stamp || session.plan.items.contains(where: { $0.draft.stamp == stamp }) else {
            throw LocalSettingCommandIssue.stale
        }
        return draft
    }

    private func installBaseline(_ snapshot: LocalPreferenceSnapshot, draft: CommandDraft,
                                 arguments: [CommandArgument], lease: CommandHostLease) throws {
        let memory = LocalSettingCommandMapping.commandValue(snapshot.value)
        let evidence = CommandPreferenceBaseline(captureID: UUID(), draftID: draft.id, capturedVersion: draft.version + 1,
            commandID: draft.commandID, instanceID: snapshot.source.instanceID, storageID: snapshot.source.storageID,
            revision: snapshot.revision, raw: LocalSettingCommandMapping.raw(snapshot.raw), memory: memory,
            stored: snapshot.storedValue.map(LocalSettingCommandMapping.commandValue))
        let baseline = CommandDraftBaseline([.init(subject: .ambient,
            parameter: LocalSettingCommandMapping.parameter(snapshot.value)): .uniform(memory)], preference: evidence)
        try coordinator.replacePreferenceBaseline(baseline, arguments: arguments, draft: draft.stamp, expecting: lease)
        issuedBaselines[evidence.captureID] = evidence
    }
}

extension LocalSettingCommandAdapter {
    /// 仅投影本适配器实际登记且仍归属于当前运行/尝试的回执。
    func report(for attempt: CommandAttemptStamp, expecting lease: CommandHostLease) throws -> LocalSettingCommandReport? {
        try coordinator.validate(lease)
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution,
              run.stamp == attempt.execution, run.attempt(attempt.unitID) == attempt,
              let report = reports[attempt], run.operation(report.operation.operationID) == report.operation,
              run.units.first(where: { $0.id == attempt.unitID })?.receipt == report.receipt else { return nil }
        return report
    }

    func canRetryPresentation(_ attempt: CommandAttemptStamp, expecting lease: CommandHostLease) -> Bool {
        !isOperating && (try? presentationWrite(attempt, lease: lease)) != nil
    }

    private func presentationWrite(_ attempt: CommandAttemptStamp, lease: CommandHostLease) throws -> LocalPreferenceWriteResult {
        _ = try assembledPreferences()
        try coordinator.validate(lease)
        let session = try coordinator.host(lease.ownership.hostID).session
        guard session.plan.items.isEmpty, session.operations.active == nil, session.operations.pending == nil else {
            throw LocalSettingCommandIssue.multipleOperations
        }
        guard let previous = writes[attempt.execution], previous.write == .returned,
              previous.readback == .matches, previous.appearance == .threw || previous.event == .threw,
              let run = session.execution, run.stamp == attempt.execution,
              try report(for: attempt, expecting: lease) != nil else { throw LocalSettingCommandIssue.notRetryable }
        guard run.retryAssessment(attempt, assurance: .idempotentExternal([.preferencePresentation]))
                == .external([.preferencePresentation]) else { throw CommandExecutionError.notRetryable }
        return previous
    }

    /// 显式重试仅针对原运行的失败展示；偏好写入从不作为展示重试的一部分。
    func retryPresentation(_ attempt: CommandAttemptStamp, expecting lease: CommandHostLease,
                           displaySession: ContentQueryReadSession? = nil) throws -> LocalSettingCommandReport {
        guard !isOperating else { throw LocalSettingCommandIssue.busy }
        isOperating = true
        defer { isOperating = false }
        let preferences = try assembledPreferences()
        try displaySession?.validateDisplayHost(expecting: lease)
        let previous = try presentationWrite(attempt, lease: lease)
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution,
              let operation = run.operation(attempt.unitID) else { throw LocalSettingCommandIssue.notRetryable }
        try coordinator.send(.retry(attempt, .idempotentExternal([.preferencePresentation])), expecting: lease)
        var host = try coordinator.host(lease.ownership.hostID)
        let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
        guard case .attempt(let nextAttempt) = effect else { throw LocalSettingCommandIssue.stale }
        host = try coordinator.host(lease.ownership.hostID)
        let request = LocalSettingCommandRequest(lease: host.lease, operation: operation, attempt: nextAttempt)
        let invocation = try coordinator.claimPreferenceInvocation(operation, attempt: nextAttempt, expecting: host.lease)
        let presentation: CommandPreferencePresentation
        do {
            presentation = try preferences.retryLocalSettingPresentation(previous) {
                try self.coordinator.validatePreferenceInvocation(invocation)
                try displaySession?.validateDisplayHost(expecting: request.lease)
            }
        } catch {
            // 没有重复写偏好；未完成的展示仍保留失败，下一次须再次核验字段证据。
            presentation = .applied(appearance: previous.appearance, event: previous.event)
        }
        if case .applied(let appearance, let event) = presentation {
            var updated = previous
            updated.appearance = appearance
            updated.event = event
            writes[attempt.execution] = updated
        }
        return try finish(.preferencePresentation(presentation), outcome: .presentation(presentation),
            request: request, invocation: invocation)
    }
}
