import SwiftData
import SwiftUI

struct TaskDetailSubtasksView: View {
    @Environment(\.modelContext) private var modelContext
    let todo: TodoItem

    @State private var newSubtaskTitle: String = ""
    @FocusState private var isInputFocused: Bool

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
    }

    // MARK: - Header & Progress

    private var headerSection: some View {
        HStack {
            Label("drawer.subtasks.title", systemImage: "checklist")
                .font(DaybookType.label)
                .foregroundStyle(DaybookTheme.muted)
            Spacer()
            if totalCount > 0 {
                Text("\(completedCount)/\(totalCount)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(completedCount == totalCount ? DaybookTheme.stamp : DaybookTheme.muted)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(DaybookTheme.rule.opacity(0.3))
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(completedCount == totalCount ? DaybookTheme.stamp : DaybookTheme.stamp.opacity(0.8))
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
                    onToggle: {
                        DayBoardMutations.toggleSubtask(subtask)
                    },
                    onUpdateTitle: { newTitle in
                        DayBoardMutations.editSubtask(subtask, title: newTitle)
                    },
                    onDelete: {
                        DayBoardMutations.deleteSubtask(subtask)
                    }
                )
            }
        }
    }

    // MARK: - Add Input

    private var addSubtaskInput: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.stamp)

            TextField("drawer.subtasks.placeholder", text: $newSubtaskTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .focused($isInputFocused)
                .onSubmit {
                    submitNewSubtask()
                }

            if !newSubtaskTitle.isEmpty {
                Button {
                    submitNewSubtask()
                } label: {
                    Text("drawer.subtasks.add")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DaybookTheme.stamp)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(DaybookTheme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(DaybookTheme.rule.opacity(0.25), lineWidth: 0.8)
                )
        )
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
    let subtask: SubtaskItem
    let onToggle: () -> Void
    let onUpdateTitle: (String) -> Bool
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var isEditing = false
    @State private var draftTitle = ""
    @FocusState private var editFocused: Bool

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
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isHovering ? DaybookTheme.cardSurfaceHover : Color.clear)
        )
        .onHover { isHovering = $0 }
        .onAppear { draftTitle = subtask.title }
        .onChange(of: subtask.title) { _, val in
            // 回滚或外部刷新不能覆盖仍在编辑的失败草稿。
            if !isEditing { draftTitle = val }
        }
    }

    private var toggleCheckboxButton: some View {
        Button(action: onToggle) {
            Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundStyle(subtask.isDone ? DaybookTheme.stamp : DaybookTheme.muted)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var subtaskTitleView: some View {
        if isEditing {
            TextField("", text: $draftTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .focused($editFocused)
                .onSubmit {
                    commitEdit()
                }
                .onExitCommand(perform: cancelEdit)
                .onChange(of: editFocused) { _, focused in
                    if !focused, isEditing {
                        if BoardSelection.shared.consumeEscapeCancelsEdits() {
                            cancelEdit()
                        } else {
                            commitEdit()
                        }
                    }
                }
        } else {
            Text(subtask.title)
                .font(.system(size: 11))
                .foregroundStyle(subtask.isDone ? DaybookTheme.muted.opacity(0.7) : DaybookTheme.ink)
                .strikethrough(subtask.isDone, color: DaybookTheme.muted.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    startEdit()
                }
        }
    }

    @ViewBuilder
    private var hoverActionButtons: some View {
        if isHovering && !isEditing {
            Button(action: startEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 9))
                    .foregroundStyle(DaybookTheme.muted)
            }
            .buttonStyle(.plain)
            .help("drawer.subtasks.edit")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 9))
                    .foregroundStyle(DaybookTheme.muted)
            }
            .buttonStyle(.plain)
            .help("drawer.subtasks.delete")
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
        isEditing = false
        editFocused = false
    }

    private func cancelEdit() {
        _ = BoardSelection.shared.consumeEscapeCancelsEdits()
        draftTitle = subtask.title
        isEditing = false
        editFocused = false
    }
}
