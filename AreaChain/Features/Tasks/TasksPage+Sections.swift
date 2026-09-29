import SwiftUI

extension TasksPage {
    func upcomingSection(_ page: TasksPageViewModel) -> some View {
        Group {
            if showUpcoming, !page.upcomingModels.isEmpty {
                DaybookSectionHeader(title: "stamp.upcoming")
                ForEach(page.upcomingModels, id: \.id) { todo in
                    leftoverTodoRow(
                        todo,
                        page: page,
                        note: DayKey.shortStamp(todo.dayKey, locale: locale),
                        visibleIDs: page.upcomingModels.map(\.id)
                    )
                }
            }
        }
    }

    func yesterdaySection(_ page: TasksPageViewModel) -> some View {
        Group {
            if showYesterday, !page.yesterdayItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    yesterdaySectionHeader(page)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)

                    VStack(spacing: 2) {
                        ForEach(page.yesterdayItems) { item in
                            leftoverRow(item, page: page)
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

    func centeredYesterdaySection(_ page: TasksPageViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            yesterdaySectionHeader(page)
                .padding(.horizontal, 4)

            VStack(spacing: 2) {
                ForEach(page.yesterdayItems) { item in
                    leftoverRow(item, page: page)
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
    }

    private func yesterdaySectionHeader(_ page: TasksPageViewModel) -> some View {
        HStack(alignment: .center) {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(DaybookType.micro.weight(.semibold))
                    .foregroundStyle(DaybookPalette.accent.base)
                Text("stamp.yesterday")
                    .font(DaybookType.caption.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)
                DaybookCount(count: page.yesterdayItems.count, emphasis: true)
            }
            Spacer()
            if page.yesterdayItems.contains(where: { $0.kind == .todo }) {
                DaybookChip(tint: DaybookPalette.accent.base, isSelected: true, action: {
                    withAnimation(DaybookMotion.interactive) {
                        moveAllYesterdayTodosToToday(page)
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

    func leftoverTodoRow(
        _ todo: TodoItem,
        page: TasksPageViewModel,
        note: String? = nil,
        visibleIDs: [UUID]
    ) -> some View {
        let display = TodoRowDisplayOptions(
            isDone: false,
            isSelected: isLeftoverSelected(todo.id),
            note: note,
            includeSubtasks: false
        )
        let actions = TodoRowActions(
            onSelect: { selectLeftover(todo.id, dayKey: todo.dayKey, in: visibleIDs, modifiers: $0) },
            onDelete: { deleteTodo(todo) }
        )
        return TaskRowFactory.todo(TodoRowContext(
            todo: todo,
            todayKey: todayKey,
            catalogs: page.catalogs,
            display: display,
            actions: actions
        ))
    }

    @ViewBuilder
    func leftoverRow(_ item: UnfinishedItem, page: TasksPageViewModel) -> some View {
        if item.kind == .todo, let todo = page.todo(item.id) {
            leftoverTodoRow(todo, page: page, visibleIDs: page.yesterdayItems.map(\.id))
        } else if item.kind == .routine, let routine = page.routine(item.id) {
            leftoverRoutineRow(routine, item: item, page: page)
        } else {
            let actions = LeftoverRowActions(
                onToggle: { completeYesterday(item, page: page) },
                onSelect: { selectLeftover(item.id, dayKey: yesterdayKey, in: page.yesterdayItems.map(\.id), modifiers: $0) },
                onMoveToDay: item.kind == .todo ? { moveYesterdayTodo(item, to: $0, page: page) } : nil
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

    private func leftoverRoutineRow(
        _ routine: DailyRoutine,
        item: UnfinishedItem,
        page: TasksPageViewModel
    ) -> some View {
        let schedule = RoutineScheduleContext(
            todayKey: todayKey,
            checkDayKey: yesterdayKey,
            checks: checks,
            locale: locale,
            lookups: page.routineLookups(for: routine.id)
        )
        let display = RoutineRowDisplayOptions(
            isDone: false,
            isSelected: isLeftoverSelected(routine.id),
            usesDefaultNote: false
        )
        let actions = RoutineRowActions(
            onSelect: { selectLeftover(routine.id, dayKey: yesterdayKey, in: page.yesterdayItems.map(\.id), modifiers: $0) },
            onDelete: {
                pendingTrash = PendingTrash(title: routine.title) {
                    DayBoardMutations.trashRoutine(routine)
                }
            },
            onToggle: { completeYesterday(item, page: page) },
            onSkip: {
                DayBoardMutations.skipRoutine(routine, on: yesterdayKey, checks: checks, context: modelContext)
            }
        )
        return TaskRowFactory.routine(RoutineRowContext(
            routine: routine,
            schedule: schedule,
            catalogs: page.catalogs,
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

    func selectLeftover(
        _ id: UUID,
        dayKey: String,
        in visibleIDs: [UUID],
        modifiers: TaskSelectionModifiers = []
    ) {
        var selection = taskSelection
        if selection.anchorID == nil && selection.ids.isEmpty {
            selection.focus(focusedTaskID?.wrappedValue ?? highlightedTaskID)
        }
        // 昨天和即将各自成区。范围只沿当前分区的屏幕顺序，不把今日清单卷进来。
        selection.select(id, in: visibleIDs, modifiers: modifiers)
        taskSelection = selection
        focusedTaskID?.wrappedValue = selection.ids.contains(id)
            ? id : visibleIDs.first { selection.ids.contains($0) }
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
