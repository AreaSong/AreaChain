import SwiftData
import SwiftUI

struct WorkspaceTodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    private var dayClock: DayClock { DayClock.shared }

    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]

    @Bindable private var navigation = WorkspaceNavigation.shared
    @State private var dayTick = Date()
    @State private var draftText = ""
    @State private var composerFocused = false
    @State private var showingRecurringEditor = false
    @State private var showingRecurringList = false

    private var todayKey: String {
        _ = dayTick
        return dayClock.todayKey
    }

    private var progress: BoardProgress {
        DayBoardLogic.todayProgress(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            dayKey: todayKey
        )
    }

    var body: some View {
        DaybookPage(
            title: "workspace.today.title",
            subtitleText: DayKey.displayName(todayKey, locale: locale),
            minWidth: 480,
            minHeight: 480
        ) {
            headerTrailing
        } content: {
            DaybookComposer(
                text: $draftText,
                placeholder: L10n.string("workspace.composer.placeholder", locale: locale),
                focus: $composerFocused,
                availableTags: tags.filter { $0.deletedAt == nil }.map(\.name),
                onSubmit: addTodo,
                onCommandReturn: {}
            )

            TasksPage(
                todayKey: todayKey,
                routines: routines,
                checks: checks,
                todos: todos,
                config: TasksPageConfig(
                    yesterdayKey: dayClock.yesterdayKey,
                    interaction: DayBoardInteraction(
                        focusedTaskID: $navigation.selectedTaskID,
                        highlightedTaskID: navigation.selectedTaskID,
                        onInspect: { WorkspaceNavigation.shared.inspectTask($0) },
                        onReturnToInput: {
                            navigation.selectedTaskID = nil
                            composerFocused = true
                        }
                    )
                )
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
        .sheet(isPresented: $showingRecurringEditor) {
            RecurringItemEditor()
                .frame(minWidth: 460, minHeight: 520)
        }
        .sheet(isPresented: $showingRecurringList) {
            ResidentsPage()
                .frame(minWidth: 560, minHeight: 480)
        }
    }

    private var headerTrailing: some View {
        HStack(spacing: 10) {
            DaybookIconButton(systemName: "plus", label: "recurring.create.open", size: .compact) {
                showingRecurringEditor = true
            }
            DaybookIconButton(systemName: "repeat", label: "workspace.residents.open", size: .compact) {
                showingRecurringList = true
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(progressTitleKey)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)

                Text("\(progress.completed)/\(progress.total)")
                    .font(DaybookType.body.weight(.medium).monospacedDigit())
                    .foregroundStyle(progress.total > 0 && progress.completed >= progress.total ? DaybookPalette.accent.base : DaybookPalette.text.primary)
            }

            DaybookProgressRing(progress: progress.ratio, lineWidth: 3.5, size: 36)
        }
        .fixedSize(horizontal: true, vertical: false)
        .animation(DaybookMotion.interactive, value: progress.total)
        .animation(DaybookMotion.interactive, value: progress.completed)
    }

    private var progressTitleKey: LocalizedStringKey {
        if progress.total == 0 {
            return "workspace.progress.label"
        }
        return progress.completed >= progress.total ? "workspace.progress.done" : "workspace.progress.label"
    }

    private func addTodo() {
        guard DayBoardMutations.addCapturedTodo(text: draftText, dayKey: todayKey, context: modelContext) else { return }
        draftText = ""
    }
}
