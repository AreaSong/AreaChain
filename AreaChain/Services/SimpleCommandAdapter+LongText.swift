import Foundation
import SwiftData

/// L-M1b：简单骨架里长文规格与普通规格的分岔点。正文只经托管：准备期同步读宿主草稿，封存时移入托管，
/// 执行时每个 attempt 签一次借用；失败或取消经 `returnLongText` 还回草稿。普通规格的流程不变。
extension SimpleCommandAdapter {
    /// 准备与重新校验共用：长文规格的输入只含印记，前后状态由准备期的原文推出；普通规格沿原 `checkedInput`。
    /// 重新校验（expected 非空）时先比计划项、草稿戳与输入，不一致即 stale，再读当前值。
    func states(_ host: CommandOwnedHost, spec: any SimpleCommandSpec, creation: CommandObjectReference?,
                expected: CommandSimplePreview? = nil, context: ModelContext)
        throws -> (CommandPlanItem, CommandResolvedInput, CommandSimpleState, CommandSimpleState) {
        let observe = { (call: CommandSimpleCall) throws -> (CommandSimpleState, CommandSimpleState) in
            let before = try spec.observe(call, in: context)
            return (before, try spec.expect(call, from: before, in: context))
        }
        let longText = spec is any SimpleLongTextCommandSpec
        let item = longText ? try CommandSimplePreview.longTextInput(in: host, shape: spec.shape)
            : try CommandSimplePreview.input(in: host, shape: spec.shape)
        if let expected, item.stamp != expected.item || item.draft.stamp != expected.draft { throw CommandSimpleIssue.stale }
        guard longText else {
            let input = try item.checkedInput()
            if let expected, input != expected.input { throw CommandSimpleIssue.stale }
            let (before, after) = try observe(.init(input: input, creation: creation))
            return (item, input, before, after)
        }
        let (input, (before, after)) = try longTextEscrow().preview(item, handles: expected?.handles ?? [:]) { raw in
            try observe(.init(input: raw, creation: creation))
        }
        if let expected, input != expected.input { throw CommandSimpleIssue.stale }
        return (item, input, before, after)
    }

    func longTextEscrow() throws -> CommandLongTextEscrow {
        guard capability == .open, let escrow else { throw CommandSimpleIssue.unassembled }
        return escrow
    }

    /// 长文规格的唯一写入：在事务内为本 attempt 签一次借用并当场交给规格的出口。
    func lentWrite(_ preview: CommandSimplePreview, spec: any SimpleCommandSpec,
                   invocation: CommandRuntimeInvocation) -> ((ModelContext) throws -> Void)? {
        guard let longText = spec as? any SimpleLongTextCommandSpec, let escrow else { return nil }
        return { context in
            try escrow.lend(invocation, preview: preview) { loan in
                try longText.apply(preview.frozenCall, loan: loan, in: context)
            }
        }
    }

    /// 未提交、取消未开始、锁定阻塞或核为未写入：托管正文还回草稿，计划项回到可编辑状态，须重新预览再封存。
    func returnLongText(_ execution: CommandExecutionStamp, expecting lease: CommandHostLease,
                        displaySession: ContentQueryReadSession? = nil) throws {
        try displaySession?.validateDisplayHost(expecting: lease)
        try longTextEscrow().returnToDraft(execution, expecting: lease)
        try displaySession?.validateDisplayHost(expecting: try coordinator.host(lease.ownership.hostID).lease)
    }
}

extension SimpleCommandAdapter {
    func isLongText(_ command: CommandID) -> Bool { (try? spec(command)) is any SimpleLongTextCommandSpec }

    /// 只有已保存的新建型指令才有“打开新对象”。
    func openTarget(_ facts: CommandSimpleFacts) -> ContentQueryBrowseOpen? {
        guard facts.state == .saved, let creation = facts.creation, let spec = try? spec(facts.command) else { return nil }
        return spec.openTarget(creation)
    }
}

extension CommandSimplePreview {
    /// 预览已分配的托管句柄；重新校验与封存沿用，使输入逐字相等。
    var handles: [CommandParameterID: UUID] {
        Dictionary(uniqueKeysWithValues: input.longTextImprints.map { ($0.parameter, $0.escrow) })
    }
}
