import Foundation

/// 只保存回调身份；计划和草稿始终从协调者读取，不在界面保存可提交副本。
struct UnifiedSearchPlanMerge: Equatable {
    let source: UnifiedSearchBuffer
    let earlier: CommandPlanItemStamp
    let later: CommandPlanItemStamp
}

extension UnifiedSearchController {
    var plan: CommandPlan? {
        _ = revision
        guard let owned = try? coordinator.host(buffer.lease.ownership.hostID),
              owned.lease.ownership == buffer.lease.ownership else { return nil }
        return owned.session.plan
    }

    var editingPlanItem: CommandPlanItem? { plan?.items.first { $0.id == plan?.editing } }
    var editingDraft: CommandDraft? { editingPlanItem?.draft ?? operations?.active }

    @discardableResult
    func enqueue(_ draft: CommandDraftStamp, source: UnifiedSearchBuffer) -> Bool {
        guard validates(source), operationVisible, let stamp = source.plan else { return rejectPlan() }
        do {
            try coordinator.send(.enqueue(draft, itemID: UUID(), plan: stamp), expecting: source.lease)
            editingParameter = nil
            cancelObjectSelection(returnFocus: false)
            _ = publishOperation(text: "")
            planMessage = "unified.plan.added"
            inputFocused = true
            return true
        } catch { return rejectPlan(error) }
    }

    @discardableResult
    func sendPlan(_ event: CommandPlanEvent, source: UnifiedSearchBuffer) -> Bool {
        guard validates(source), operationVisible, let stamp = source.plan else { return rejectPlan() }
        do {
            try coordinator.send(.plan(event, stamp), expecting: source.lease)
            _ = publishOperation(text: buffer.text)
            planMessage = "unified.plan.notExecutable"
            return true
        } catch { return rejectPlan(error) }
    }

    func sendPlanDraft(_ event: CommandDraftEvent, source: UnifiedSearchBuffer) -> UnifiedSearchBuffer? {
        guard let item = editingPlanItem, item.stamp == source.planItem,
              item.draft.stamp == source.operation else { return nil }
        let planEvent: CommandPlanEvent
        switch event {
        case .edit(let stamp, let argument) where stamp == item.draft.stamp:
            planEvent = .edit(item.stamp, argument)
        case .selectTargets(let stamp, let targets, _) where stamp == item.draft.stamp:
            // 候选摘要不是完整原值；原领域 select 负责使旧基线失效。
            planEvent = .selectTargets(item.stamp, targets)
        default: return nil
        }
        return sendPlan(planEvent, source: source) ? buffer : nil
    }

    func beginPlanEditing(_ item: CommandPlanItemStamp, source: UnifiedSearchBuffer) {
        guard validates(source), operationVisible, plan?.items.contains(where: { $0.stamp == item }) == true else {
            _ = rejectPlan(); return
        }
        if let current = editingPlanItem {
            guard current.stamp != item else { return }
            guard sendPlan(.endEditing(current.stamp, .cancelKeepingChanges), source: source) else { return }
        }
        // 同步完成上一项收起后只接续原先指定的项；没有 await 或外部回调续租。
        guard sendPlan(.beginEditing(item), source: buffer) else { return }
        editingParameter = nil
        cancelObjectSelection(returnFocus: false)
        operationExpanded = true
        _ = publishOperation(text: "")
    }

    func endPlanEditing(_ item: CommandPlanItemStamp, source: UnifiedSearchBuffer) {
        guard sendPlan(.endEditing(item, .cancelKeepingChanges), source: source) else { return }
        editingParameter = nil
        cancelObjectSelection(returnFocus: false)
        _ = publishOperation(text: "")
        planReturnItem = item.id
        planReturnRevision &+= 1
    }

    @discardableResult
    func removePlanItem(_ item: CommandPlanItemStamp, source: UnifiedSearchBuffer) -> Bool {
        guard validates(source), operationVisible, let stamp = source.plan else { return rejectPlan() }
        do {
            try coordinator.send(.removeFromPlan(item, stamp), expecting: source.lease)
            _ = publishOperation(text: buffer.text)
            planMessage = "unified.plan.removed"
            inputFocused = true
            return true
        } catch { return rejectPlan(error) }
    }

    func movePlanItem(_ item: CommandPlanItemStamp, offset: Int, source: UnifiedSearchBuffer) {
        guard validates(source), let plan, let index = plan.items.firstIndex(where: { $0.stamp == item }),
              [-1, 1].contains(offset), plan.items.indices.contains(index + offset) else { _ = rejectPlan(); return }
        var order = plan.items.map(\.id)
        order.swapAt(index, index + offset)
        _ = sendPlan(.reorder(order), source: source)
    }

    func proposePlanMerge(_ item: CommandPlanItemStamp, source: UnifiedSearchBuffer) -> UnifiedSearchPlanMerge? {
        guard validates(source), operationVisible, let plan,
              let index = plan.items.firstIndex(where: { $0.stamp == item }), index > 0 else { return nil }
        if let conflict = CommandPlanSemantics.mergeConflict(plan.items, earlier: index - 1, later: index) {
            _ = rejectPlan(CommandPlanError.mergeConflict(conflict)); return nil
        }
        return .init(source: source, earlier: plan.items[index - 1].stamp, later: item)
    }

    func acceptPlanMerge(_ proposal: UnifiedSearchPlanMerge) {
        _ = sendPlan(.merge(earlier: proposal.earlier, later: proposal.later), source: proposal.source)
    }

    @discardableResult
    func rejectPlan(_ error: Error = CommandPlanError.stale) -> Bool {
        planMessage = UnifiedSearchPlanCopy.errorKey(error)
        refreshOperationPresentation()
        return false
    }
}
