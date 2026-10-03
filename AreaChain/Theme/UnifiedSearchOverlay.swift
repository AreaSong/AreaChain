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

/// 与输入布局解耦；未来预览作为宿主的独立下方内容，不重复挂载此补全层。
private struct UnifiedSearchOverlayHost: ViewModifier {
    var motionDisabled = false
    func body(content: Content) -> some View {
        content.overlayPreferenceValue(UnifiedSearchAnchorKey.self) { sources in
            GeometryReader { proxy in
                if let source = sources.first(where: { $0.state.focused && $0.state.suggestions.isActive }) {
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
        let completion = state.completion
        ZStack(alignment: .topLeading) {
            // 仅局部点击层关闭候选，不注册任何键盘监听。
            if !source.previewBelow {
                Color.clear.contentShape(UnifiedSearchDismissRegion(input: anchor), eoFill: true)
                    .onTapGesture { state.suggestions.dismiss() }
                    .accessibilityHidden(true)
            }
            SyntaxAutocompletePopup(
                state: state.suggestions, growsUpward: placement.growsUpward,
                width: placement.frame.width, maxHeight: placement.frame.height, motionDisabled: reduceMotion || motionDisabled,
                onCommit: { item in
                    guard let completion, let candidate = completion.result.candidates.first(where: { $0.id == item.id }) else { return }
                    _ = state.accept(candidate, source: completion)
                },
                customRow: { item, selected in
                    AnyView(UnifiedSearchCandidateRow(candidate: completion?.result.candidates.first { $0.id == item.id },
                                                     selected: selected, locale: source.locale))
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

private struct UnifiedSearchCandidateRow: View {
    let candidate: CommandPathCandidate?
    let selected: Bool
    let locale: Locale

    var body: some View {
        if let candidate {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verbatim: candidate.title).font(DaybookType.body.weight(.medium)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(verbatim: L10n.format("unified.category." + candidate.category.rawValue, locale: locale))
                        .font(DaybookType.micro)
                }
                Text(verbatim: candidate.summary).font(DaybookType.caption).lineLimit(1)
                Text(verbatim: availability(candidate)).font(DaybookType.micro).lineLimit(1)
            }
            .foregroundStyle(DaybookPalette.text.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
            .background(RoundedRectangle(cornerRadius: DaybookRadius.xs)
                .fill(selected ? DaybookPalette.accent.fill : .clear))
            .help(candidate.title + "\n" + candidate.summary + "\n" + availability(candidate))
            .accessibilityElement(children: .combine)
        }
    }

    private func availability(_ candidate: CommandPathCandidate) -> String {
        if candidate.category == .group { return L10n.format("unified.input.browse", locale: locale) }
        if candidate.category == .scope { return L10n.format("unified.input.scope", locale: locale) }
        return L10n.format("unified.input.unavailable", locale: locale)
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
