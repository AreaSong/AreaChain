import SwiftUI

/// 在原预览的固定滚动区域中组合；没有第二份计划数组或补全浮层。
struct UnifiedSearchPlanList: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale

    var body: some View {
        if controller.showsTaskChain { UnifiedSearchTaskChainSubmission(controller: controller) }
        if let plan = controller.plan, !plan.items.isEmpty {
            DaybookDivider()
            Text(verbatim: L10n.format("unified.plan.count", locale: locale, plan.items.count))
                .font(DaybookType.body.weight(.semibold))
            if controller.showsSubtask {
                Text("unified.subtask.pending").font(DaybookType.caption)
            } else if controller.showsTaskTitle {
                Text("unified.title.pending").font(DaybookType.caption)
            } else if controller.showsTaskCreate {
                Text("unified.task.pending").font(DaybookType.caption)
            } else if controller.fileSettings != nil {
                Text("unified.group.planHint").font(DaybookType.caption)
            } else { Text(controller.hasSettingAdapter ? "unified.setting.singleOnly" : "unified.plan.notExecutable").font(DaybookType.caption) }
            if controller.fileSettings != nil, plan.items.count > 1, plan.items.first?.atomicGroup != nil {
                Text(verbatim: L10n.format("unified.group.title", locale: locale, plan.items.count))
                    .font(DaybookType.body.weight(.semibold))
                    .accessibilityIdentifier("unified.group.title")
            }
            let check = plan.check()
            ForEach(Array(plan.items.enumerated()), id: \.element.id) { index, item in
                UnifiedSearchPlanRow(controller: controller, item: item, source: controller.buffer, index: index, check: check)
                DaybookDivider()
            }
        }
    }
}

private struct UnifiedSearchPlanRow: View {
    @Bindable var controller: UnifiedSearchController
    let item: CommandPlanItem
    let source: UnifiedSearchBuffer
    let index: Int
    let check: CommandPlanCheck
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @State private var proposal: UnifiedSearchPlanMerge?

    private var isEditing: Bool { controller.plan?.editing == item.id }

    var body: some View {
        if let command = CommandCatalog.standard.command(id: item.draft.commandID) {
            VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                Text(verbatim: "\(index + 1). " + command.name(locale: locale)).font(DaybookType.body.weight(.medium))
                if !command.targetTypes.isEmpty {
                    Text(verbatim: L10n.format("unified.objects.count", locale: locale, item.draft.targets.objects.count))
                        .font(DaybookType.caption)
                    Text("unified.objects.finalCheck").font(DaybookType.micro)
                }
                let summary = UnifiedSearchOperationCopy.summary(command, draft: item.draft, locale: locale, calendar: calendar)
                if !summary.isEmpty { Text(verbatim: summary).font(DaybookType.caption).lineLimit(2) }
                if !isEditing, controller.supportsSetting(command.id) {
                    UnifiedSearchSettingValues(before: item.draft.baseline.preferenceGroup?.values[command.id] ?? item.draft.baseline.preference?.memory,
                                               after: item.draft.arguments.first?.value)
                }
                if let original = item.draft.baseline.preferenceGroup?.values[command.id],
                   original == item.draft.arguments.first?.value {
                    Text("unified.group.memberNoChange").font(DaybookType.caption)
                }
                diagnostics
                controls
                if let proposal, proposal.source == controller.buffer {
                    mergeConfirmation(proposal, command: command)
                }
                if isEditing {
                    Text("unified.plan.editing").font(DaybookType.caption)
                    UnifiedSearchPlanDependencies(controller: controller, item: item, source: source)
                    ForEach(command.parameters, id: \.id) { parameter in
                        UnifiedSearchParameterField(controller: controller, draft: item.draft,
                            command: command, parameter: parameter, source: source)
                        DaybookDivider()
                    }
                    Button("unified.plan.close") { controller.endPlanEditing(item.stamp, source: source) }
                        .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                        .accessibilityIdentifier("unified.plan.close")
                } else {
                    UnifiedSearchPlanDependencies(controller: controller, item: item, source: source, editable: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("unified.plan.item." + item.id.uuidString)
        }
    }

    private var diagnostics: some View {
        let result = check.items.first { $0.item == item.stamp }
        return VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(result?.arguments.isEmpty == true && result?.targets.isEmpty == true
                 ? "unified.plan.shapeValid" : "unified.plan.needsInput").font(DaybookType.caption)
            ForEach(Array((result?.arguments ?? []).enumerated()), id: \.offset) { _, issue in
                Text(verbatim: UnifiedSearchOperationCopy.issue(issue, locale: locale)).font(DaybookType.caption)
            }
            if result?.targets.isEmpty == false { Text("unified.operation.targetIssue").font(DaybookType.caption) }
            ForEach(Array(check.dependencies.enumerated()), id: \.offset) { _, issue in
                if let key = UnifiedSearchPlanCopy.dependency(issue, item: item.id) {
                    Text(LocalizedStringKey(key)).font(DaybookType.caption)
                }
            }
            if item.atomicGroup != nil {
                Text(controller.fileSettings != nil ? "unified.group.member" : "unified.plan.atomic").font(DaybookType.caption)
            }
        }.foregroundStyle(DaybookPalette.text.secondary)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            HStack {
                UnifiedSearchPlanButton(title: isEditing ? "unified.plan.close" : "unified.plan.edit",
                    identifier: "unified.plan.edit." + item.id.uuidString,
                    focusRevision: controller.planReturnItem == item.id ? controller.planReturnRevision : 0) {
                    if isEditing { controller.endPlanEditing(item.stamp, source: source) }
                    else { controller.beginPlanEditing(item.stamp, source: source) }
                }
                UnifiedSearchPlanButton(title: "unified.plan.up", identifier: "unified.plan.up." + item.id.uuidString) {
                    controller.movePlanItem(item.stamp, offset: -1, source: source)
                }.disabled(index == 0)
                UnifiedSearchPlanButton(title: "unified.plan.down", identifier: "unified.plan.down." + item.id.uuidString) {
                    controller.movePlanItem(item.stamp, offset: 1, source: source)
                }
                    .disabled(index + 1 == controller.plan?.items.count)
            }
            Button("unified.plan.remove") { _ = controller.removePlanItem(item.stamp, source: source) }
                .accessibilityIdentifier("unified.plan.remove." + item.id.uuidString)
            if index > 0 {
                Button("unified.plan.merge") { proposal = controller.proposePlanMerge(item.stamp, source: source) }
                    .accessibilityIdentifier("unified.plan.merge." + item.id.uuidString)
            }
        }.buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
    }

    private func mergeConfirmation(_ proposal: UnifiedSearchPlanMerge, command: CommandDescriptor) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.plan.merge.question").font(DaybookType.caption)
            Text(verbatim: UnifiedSearchOperationCopy.summary(command, draft: item.draft, locale: locale, calendar: calendar))
                .font(DaybookType.caption)
            HStack {
                Button("unified.plan.merge.accept") { controller.acceptPlanMerge(proposal); self.proposal = nil }
                    .accessibilityIdentifier("unified.plan.merge.accept")
                Button("unified.operation.cancel") { self.proposal = nil }
            }.buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
        }
    }
}
