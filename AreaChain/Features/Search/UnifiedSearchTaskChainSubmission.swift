import SwiftUI

/// 原 PlanList 内呈现逐步事实；第一步成功不是整链成功，等待第二次明确接受。
struct UnifiedSearchTaskChainSubmission: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale

    var body: some View {
        let source = controller.buffer
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.chain.title").font(DaybookType.body.weight(.semibold))
            Text("unified.chain.boundary").font(DaybookType.caption)
            if controller.taskChain == nil { Text("unified.chain.unassembled").font(DaybookType.caption) }
            if let run = controller.settingExecution {
                ForEach(Array(run.snapshot.items.enumerated()), id: \.element.id) { index, item in
                    Text(verbatim: "\(index + 1). " + (CommandCatalog.standard.command(id: item.draft.commandID)?.name(locale: locale) ?? ""))
                        .font(DaybookType.body.weight(.medium))
                    if let unit = run.units.first(where: { $0.id == item.id }) {
                        if let facts = unit.taskCreation {
                            UnifiedSearchTaskCreateSubmission(controller: controller).result(facts, unit: unit, source: source, allowsRelease: false)
                        } else if let facts = unit.taskTitle {
                            UnifiedSearchTaskTitleSubmission(controller: controller).result(facts, unit: unit, source: source)
                        } else { consumer(source) }
                    }
                    DaybookDivider()
                }
            } else {
                Text("unified.chain.dependency").font(DaybookType.caption)
                Text("unified.chain.minimal").font(DaybookType.caption)
                UnifiedSearchPlanButton(title: "unified.chain.prepare", identifier: "unified.chain.prepare") {
                    controller.prepareTaskChain(source)
                }.disabled(controller.settingSubmitting || controller.taskChain == nil)
                if controller.chainCreationPreparation?.lease == source.lease {
                    Text("unified.chain.prepared").font(DaybookType.caption)
                    UnifiedSearchPlanButton(title: "unified.chain.create", identifier: "unified.chain.create", variant: .prominent) {
                        controller.requestOperationSubmit(source)
                    }.disabled(controller.settingSubmitting)
                }
            }
            if let failure = controller.chainFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption).accessibilityIdentifier("unified.chain.issue")
            }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain).accessibilityIdentifier("unified.chain.submission")
    }

    private func consumer(_ source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if controller.chainCanPrepareTitle {
                Text("unified.chain.waiting").font(DaybookType.caption).accessibilityIdentifier("unified.chain.waiting")
                if let preview = controller.currentTaskTitlePreview {
                    UnifiedSearchTaskTitlePreview(preview: preview)
                    if controller.currentTaskTitleAcceptance == nil {
                        UnifiedSearchPlanButton(title: "unified.title.accept", identifier: "unified.chain.acceptTitle", variant: .prominent) {
                            controller.acceptTaskChainTitle(preview, source: source)
                        }.disabled(controller.settingSubmitting)
                    } else {
                        UnifiedSearchPlanButton(title: "unified.chain.saveTitle", identifier: "unified.chain.saveTitle", variant: .prominent) {
                            controller.requestOperationSubmit(source)
                        }.disabled(controller.settingSubmitting)
                    }
                }
                UnifiedSearchPlanButton(title: "unified.chain.prepareTitle", identifier: "unified.chain.prepareTitle") {
                    controller.prepareTaskChainTitle(source)
                }.disabled(controller.settingSubmitting || controller.taskChain == nil)
            } else { Text("unified.chain.blocked").font(DaybookType.caption).accessibilityIdentifier("unified.chain.blocked") }
        }
    }
}
