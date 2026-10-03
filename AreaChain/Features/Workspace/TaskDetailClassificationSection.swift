import SwiftData
import SwiftUI

// MARK: - Tag Selector

/// 抽屉标签多选与新建组件
struct TaskDetailTagSelector: View {
    var tagIDs: String
    var tags: [TagItem]
    var onToggleTag: (UUID) -> Void
    var onCreateTag: (String) -> Bool

    @Environment(\.locale) private var locale
    @State private var isCreatingTag = false
    @State private var newTagName = ""
    @State private var createError: String?

    private var activeTags: [TagItem] {
        Catalog.taskPickerTags(tags, attachedIDs: tagIDs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: L10n.string("drawer.tags.title", locale: locale))
                    .font(DaybookType.label)
                    .foregroundStyle(DaybookPalette.text.secondary)
                Spacer()
                DaybookIconButton(systemName: "plus.circle", label: "drawer.tag.add", size: .inline) {
                    createError = nil
                    newTagName = ""
                    isCreatingTag = true
                }
            }

            if activeTags.isEmpty {
                Text(verbatim: L10n.string("drawer.tag.empty", locale: locale))
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.secondary.opacity(0.7)) // token-exempt: 70% 次要色没有对应令牌
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 4)], spacing: 4) {
                    ForEach(activeTags) { tag in
                        let isContained = TagIDList.contains(tagIDs, tag.id)
                        DaybookChip(
                            tint: DaybookPalette.tagDefault,
                            isSelected: isContained,
                            action: { onToggleTag(tag.id) }
                        ) {
                            Text("#\(tag.name)")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isCreatingTag) {
            newTagSheet
                .environment(\.locale, locale)
        }
    }

    private var newTagSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: L10n.string("drawer.tag.create.title", locale: locale))
                .font(DaybookType.body.weight(.semibold))
                .foregroundStyle(DaybookPalette.text.primary)
            DaybookFormTextField(verbatim: L10n.string("drawer.tag.create.name", locale: locale), text: $newTagName)
                .accessibilityIdentifier("drawer.tag.create.name")
                .onChange(of: newTagName) { _, _ in createError = nil }
            if let createError {
                Text(verbatim: createError)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.status.danger)
            }
            HStack {
                Spacer()
                Button(L10n.string("alert.cancel", locale: locale)) {
                    newTagName = ""
                    createError = nil
                    isCreatingTag = false
                }
                .buttonStyle(DaybookButtonStyle(.quiet))
                Button(L10n.string("drawer.tag.create", locale: locale)) {
                    let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    if DiaryMemoTags.isPresetName(name) {
                        createError = L10n.string("tag.preset.reserved", locale: locale)
                        return
                    }
                    guard onCreateTag(name) else {
                        createError = L10n.string("save.failure.title", locale: locale)
                        return
                    }
                    newTagName = ""
                    createError = nil
                    isCreatingTag = false
                }
                .buttonStyle(DaybookButtonStyle(.prominent))
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 240)
    }
}
