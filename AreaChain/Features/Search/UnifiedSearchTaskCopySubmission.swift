import SwiftUI

/// 复制预览只显示将写入的确切文字；成功才显示“已复制”，失败如实提示。
struct UnifiedSearchTaskCopySubmission: View {
    @Bindable var controller: UnifiedSearchController

    var body: some View {
        let source = controller.buffer
        let preview = controller.currentTaskCopyPreview
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.copy.pending").font(DaybookType.body)
            if let preview {
                Text(LocalizedStringKey(UnifiedSearchTaskCopyCopy.section(preview.section))).font(DaybookType.caption)
                    .accessibilityIdentifier("unified.copy.section")
                Text(verbatim: preview.text).font(DaybookType.body).lineLimit(4).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("unified.copy.content")
                Text("unified.copy.visibility").font(DaybookType.micro).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(controller.taskCopyPreview == nil ? "unified.copy.baseline" : "unified.copy.stale").font(DaybookType.caption)
            }
            UnifiedSearchPlanButton(title: "unified.copy.prepare", identifier: "unified.copy.prepare") {
                controller.prepareTaskCopy(source)
            }.disabled(controller.settingSubmitting)
            UnifiedSearchPlanButton(title: "unified.copy.submit", identifier: "unified.copy.submit", variant: .prominent) {
                controller.requestOperationSubmit(source)
            }.disabled(controller.settingSubmitting || preview == nil)
            if controller.currentTaskCopyResult != nil {
                Label("diary.copied", systemImage: "checkmark").font(DaybookType.caption)
                    .accessibilityIdentifier("unified.copy.status")
            }
            if let failure = controller.taskCopyFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("unified.copy.issue")
            }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain).accessibilityIdentifier("unified.copy.submission")
    }
}
