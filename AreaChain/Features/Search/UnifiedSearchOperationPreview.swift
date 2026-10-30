import SwiftUI

/// 下方内容独立于搜索结果和补全 preference；只读协调者快照，事件带原缓冲。
struct UnifiedSearchOperationPreview: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @FocusState private var disclosureFocused: Bool

    var body: some View {
        let keySelection = controller.objectSelection
        let source = controller.buffer
        Group {
            if controller.isNavigationInput { UnifiedSearchNavigationPanel(controller: controller) }
            else if let picker = controller.tagSelection {
                UnifiedSearchTagSetField(controller: controller, picker: picker)
                    .background(DaybookPalette.cardSurface)
            } else if controller.objectSelectionLocation != nil, let draft = controller.editingDraft,
               let command = CommandCatalog.standard.command(id: draft.commandID) {
                UnifiedSearchObjectPicker(controller: controller, command: command)
                    .padding(DaybookSpacing.md)
                    .background(DaybookPalette.cardSurface)
            } else { operationContent }
        }
        .onKeyPress(keys: [.upArrow, .downArrow, .space, .return, .tab, .escape]) { key in
            if key.key == .return, key.modifiers == .command {
                controller.requestOperationSubmit(source)
                return .handled
            }
            guard let picker = keySelection, key.modifiers.isEmpty else { return .ignored }
            let intent: UnifiedSearchIntent
            switch key.key {
            case .upArrow: intent = .results(-1)
            case .downArrow: intent = .results(1)
            case .space: intent = .selectActive
            case .escape: intent = .escape
            default: intent = .open
            }
            controller.intent(intent, source: picker.source)
            return .handled
        }
    }

    private var operationContent: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if !controller.showsMultiPlan, controller.fileSettings != nil, controller.settingExecution == nil,
               controller.plan?.items.isEmpty == false {
                Text(LocalizedStringKey(controller.fileSettingIssue ?? "unified.group.ready"))
                    .font(DaybookType.caption).padding(.horizontal, DaybookSpacing.md)
                    .accessibilityIdentifier("unified.group.fixedStatus")
            }
            if controller.planMessage != "unified.plan.notExecutable", controller.planMessage != "unified.group.ready" {
                Text(LocalizedStringKey(controller.planMessage)).font(DaybookType.caption)
                    .padding(.horizontal, DaybookSpacing.md)
                    .accessibilityIdentifier("unified.plan.message")
            }
            operationScroll
        }
        .background(DaybookPalette.cardSurface)
    }

    private var operationScroll: some View {
        let source = controller.buffer
        return ScrollView {
            VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                if let state = controller.operations, let draft = state.active,
                   let command = CommandCatalog.standard.command(id: draft.commandID) {
                    header(command, draft: draft, source: source)
                    if let decision = state.pending { decisionControls(decision, source: source) }
                    if controller.operationExpanded && controller.editingPlanItem == nil {
                        ForEach(command.parameters, id: \.id) { parameter in
                            UnifiedSearchParameterField(controller: controller, draft: draft,
                                command: command, parameter: parameter, source: source)
                            DaybookDivider()
                        }
                        validation(draft)
                    }
                } else if let command = controller.browsedCommand, controller.editingPlanItem == nil,
                          !(controller.showsMultiPlan && controller.settingExecution != nil),
                          !((controller.showsBatch || controller.showsTaskTitle || controller.showsTaskField
                            || controller.showsSubtask || controller.showsRoutine || controller.showsTrash
                            || controller.showsConvert || controller.showsSimple)
                            && controller.settingExecution != nil) {
                    Text(verbatim: command.name(locale: locale)).font(DaybookType.body.weight(.semibold))
                    ForEach(command.parameters, id: \.id) { parameter in
                        Text(verbatim: L10n.format(parameter.id.nameKey, locale: locale) + " · "
                            + L10n.format(parameter.required ? "unified.operation.required" : "unified.operation.optional", locale: locale))
                    }
                    Button("unified.operation.begin") { controller.beginOperation(command.id, source: source) }
                        .buttonStyle(DaybookButtonStyle(.prominent, size: .regular))
                        .accessibilityIdentifier("unified.operation.begin")
                }
                if let state = controller.operations { retained(state, source: source) }
                UnifiedSearchPlanList(controller: controller)
                UnifiedSearchSettingSubmission(controller: controller)
            }
            .padding(DaybookSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DaybookScrollerConfigurator())
        .background(DaybookPalette.cardSurface)
        .accessibilityIdentifier("unified.operation.preview")
    }

    /// 标题区只回答“要做什么、会变成什么样、怎么确认”：指令名、具体预览与按钮；
    /// 参数不完整、需要认证或后续填写等只在发生时说明，状态性与实现层说明不显示。
    private func header(_ command: CommandDescriptor, draft: CommandDraft, source: UnifiedSearchBuffer) -> some View {
        let preview = UnifiedSearchOperationCopy.preview(command, draft: draft, locale: locale, calendar: calendar)
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(verbatim: command.name(locale: locale)).font(DaybookType.body.weight(.semibold))
            if !preview.isEmpty {
                Text(verbatim: preview).font(DaybookType.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("unified.operation.preview.summary")
            }
            if !draft.check().staticallyValid {
                Text("unified.operation.incomplete").font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.status.pending)
            }
            if !command.interactions.isDisjoint(with: [.secureInput, .authentication, .freshAuthentication]) {
                Text("unified.operation.secure").font(DaybookType.caption)
            }
            if command.parameters.contains(where: {
                !UnifiedSearchParameterContext.supports($0, command: command)
                    && !controller.supportsObjectField($0, command: command)
                    && !controller.supportsTagField($0, command: command)
                    && !controller.supportsLongText($0)
            }) {
                Text("unified.operation.later").font(DaybookType.caption)
            }
            if !command.targetTypes.isEmpty {
                Text(verbatim: L10n.format("unified.objects.count", locale: locale, draft.targets.objects.count))
                    .font(DaybookType.caption)
            }
            HStack {
                Button(controller.operationExpanded ? "unified.operation.collapse" : "unified.operation.expand") {
                    guard controller.validates(source) else { return }
                    controller.operationExpanded.toggle()
                    if !controller.operationExpanded { controller.endLongText() }
                    if !controller.operationExpanded { disclosureFocused = true }
                }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact)).focused($disclosureFocused)
                .help(Text("unified.operation.draftOnly"))
                .accessibilityIdentifier("unified.operation.disclosure")
                Button("unified.plan.enqueue") { _ = controller.enqueue(draft.stamp, source: source) }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                    .accessibilityIdentifier("unified.plan.enqueue")
            }
            // 设置与新建任务的待提交状态由各自的提交区说明；这里只留执行反馈（例如过期、被挡）。
            if !(controller.hasSettingAdapter && controller.supportsSetting(command.id)),
               !(command.id.rawValue == "todo.create" && controller.taskCreate?.supports(command.id) == true),
               controller.operationMessage != "unified.operation.notExecuted" {
                Text(LocalizedStringKey(controller.operationMessage)).font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
        }
    }

    private func validation(_ draft: CommandDraft) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            ForEach(Array(draft.check().argumentIssues.enumerated()), id: \.offset) { _, issue in
                Text(verbatim: UnifiedSearchOperationCopy.issue(issue, locale: locale)).font(DaybookType.caption)
            }
            if !draft.check().targetIssues.isEmpty { Text("unified.operation.targetIssue").font(DaybookType.caption) }
        }
    }

    private func decisionControls(_ decision: CommandDraftDecision, source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.operation.switchQuestion").font(DaybookType.body)
            HStack {
                Button("unified.operation.retain") { controller.resolveOperation(decision, choice: .retain, source: source) }
                    .accessibilityIdentifier("unified.operation.retain")
                Button("unified.operation.discard") { controller.resolveOperation(decision, choice: .discard, source: source) }
                    .accessibilityIdentifier("unified.operation.discard")
                Button("unified.operation.cancel") { controller.resolveOperation(decision, choice: .cancel, source: source) }
                    .accessibilityIdentifier("unified.operation.cancel")
            }.buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
        }
    }

    private func retained(_ state: CommandDraftSession, source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if !state.retained.isEmpty { Text("unified.operation.retained").font(DaybookType.caption) }
            ForEach(state.retained, id: \.id) { draft in
                if let command = CommandCatalog.standard.command(id: draft.commandID) {
                    Button { controller.restoreOperation(draft.stamp, source: source) } label: {
                        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                            Text(verbatim: command.name(locale: locale))
                            let preview = UnifiedSearchOperationCopy.summary(command, draft: draft, locale: locale, calendar: calendar)
                            if !preview.isEmpty { Text(verbatim: preview).font(DaybookType.caption).lineLimit(2) }
                        }
                    }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                    .disabled(controller.plan?.editing != nil)
                    .accessibilityIdentifier("unified.operation.restore." + command.id.rawValue)
                    Button("unified.plan.enqueue") { _ = controller.enqueue(draft.stamp, source: source) }
                        .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                        .accessibilityIdentifier("unified.plan.enqueue.retained." + draft.id.uuidString)
                }
            }
        }
    }
}
