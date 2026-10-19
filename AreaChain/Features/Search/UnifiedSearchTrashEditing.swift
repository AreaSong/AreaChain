import Foundation

/// 回收的预览、接受与独立确认只是原 Plan/Run 之外的不可编辑投影；草稿与计划仍归 Coordinator。
extension UnifiedSearchController {
    var showsTrash: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
            + (settingExecution?.snapshot.items.map(\.draft) ?? [])
        return drafts.contains { routesTrash($0.commandID) }
    }

    func routesTrash(_ command: CommandID) -> Bool { trash?.supports(command) == true }

    var hasTrash: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
        return !drafts.isEmpty && drafts.allSatisfy { trash?.supports($0.commandID) == true }
    }

    var currentTrashPreview: CommandTrashPreview? {
        guard operationVisible, let preview = trashPreview, let trash,
              (try? trash.validatePreview(preview, expecting: buffer.lease, displaySession: session)) != nil else { return nil }
        return preview
    }

    var currentTrashAcceptance: CommandTrashAcceptance? {
        guard let accepted = trashAcceptance, accepted.preview == currentTrashPreview else { return nil }
        return accepted
    }

    var trashUnit: CommandExecutionUnit? {
        guard operationVisible, let run = settingExecution, run.snapshot.items.count == 1,
              run.snapshot.items.first.map({ CommandTrashEdit.commands.contains($0.draft.commandID.rawValue) }) == true else { return nil }
        return run.units.first
    }

    func revokeTrash() {
        if let confirmation = trashConfirmation { trash?.cancel(confirmation) }
        trashPreview = nil
        trashAcceptance = nil
        trashConfirmation = nil
    }

    private func checkTrash(_ source: UnifiedSearchBuffer) throws {
        guard validates(source), operationVisible else { throw CommandTrashIssue.stale }
        guard hasTrash else { throw CommandTrashIssue.unassembled }
        guard editingParameter == nil, tagSelection == nil, objectSelectionLocation == nil, !objectSelectionLoading,
              settingExecution == nil, let operations, operations.pending == nil, operations.retained.isEmpty,
              let plan, plan.editing == nil, plan.stamp == source.plan else {
            throw CommandTrashIssue.unsupportedPlan
        }
        if let draft = operations.active {
            guard plan.items.isEmpty, draft.stamp == source.operation,
                  CommandTrashEdit.commands.contains(draft.commandID.rawValue) else { throw CommandTrashIssue.unsupportedPlan }
            guard draft.check().staticallyValid else { throw CommandTrashIssue.invalidArguments }
        }
        try session.validateDisplayHost(expecting: source.lease)
    }

    private func trashAction(_ source: UnifiedSearchBuffer, _ work: () throws -> Void) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkTrash(source)
            try work()
            trashFailure = nil
            trashProblems = []
        } catch { recordTrashError(error) }
    }

    func prepareTrash(_ source: UnifiedSearchBuffer) {
        trashAction(source) {
            revokeTrash()
            if let draft = operations?.active, let plan {
                try coordinator.send(.enqueue(draft.stamp, itemID: UUID(), plan: plan.stamp), expecting: source.lease)
                _ = publishOperation(text: buffer.text)
            }
            guard let plan, let trash else { throw CommandTrashIssue.stale }
            trashPreview = try trash.prepare(plan: plan.stamp, expecting: buffer.lease, displaySession: session)
        }
    }

    func acceptTrash(_ preview: CommandTrashPreview, source: UnifiedSearchBuffer) {
        trashAction(source) {
            guard trashPreview == preview, trashConfirmation == nil, let trash else { throw CommandTrashIssue.stale }
            trashAcceptance = nil
            trashAcceptance = try trash.accept(preview, expecting: source.lease, displaySession: session)
        }
    }

    /// 普通提交（按钮与 ⌘Return）只打开独立确认，从不直接写入。
    func requestTrashConfirmation(_ source: UnifiedSearchBuffer) {
        guard trashConfirmation == nil, settingExecution == nil else { return }
        trashAction(source) {
            guard let accepted = currentTrashAcceptance, let trash else { throw CommandTrashIssue.confirmationRequired }
            trashConfirmation = try trash.confirm(accepted, expecting: source.lease, displaySession: session)
            inputFocused = false
        }
    }

    /// Esc 与取消只撤销确认；草稿、计划、预览和接受均保持原样。
    func cancelTrashConfirmation() {
        guard let confirmation = trashConfirmation else { return }
        trash?.cancel(confirmation)
        trashConfirmation = nil
        inputFocused = true
        refreshOperationPresentation()
    }

    func confirmTrash(_ confirmation: CommandTrashConfirmation, source: UnifiedSearchBuffer) {
        guard trashConfirmation == confirmation, settingExecution == nil else { return }
        trashAction(source) {
            defer { trashConfirmation = nil; inputFocused = true }
            guard let accepted = trashAcceptance, let trash else { throw CommandTrashIssue.stale }
            do {
                _ = try trash.submit(accepted: accepted, confirmation: confirmation, expecting: source.lease, displaySession: session)
            } catch {
                // 失败前的原因要求重新预览；已进入 Run 的结果仍由原 Run 展示。
                trashAcceptance = nil
                if settingExecution == nil { trashPreview = nil }
                if settingExecution != nil { _ = publishOperation(text: buffer.text) }
                throw error
            }
            _ = publishOperation(text: buffer.text)
            planMessage = "unified.plan.notExecutable"
        }
    }

    func recordTrashError(_ error: Error) {
        trashFailure = UnifiedSearchTrashCopy.error(error)
        if case .invalidTargets(let problems) = error as? CommandTrashIssue { trashProblems = problems } else { trashProblems = [] }
    }

    func removeTrashTarget(_ target: CommandObjectReference, preview: CommandTrashPreview, source: UnifiedSearchBuffer) {
        guard validates(source), operationVisible, !settingSubmitting, trashConfirmation == nil, trashPreview == preview,
              preview.edit == .batch, preview.targets.objects.count > 1,
              plan?.stamp == preview.plan, plan?.editing == nil, preview.targets.objects.contains(target) else { return }
        beginPlanEditing(preview.item, source: source)
        guard let item = editingPlanItem, item.id == preview.item.id else { return }
        removeObject(target, location: .targets, source: buffer)
        if let current = editingPlanItem { endPlanEditing(current.stamp, source: buffer) }
        trashFailure = "unified.trash.reprepare"
    }
}

enum UnifiedSearchTrashCopy {
    static func error(_ error: Error) -> String {
        guard let issue = error as? CommandTrashIssue else {
            if error as? CommandExecutionError == .busy { return "unified.trash.busy" }
            return "unified.trash.stale"
        }
        switch issue {
        case .unassembled: return "unified.trash.unassembled"
        case .unsupportedPlan: return "unified.trash.single"
        case .invalidArguments: return "unified.trash.input"
        case .invalidTargets: return "unified.trash.targetsChanged"
        case .confirmationRequired: return "unified.trash.acceptFirst"
        case .confirmationStale, .stale, .alreadyInvoked: return "unified.trash.stale"
        case .invalidRepository: return "unified.trash.unassembled"
        case .writeLimit: return "unified.trash.writeLimit"
        }
    }

    static func reason(_ reason: CommandTrashTargetProblem.Reason) -> String {
        "unified.trash.problem." + String(describing: reason)
    }

    static func result(_ facts: CommandTrashFacts) -> String {
        "unified.trash." + (facts.state == .pending ? "pendingResult" : String(describing: facts.state))
    }
}
