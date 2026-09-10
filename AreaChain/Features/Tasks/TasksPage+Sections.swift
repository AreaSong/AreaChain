import SwiftUI

extension TasksPage {
    var upcomingSection: some View {
        Group {
            if showUpcoming, !upcomingModels.isEmpty {
                SectionStamp(title: "stamp.upcoming")
                ForEach(upcomingModels, id: \.id) { todo in
                    leftoverTodoRow(todo, note: DayKey.shortStamp(todo.dayKey, locale: locale))
                }
            }
        }
    }

    var yesterdaySection: some View {
        Group {
            if showYesterday {
                SectionStamp(title: "stamp.yesterday")
                ForEach(yesterdayItems) { item in
                    leftoverRow(item)
                }
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
            isSelected: highlightedTaskID == todo.id,
            note: note,
            includeSubtasks: false
        )
        let actions = TodoRowActions(
            onSelect: { inspectLeftover(todo.id, dayKey: todo.dayKey) },
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
                onSelect: { inspectLeftover(item.id, dayKey: yesterdayKey) },
                onMoveToDay: item.kind == .todo ? { moveYesterdayTodo(item, to: $0) } : nil
            )
            TaskRowFactory.leftoverFallback(LeftoverRowContext(
                item: item,
                todayKey: todayKey,
                yesterdayKey: yesterdayKey,
                isSelected: highlightedTaskID == item.id,
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
            isSelected: highlightedTaskID == routine.id,
            usesDefaultNote: false
        )
        let actions = RoutineRowActions(
            onSelect: { inspectLeftover(routine.id, dayKey: yesterdayKey) },
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

    func inspectLeftover(_ id: UUID, dayKey: String) {
        BoardSelection.shared.inspectBoard(dayKey)
        if let onInspect {
            onInspect(id)
            return
        }
        AppWindows.openWorkspace(tab: .today)
        WorkspaceNavigation.shared.inspectTask(id)
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

struct LeftoverChipsBar: View {
    var config: LeftoverChipsBarConfig

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
                        keyPrefix: "yesterday",
                        action: yesterday.onToggle
                    ))
                }
                if upcoming.count > 0 {
                    chip(LeftoverChipConfig(
                        title: "chip.upcoming",
                        count: upcoming.count,
                        expanded: upcoming.isExpanded,
                        keyPrefix: "upcoming",
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
        var keyPrefix: String
        var action: () -> Void

        var emptyLabel: LocalizedStringKey {
            LocalizedStringKey("a11y.\(keyPrefix).zero")
        }
        var countLabel: LocalizedStringKey {
            LocalizedStringKey("a11y.\(keyPrefix).count \(count)")
        }
    }

    private func chip(_ config: LeftoverChipConfig) -> some View {
        Button(action: config.action) {
            HStack(spacing: 4) {
                Text(config.title)
                    .font(.system(size: 11, weight: config.expanded ? .semibold : .medium))
                Text("\(config.count)")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 0.5)
                    .background(DaybookTheme.stamp.opacity(config.count == 0 ? 0.12 : 0.20))
                    .foregroundStyle(DaybookTheme.stamp)
                    .clipShape(Capsule())
                Image(systemName: config.expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.75))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(config.expanded ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.ink.opacity(0.04))
            )
            .overlay(
                Capsule()
                    .stroke(
                        config.expanded ? DaybookTheme.stamp.opacity(0.35) : DaybookTheme.rule.opacity(0.4),
                        lineWidth: 0.7
                    )
            )
            .foregroundStyle(config.expanded ? DaybookTheme.ink : DaybookTheme.muted)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(config.count == 0)
        .opacity(config.count == 0 ? 0.45 : 1)
        .accessibilityLabel(config.count == 0 ? config.emptyLabel : config.countLabel)
        .accessibilityAddTraits(config.expanded ? [.isSelected] : [])
    }
}
