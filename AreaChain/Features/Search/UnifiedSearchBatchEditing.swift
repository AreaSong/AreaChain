import Foundation

/// 原 Plan/Run 独占输入；这里只持有不可编辑的准备、接受与核验投影。
extension UnifiedSearchController {
    var showsBatch: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
            + (settingExecution?.snapshot.items.map(\.draft) ?? [])
        return drafts.contains { routesBatch($0.commandID) }
    }

    func routesBatch(_ command: CommandID) -> Bool {
        CommandBatchEdit.commands.contains(command.rawValue)
    }

    var hasBatch: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
        return !drafts.isEmpty && drafts.allSatisfy { batch?.supports($0.commandID) == true }
    }

    var currentBatchPreview: CommandBatchPreview? {
        guard operationVisible, let preview = batchPreview, let batch,
              (try? batch.validatePreview(preview, expecting: buffer.lease, displaySession: session)) != nil else { return nil }
        return preview
    }

    var currentBatchAcceptance: CommandBatchAcceptance? {
        guard let accepted = batchAcceptance, accepted.preview == currentBatchPreview else { return nil }
        return accepted
    }

    var batchUnit: CommandExecutionUnit? {
        guard operationVisible, let run = settingExecution, run.snapshot.items.count == 1,
              run.snapshot.items.first.map({ CommandBatchEdit.commands.contains($0.draft.commandID.rawValue) }) == true else { return nil }
        return run.units.first
    }

    func revokeBatch() {
        batchPreview = nil
        batchAcceptance = nil
    }

    private func checkBatch(_ source: UnifiedSearchBuffer) throws {
        guard validates(source), operationVisible else { throw CommandBatchIssue.stale }
        guard hasBatch else { throw CommandBatchIssue.unassembled }
        guard editingParameter == nil, tagSelection == nil, objectSelectionLocation == nil, !objectSelectionLoading,
              settingExecution == nil, let operations, operations.pending == nil, operations.retained.isEmpty,
              let plan, plan.editing == nil, plan.stamp == source.plan else {
            throw CommandBatchIssue.unsupportedPlan
        }
        if let draft = operations.active {
            guard plan.items.isEmpty, draft.stamp == source.operation, CommandBatchEdit.commands.contains(draft.commandID.rawValue) else {
                throw CommandBatchIssue.unsupportedPlan
            }
            // 无效 shortText 的原文仍在原生拼写缓冲；不能入列后让“未填”掩盖换行等输入。
            guard draft.check().staticallyValid else { throw CommandBatchIssue.invalidArguments }
        }
        try session.validateDisplayHost(expecting: source.lease)
    }

    func prepareBatch(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkBatch(source)
            revokeBatch()
            if let draft = operations?.active, let plan {
                try coordinator.send(.enqueue(draft.stamp, itemID: UUID(), plan: plan.stamp), expecting: source.lease)
                _ = publishOperation(text: buffer.text)
            }
            guard let plan, let batch else { throw CommandBatchIssue.stale }
            batchPreview = try batch.prepare(plan: plan.stamp, expecting: buffer.lease, displaySession: session)
            batchFailure = nil
            batchProblems = []
        } catch {
            revokeBatch()
            recordBatchError(error)
        }
    }

    func acceptBatch(_ preview: CommandBatchPreview, source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkBatch(source)
            guard batchPreview == preview, let batch else { throw CommandBatchIssue.stale }
            batchAcceptance = try batch.accept(preview, expecting: source.lease, displaySession: session)
            batchFailure = nil
            batchProblems = []
        } catch {
            batchAcceptance = nil
            recordBatchError(error)
        }
    }

    func submitBatch(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible, settingExecution == nil else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkBatch(source)
            // 交原接受给适配器，保留最后检查的具体拒绝原因；不重准备或更换原 lease。
            guard let accepted = batchAcceptance, let batch else { throw CommandBatchIssue.stale }
            _ = try batch.submit(accepted: accepted, expecting: source.lease, displaySession: session)
            _ = publishOperation(text: buffer.text)
            planMessage = "unified.plan.notExecutable"
        } catch {
            batchAcceptance = nil
            if settingExecution != nil {
                _ = publishOperation(text: buffer.text)
                planMessage = "unified.plan.notExecutable"
            }
            recordBatchError(error)
        }
    }

    func recordBatchError(_ error: Error) {
        batchFailure = UnifiedSearchBatchCopy.error(error)
        if case .invalidTargets(let problems) = error as? CommandBatchIssue { batchProblems = problems }
        else { batchProblems = [] }
    }

    func removeBatchTarget(_ target: CommandObjectReference, preview: CommandBatchPreview, source: UnifiedSearchBuffer) {
        guard validates(source), operationVisible, !settingSubmitting, batchPreview == preview,
              plan?.stamp == preview.plan, plan?.editing == nil, preview.targets.objects.contains(target) else { return }
        beginPlanEditing(preview.item, source: source)
        guard let item = editingPlanItem, item.id == preview.item.id else { return }
        removeObject(target, location: .targets, source: buffer)
        if let current = editingPlanItem { endPlanEditing(current.stamp, source: buffer) }
        batchFailure = "unified.batch.reprepare"
    }
}
