import AppKit
import SwiftUI

enum UnifiedSearchInputLayout: CaseIterable {
    case standard, compact
    var minimumWidth: CGFloat { self == .standard ? 420 : 280 }
    var maximumSuggestionsHeight: CGFloat { self == .standard ? 300 : 240 }
}

/// 宿主提供唯一显示值和带原 lease 的事件回调；仅在隔离宿主使用，尚未接生产。
struct UnifiedSearchInput: View {
    let buffer: UnifiedSearchBuffer
    let actions: UnifiedSearchActions
    var layout: UnifiedSearchInputLayout = .standard
    var parser = CommandPathParser()
    var configuration = CommandDiscoveryConfiguration.standard
    var reset: UnifiedSearchInputReset?
    var parameter: UnifiedSearchParameterContext?
    var previewBelow = false
    var showsStatus = true
    @Binding var focused: Bool
    @Environment(\.locale) private var locale
    @State private var state: UnifiedSearchInputState

    init(buffer: UnifiedSearchBuffer, focused: Binding<Bool>, actions: UnifiedSearchActions,
         layout: UnifiedSearchInputLayout = .standard, parser: CommandPathParser = .init(),
         configuration: CommandDiscoveryConfiguration = .standard, reset: UnifiedSearchInputReset? = nil,
         parameter: UnifiedSearchParameterContext? = nil, previewBelow: Bool = false, showsStatus: Bool = true) {
        self.buffer = buffer
        _focused = focused
        self.actions = actions
        self.layout = layout
        self.parser = parser
        self.configuration = configuration
        self.reset = reset
        self.parameter = parameter
        self.previewBelow = previewBelow
        self.showsStatus = showsStatus
        _state = State(initialValue: UnifiedSearchInputState(buffer: buffer, parser: parser, actions: actions))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DaybookInputShell(kind: .search, focused: focused) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .accessibilityHidden(true)
            } field: {
                DaybookTextField(
                    text: .constant(buffer.text), placeholder: L10n.format("unified.input.placeholder", locale: locale),
                    focus: $focused, onSubmit: {}, onCommandReturn: {},
                    commandChord: .init(keyCode: ShortcutKey.returnKey, modifiers: ShortcutModifier.command),
                    allowsShiftNewline: false, unifiedSearch: state, searchBuffer: buffer,
                    searchConfiguration: .init(actions: actions, parser: parser, discovery: configuration,
                                               locale: locale, parameter: parameter)
                )
                .accessibilityLabel(Text("unified.input.label"))
                .accessibilityIdentifier("unified.search.input")
            }
            .anchorPreference(key: UnifiedSearchAnchorKey.self, value: .bounds) {
                [UnifiedSearchAnchor(bounds: $0, state: state, layout: layout, locale: locale, previewBelow: previewBelow)]
            }
            if showsStatus { Text(verbatim: status)
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .lineLimit(2)
                .frame(height: 32, alignment: .topLeading)
                .accessibilityIdentifier("unified.search.status") }
        }
        .frame(minWidth: layout.minimumWidth)
        .onAppear { reset?.state = state }
        .onDisappear { state.end(); if reset?.state === state { reset?.state = nil } }
    }

    private var status: String {
        if buffer.selectingObjects { return L10n.format("unified.objects.keyboard", locale: locale) }
        if let parameter {
            return L10n.format("unified.operation.editing", locale: locale)
                + " · " + L10n.format(parameter.parameter.id.nameKey, locale: locale)
        }
        let result = state.completion?.result
        let key: String
        switch result?.state {
        case .invalid: key = "unified.input.invalid"
        case .incompletePath: key = "unified.input.incomplete"
        case .incompleteArguments: key = "unified.input.parameters"
        case .group: key = "unified.input.browse"
        case .scope: key = "unified.input.scope"
        case .command: key = "unified.input.unavailable"
        default: key = "unified.input.hint"
        }
        return L10n.format(key, locale: locale)
    }
}
