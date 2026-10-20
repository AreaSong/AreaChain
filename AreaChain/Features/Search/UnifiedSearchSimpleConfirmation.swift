import SwiftUI

/// 合并批 M-2：需要独立确认的简单指令（标签回收／恢复、附件回收）沿 T-M4／T-M5 的共用确认面板。
/// 接受后由“确认”打开面板（按钮与 ⌘Return 同一入口），面板的确认才提交；Esc 与取消只撤销确认。
extension UnifiedSearchController {
    var simpleNeedsConfirmation: Bool {
        guard let draft = (operations?.allDrafts ?? []).first ?? plan?.items.first?.draft else { return false }
        return simple?.needsConfirmation(draft.commandID) == true
    }

    func requestSimpleConfirmation(_ source: UnifiedSearchBuffer) {
        guard simpleConfirmation == nil, settingExecution == nil, validates(source), operationVisible,
              !settingSubmitting else { return }
        do {
            guard let accepted = currentSimpleAcceptance, let simple else { throw CommandSimpleIssue.confirmationRequired }
            simpleConfirmation = try simple.confirm(accepted, expecting: source.lease, displaySession: session)
            simpleFailure = nil
            inputFocused = false
        } catch { simpleFailure = UnifiedSearchSimpleCopy.error(error) }
        refreshOperationPresentation()
    }

    func cancelSimpleConfirmation() {
        guard let confirmation = simpleConfirmation else { return }
        coordinator.simples.cancel(confirmation)
        simpleConfirmation = nil
        inputFocused = true
        refreshOperationPresentation()
    }

    /// 提交仍走原 submitSimple；适配器在封存前核对这份确认仍与接受逐项一致。
    func confirmSimple(_ confirmation: CommandSimpleConfirmation, source: UnifiedSearchBuffer) {
        guard simpleConfirmation == confirmation, settingExecution == nil else { return }
        submitSimple(source)
        simpleConfirmation = nil
        inputFocused = true
    }
}

/// 确认说明：列出目标（前几个标题）与预览里的说明行（受影响对象数、孤儿规则等）。
struct UnifiedSearchSimpleConfirmationDetails: View {
    let confirmation: CommandSimpleConfirmation
    @Environment(\.locale) private var locale

    var body: some View {
        ForEach(Array(confirmation.titles.enumerated()), id: \.offset) { _, title in
            Text(verbatim: "· " + title).font(DaybookType.caption).lineLimit(2)
        }
        if confirmation.targets.count > confirmation.titles.count {
            Text(verbatim: L10n.format("unified.trash.confirm.more", locale: locale,
                                       confirmation.targets.count - confirmation.titles.count)).font(DaybookType.caption)
        }
        ForEach(Array(confirmation.summary.notices.enumerated()), id: \.offset) { _, notice in
            Text(verbatim: L10n.format(notice.key, locale: locale, notice.title)).font(DaybookType.caption)
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("unified.simple.confirmNotice")
        }
    }
}
