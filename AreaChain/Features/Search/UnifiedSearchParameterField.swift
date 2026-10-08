import SwiftUI

/// 每个回调捕获渲染时的 lease/stamp。只有原生连续文字编辑能消费同步返回的新缓冲。
struct UnifiedSearchParameterField: View {
    @Bindable var controller: UnifiedSearchController
    let draft: CommandDraft
    let command: CommandDescriptor
    let parameter: CommandParameter
    let source: UnifiedSearchBuffer
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @State private var dateExpanded = false
    @FocusState private var dateButtonFocused: Bool
    @FocusState private var tagsButtonFocused: Bool

    private var argument: CommandArgument? { draft.arguments.first { $0.parameter == parameter.id } }
    private var operation: CommandFieldOperation { argument?.operation ?? .unspecified }
    private var context: UnifiedSearchParameterContext {
        .init(command: command, parameter: parameter, operation: controller.fieldOperation(parameter, draft: draft))
    }
    private var supported: Bool { UnifiedSearchParameterContext.supports(parameter, command: command) }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            HStack {
                Text(verbatim: L10n.format(parameter.id.nameKey, locale: locale)).font(DaybookType.body.weight(.medium))
                Text(parameter.required ? "unified.operation.required" : "unified.operation.optional")
                    .font(DaybookType.micro).foregroundStyle(DaybookPalette.text.secondary)
                Spacer(minLength: 0)
            }
            if controller.editingPlanItem?.links.results[parameter.id] != nil {
                Text("unified.plan.reference.bound").font(DaybookType.caption)
            } else if parameter.id == .target || isObject {
                UnifiedSearchObjectField(controller: controller, draft: draft, command: command,
                    location: parameter.id == .target ? .targets : .parameter(parameter.id), source: source)
            } else if controller.supportsTagField(parameter, command: command) {
                operationPicker
                if context.operation.requiresValue {
                    Button("unified.tags.choose") { controller.beginTagSelection(source: source) }
                        .buttonStyle(DaybookButtonStyle(.quiet, size: .compact)).focusable().focused($tagsButtonFocused)
                        .accessibilityIdentifier("unified.tags.choose")
                }
                Text(command.id.rawValue == "todo.tags" ? "unified.field.tagsHint" : "unified.tags.syntaxHint").font(DaybookType.caption)
            } else if supported {
                operationPicker
                if context.operation.requiresValue { editor }
                if parameter.type == .boolean || isChoice {
                    Button("unified.operation.useInput") { controller.chooseParameter(parameter.id, source: source) }
                        .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                }
            } else {
                Text(LocalizedStringKey(UnifiedSearchOperationCopy.requirement(parameter, command: command)))
                    .font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
            }
            if parameter.id != .target && !isObject { preview }
            if command.id.rawValue == "todo.create", ![.title, .day].contains(parameter.id),
               !controller.hasTaskComposition || parameter.id == .notes {
                Text("unified.composition.unsupportedField").font(DaybookType.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unified.parameter." + parameter.id.rawValue)
        .onChange(of: controller.tagReturnRevision) { _, _ in
            restoreTagFocus()
        }
        .onAppear { restoreTagFocus() }
    }

    private func restoreTagFocus() {
        if parameter.id == .tags, controller.tagReturnDraftID == draft.id {
            tagsButtonFocused = true
            controller.tagReturnDraftID = nil
        }
    }

    private var isChoice: Bool { if case .choice = parameter.type { return true }; return false }
    private var isObject: Bool {
        switch parameter.type {
        case .object, .objects: return true
        default: return false
        }
    }

    private var operationPicker: some View {
        DaybookPicker("unified.operation.mode", selection: Binding(get: { operation }, set: { mode in
            guard controller.validates(source) else { return }
            controller.parameterText[draft.id]?[parameter.id] = nil
            _ = controller.editParameter(.init(parameter: parameter.id, operation: mode,
                value: mode.requiresValue ? argument?.value : nil), source: source)
        }), options: ([CommandFieldOperation.unspecified] + CommandFieldOperation.allCases.filter {
            parameter.operations.contains($0) && $0 != .unspecified
        }).map { .init($0, verbatim: L10n.format("unified.operation.mode." + $0.rawValue, locale: locale)) }, layout: .formRow, eventVersion: source.version)
        .accessibilityIdentifier("unified.parameter.mode." + parameter.id.rawValue)
    }

    @ViewBuilder private var editor: some View {
        switch parameter.type {
        case .choice(let choices):
            DaybookPicker("unified.operation.value", selection: Binding(get: {
                if case .choice(let value) = argument?.value { return value }; return ""
            }, set: { send($0.isEmpty ? nil : .choice($0)) }), options: [.init("", "unified.operation.unfilled")]
                + choices.map { .init($0.value, verbatim: controller.localSettings?.supports(command.id) == true
                    ? UnifiedSearchSettingCopy.value(.choice($0.value), locale: locale, calendar: calendar)
                    : L10n.format($0.nameKey, locale: locale)) }, layout: .formRow, eventVersion: source.version)
            .accessibilityIdentifier("unified.parameter.choice." + parameter.id.rawValue)
        case .boolean:
            DaybookPicker("unified.operation.value", selection: Binding<Bool?>(get: {
                if case .boolean(let value) = argument?.value { return value }; return nil
            }, set: { send($0.map(CommandValue.boolean)) }), options: [
                .init(nil, "unified.operation.unfilled"),
                .init(true, command.id.rawValue == "todo.completion" ? "unified.field.completed" : "unified.operation.on"),
                .init(false, command.id.rawValue == "todo.completion" ? "unified.field.open" : "unified.operation.off")
            ], layout: .formRow, eventVersion: source.version)
            .accessibilityIdentifier("unified.parameter.boolean." + parameter.id.rawValue)
        case .number(let range, let integer):
            textEditor
            Text(verbatim: "\(range.lowerBound.formatted()) … \(range.upperBound.formatted()) · "
                + L10n.format(integer ? "unified.operation.integer" : "unified.operation.decimal", locale: locale))
                .font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
        case .shortText: textEditor
        case .day: dayEditor
        case .time:
            DaybookTimePicker("command.parameter.time", minutes: Binding(get: {
                if case .time(let value) = argument?.value { return value }; return nil
            }, set: { if let value = $0 { send(.time(value)) } }), eventVersion: source.version)
        case .weekdays:
            DaybookWeekdayPicker(selection: weekdayValue, onUpdateSelection: { value in
                send(value == 0 ? nil : .weekdays(value))
            }, allowsEmpty: true, accessibilityTitle: Text("command.parameter.weekdays"))
            if weekdayValue == 0 { Text("unified.routine.chooseDay").font(DaybookType.caption) }
        default: EmptyView()
        }
    }

    private var textEditor: some View {
        UnifiedSearchParameterText(controller: controller, context: context,
            buffer: controller.parameterBuffer(parameter, draft: draft))
            .id(draft.id.uuidString + parameter.id.rawValue)
    }

    private var dayEditor: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Button(dateExpanded ? "unified.operation.hideDate" : "unified.operation.chooseDate") {
                guard controller.validates(source) else { return }
                dateExpanded.toggle()
                if !dateExpanded { dateButtonFocused = true }
            }
            .buttonStyle(DaybookButtonStyle(.quiet, size: .compact)).focused($dateButtonFocused)
            .accessibilityIdentifier("unified.parameter.date")
            if dateExpanded {
                DaybookDatePicker(selection: Binding(get: {
                    if case .day(let key) = argument?.value { return key }; return ""
                }, set: { send(.day($0)) }))
                .onExitCommand { dateExpanded = false; dateButtonFocused = true }
            }
        }
    }

    private var weekdayValue: Int { if case .weekdays(let value) = argument?.value { return value }; return 0 }

    private func send(_ value: CommandValue?) {
        _ = controller.editParameter(.init(parameter: parameter.id, operation: context.operation, value: value), source: source)
    }

    private var preview: some View {
        let before = UnifiedSearchOperationCopy.original(draft.baseline.original(parameter.id, targets: draft.targets),
                                                        locale: locale, calendar: calendar)
        let after: String = {
            guard let argument else { return L10n.format("unified.operation.unfilled", locale: locale) }
            if !argument.operation.requiresValue {
                return L10n.format("unified.operation.mode." + argument.operation.rawValue, locale: locale)
            }
            return UnifiedSearchOperationCopy.value(argument.value, locale: locale, calendar: calendar)
        }()
        return VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            if command.id.rawValue == "todo.title" {
                Text("unified.title.inputHint").font(DaybookType.caption)
                Text(verbatim: after).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
            } else if command.id.rawValue == "todo.create" {
                Text(verbatim: after).font(DaybookType.caption)
                    .fixedSize(horizontal: false, vertical: true)
            } else if controller.localSettings?.supports(command.id) == true {
                UnifiedSearchSettingValues(before: draft.baseline.preference?.memory, after: argument?.value)
            } else {
                Text(verbatim: before + " → " + after).font(DaybookType.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let raw = controller.parameterText[draft.id]?[parameter.id]?.text,
               !raw.isEmpty, context.value(raw) == nil {
                Text("unified.operation.invalid").font(DaybookType.caption)
            }
        }.foregroundStyle(DaybookPalette.text.secondary)
    }
}
