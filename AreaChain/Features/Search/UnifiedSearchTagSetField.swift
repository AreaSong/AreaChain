import SwiftUI

/// 标签集合临时选择复用原字段外壳和原生文本；不拥有参数字典或标签写入入口。
struct UnifiedSearchTagSetField: View {
    @Bindable var controller: UnifiedSearchController
    let picker: UnifiedSearchTagSelection
    @Environment(\.locale) private var locale
    @State private var queryFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.tags.choose").font(DaybookType.body.weight(.semibold))
            if controller.validatesTagSelection(picker) {
                DaybookInputShell(kind: .search, focused: queryFocused) {
                    DaybookTextField(text: Binding(get: { picker.query }, set: {
                        controller.updateTagQuery($0, picker: picker)
                    }), placeholder: L10n.format("unified.tags.query", locale: locale), focus: $queryFocused,
                    onSubmit: { controller.acceptTags(picker) }, onCommandReturn: {},
                    allowsShiftNewline: false, onEscape: { controller.cancelTags(picker.id) },
                    onMoveDown: {
                        queryFocused = false
                        controller.inputFocused = true
                        controller.moveTag(1, picker: picker)
                        return true
                    })
                }
                .accessibilityIdentifier("unified.tags.query")
                Text(verbatim: L10n.format("unified.objects.temporaryCount", locale: locale, picker.selected.count))
                    .font(DaybookType.caption)
                rows
                Button("unified.tags.accept") { controller.acceptTags(picker) }
                    .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                    .accessibilityIdentifier("unified.tags.accept")
            } else {
                Text("unified.composition.stale").font(DaybookType.caption)
            }
            Button("unified.operation.cancel") { controller.cancelTags(picker.id) }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                .accessibilityIdentifier("unified.tags.cancel")
        }
        .padding(DaybookSpacing.md)
        .onKeyPress(keys: [.upArrow, .downArrow, .space, .return, .tab, .escape]) { key in
            guard key.modifiers.isEmpty, !queryFocused else { return .ignored }
            switch key.key {
            case .upArrow: controller.moveTag(-1, picker: picker)
            case .downArrow: controller.moveTag(1, picker: picker)
            case .space: if let id = picker.active { controller.toggleTag(id, picker: picker) }
            case .escape: controller.cancelTags(picker.id)
            default: controller.acceptTags(picker)
            }
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unified.tags.picker")
    }

    private var rows: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                    ForEach(picker.candidates.matching(picker.query), id: \.id) { row in
                        if let id = row.id, let name = row.name {
                            Button { controller.toggleTag(id, picker: picker) } label: {
                                HStack {
                                    Image(systemName: picker.selected.contains(id) ? "checkmark.square.fill" : "square")
                                    Text(verbatim: name).fixedSize(horizontal: false, vertical: true)
                                    if row.state != .live { Text("unified.tags.tombstone").font(DaybookType.micro) }
                                    Spacer(minLength: 0)
                                }
                                .padding(DaybookSpacing.xs)
                                .background(picker.active == id ? DaybookPalette.fill.subtle : .clear)
                            }
                            .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                            .accessibilityIdentifier("unified.tags.row." + id.uuidString)
                            .accessibilityAddTraits(picker.selected.contains(id) ? .isSelected : [])
                            .id(id)
                        }
                    }
                }
            }
            .background(DaybookScrollerConfigurator())
            .onChange(of: picker.active) { _, id in if let id { proxy.scrollTo(id) } }
        }
    }
}
