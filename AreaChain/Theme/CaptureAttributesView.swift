import SwiftUI

struct CaptureAttributes {
    struct Item: Identifiable {
        let id: String
        let title: String
        let icon: String
        var isNewTag = false
        var isPriority = false
    }

    let items: [Item]
    var count: Int { items.count }

    init(text: String, knownTags: [String]) {
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        let known = Set(knownTags.map(TagSyntax.normalizedName))
        var items = parsed.tagNames.map {
            Item(id: "tag." + $0, title: "#" + $0, icon: "tag", isNewTag: !known.contains(TagSyntax.normalizedName($0)))
        }
        if let time = parsed.timeLabel { items.append(Item(id: "time", title: time, icon: "clock")) }
        if let priority = parsed.priorityLabel {
            items.append(Item(id: "priority", title: priority, icon: "exclamationmark.circle", isPriority: true))
        }
        self.items = items
    }
}

struct CaptureAttributesButton: View {
    var text: String
    var knownTags: [String]
    @Bindable var state: SyntaxAutocompleteState
    @Environment(\.locale) private var locale

    var body: some View {
        let attributes = CaptureAttributes(text: text, knownTags: knownTags)
        let displayCount = attributes.count > 99 ? "99+" : String(attributes.count)
        Button {
            if state.showsAttributes { state.dismiss() }
            else { state.showAttributes() }
        } label: {
            Group {
                if attributes.count > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "slider.horizontal.3")
                            .font(DaybookType.micro)
                        Text(displayCount)
                            .font(DaybookType.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .foregroundStyle(DaybookPalette.accent.base)
                    .background(
                        Capsule()
                            .fill(DaybookPalette.accent.base.opacity(state.showsAttributes ? 0.20 : 0.12)) // token-exempt: 20% 与 12% 写在同一个三元表达式里
                    )
                    .overlay(
                        Capsule()
                            .stroke(DaybookPalette.accent.border, lineWidth: 0.8)
                    )
                } else {
                    Image(systemName: "slider.horizontal.3")
                        .font(DaybookType.badge)
                        .foregroundStyle(DaybookPalette.text.secondary.opacity(0.40)) // token-exempt: 40% 次要色没有对应令牌
                }
            }
            .frame(width: 58, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 属性按钮固定 58×22，胶囊留给 P5
        .background(SyntaxViewAnchor("syntax.attributes.button"))
        .disabled(attributes.count == 0)
        .accessibilityIdentifier("syntax.attributes.button")
        .accessibilityLabel(L10n.format("syntax.attributes.accessibility", locale: locale, attributes.count))
        .accessibilityAddTraits(state.showsAttributes ? [.isSelected] : [])
        .help("syntax.attributes.help")
        .syntaxAttributes(state, attributes: attributes)
        .onChange(of: text) { _, _ in
            if state.showsAttributes { state.dismiss() }
        }
    }
}

struct CaptureAttributesPopup: View {
    let attributes: CaptureAttributes
    let maxHeight: CGFloat
    @Bindable var state: SyntaxAutocompleteState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("syntax.attributes.title", systemImage: "slider.horizontal.3")
                    .font(DaybookType.label)
                Spacer()
                DaybookIconButton(systemName: "xmark", label: "common.close", size: .inline) {
                    state.dismiss()
                }
                .focusable(false)
                .background(SyntaxViewAnchor("syntax.attributes.close"))
                .accessibilityIdentifier("syntax.attributes.close")
            }
            .padding(10)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(attributes.items) { item in attributeRow(item) }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .daybookScroll()
            .frame(height: max(0, maxHeight - 78))
            Divider()
            Text("syntax.attributes.readonly")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .padding(10)
        }
        .frame(height: maxHeight, alignment: .top)
        .foregroundStyle(DaybookPalette.text.primary)
        .background(RoundedRectangle(cornerRadius: DaybookRadius.small).fill(DaybookPalette.fill.page))
        .overlay(RoundedRectangle(cornerRadius: DaybookRadius.small).stroke(DaybookPalette.border.default.opacity(0.7), lineWidth: 0.7)) // token-exempt: 70% 分隔线没有对应令牌
        .daybookElevation(.floating)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("syntax.overlay.attributes")
    }

    private func attributeRow(_ item: CaptureAttributes.Item) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.icon).foregroundStyle(DaybookPalette.accent.base).frame(width: 14)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                if item.isPriority { Text(LocalizedStringKey(item.title)) }
                else { Text(item.title) }
                if item.isNewTag {
                    Text("syntax.tag.create.on.save").font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
                }
            }
            .font(DaybookType.subtitle)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("syntax.attribute." + item.id)
    }
}
