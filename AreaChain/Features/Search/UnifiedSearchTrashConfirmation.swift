import SwiftUI

/// 独立确认：沿 TrashConfirm 文案与 Daybook 按钮；默认焦点在取消，确认按钮与普通提交分开。
/// Esc 与取消只撤销确认，不动草稿、计划和接受。
struct UnifiedSearchTrashConfirmationPanel: View {
    @Bindable var controller: UnifiedSearchController
    let confirmation: CommandTrashConfirmation
    let source: UnifiedSearchBuffer
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("alert.trash.title").font(DaybookType.body.weight(.semibold))
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("unified.trash.confirmTitle")
            message
            if confirmation.counts.subtasks > 0 || confirmation.counts.attachments > 0 {
                Text(verbatim: L10n.format("unified.trash.confirm.cascade", locale: locale,
                                           confirmation.counts.subtasks, confirmation.counts.attachments))
                    .font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("unified.trash.confirmCascade")
            }
            if confirmation.targets.contains(where: { $0.type == .subtask }) {
                Text("unified.trash.confirm.subtaskNote").font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DaybookSpacing.sm) {
                UnifiedSearchPlanButton(title: "alert.cancel", identifier: "unified.trash.cancel",
                                        focusRevision: controller.trashConfirmationFocus) {
                    controller.cancelTrashConfirmation()
                }
                UnifiedSearchPlanButton(title: "alert.trash.move", identifier: "unified.trash.confirm", variant: .destructive) {
                    controller.confirmTrash(confirmation, source: source)
                }.disabled(controller.settingSubmitting)
            }
        }
        .padding(DaybookSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous).fill(DaybookPalette.fill.subtle))
        .onAppear { controller.focusTrashConfirmationCancel() }
        .onKeyPress(.escape) {
            controller.cancelTrashConfirmation()
            return .handled
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("unified.trash.confirmation")
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
