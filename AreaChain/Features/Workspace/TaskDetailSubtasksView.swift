import SwiftData
import SwiftUI

struct TaskDetailSubtasksView: View {
    @WorkspaceDraftContext private var drafts
    @Environment(\.workspaceSearchRouter) private var router
    @Environment(\.workspaceHostContext) private var hostContext
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    let todo: TodoItem

    @State private var newSubtaskTitle: String = ""
    @State private var isInputFocused = false

    private var activeSubtasks: [SubtaskItem] {
        todo.subtasks
            .filter { $0.deletedAt == nil }
            .sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    private var completedCount: Int {
        activeSubtasks.filter(\.isDone).count
    }

    private var totalCount: Int {
        activeSubtasks.count
    }

    private var progressRatio: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerSection

            if totalCount > 0 {
                progressBar
                subtaskList
            }

            addSubtaskInput
        }
        .onAppear { if hostContext != nil { newSubtaskTitle = drafts.titles["subtask-new-\(todo.id)"] ?? "" } }
        .onChange(of: newSubtaskTitle) { _, value in if hostContext != nil { drafts.titles["subtask-new-\(todo.id)"] = value } }
    }

    // MARK: - Header & Progress

    private var headerSection: some View {
        HStack {
            Label("drawer.subtasks.title", systemImage: "checklist")
                .font(DaybookType.label)
                .foregroundStyle(DaybookPalette.text.secondary)
            Spacer()
            if totalCount > 0 {
                Text("\(completedCount)/\(totalCount)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced)) // token-exempt: 子任务计数用等宽
                    .foregroundStyle(completedCount == totalCount ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                    .fill(DaybookPalette.border.default.opacity(0.3)) // token-exempt: 30% 分隔线没有对应令牌
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                    .fill(completedCount == totalCount ? DaybookPalette.accent.base : DaybookPalette.accent.base.opacity(0.8)) // token-exempt: 80% 印章色没有对应令牌
                    .frame(width: geo.size.width * CGFloat(progressRatio), height: 3)
            }
        }
        .frame(height: 3)
        .padding(.vertical, 2)
    }

    // MARK: - List

    private var subtaskList: some View {
        VStack(spacing: 4) {
            ForEach(activeSubtasks) { subtask in
                SubtaskRowView(
                    subtask: subtask,
                    siblingIDs: activeSubtasks.map(\.id),
                    onToggle: {
                        DayBoardMutations.toggleSubtask(subtask)
                    },
                    onUpdateTitle: { newTitle in
                        DayBoardMutations.editSubtask(subtask, title: newTitle)
                    },
                    onDelete: {
                        DayBoardMutations.deleteSubtask(subtask)
                    },
                    onReorder: { ordered in
                        DayBoardMutations.reorderSubtasks(for: todo, orderedIDs: ordered)
                    }
                )
                .id(subtask.id)
                .background(WorkspaceNavigationProbe(router: router, key: "object." + subtask.id.uuidString))
            }
        }
    }

    // MARK: - Add Input

    private var addSubtaskInput: some View {
        DaybookInputShell(kind: .composer, focused: isInputFocused) {
            Image(systemName: "plus.circle")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.accent.base)
        } field: {
            SyntaxTextField(
                text: $newSubtaskTitle, placeholder: L10n.string("drawer.subtasks.placeholder", locale: locale),
                focused: $isInputFocused, context: .taskTags, fontSize: 11, onSubmit: submitNewSubtask
            )
        } trailing: {
            if !newSubtaskTitle.isEmpty {
                Button {
                    submitNewSubtask()
                } label: {
                    Text("drawer.subtasks.add")
                        .font(DaybookType.badge.weight(.medium))
                }
                .buttonStyle(DaybookButtonStyle(.prominent, size: .inline))
            }
        }
    }

    private func submitNewSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if DayBoardMutations.addSubtask(to: todo, title: trimmed, context: modelContext) {
            newSubtaskTitle = ""
            isInputFocused = true
        }
    }
}

struct SubtaskRowView: View {
    @WorkspaceDraftContext private var drafts
    @WorkspaceBoardContext private var boardSelection
    @Environment(\.workspaceHostContext) private var hostContext
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    let subtask: SubtaskItem
    var siblingIDs: [UUID] = []
    let onToggle: () -> Void
    let onUpdateTitle: (String) -> Bool
    let onDelete: () -> Void
    var onReorder: ([UUID]) -> Bool = { _ in false }

    @State private var isHovering = false
    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var editFocused = false

    var body: some View {
        HStack(spacing: 6) {
            toggleCheckboxButton
            subtaskTitleView
            Spacer(minLength: 4)
            hoverActionButtons
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                .fill(isHovering ? DaybookPalette.cardSurfaceHover : Color.clear)
        )
        .onHover { isHovering = $0 }
        .dropDestination(for: String.self) { items, _ in
            guard !isEditing, let raw = items.first,
                  let moving = SubtaskReorderToken.decode(raw),
                  let next = ManualOrder.reordered(siblingIDs, moving: moving, before: subtask.id) else {
                return false
            }
            return onReorder(next)
        }
        .zIndex(isEditing ? 20 : 0)
        .onAppear {
            draftTitle = hostContext == nil ? subtask.title : drafts.titles["subtask-\(subtask.id)"] ?? subtask.title
            isEditing = hostContext != nil && drafts.titles["subtask-\(subtask.id)"] != nil
        }
        .onChange(of: draftTitle) { _, value in
            if isEditing, hostContext != nil { drafts.titles["subtask-\(subtask.id)"] = value }
        }
        .onDisappear { if isEditing, hostContext != nil { drafts.titles["subtask-\(subtask.id)"] = draftTitle } }
        .onChange(of: subtask.title) { _, val in
            // 回滚或外部刷新不能覆盖仍在编辑的失败草稿。
            if !isEditing { draftTitle = val }
        }
    }

    private var toggleCheckboxButton: some View {
        ModernCheckbox(isDone: subtask.isDone, presentation: .detailSubtask, action: onToggle)
            .accessibilityIdentifier("detail.subtask.complete.\(subtask.id)")
    }

    @ViewBuilder
    private var subtaskTitleView: some View {
        if isEditing {
            SyntaxTextField(
                text: $draftTitle, placeholder: L10n.string("drawer.subtasks.placeholder", locale: locale),
                focused: $editFocused, context: .taskTags, fontSize: 11, onSubmit: commitEdit, onEscape: cancelEdit
            )
                .onChange(of: editFocused) { _, focused in
                    if !focused, isEditing, hostContext == nil {
                        if boardSelection.consumeEscapeCancelsEdits() {
                            cancelEdit()
                        } else {
                            commitEdit()
                        }
                    }
                }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text(subtask.title)
                    .font(DaybookType.caption)
                    .foregroundStyle(subtask.isDone ? DaybookPalette.text.done : DaybookPalette.text.primary)
                    .strikethrough(subtask.isDone, color: DaybookPalette.text.done)
                assignedTagChips
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .overlay {
                if !isEditing {
                    BoardRowPointerRegion(
                        id: subtask.id,
                        plainDoubleClick: true,
                        dragPayload: SubtaskReorderToken.encode(subtask.id),
                        onSelect: { _, _ in },
                        onDoubleClick: startEdit
                    )
                }
            }
            .accessibilityAction(named: Text("drawer.subtasks.edit"), startEdit)
        }
    }

    @ViewBuilder
    private var assignedTagChips: some View {
        let assigned = tags.filter { $0.deletedAt == nil && TagIDList.contains(subtask.tagIDs, $0.id) }
        if !assigned.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(assigned) { tag in
                        DaybookChip(tint: DaybookPalette.accent.base, isSelected: true, action: {
                            DayBoardMutations.toggleSubtaskTag(subtask, tagID: tag.id)
                        }) {
                            Label("#" + tag.name, systemImage: "xmark")
                        }
                        .help("syntax.tag.remove")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var hoverActionButtons: some View {
        if isHovering && !isEditing {
            DaybookIconButton(systemName: "pencil", label: "drawer.subtasks.edit", size: .inline, action: startEdit)

            DaybookIconButton(systemName: "trash", label: "drawer.subtasks.delete", size: .inline, action: onDelete)
        }
    }

    private func startEdit() {
        draftTitle = subtask.title
        isEditing = true
        editFocused = true
    }

    private func commitEdit() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            guard onUpdateTitle(trimmed) else { return }
        } else {
            draftTitle = subtask.title
        }
        drafts.titles.removeValue(forKey: "subtask-\(subtask.id)")
        isEditing = false
        editFocused = false
    }

    private func cancelEdit() {
        _ = boardSelection.consumeEscapeCancelsEdits()
        draftTitle = subtask.title
        drafts.titles.removeValue(forKey: "subtask-\(subtask.id)")
        isEditing = false
        editFocused = false
    }
}

private enum SubtaskReorderToken {
    private static let prefix = "subtask-order:"

    static func encode(_ id: UUID) -> String {
        prefix + id.uuidString
    }

    static func decode(_ raw: String) -> UUID? {
        guard raw.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(raw.dropFirst(prefix.count)))
    }
}
