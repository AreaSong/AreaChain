import SwiftUI

extension TasksPage {
    var upcomingSection: some View {
        Group {
            if showUpcoming, !upcomingModels.isEmpty {
                DaybookSectionHeader(title: "stamp.upcoming")
                ForEach(upcomingModels, id: \.id) { todo in
                    leftoverTodoRow(todo, note: DayKey.shortStamp(todo.dayKey, locale: locale))
                }
            }
        }
    }

    var yesterdaySection: some View {
        Group {
            if showYesterday, !yesterdayItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    yesterdaySectionHeader
                        .padding(.horizontal, 4)
                        .padding(.top, 2)

                    VStack(spacing: 2) {
                        ForEach(yesterdayItems) { item in
                            leftoverRow(item)
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                        .fill(DaybookPalette.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                        .strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.8)
                )
                .padding(.horizontal, 1)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    var centeredYesterdaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            yesterdaySectionHeader
                .padding(.horizontal, 4)

            VStack(spacing: 2) {
                ForEach(yesterdayItems) { item in
                    leftoverRow(item)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .fill(DaybookPalette.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.8)
        )
        .padding(.horizontal, 4)
        .containerRelativeFrame(.vertical, alignment: .center) { length, _ in
            max(length - 16, 120)
        }
    }

    private var yesterdaySectionHeader: some View {
        HStack(alignment: .center) {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(DaybookType.micro.weight(.semibold))
                    .foregroundStyle(DaybookPalette.accent.base)
                Text("stamp.yesterday")
                    .font(DaybookType.caption.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)
                Text("\(yesterdayItems.count)")
                    .font(DaybookType.badge.weight(.bold).monospacedDigit())
                    .foregroundStyle(DaybookPalette.accent.base)
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 0.5)
                    .background(DaybookPalette.accent.base.opacity(0.14)) // token-exempt: 14% 印章底没有对应令牌
                    .clipShape(Capsule()) // token-exempt: 计数胶囊裁切
            }
            Spacer()
            if yesterdayItems.contains(where: { $0.kind == .todo }) {
                DaybookChip(tint: DaybookPalette.accent.base, isSelected: true, action: {
                    withAnimation(DaybookMotion.interactive) {
                        moveAllYesterdayTodosToToday()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.right.to.line")
                        Text("stamp.yesterday.moveAll")
                    }
                }
                .help("stamp.yesterday.moveAll.help")
                .accessibilityLabel("stamp.yesterday.moveAll")
            }
        }
    }

    private var catalogContext: TaskCatalogContext {
        TaskCatalogContext(
            projects: projects,
            tags: tags,
            attachments: attachments,
            context: modelContext
        )
    }

    func leftoverTodoRow(_ todo: TodoItem, note: String? = nil) -> some View {
        let display = TodoRowDisplayOptions(
            isDone: false,
            isSelected: isLeftoverSelected(todo.id),
            note: note,
            includeSubtasks: false
        )
        let actions = TodoRowActions(
            onSelect: { selectLeftover(todo.id, dayKey: todo.dayKey, modifiers: $0) },
            onDelete: { deleteTodo(todo) }
        )
        return TaskRowFactory.todo(TodoRowContext(
            todo: todo,
            todayKey: todayKey,
            catalogs: catalogContext,
            display: display,
            actions: actions
        ))
    }

    @ViewBuilder
    func leftoverRow(_ item: UnfinishedItem) -> some View {
        if item.kind == .todo, let todo = todos.first(where: { $0.id == item.id }) {
            leftoverTodoRow(todo)
        } else if item.kind == .routine, let routine = routines.first(where: { $0.id == item.id }) {
            leftoverRoutineRow(routine, item: item)
        } else {
            let actions = LeftoverRowActions(
                onToggle: { completeYesterday(item) },
                onSelect: { selectLeftover(item.id, dayKey: yesterdayKey, modifiers: $0) },
                onMoveToDay: item.kind == .todo ? { moveYesterdayTodo(item, to: $0) } : nil
            )
            TaskRowFactory.leftoverFallback(LeftoverRowContext(
                item: item,
                todayKey: todayKey,
                yesterdayKey: yesterdayKey,
                isSelected: isLeftoverSelected(item.id),
                actions: actions
            ))
        }
    }

    private func leftoverRoutineRow(_ routine: DailyRoutine, item: UnfinishedItem) -> some View {
        let schedule = RoutineScheduleContext(
            todayKey: todayKey,
            checkDayKey: yesterdayKey,
            checks: checks,
            locale: locale
        )
        let display = RoutineRowDisplayOptions(
            isDone: false,
            isSelected: isLeftoverSelected(routine.id),
            usesDefaultNote: false
        )
        let actions = RoutineRowActions(
            onSelect: { selectLeftover(routine.id, dayKey: yesterdayKey, modifiers: $0) },
            onDelete: {
                pendingTrash = PendingTrash(title: routine.title) {
                    DayBoardMutations.trashRoutine(routine)
                }
            },
            onToggle: { completeYesterday(item) },
            onSkip: {
                DayBoardMutations.skipRoutine(routine, on: yesterdayKey, checks: checks, context: modelContext)
            }
        )
        return TaskRowFactory.routine(RoutineRowContext(
            routine: routine,
            schedule: schedule,
            catalogs: catalogContext,
            display: display,
            actions: actions
        ))
    }

    func isLeftoverSelected(_ id: UUID) -> Bool {
        if taskSelection.anchorID != nil || !taskSelection.ids.isEmpty {
            return taskSelection.ids.contains(id)
        }
        return focusedTaskID?.wrappedValue == id || highlightedTaskID == id
    }

    func selectLeftover(_ id: UUID, dayKey: String, modifiers: TaskSelectionModifiers = []) {
        var selection = taskSelection
        if selection.anchorID == nil && selection.ids.isEmpty {
            selection.focus(focusedTaskID?.wrappedValue ?? highlightedTaskID)
        }
        selection.select(id, in: allVisibleIDs, modifiers: modifiers)
        taskSelection = selection
        focusedTaskID?.wrappedValue = selection.ids.contains(id)
            ? id : allVisibleIDs.first { selection.ids.contains($0) }
        BoardSelection.shared.inspectBoard(dayKey)
        if modifiers.isEmpty {
            onInspect?(id)
        }
    }
}

/// 单个遗留任务芯片的状态与交互
struct LeftoverChipState {
    var count: Int
    var isExpanded: Bool
    var onToggle: () -> Void
}

/// 遗留任务栏整体配置
struct LeftoverChipsBarConfig {
    var yesterday: LeftoverChipState
    var upcoming: LeftoverChipState
}

enum LeftoverChipKind {
    case yesterday, upcoming

    func accessibilityLabel(count: Int, locale: Locale) -> String {
        // 使用完整字面量保留本地化占位符；动态拼接资源键会让朗读器读出键名。
        switch self {
        case .yesterday:
            return count == 0
                ? L10n.string("a11y.yesterday.zero", locale: locale)
                : L10n.string("a11y.yesterday.count \(count)", locale: locale)
        case .upcoming:
            return count == 0
                ? L10n.string("a11y.upcoming.zero", locale: locale)
                : L10n.string("a11y.upcoming.count \(count)", locale: locale)
        }
    }
}

struct LeftoverChipsBar: View {
    var config: LeftoverChipsBarConfig
    @Environment(\.locale) private var locale

    private var yesterday: LeftoverChipState { config.yesterday }
    private var upcoming: LeftoverChipState { config.upcoming }

    var body: some View {
        if yesterday.count > 0 || upcoming.count > 0 {
            HStack(spacing: 12) {
                if yesterday.count > 0 {
                    chip(LeftoverChipConfig(
                        title: "chip.yesterday",
                        count: yesterday.count,
                        expanded: yesterday.isExpanded,
                        kind: .yesterday,
                        action: yesterday.onToggle
                    ))
                }
                if upcoming.count > 0 {
                    chip(LeftoverChipConfig(
                        title: "chip.upcoming",
                        count: upcoming.count,
                        expanded: upcoming.isExpanded,
                        kind: .upcoming,
                        action: upcoming.onToggle
                    ))
                }
            }
        }
    }

    private struct LeftoverChipConfig {
        var title: LocalizedStringKey
        var count: Int
        var expanded: Bool
        var kind: LeftoverChipKind
        var action: () -> Void
    }

    private func chip(_ config: LeftoverChipConfig) -> some View {
        DaybookChip(tint: DaybookPalette.accent.base, isSelected: config.expanded, action: config.action) {
            HStack(spacing: 4) {
                Text(config.title)
                Text("\(config.count)")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded)) // token-exempt: 遗留计数用圆体
                Image(systemName: config.expanded ? "chevron.up" : "chevron.down")
                    .accessibilityHidden(true)
            }
        }
        .disabled(config.count == 0)
        .opacity(config.count == 0 ? 0.45 : 1)
        .accessibilityLabel(config.kind.accessibilityLabel(count: config.count, locale: locale))
    }
}
