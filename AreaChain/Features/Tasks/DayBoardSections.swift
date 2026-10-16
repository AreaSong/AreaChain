import SwiftUI

extension DayBoardList {
    @ViewBuilder
    func openItemsSection(_ identity: DayBoardListIdentity) -> some View {
        let flatMode = AppPreferences.shared.expandSubtasksByDefault
        let doneSubtasks = flatMode ? identity.doneFlatSubtasksFromOpenRows(dayKey: dayKey) : []
        let hasCompleted = !identity.doneRows.isEmpty || !doneSubtasks.isEmpty
        if identity.openRows.isEmpty && hasCompleted {
            allDoneBanner
        } else if !identity.openRows.isEmpty {
            ForEach(identity.openRows, id: \.listID) { row in
                dayRow(row, isDone: false, identity: identity)
                if flatMode {
                    switch row {
                    case .todo(let todo):
                        ForEach(identity.flatSubtasks(for: todo, isDone: false)) { subItem in
                            flatSubtaskRow(subItem, parent: todo)
                        }
                    case .resident(let routine):
                        ForEach(identity.flatSubtasks(for: routine, dayKey: dayKey, isDone: false)) { subItem in
                            flatSubtaskRow(subItem, routine: routine)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var allDoneBanner: some View {
        let hasOverdue = config.yesterdayUnfinishedCount > 0
        Button {
            if hasOverdue {
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    config.onToggleYesterday?()
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(DaybookType.body.weight(.semibold))
                    .foregroundStyle(DaybookPalette.accent.base)
                if hasOverdue {
                    Text("board.banner.all_done_with_overdue \(config.yesterdayUnfinishedCount)")
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(DaybookPalette.text.primary.opacity(0.85)) // token-exempt: 85% 墨色没有对应令牌
                    Spacer()
                    Image(systemName: config.isYesterdayExpanded ? "chevron.up" : "chevron.down")
                        .font(DaybookType.micro.weight(.semibold))
                        .foregroundStyle(DaybookPalette.accent.base)
                } else {
                    Text("board.banner.all_done")
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(DaybookPalette.text.primary.opacity(0.85)) // token-exempt: 85% 墨色没有对应令牌
                    Spacer()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 全清横幅折叠展开交互
        .disabled(!hasOverdue)
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.accent.base.opacity(0.05)) // token-exempt: 5% 印章底没有对应令牌
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .strokeBorder(DaybookPalette.accent.fill, lineWidth: 0.8)
        )
        .padding(.top, 2)
    }

    @ViewBuilder
    func completedSection(_ identity: DayBoardListIdentity) -> some View {
        let flatMode = AppPreferences.shared.expandSubtasksByDefault
        let doneSubtasks = flatMode ? identity.doneFlatSubtasksFromOpenRows(dayKey: dayKey) : []
        let completedCount = identity.doneRows.count + doneSubtasks.count

        Divider()
            .opacity(0.15)
            .padding(.top, 4)
            .padding(.bottom, 4)

        Button {
            withAnimation(DaybookMotion.animation(reduceMotion)) {
                showCompleted.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                    .font(DaybookType.micro.weight(.bold))
                    .foregroundStyle(DaybookPalette.text.secondary)
                DaybookSectionHeader(
                    title: showCompleted
                        ? "stamp.completed.collapse \(completedCount)"
                        : "stamp.completed \(completedCount)",
                    icon: "checkmark.circle"
                )
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 分节折叠头，整行点击
        .opacity(showCompleted ? 1.0 : 0.6)
        .accessibilityAddTraits(showCompleted ? [.isSelected] : [])

        if showCompleted {
            ForEach(doneSubtasks) { subItem in
                if let parent = identity.todo(subItem.parentID) {
                    flatSubtaskRow(subItem, parent: parent, showsParentBadge: true)
                } else if let routine = identity.routine(subItem.parentID) {
                    flatSubtaskRow(subItem, routine: routine, showsParentBadge: true)
                }
            }
            ForEach(identity.doneRows, id: \.listID) { row in
                dayRow(row, isDone: true, identity: identity)
                if flatMode {
                    switch row {
                    case .todo(let todo):
                        ForEach(identity.flatSubtasks(for: todo)) { subItem in
                            flatSubtaskRow(subItem, parent: todo, showsParentBadge: false)
                        }
                    case .resident(let routine):
                        ForEach(identity.flatSubtasks(for: routine, dayKey: dayKey)) { subItem in
                            flatSubtaskRow(subItem, routine: routine, showsParentBadge: false)
                        }
                    }
                }
            }
        }
    }

    func flatSubtaskRow(_ subItem: FlatSubtaskItem, parent: TodoItem, showsParentBadge: Bool = false) -> some View {
        FlatSubtaskRow(
            item: subItem,
            isSelected: false,
            showsParentBadge: showsParentBadge,
            reduceMotion: reduceMotion,
            onToggle: {
                guard let sub = parent.subtasks.first(where: { $0.id == subItem.id && $0.deletedAt == nil }) else { return }
                _ = DayBoardMutations.toggleSubtask(sub)
            },
            onSelect: {
                focusedListID = BoardItemReference.todo(parent.id).id
                selectTask(parent.id)
            },
            onDelete: {
                guard let sub = parent.subtasks.first(where: { $0.id == subItem.id && $0.deletedAt == nil }) else { return }
                pendingTrash = PendingTrash(title: sub.title) {
                    _ = DayBoardMutations.deleteSubtask(sub)
                }
            }
        )
    }

    func flatSubtaskRow(_ subItem: FlatSubtaskItem, routine: DailyRoutine, showsParentBadge: Bool = false) -> some View {
        FlatSubtaskRow(
            item: subItem,
            isSelected: false,
            showsParentBadge: showsParentBadge,
            reduceMotion: reduceMotion,
            onToggle: {
                _ = DayBoardMutations.toggleRoutineSubtask(routine, subtaskID: subItem.id, on: dayKey)
            },
            onSelect: {
                focusedListID = BoardItemReference.recurring(routine.id).id
                selectTask(routine.id)
            },
            onDelete: {
                pendingTrash = PendingTrash(title: subItem.subtask.title) {
                    _ = DayBoardMutations.deleteRoutineSubtask(routine: routine, subtaskID: subItem.id)
                }
            }
        )
    }
}

struct DayBoardKeyNavigationModifier: ViewModifier {
    var interaction: DayBoardInteraction
    var onNavigate: (Int) -> Void
    var onToggle: (UUID) -> Void
    var onDelete: (UUID) -> Void
    var onInspect: (UUID) -> Void

    func body(content: Content) -> some View {
        content
            .onKeyPress(.downArrow) { handle(.downArrow) }
            .onKeyPress(.upArrow) { handle(.upArrow) }
            .onKeyPress(.space) { handle(.space) }
            .onKeyPress(.delete) { handle(.delete) }
            .onKeyPress(.return) { handle(.return) }
    }

    func handle(_ key: KeyEquivalent) -> KeyPress.Result {
        guard interaction.isKeyboardEnabled(), let focus = interaction.focusedTaskID else { return .ignored }
        switch key {
        case .downArrow: onNavigate(1)
        case .upArrow: onNavigate(-1)
        case .space:
            guard let id = focus.wrappedValue else { return .ignored }
            onToggle(id)
        case .delete:
            guard let id = focus.wrappedValue else { return .ignored }
            onDelete(id)
        case .return:
            guard let id = focus.wrappedValue else { return .ignored }
            onInspect(id)
        default: return .ignored
        }
        return .handled
    }
}
