import SwiftUI

/// 剪贴板加今天：预览明确提示“将读取当前剪贴板”，不显示剪贴板内容；提交后才读取并给出结果。
struct UnifiedSearchClipboardCaptureSubmission: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale

    var body: some View {
        let source = controller.buffer
        let preview = controller.currentClipboardCapturePreview
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.clipboardCapture.pending").font(DaybookType.body)
            if let preview {
                Text("unified.clipboardCapture.readNotice").font(DaybookType.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("unified.clipboardCapture.notice")
                Text("unified.clipboardCapture.rules").font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                Text(verbatim: preview.dayKey).font(DaybookType.caption).accessibilityIdentifier("unified.clipboardCapture.day")
                Text(preview.stampsSource ? "unified.clipboardCapture.source.on" : "unified.clipboardCapture.source.off")
                    .font(DaybookType.caption)
            } else if controller.clipboardCapture.facts == nil {
                Text("unified.clipboardCapture.baseline").font(DaybookType.caption)
            }
            UnifiedSearchPlanButton(title: "unified.clipboardCapture.prepare", identifier: "unified.clipboardCapture.prepare") {
                controller.prepareClipboardCapture(source)
            }.disabled(controller.settingSubmitting)
            UnifiedSearchPlanButton(title: "unified.clipboardCapture.submit", identifier: "unified.clipboardCapture.submit",
                                    variant: .prominent) {
                controller.requestOperationSubmit(source)
            }.disabled(controller.settingSubmitting || preview == nil)
            if let facts = controller.clipboardCapture.facts { result(facts) }
            if controller.unresolvedClipboardCapture != nil {
                Text("unified.simple.unknownDetail").font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                UnifiedSearchPlanButton(title: "unified.simple.verify", identifier: "unified.clipboardCapture.verify") {
                    controller.verifyClipboardCapture(source)
                }
            }
            if let verification = controller.clipboardCapture.verification {
                Text(LocalizedStringKey("unified.clipboardCapture.verification." + verification.rawValue)).font(DaybookType.caption)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("unified.clipboardCapture.verification")
            }
            if let failure = controller.clipboardCapture.failure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("unified.clipboardCapture.issue")
            }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain).accessibilityIdentifier("unified.clipboardCapture.submission")
    }

    private func result(_ facts: CommandClipboardCaptureFacts) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(LocalizedStringKey("unified.clipboardCapture.state." + facts.state.rawValue)).font(DaybookType.body)
                .accessibilityIdentifier("unified.clipboardCapture.status")
            ForEach(Array(facts.protectedTags.enumerated()), id: \.offset) { _, notice in
                Text(verbatim: L10n.format(notice.key, locale: locale, notice.title)).font(DaybookType.caption)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("unified.clipboardCapture.protectedTag")
            }
            if facts.state == .saved, let kind = facts.kind {
                Text(LocalizedStringKey("unified.clipboardCapture.kind." + kind.rawValue)).font(DaybookType.caption)
                    .accessibilityIdentifier("unified.clipboardCapture.kind")
                Text(facts.publication == .returned ? "unified.task.published" : "unified.field.publicationIssue")
                    .font(DaybookType.caption)
            }
        }
    }
}
