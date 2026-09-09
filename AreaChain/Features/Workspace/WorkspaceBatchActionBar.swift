import SwiftData
import SwiftUI

/// 工作台底部悬浮批量操作栏容器
struct WorkspaceBatchActionBar: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var navigation: WorkspaceNavigation
    var todos: [TodoItem]
    var routines: [DailyRoutine]
    var checks: [RoutineCheck]
    var projects: [ProjectItem]
    var tags: [TagItem]
    @State private var pendingTrash: PendingTrash?

    var body: some View {
        BatchActionBar(
            selectedCount: navigation.selectedTaskIDs.count,
            onMoveToday: {
                let today = DayClock.shared.todayKey
                DayBoardMutations.batchMoveTodos(navigation.selectedTaskIDs, to: today, todos: todos)
                navigation.clearSelection()
            },
            onMoveTomorrow: {
                let tomorrow = DayKey.shifted(DayClock.shared.todayKey, by: 1)
                DayBoardMutations.batchMoveTodos(navigation.selectedTaskIDs, to: tomorrow, todos: todos)
                navigation.clearSelection()
            },
            onToggleDone: { markDone in
                let ids = navigation.selectedTaskIDs
                let today = DayClock.shared.todayKey
                DayBoardMutations.batchToggleDone(ids, markDone: markDone, todos: todos)
                DayBoardMutations.batchSetRoutineChecks(
                    ids,
                    markDone: markDone,
                    on: today,
                    routines: routines,
                    checks: checks,
                    context: modelContext
                )
                navigation.clearSelection()
            },
            onSetProject: { pid in
                DayBoardMutations.batchSetProject(
                    navigation.selectedTaskIDs,
                    projectID: pid,
                    todos: todos,
                    routines: routines
                )
                navigation.clearSelection()
            },
            onToggleTag: { tid in
                DayBoardMutations.batchToggleTag(
                    navigation.selectedTaskIDs,
                    tagID: tid,
                    todos: todos,
                    routines: routines
                )
                navigation.clearSelection()
            },
            onTrash: {
                let count = navigation.selectedTaskIDs.count
                pendingTrash = PendingTrash(title: "\(count)") {
                    DayBoardMutations.batchTrash(
                        navigation.selectedTaskIDs,
                        todos: todos,
                        routines: routines
                    )
                    navigation.clearSelection()
                }
            },
            onClear: {
                withAnimation(ModernMotion.interactive) {
                    navigation.clearSelection()
                }
            },
            projects: projects,
            tags: tags
        )
        .confirmMoveToTrash($pendingTrash)
    }
}
