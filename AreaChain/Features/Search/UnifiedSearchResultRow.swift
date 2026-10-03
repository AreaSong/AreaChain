import SwiftUI

struct UnifiedSearchResultRow: View {
    let row: ContentQueryPresentationRow
    let layout: UnifiedSearchInputLayout
    let active: Bool
    let selected: Bool
    let activate: () -> Void
    let select: () -> Void
    var selectionLabel: String?
    var showsIdentityDate = false
    @FocusState private var selectionFocused: Bool
    @State private var pendingSelection: (() -> Void)?
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: select) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(DaybookButtonStyle(.quiet))
            .focusable().focused($selectionFocused)
            .onKeyPress(.space, phases: [.down, .repeat, .up]) { press in
                guard selectionFocused, press.modifiers.isEmpty else { pendingSelection = nil; return .ignored }
                // 保留按下时的回调及其宿主版本；释放时不能换成重绘后的新事件。
                if press.phase == .down { pendingSelection = select }
                if press.phase == .up { let action = pendingSelection; pendingSelection = nil; action?() }
                return .handled
            }
            .onChange(of: selectionFocused) { _, value in if !value { pendingSelection = nil } }
            .accessibilityLabel(Text(LocalizedStringKey(selectionLabel ?? (selected ? "unified.results.deselect" : "unified.results.select"))))
            .accessibilityValue(Text(selected ? "unified.results.selected" : "unified.results.unselected"))
            .accessibilityIdentifier("unified.select." + row.id.searchIdentifier)
            Button(action: activate) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: L10n.format(UnifiedSearchResultCopy.typeKey(row.id.type), locale: locale))
                        .font(DaybookType.badge.weight(.semibold))
                        .foregroundStyle(DaybookPalette.accent.base)
                    if showsIdentityDate, let day = row.id.dayKey {
                        Text(verbatim: day).font(DaybookType.caption)
                    }
                    if let primary = row.primary {
                        DaybookSearchFragment(value: primary, identifier: "unified.title." + row.id.searchIdentifier)
                    } else if row.summary == nil {
                        Text("unified.results.metadataOnly")
                    }
                    if let summary = row.summary {
                        DaybookSearchFragment(value: summary, secondary: true,
                                              identifier: "unified.summary." + row.id.searchIdentifier)
                    }
                    ForEach(row.relations.indices, id: \.self) { index in
                        Text(verbatim: UnifiedSearchResultCopy.relation(row.relations[index], locale: locale))
                            .font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary).lineLimit(2)
                    }
                    let metadata = UnifiedSearchResultCopy.metadata(row.metadata, locale: locale)
                    if !metadata.isEmpty {
                        Text(verbatim: metadata).font(DaybookType.caption)
                            .foregroundStyle(DaybookPalette.text.secondary).lineLimit(2).help(metadata)
                    }
                    if !row.diagnostics.isEmpty {
                        Text("unified.results.fragmentLimited").font(DaybookType.caption)
                            .foregroundStyle(DaybookPalette.text.secondary)
                    }
                }
                .font(DaybookType.body).foregroundStyle(DaybookPalette.text.primary)
                .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain) // control: 结果行仅改变浏览活动身份，真实打开由输入意图消费。
            .accessibilityIdentifier("unified.hit." + row.id.searchIdentifier)
            .accessibilityValue(Text(active ? "unified.results.current" : "unified.results.match"))
        }
        .padding(layout == .compact ? 8 : 12)
        .daybookSearchResultSurface(isSelected: active)
    }
}

extension CommandObjectReference {
    var searchIdentifier: String { type.rawValue + "." + id.uuidString + (dayKey.map { "." + $0 } ?? "") }
}

extension ContentQueryMatchField {
    var searchIdentifier: String {
        switch self {
        case .title: "title"
        case .notes: "notes"
        case .diaryBody: "diaryBody"
        case .clipboardPlainText: "clipboardPlainText"
        case .filename: "filename"
        case .tagName: "tagName"
        default: "metadata"
        }
    }
}
