import Foundation

/// 合并批 M-2：需要独立确认的简单指令（标签回收／恢复、附件回收）沿 T-M4／T-M5 的同一绑定规则与共用面板。
/// 摘要来自同一份冻结预览：目标行数与预览说明行（受影响对象数等）；预览一变，旧确认就不再匹配。
struct CommandSimpleConfirmationSummary: Equatable {
    let rows: Int
    let notices: [CommandSimpleNotice]
}

typealias CommandSimpleConfirmation = CommandIndependentConfirmation<CommandSimpleConfirmationSummary>

extension CommandSimpleAcceptance {
    var confirmationBinding: CommandSimpleConfirmation.Binding {
        .init(acceptanceID: id, plan: preview.plan, item: preview.item, targets: preview.input.targets.objects,
              summary: .init(rows: preview.after.rows.count, notices: preview.after.notices))
    }
}

extension CommandSimpleRegistry {
    /// 只为当前接受签发；新接受、取消或执行都撤销旧确认。
    func confirm(_ accepted: CommandSimpleAcceptance) throws -> CommandSimpleConfirmation {
        guard acceptances[accepted.preview.draft.draftID] == accepted, !wasInvoked(accepted.id) else {
            throw CommandSimpleIssue.stale
        }
        return confirmations.issue(accepted.confirmationBinding, titles: accepted.preview.after.rows.map(\.title))
    }

    func cancel(_ confirmation: CommandSimpleConfirmation) { confirmations.cancel(confirmation) }

    func confirmation(for accepted: CommandSimpleAcceptance) throws -> CommandSimpleConfirmation {
        switch confirmations.lookup(accepted.confirmationBinding) {
        case .missing: throw CommandSimpleIssue.confirmationRequired
        case .stale: throw CommandSimpleIssue.stale
        case .current(let confirmation): return confirmation
        }
    }
}
