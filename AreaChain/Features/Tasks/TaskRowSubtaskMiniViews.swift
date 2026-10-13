import SwiftUI

struct TaskRowSubtaskChip: View {
    let subtasks: [SubtaskSnapshot]
    @Binding var isExpanded: Bool
    var isFlatMode: Bool = false
    var reduceMotion: Bool = false

    var body: some View {
        let completed = subtasks.filter(\.isDone).count
        let total = subtasks.count
        let allDone = completed == total && total > 0
        return DaybookChip(
            tint: DaybookPalette.accent.base,
            isSelected: allDone,
            action: isFlatMode ? nil : {
                withAnimation(DaybookMotion.animation(reduceMotion)) {
                    isExpanded.toggle()
                }
            }
        ) {
            HStack(spacing: 3) {
                Image(systemName: allDone ? "checkmark.circle.fill" : "checklist")
                Text("\(completed)/\(total)")
                if !isFlatMode {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                }
            }
        }
        .help(isFlatMode ? "row.subtasks.flat" : (isExpanded ? "row.subtasks.collapse" : "row.subtasks.expand"))
    }
}

struct FlatSubtaskItem: Identifiable, Equatable {
    var id: UUID { subtask.id }
    let subtask: SubtaskSnapshot
    let parentID: UUID
    let parentTitle: String
    let tagNames: [String]

    static func build(
        for todo: TodoItem,
        tags: [TagItem],
        allowedIDs: Set<UUID>? = nil,
        isDone: Bool? = nil
    ) -> [FlatSubtaskItem] {
        let liveTags = tags.filter { $0.deletedAt == nil }
        let liveSubtasks = todo.subtasks
            .filter { sub in
                sub.deletedAt == nil
                    && (allowedIDs == nil || allowedIDs?.contains(sub.id) == true)
                    && (isDone == nil || sub.isDone == isDone)
            }
            .sorted { $0.sortOrder < $1.sortOrder }

        return liveSubtasks.map { sub in
            let selectedTagIDs = Set(TagIDList.parse(sub.tagIDs))
            let tagNames = liveTags.filter { selectedTagIDs.contains($0.id) }.map(\.name)
            return FlatSubtaskItem(
                subtask: SubtaskSnapshot(
                    id: sub.id,
                    todoId: todo.id,
                    title: sub.title,
                    isDone: sub.isDone,
                    sortOrder: sub.sortOrder,
                    createdAt: sub.createdAt,
                    deletedAt: sub.deletedAt,
                    tagIDs: sub.tagIDs
                ),
                parentID: todo.id,
                parentTitle: todo.title,
                tagNames: tagNames
            )
        }
    }
}

struct FlatSubtaskRow: View {
    let item: FlatSubtaskItem
    var isSelected: Bool = false
    var reduceMotion: Bool = false
    var onToggle: () -> Void
    var onSelect: () -> Void = {}
    var onDelete: (() -> Void)? = nil

    @State private var isHovered = false

    private var parentBadgeTitle: String {
        let trimmed = item.parentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 12 else { return trimmed }
        return String(trimmed.prefix(12)) + "…"
    }

    var body: some View {
        let visuallyDone = PendingCompletionManager.shared.isVisuallyDone(
            id: item.subtask.id,
            actualDone: item.subtask.isDone
        )
        HStack(alignment: .center, spacing: DaybookSpacing.xs) {
            ModernCheckbox(isDone: visuallyDone) {
                PendingCompletionManager.shared.toggle(
                    id: item.subtask.id,
                    currentlyDone: item.subtask.isDone,
                    reduceMotion: reduceMotion
                ) {
                    onToggle()
                }
            }
            .accessibilityIdentifier("task.subtask.complete.\(item.subtask.id)")

            ModernTaskTitle(
                text: item.subtask.title,
                isDone: visuallyDone,
                font: DaybookType.body
            )
            .lineLimit(1)
            .truncationMode(AppPreferences.shared.contentTruncation.textTruncation)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }

            HStack(spacing: 4) {
                ForEach(Array(item.tagNames.prefix(2)), id: \.self) { tagName in
                    Text("#\(tagName)")
                        .font(DaybookType.micro.weight(.semibold))
                        .foregroundStyle(DaybookPalette.Syntax.tag)
                        .lineLimit(1)
                        .padding(.horizontal, 4.5)
                        .frame(height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                                .fill(DaybookPalette.Syntax.tagFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                                .stroke(DaybookPalette.Syntax.tagStroke, lineWidth: 0.6)
                        )
                }

                DaybookChip(
                    tint: DaybookPalette.accent.base,
                    isSelected: isHovered || isSelected,
                    action: onSelect
                ) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.turn.down.right")
                        Text(parentBadgeTitle)
                            .lineLimit(1)
                    }
                }
                .help(item.parentTitle)
                .accessibilityIdentifier("task.subtask.parentBadge.\(item.subtask.id)")
            }
            .fixedSize(horizontal: true, vertical: false)
            .opacity(isHovered || isSelected ? 1.0 : 0.75) // token-exempt: 行右侧徽标悬停前降透明
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: DaybookMetrics.rowHeight)
        .daybookSurface(.row, isHovered: isHovered, isSelected: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(item.subtask.isDone ? "menu.markOpen" : "menu.markDone") {
                onToggle()
            }
            if let onDelete {
                Divider()
                Button("common.moveToTrash", role: .destructive) {
                    onDelete()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task.subtask.flatRow.\(item.subtask.id)")
    }
}

struct TaskRowSubtaskInlineList: View {
    let subtasks: [SubtaskSnapshot]
    var onToggle: ((UUID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(subtasks) { subtask in
                HStack(spacing: 5) {
                    ModernCheckbox(isDone: subtask.isDone, presentation: .inlineSubtask) {
                        onToggle?(subtask.id)
                    }
                    .accessibilityIdentifier("task.subtask.complete.\(subtask.id)")

                    ModernTaskTitle(
                        text: subtask.title,
                        isDone: subtask.isDone,
                        font: .system(size: 11)
                    )
                    .lineLimit(1)
                    .truncationMode(AppPreferences.shared.contentTruncation.textTruncation)
                }
                .padding(.vertical, 0.5)
            }
        }
        .padding(.leading, 2)
        .padding(.top, 2)
    }
}

struct TaskRowSubtaskProgressBar: View {
    let subtasks: [SubtaskSnapshot]
    var isParentDone: Bool = false
    var reduceMotion: Bool = false

    var completedCount: Int {
        subtasks.filter(\.isDone).count
    }

    var totalCount: Int {
        subtasks.count
    }

    var body: some View {
        if totalCount > 0 {
            HStack(spacing: DaybookSpacing.xxs) {
                ForEach(0..<totalCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                        .fill(segmentColor(isCompleted: index < completedCount))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: DaybookRadius.xxs)
            .padding(.horizontal, DaybookSpacing.xs)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
            .animation(DaybookMotion.interactive(reduceMotion), value: completedCount)
            .allowsHitTesting(false)
        }
    }

    private func segmentColor(isCompleted: Bool) -> Color {
        if isCompleted {
            return isParentDone ? DaybookPalette.accent.border : DaybookPalette.accent.base
        }
        return DaybookPalette.border.default
    }
}

struct TodoDragIfNeeded: ViewModifier {
    var payload: String?

    func body(content: Content) -> some View {
        if let payload {
            content.draggable(payload)
        } else {
            content
        }
    }
}
