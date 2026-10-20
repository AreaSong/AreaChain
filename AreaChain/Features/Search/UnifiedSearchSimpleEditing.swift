import Foundation

/// X-1 简单指令的预览、接受、提交与未知核对只是原 Plan/Run 之外的不可编辑投影；草稿与计划仍归 Coordinator。
extension UnifiedSearchController {
    var showsSimple: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
            + (settingExecution?.snapshot.items.map(\.draft) ?? [])
        return drafts.contains { routesSimple($0.commandID) }
    }

    func routesSimple(_ command: CommandID) -> Bool { simple?.supports(command) == true }

    /// 由简单骨架经托管执行的普通长文草稿；受保护、required、unknown 不算。
    func escrowsLongText(_ draft: CommandDraft) -> Bool {
        routesSimple(draft.commandID) && simple?.isLongText(draft.commandID) == true && !draft.blocksUnprotectedTransfer
    }

    var hasSimple: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
        return drafts.count == 1 && drafts.allSatisfy { routesSimple($0.commandID) }
    }

    var currentSimplePreview: CommandSimplePreview? {
        guard operationVisible, let preview = simplePreview, let simple,
              (try? simple.validatePreview(preview, expecting: buffer.lease, displaySession: session)) != nil else { return nil }
        return preview
    }

    var currentSimpleAcceptance: CommandSimpleAcceptance? {
        guard let accepted = simpleAcceptance, accepted.preview == currentSimplePreview else { return nil }
        return accepted
    }

    var simpleUnit: CommandExecutionUnit? {
        guard operationVisible, let run = settingExecution, run.snapshot.items.count == 1,
              run.snapshot.items.first.map({ routesSimple($0.draft.commandID) }) == true else { return nil }
        return run.units.first
    }

    func revokeSimple() {
        simplePreview = nil
        simpleAcceptance = nil
    }

    private func checkSimple(_ source: UnifiedSearchBuffer) throws {
        guard validates(source), operationVisible else { throw CommandSimpleIssue.stale }
        guard hasSimple else { throw CommandSimpleIssue.unsupportedPlan }
        guard editingParameter == nil, tagSelection == nil, objectSelectionLocation == nil, !objectSelectionLoading,
              settingExecution == nil, let operations, operations.pending == nil, operations.retained.isEmpty,
              let plan, plan.editing == nil, plan.stamp == source.plan else {
            throw CommandSimpleIssue.unsupportedPlan
        }
        if let draft = operations.active {
            guard plan.items.isEmpty, draft.stamp == source.operation, routesSimple(draft.commandID) else {
                throw CommandSimpleIssue.unsupportedPlan
            }
            guard draft.check().staticallyValid else { throw CommandSimpleIssue.invalidArguments }
        }
        try session.validateDisplayHost(expecting: source.lease)
    }

    private func simpleAction(_ source: UnifiedSearchBuffer, _ work: () throws -> Void) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkSimple(source)
            try work()
            simpleFailure = nil
        } catch { simpleFailure = UnifiedSearchSimpleCopy.error(error) }
    }

    func prepareSimple(_ source: UnifiedSearchBuffer) {
        simpleAction(source) {
            revokeSimple()
            if let draft = operations?.active, let plan {
                try coordinator.send(.enqueue(draft.stamp, itemID: UUID(), plan: plan.stamp), expecting: source.lease)
                _ = publishOperation(text: buffer.text)
            }
            guard let plan, let simple else { throw CommandSimpleIssue.stale }
            simplePreview = try simple.prepare(plan: plan.stamp, expecting: buffer.lease, displaySession: session)
        }
    }

    func acceptSimple(_ preview: CommandSimplePreview, source: UnifiedSearchBuffer) {
        simpleAction(source) {
            guard simplePreview == preview, let simple else { throw CommandSimpleIssue.stale }
            simpleAcceptance = nil
            simpleAcceptance = try simple.accept(preview, expecting: source.lease, displaySession: session)
        }
    }

    /// 按钮与 ⌘Return 共用；只提交已接受的同一份预览。
    func submitSimple(_ source: UnifiedSearchBuffer) {
        guard settingExecution == nil else { return }
        simpleAction(source) {
            guard let accepted = currentSimpleAcceptance, let simple else { throw CommandSimpleIssue.stale }
            do {
                _ = try simple.submit(accepted: accepted, expecting: source.lease, displaySession: session)
            } catch {
                // 失败前的原因要求重新预览；已进入 Run 的结果仍由原 Run 展示。
                simpleAcceptance = nil
                if settingExecution == nil { simplePreview = nil }
                if settingExecution != nil { _ = publishOperation(text: buffer.text) }
                throw error
            }
            _ = publishOperation(text: buffer.text)
            planMessage = "unified.plan.notExecutable"
        }
    }

    /// 长文 Run 未提交、取消未开始、锁定阻塞或核为未写入时可以返回编辑：托管正文还回草稿，须重新预览。
    var simpleReturnable: Bool {
        guard let simple, let unit = simpleUnit, let run = settingExecution,
              run.snapshot.items.first.map({ simple.isLongText($0.draft.commandID) }) == true else { return false }
        return unit.simple?.state == .notSubmitted || unit.state == .notExecuted
            || unit.simple?.state == .unknown && simpleVerification?.outcome == .notApplied
    }

    func returnSimpleLongText(_ source: UnifiedSearchBuffer) {
        guard validates(source), let simple, let run = settingExecution, simpleReturnable else { return }
        do {
            try simple.returnLongText(run.stamp, expecting: source.lease, displaySession: session)
            revokeSimple()
            simpleVerification = nil
            simpleFailure = nil
            _ = publishOperation(text: buffer.text)
        } catch { simpleFailure = UnifiedSearchSimpleCopy.error(error) }
    }

    /// 只读核对未知结果；不自动重试、不恢复同一计划的执行资格。
    func verifySimpleUnknown(_ source: UnifiedSearchBuffer) {
        guard validates(source), let simple, let run = settingExecution, let unit = simpleUnit,
              unit.simple?.state == .unknown, let operation = run.snapshot.items.first.flatMap({ run.operation($0.id) }) else { return }
        do {
            simpleVerification = try simple.verifyUnknown(operation, expecting: source.lease, displaySession: session)
            simpleFailure = nil
        } catch { simpleFailure = UnifiedSearchSimpleCopy.error(error) }
    }
}

enum UnifiedSearchSimpleCopy {
    static func error(_ error: Error) -> String {
        if error as? CommandLongTextLoanError == .revoked { return "unified.simple.problem.locked" }
        guard let issue = error as? CommandSimpleIssue else {
            if error as? CommandExecutionError == .busy { return "unified.simple.busy" }
            return "unified.simple.stale"
        }
        switch issue {
        case .unassembled: return "unified.simple.unassembled"
        case .unsupportedPlan: return "unified.simple.single"
        case .invalidArguments: return "unified.simple.input"
        case .invalidTarget(let problem): return "unified.simple.problem." + problem.rawValue
        case .stale, .alreadyInvoked: return "unified.simple.stale"
        case .verificationRequired: return "unified.simple.verificationRequired"
        }
    }

    static func result(_ facts: CommandSimpleFacts) -> String {
        "unified.simple.state." + facts.state.rawValue
    }

    static func outcome(_ verification: CommandSimpleVerification) -> String {
        "unified.simple.verification." + verification.outcome.rawValue
    }
}
