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

    private var todayKey: String {
        _ = dayTick
        return dayClock.todayKey
    }

    var body: some View {
        DaybookPage(
            minWidth: 480,
            minHeight: 480
        ) {
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
    }

    private func addTodo() {
        guard DayBoardMutations.addCapturedTodo(text: draftText, dayKey: todayKey, context: modelContext) else { return }
        draftText = ""
    }
}
