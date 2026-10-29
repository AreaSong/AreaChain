import SwiftUI

/// 独立确认的唯一宿主面板：回收与转换共用。各指令只提供标识前缀、标题、确认文案与说明内容；
/// 默认焦点在取消，确认按钮与普通提交分开；Esc 与取消只撤销确认，不动草稿、计划和接受。
struct UnifiedSearchIndependentConfirmationPanel<Details: View>: View {
    @Bindable var controller: UnifiedSearchController
    /// 例如 "unified.trash"：面板、标题、取消与确认按钮的标识都从它派生。
    let identifier: String
    let title: LocalizedStringKey
    let confirmTitle: LocalizedStringKey
    let confirm: () -> Void
    @ViewBuilder let details: () -> Details

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(title).font(DaybookType.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier(identifier + ".confirmTitle")
            details()
            HStack(spacing: DaybookSpacing.sm) {
                UnifiedSearchPlanButton(title: "alert.cancel", identifier: identifier + ".cancel",
                                        focusRevision: controller.confirmationFocus) {
                    controller.cancelIndependentConfirmation()
                }
                UnifiedSearchPlanButton(title: confirmTitle, identifier: identifier + ".confirm", variant: .destructive,
                                        action: confirm)
                    .disabled(controller.settingSubmitting)
            }
        }
        .padding(DaybookSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous).fill(DaybookPalette.fill.subtle))
        .onAppear { controller.focusIndependentConfirmationCancel() }
        .onKeyPress(.escape) {
            controller.cancelIndependentConfirmation()
            return .handled
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier(identifier + ".confirmation")
    }
}

/// 回收的说明行：沿 TrashConfirm 文案，列出目标、连带计数与子任务说明。
struct UnifiedSearchTrashConfirmationDetails: View {
    let confirmation: CommandTrashConfirmation
    @Environment(\.locale) private var locale

    var body: some View {
        message
        if confirmation.counts.subtasks > 0 || confirmation.counts.attachments > 0 {
            Text(verbatim: L10n.format("unified.trash.confirm.cascade", locale: locale,
                                       confirmation.counts.subtasks, confirmation.counts.attachments))
                .font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("unified.trash.confirmCascade")
        }
        if confirmation.counts.notes > 0 {
            Text(verbatim: L10n.format("unified.trash.notes", locale: locale, confirmation.counts.notes))
                .font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("unified.trash.confirmNotes")
        }
        if confirmation.targets.contains(where: { $0.type == .subtask }) {
            Text("unified.trash.confirm.subtaskNote").font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var message: some View {
        if confirmation.targets.count == 1, let title = confirmation.titles.first {
            Text("alert.trash.message \(title)").font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("unified.trash.confirmMessage")
        } else {
            Text(verbatim: L10n.format("unified.trash.confirm.many", locale: locale, confirmation.targets.count))
                .font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("unified.trash.confirmMessage")
            ForEach(Array(confirmation.titles.enumerated()), id: \.offset) { _, title in
                Text(verbatim: "· " + title).font(DaybookType.caption).lineLimit(2)
            }
            if confirmation.targets.count > confirmation.titles.count {
                Text(verbatim: L10n.format("unified.trash.confirm.more", locale: locale,
                                           confirmation.targets.count - confirmation.titles.count)).font(DaybookType.caption)
            }
        }
    }
}

/// 两个使用者共用的焦点与撤销路由；控制器在确认期间只放行 Esc（见 UnifiedSearchController 的键盘分派）。
extension UnifiedSearchController {
    var hasIndependentConfirmation: Bool { trashConfirmation != nil || convertConfirmation != nil || simpleConfirmation != nil }

    /// 面板出现后才递增：取消按钮须先存在，焦点修订的变化才会把默认焦点放到取消上。
    func focusIndependentConfirmationCancel() {
        guard hasIndependentConfirmation else { return }
        confirmationFocus &+= 1
    }

    func cancelIndependentConfirmation() {
        if trashConfirmation != nil { cancelTrashConfirmation() }
        if convertConfirmation != nil { cancelConvertConfirmation() }
        if simpleConfirmation != nil { cancelSimpleConfirmation() }
    }
}
