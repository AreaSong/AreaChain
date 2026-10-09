import SwiftUI

/// 只展示服务给出的来源与最终计划；折叠不隐藏新建/恢复副作用的数量。
struct UnifiedSearchTaskCompositionPreview: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale

    var body: some View {
        let source = controller.buffer
        let preview = controller.currentTaskComposition
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.composition.capability").font(DaybookType.caption)
            if let preview {
                UnifiedSearchTaskCreationImpact(preview: preview)
                if controller.currentTaskAcceptance != nil {
                    Text("unified.composition.accepted").font(DaybookType.caption)
                } else {
                    Button("unified.composition.accept") { controller.acceptTaskComposition(preview, source: source) }
                        .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                        .disabled(!preview.canPrepareExecution || controller.settingSubmitting)
                        .accessibilityIdentifier("unified.composition.accept")
                }
            } else {
                Text(controller.taskCompositionPreview == nil ? "unified.composition.unprepared" : "unified.composition.stale")
                    .font(DaybookType.caption)
            }
            if let failure = controller.compositionFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption)
                    .accessibilityIdentifier("unified.composition.issue")
            }
            Button("unified.composition.prepare") { controller.prepareTaskComposition(source) }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact)).disabled(controller.settingSubmitting)
                .accessibilityIdentifier("unified.task.prepare")
            Button("unified.task.create") { controller.requestOperationSubmit(source) }
                .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                .disabled(controller.settingSubmitting || controller.currentTaskAcceptance == nil)
                .accessibilityIdentifier("unified.task.create")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unified.composition.preview")
    }

}
