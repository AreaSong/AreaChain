import SwiftUI

struct UnifiedSearchAnchor {
    let bounds: Anchor<CGRect>
    let state: UnifiedSearchInputState
    let layout: UnifiedSearchInputLayout
    let locale: Locale
    var previewBelow = false
}

struct UnifiedSearchAnchorKey: PreferenceKey {
    static let defaultValue: [UnifiedSearchAnchor] = []
    static func reduce(value: inout [UnifiedSearchAnchor], nextValue: () -> [UnifiedSearchAnchor]) {
        value.append(contentsOf: nextValue())
    }
}

/// 仅承载 `#`／`!`／`@` 搜索语法候选浮层；`/` 命令行补全与动作匹配由 `UnifiedSearchCLIPanel` 统一承载。
private struct UnifiedSearchOverlayHost: ViewModifier {
    var motionDisabled = false
    func body(content: Content) -> some View {
        content.overlayPreferenceValue(UnifiedSearchAnchorKey.self) { sources in
            GeometryReader { proxy in
                if let source = sources.first(where: { $0.state.focused && $0.state.showsSyntax && $0.state.suggestions.isActive }) {
                    UnifiedSearchOverlay(source: source, proxy: proxy, motionDisabled: motionDisabled)
                }
            }
        }
        .transformPreference(UnifiedSearchAnchorKey.self) { $0 = [] }
    }
}

private struct UnifiedSearchOverlay: View {
    let source: UnifiedSearchAnchor
    let proxy: GeometryProxy
    var motionDisabled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let anchor = proxy[source.bounds]
        let available = source.previewBelow ? max(1, anchor.minY - 12) : source.layout.maximumSuggestionsHeight
        let placement = SyntaxOverlayPlacement.resolve(
            anchor: anchor, container: proxy.size,
            preferred: CGSize(width: anchor.width, height: min(available,
                CGFloat(source.state.suggestions.candidates.count) * 68 + 33)),
            prefersAbove: true, matchAnchorWidth: true
        )
        let state = source.state
        ZStack(alignment: .topLeading) {
            if !source.previewBelow {
                Color.clear.contentShape(UnifiedSearchDismissRegion(input: anchor), eoFill: true)
                    .onTapGesture { state.suggestions.dismiss() }
                    .accessibilityHidden(true)
            }
            SyntaxAutocompletePopup(
                state: state.suggestions, growsUpward: placement.growsUpward,
                width: placement.frame.width, maxHeight: placement.frame.height, motionDisabled: reduceMotion || motionDisabled,
                onCommit: { item in
                    _ = state.accept(syntax: item)
                },
                customRow: { item, selected in
                    AnyView(UnifiedSearchSyntaxRow(candidate: item, selected: selected, locale: source.locale))
                }, rowHeight: 68, listMaximumHeight: source.layout.maximumSuggestionsHeight - 25
            )
            .environment(\.locale, source.locale)
            .frame(width: placement.frame.width, height: placement.frame.height, alignment: .top)
            .background(SyntaxViewAnchor("syntax.unified.candidates"))
            .accessibilityIdentifier("syntax.unified.candidates")
            .offset(x: placement.frame.minX, y: placement.frame.minY)
        }
    }
}

/// `#`／`!`／`@` 语法候选行。
private struct UnifiedSearchSyntaxRow: View {
    let candidate: SyntaxCandidate
    let selected: Bool
    let locale: Locale

    var body: some View {
        let summary = candidate.subtitle.map { L10n.format($0, locale: locale) } ?? ""
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(verbatim: candidate.title).font(DaybookType.body.weight(.medium)).lineLimit(1)
                Spacer(minLength: 4)
                Text(verbatim: candidate.kind.symbol).font(DaybookType.micro)
            }
            Text(verbatim: summary).font(DaybookType.caption).lineLimit(1)
        }
        .foregroundStyle(DaybookPalette.text.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(4)
        .background(RoundedRectangle(cornerRadius: DaybookRadius.xs)
            .fill(selected ? DaybookPalette.accent.fill : .clear))
        .help(candidate.title + "\n" + summary)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func unifiedSearchOverlayHost(motionDisabled: Bool = false) -> some View {
        modifier(UnifiedSearchOverlayHost(motionDisabled: motionDisabled))
    }
}

private struct UnifiedSearchDismissRegion: Shape {
    let input: CGRect
    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRect(input)
        return path
    }
}
