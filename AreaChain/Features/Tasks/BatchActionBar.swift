import SwiftData
import SwiftUI

struct BatchActionBar: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let selectedCount: Int
    let onMoveToday: () -> Void
    let onMoveTomorrow: () -> Void
    let onToggleDone: (Bool) -> Void
    let onSetProject: (UUID?) -> Void
    let onToggleTag: (UUID) -> Void
    let onTrash: () -> Void
    let onClear: () -> Void

    var projects: [ProjectItem] = []
    var tags: [TagItem] = []

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.badge.questionmark.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(DaybookTheme.stamp)
                Text("已选 \(selectedCount) 项")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DaybookTheme.ink)
            }
            .padding(.trailing, 4)

            Divider()
                .frame(height: 14)
                .opacity(0.3)

            // 日期调整
            Menu {
                Button("今天", action: onMoveToday)
                Button("明天", action: onMoveTomorrow)
            } label: {
                Label("移动日期", systemImage: "calendar")
                    .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // 状态调整
            Menu {
                Button("标记为已完成") { onToggleDone(true) }
                Button("标记为未完成") { onToggleDone(false) }
            } label: {
                Label("状态", systemImage: "checkmark.circle")
                    .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // 项目设置
            if !projects.isEmpty {
                Menu {
                    Button("移除项目") { onSetProject(nil) }
                    Divider()
                    ForEach(projects.filter { $0.deletedAt == nil }) { proj in
                        Button(proj.name) { onSetProject(proj.id) }
                    }
                } label: {
                    Label("设置项目", systemImage: "folder")
                        .font(.system(size: 11))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            // 标签设置
            if !tags.isEmpty {
                Menu {
                    ForEach(tags.filter { $0.deletedAt == nil }) { tag in
                        Button("#\(tag.name)") { onToggleTag(tag.id) }
                    }
                } label: {
                    Label("打标签", systemImage: "tag")
                        .font(.system(size: 11))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            // 删除
            Button(role: .destructive, action: onTrash) {
                Label("移入回收站", systemImage: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.destructive)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DaybookTheme.muted)
            }
            .buttonStyle(.plain)
            .help("取消选择")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(DaybookTheme.stamp.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
        )
    }
}
