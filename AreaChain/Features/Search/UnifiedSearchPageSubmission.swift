import SwiftUI

/// 页面指令面板：说明作用于哪一页，逐行列出“现在”与“执行后”的页面状态；状态直接读页面那一份，
/// 页面上改了就会让旧预览失效并提示重新预览。按钮与 ⌘Return 走同一入口。
struct UnifiedSearchPageSubmission: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale

    var body: some View {
        let source = controller.buffer
        let preview = controller.currentPagePreview
        let tags = controller.pageCommands?.tagNames() ?? [:]
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.page.pending").font(DaybookType.body).fixedSize(horizontal: false, vertical: true)
            if let preview {
                Text(verbatim: target(preview)).font(DaybookType.caption).accessibilityIdentifier("unified.page.target")
                block("unified.page.before", UnifiedSearchPageCopy.lines(preview.before, tags: tags, locale: locale),
                      identifier: "unified.page.before")
                if let after = preview.after {
                    block("unified.page.after", UnifiedSearchPageCopy.lines(after, tags: tags, locale: locale),
                          identifier: "unified.page.after")
                } else if preview.revealsPage {
                    Text("unified.page.selection.reveal").font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(controller.pagePreview == nil ? "unified.page.baseline" : "unified.page.stale").font(DaybookType.caption)
                    .accessibilityIdentifier("unified.page.baseline")
            }
            UnifiedSearchPlanButton(title: "unified.page.prepare", identifier: "unified.page.prepare") {
                controller.preparePage(source)
            }.disabled(controller.settingSubmitting)
            UnifiedSearchPlanButton(title: "unified.page.apply", identifier: "unified.page.apply", variant: .prominent) {
                controller.requestOperationSubmit(source)
            }.disabled(controller.settingSubmitting || preview == nil)
            if let receipt = controller.pageReceipt {
                block("unified.page.done", UnifiedSearchPageCopy.lines(receipt.after, tags: tags, locale: locale),
                      identifier: "unified.page.status")
            }
            if let failure = controller.pageFailure {
                Text(verbatim: UnifiedSearchPageCopy.message(failure, locale: locale)).font(DaybookType.caption)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("unified.page.issue")
            }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain).accessibilityIdentifier("unified.page.submission")
    }

    private func target(_ preview: WorkspacePagePreview) -> String {
        guard let page = preview.page else { return L10n.string("unified.page.targetWorkspace", locale: locale) }
        return L10n.format("unified.page.target", locale: locale, UnifiedSearchPageCopy.pageName(page.rawValue, locale: locale))
    }

    private func block(_ title: LocalizedStringKey, _ lines: [String], identifier: String) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(title).font(DaybookType.caption.weight(.semibold))
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(verbatim: line).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
            }
        }.accessibilityElement(children: .combine).accessibilityIdentifier(identifier)
    }
}
