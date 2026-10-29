import SwiftData
import SwiftUI

struct RoutineDetailSubtasksView: View {
    @WorkspaceDraftContext private var drafts
    @Environment(\.workspaceHostContext) private var hostContext
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    let routine: DailyRoutine
    let boardDayKey: String

    @State private var newSubtaskTitle: String = ""
    @State private var isInputFocused = false

    private var templates: [RoutineSubtaskTemplate] {
        routine.subtaskTemplates.sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    private var todayCompletedIDs: Set<UUID> {
        let check = routine.checks.first(where: { $0.dayKey == boardDayKey })
        return check?.completedSubtaskIDSet ?? []
    }

    private var completedCount: Int {
        templates.filter { todayCompletedIDs.contains($0.id) }.count
    }

    private var totalCount: Int {
        templates.count
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
        .onAppear { if hostContext != nil { newSubtaskTitle = drafts.titles["routine-subtask-new-\(routine.id)"] ?? "" } }
        .onChange(of: newSubtaskTitle) { _, value in if hostContext != nil { drafts.titles["routine-subtask-new-\(routine.id)"] = value } }
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
            ForEach(templates) { template in
                RoutineSubtaskRowView(
                    template: template,
                    isDone: todayCompletedIDs.contains(template.id),
                    siblingIDs: templates.map(\.id),
                    onToggle: {
                        DayBoardMutations.toggleRoutineSubtask(routine, subtaskID: template.id, on: boardDayKey)
                    },
                    onUpdateTitle: { newTitle in
                        DayBoardMutations.editRoutineSubtask(routine: routine, subtaskID: template.id, title: newTitle)
                    },
                    onDelete: {
                        DayBoardMutations.deleteRoutineSubtask(routine: routine, subtaskID: template.id)
                    },
                    onReorder: { ordered in
                        DayBoardMutations.reorderRoutineSubtasks(routine: routine, orderedIDs: ordered)
                    }
                )
                .id(template.id)
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
        if DayBoardMutations.addRoutineSubtask(to: routine, title: trimmed, context: modelContext) {
            newSubtaskTitle = ""
            isInputFocused = true
        }
    }
}

struct RoutineSubtaskRowView: View {
    @WorkspaceDraftContext private var drafts
    @WorkspaceBoardContext private var boardSelection
    @Environment(\.workspaceHostContext) private var hostContext
    @Environment(\.locale) private var locale
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    let template: RoutineSubtaskTemplate
    let isDone: Bool
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
                  let moving = RoutineSubtaskReorderToken.decode(raw),
                  let next = ManualOrder.reordered(siblingIDs, moving: moving, before: template.id) else {
                return false
            }
            return onReorder(next)
        }
        .zIndex(isEditing ? 20 : 0)
        .onAppear {
            draftTitle = hostContext == nil ? template.title : drafts.titles["routine-subtask-\(template.id)"] ?? template.title
            isEditing = hostContext != nil && drafts.titles["routine-subtask-\(template.id)"] != nil
        }
        .onChange(of: draftTitle) { _, value in
            if isEditing, hostContext != nil { drafts.titles["routine-subtask-\(template.id)"] = value }
        }
        .onDisappear { if isEditing, hostContext != nil { drafts.titles["routine-subtask-\(template.id)"] = draftTitle } }
        .onChange(of: template.title) { _, val in
            if !isEditing { draftTitle = val }
        }
    }

    private var toggleCheckboxButton: some View {
        ModernCheckbox(isDone: isDone, presentation: .detailSubtask, action: onToggle)
            .accessibilityIdentifier("detail.routineSubtask.complete.\(template.id)")
    }

    @ViewBuilder
    private var subtaskTitleView: some View {
        if isEditing {
            SyntaxTextField(
                text: $draftTitle, placeholder: L10n.string("drawer.subtasks.placeholder", locale: locale),
                focused: $editFocused, context: .taskTags, fontSize: 11, onSubmit: commitEdit, onEscape: cancelEdit
            )
            .onChange(of: editFocused) { _, focused in
                // 只有隔离宿主为保证导航零写入不在失焦时保存；正式版与旧界面一致，失焦即保存。
                if !focused, isEditing, hostContext?.isIsolated != true {
                    if boardSelection.consumeEscapeCancelsEdits() {
                        cancelEdit()
                    } else {
                        commitEdit()
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text(template.title)
                    .font(DaybookType.body)
                    .foregroundStyle(isDone ? DaybookPalette.text.tertiary : DaybookPalette.text.primary)
                    .strikethrough(isDone, color: DaybookPalette.text.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { startEdit() }
            }
        }
    }

    @ViewBuilder
    private var hoverActionButtons: some View {
        if isHovering && !isEditing {
            HStack(spacing: 2) {
                DaybookIconButton(systemName: "pencil", label: "drawer.subtasks.edit", size: .inline, action: startEdit)
                DaybookIconButton(systemName: "trash", label: "drawer.subtasks.delete", size: .inline, action: onDelete)
            }
        }
    }

    private func startEdit() {
        draftTitle = template.title
        isEditing = true
        editFocused = true
    }

    private func cancelEdit() {
        draftTitle = template.title
        isEditing = false
        editFocused = false
        if hostContext != nil { drafts.titles["routine-subtask-\(template.id)"] = nil }
    }

    private func commitEdit() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            cancelEdit()
            return
        }
        if onUpdateTitle(trimmed) {
            isEditing = false
            editFocused = false
            if hostContext != nil { drafts.titles["routine-subtask-\(template.id)"] = nil }
        }
    }
}

private enum RoutineSubtaskReorderToken {
    private static let prefix = "routine-subtask-order:"

    static func encode(_ id: UUID) -> String {
        prefix + id.uuidString
    }

    static func decode(_ raw: String) -> UUID? {
        guard raw.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(raw.dropFirst(prefix.count)))
    }
}
