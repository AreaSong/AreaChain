import SwiftData
import SwiftUI

// MARK: - Project Picker

/// 抽屉归属项目选择组件
struct TaskDetailProjectPicker: View {
    var selectedID: UUID?
    var projects: [ProjectItem]
    var onSelect: (UUID?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("drawer.project.title")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DaybookTheme.muted)

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
                        .font(.system(size: 11))
                        .foregroundStyle(DaybookTheme.stamp)
                    let name = projects.first(where: { $0.id == selectedID })?.name ?? "无项目"
                    Text(name)
                        .font(.system(size: 11.5))
                        .foregroundStyle(DaybookTheme.ink)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(DaybookTheme.muted)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .modernCard(cornerRadius: DaybookRadius.small)
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
    var onCreateTag: (String) -> Void

    @State private var isCreatingTag = false
    @State private var newTagName = ""

    private var activeTags: [TagItem] {
        tags.filter { $0.deletedAt == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("drawer.tags.title")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted)
                Spacer()
                Button {
                    isCreatingTag = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(DaybookTheme.stamp)
                }
                .buttonStyle(.plain)
                .help("添加新标签")
            }

            if activeTags.isEmpty {
                Text("暂无标签，点击右上角「+」创建")
                    .font(.system(size: 10))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.7))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 4)], spacing: 4) {
                    ForEach(activeTags) { tag in
                        let isContained = TagIDList.contains(tagIDs, tag.id)
                        PillBadge(
                            title: "#\(tag.name)",
                            color: Color.daybook(light: NSColor.systemIndigo, dark: NSColor.systemIndigo),
                            isSelected: isContained,
                            action: { onToggleTag(tag.id) }
                        )
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
            Text("创建新标签")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DaybookTheme.ink)
            TextField("标签名称", text: $newTagName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") {
                    newTagName = ""
                    isCreatingTag = false
                }
                Button("创建") {
                    let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        onCreateTag(name)
                        newTagName = ""
                        isCreatingTag = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 240)
    }
}
