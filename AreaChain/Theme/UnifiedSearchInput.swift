import AppKit
import SwiftUI

enum UnifiedSearchInputLayout: CaseIterable {
    case standard, compact
    var minimumWidth: CGFloat { self == .standard ? 420 : 280 }
    var maximumSuggestionsHeight: CGFloat { self == .standard ? 300 : 240 }
}

/// 宿主提供唯一显示值和带原 lease 的事件回调；隔离宿主与正式版共用。
struct UnifiedSearchInput: View {
    let buffer: UnifiedSearchBuffer
    let actions: UnifiedSearchActions
    var layout: UnifiedSearchInputLayout = .standard
    var reset: UnifiedSearchInputReset?
    var previewBelow = false
    var showsStatus = true
    /// 宿主可收窄最小宽度（菜单栏底栏）；nil 沿布局默认值，候选浮层高度仍按布局。
    var minimumWidth: CGFloat?
    /// `#` 候选可列的已有标签名；宿主按旧搜索取存活标签，不传则 `#` 不出候选。
    var availableTags: [String] = []
    @Binding var focused: Bool
    @Environment(\.locale) private var locale
    @State private var state: UnifiedSearchInputState

    init(buffer: UnifiedSearchBuffer, focused: Binding<Bool>, actions: UnifiedSearchActions,
         layout: UnifiedSearchInputLayout = .standard, reset: UnifiedSearchInputReset? = nil,
         previewBelow: Bool = false, showsStatus: Bool = true,
         minimumWidth: CGFloat? = nil, availableTags: [String] = []) {
        self.minimumWidth = minimumWidth
        self.availableTags = availableTags
        self.buffer = buffer
        _focused = focused
        self.actions = actions
        self.layout = layout
        self.reset = reset
        self.previewBelow = previewBelow
        self.showsStatus = showsStatus
        _state = State(initialValue: UnifiedSearchInputState(buffer: buffer, actions: actions))
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
                    searchConfiguration: .init(actions: actions, locale: locale, availableTags: availableTags)
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
        .frame(minWidth: minimumWidth ?? layout.minimumWidth)
        .onAppear { reset?.state = state }
        .onDisappear { state.end(); if reset?.state === state { reset?.state = nil } }
    }

    private var status: String {
        if buffer.selectingObjects { return L10n.format("unified.objects.keyboard", locale: locale) }
        if UnifiedSearchInputState.isContentScopePrefix(buffer.text) {
            return L10n.format("unified.input.scope", locale: locale)
        }
        return L10n.format("unified.input.hint", locale: locale)
    }
}
