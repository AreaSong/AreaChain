import SwiftUI

/// 下方内容独立于搜索结果和补全 preference；只读协调者快照，事件带原缓冲。
struct UnifiedSearchOperationPreview: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @FocusState private var disclosureFocused: Bool

    var body: some View {
        let keySelection = controller.objectSelection
        Group {
            if controller.objectSelectionLocation != nil, let draft = controller.operations?.active,
               let command = CommandCatalog.standard.command(id: draft.commandID) {
                UnifiedSearchObjectPicker(controller: controller, command: command)
                    .padding(DaybookSpacing.md)
                    .background(DaybookPalette.cardSurface)
            } else { operationContent }
        }
        .onKeyPress(keys: [.upArrow, .downArrow, .space, .return, .tab, .escape]) { key in
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
        let source = controller.buffer
        return ScrollView {
            VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                if let state = controller.operations, let draft = state.active,
                   let command = CommandCatalog.standard.command(id: draft.commandID) {
                    header(command, draft: draft, source: source)
                    if let decision = state.pending { decisionControls(decision, source: source) }
                    if controller.operationExpanded {
                        ForEach(command.parameters, id: \.id) { parameter in
                            UnifiedSearchParameterField(controller: controller, draft: draft,
                                command: command, parameter: parameter, source: source)
                            DaybookDivider()
                        }
                        validation(draft)
                    }
                    retained(state, source: source)
                } else if let command = controller.browsedCommand {
                    Text(verbatim: command.name(locale: locale)).font(DaybookType.body.weight(.semibold))
                    Text(verbatim: command.summary(locale: locale)).font(DaybookType.caption)
                    ForEach(command.parameters, id: \.id) { parameter in
                        Text(verbatim: L10n.format(parameter.id.nameKey, locale: locale) + " · "
                            + L10n.format(parameter.required ? "unified.operation.required" : "unified.operation.optional", locale: locale))
                    }
                    Button("unified.operation.begin") { controller.beginOperation(command.id, source: source) }
                        .buttonStyle(DaybookButtonStyle(.prominent, size: .regular))
                        .accessibilityIdentifier("unified.operation.begin")
                }
            }
            .padding(DaybookSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DaybookScrollerConfigurator())
        .background(DaybookPalette.cardSurface)
        .accessibilityIdentifier("unified.operation.preview")
    }

    private func header(_ command: CommandDescriptor, draft: CommandDraft, source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(verbatim: command.name(locale: locale)).font(DaybookType.body.weight(.semibold))
            Text(verbatim: command.summary(locale: locale)).font(DaybookType.caption)
            Text(draft.check().staticallyValid ? "unified.operation.complete" : "unified.operation.incomplete")
                .font(DaybookType.caption)
            if !command.interactions.isDisjoint(with: [.secureInput, .authentication, .freshAuthentication]) {
                Text("unified.operation.secure").font(DaybookType.caption)
            }
            if command.parameters.contains(where: {
                !UnifiedSearchParameterContext.supports($0, command: command)
                    && !controller.supportsObjectField($0, command: command)
            }) {
                Text("unified.operation.later").font(DaybookType.caption)
            }
            if !command.targetTypes.isEmpty {
                Text(verbatim: L10n.format("unified.objects.count", locale: locale, draft.targets.objects.count))
                    .font(DaybookType.caption)
            }
            Text(verbatim: summary(command, draft: draft)).font(DaybookType.caption)
                .lineLimit(2).help(summary(command, draft: draft))
            HStack {
                Button(controller.operationExpanded ? "unified.operation.collapse" : "unified.operation.expand") {
                    guard controller.validates(source) else { return }
                    controller.operationExpanded.toggle()
                    if !controller.operationExpanded { disclosureFocused = true }
                }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact)).focused($disclosureFocused)
                .accessibilityIdentifier("unified.operation.disclosure")
                Text("unified.operation.draftOnly").font(DaybookType.micro)
            }
            if !draft.baseline.values.isEmpty { Text("unified.operation.syntheticBaseline").font(DaybookType.caption) }
            Text(LocalizedStringKey(controller.operationMessage)).font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
        }
    }

    private func summary(_ command: CommandDescriptor, draft: CommandDraft) -> String {
        command.parameters.compactMap { parameter in
            guard let argument = draft.arguments.first(where: { $0.parameter == parameter.id }) else { return nil }
            let value = argument.operation.requiresValue
                ? UnifiedSearchOperationCopy.value(argument.value, locale: locale, calendar: calendar)
                : L10n.format("unified.operation.mode." + argument.operation.rawValue, locale: locale)
            return L10n.format(parameter.id.nameKey, locale: locale) + ": " + value
        }.joined(separator: " · ")
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
                    Button { controller.beginOperation(command.id, source: source) } label: {
                        Text(verbatim: command.name(locale: locale))
                    }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                    .accessibilityIdentifier("unified.operation.restore." + command.id.rawValue)
                }
            }
        }
    }
}
