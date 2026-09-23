import SwiftData
import SwiftUI

// MARK: - Project Picker

/// 抽屉归属项目选择组件
struct TaskDetailProjectPicker: View {
    var selectedID: UUID?
    var projects: [ProjectItem]
    var onSelect: (UUID?) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("drawer.project.title")
                .font(DaybookType.label)
                .foregroundStyle(DaybookPalette.text.secondary)

            Menu {
                Button("classify.project.none") {
                    onSelect(nil)
                }
                ForEach(projects.filter { $0.deletedAt == nil }) { proj in
                    Button(proj.name) {
                        onSelect(proj.id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.accent.base)
                    let name = projects.first(where: { $0.id == selectedID && $0.deletedAt == nil })?.name
                        ?? L10n.string("classify.project.none", locale: locale)
                    Text(name)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(DaybookType.micro)
                        .foregroundStyle(DaybookPalette.text.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .daybookSurface(.card, configure: { $0.radius = DaybookRadius.small })
            }
            .menuStyle(.borderlessButton)
        }
    }
}

// MARK: - Tag Selector

/// 抽屉标签多选与新建组件
struct TaskDetailTagSelector: View {
    var tagIDs: String
    var tags: [TagItem]
    var onToggleTag: (UUID) -> Void
    var onCreateTag: (String) -> Bool

    @State private var isCreatingTag = false
    @State private var newTagName = ""
    @State private var createError: LocalizedStringKey?

    private var activeTags: [TagItem] {
        Catalog.taskPickerTags(tags, attachedIDs: tagIDs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("drawer.tags.title")
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
                Text("drawer.tag.empty")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.secondary.opacity(0.7)) // token-exempt: 70% 次要色没有对应令牌
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 4)], spacing: 4) {
                    ForEach(activeTags) { tag in
                        let isContained = TagIDList.contains(tagIDs, tag.id)
                        DaybookChip(
                            tint: Color(nsColor: .systemIndigo), // token-exempt: 没有靛蓝令牌
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
        }
    }

    private var newTagSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("drawer.tag.create.title")
                .font(DaybookType.body.weight(.semibold))
                .foregroundStyle(DaybookPalette.text.primary)
            TextField("drawer.tag.create.name", text: $newTagName)
                .textFieldStyle(.roundedBorder)
                .onChange(of: newTagName) { _, _ in createError = nil }
            if let createError {
                Text(createError)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.status.danger)
            }
            HStack {
                Spacer()
                Button("alert.cancel") {
                    newTagName = ""
                    createError = nil
                    isCreatingTag = false
                }
                Button("drawer.tag.create") {
                    let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    if DiaryMemoTags.isPresetName(name) {
                        createError = "tag.preset.reserved"
                        return
                    }
                    guard onCreateTag(name) else {
                        createError = "save.failure.title"
                        return
                    }
                    newTagName = ""
                    createError = nil
                    isCreatingTag = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 240)
    }
}
