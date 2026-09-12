import SwiftData
import SwiftUI

/// 工作台批量操作数据源
struct WorkspaceBatchData {
    var todos: [TodoItem]
    var routines: [DailyRoutine]
    var checks: [RoutineCheck]
    var projects: [ProjectItem]
    var tags: [TagItem]

    init(
        todos: [TodoItem] = [],
        routines: [DailyRoutine] = [],
        checks: [RoutineCheck] = [],
        projects: [ProjectItem] = [],
        tags: [TagItem] = []
    ) {
        self.todos = todos
        self.routines = routines
        self.checks = checks
        self.projects = projects
        self.tags = tags
    }
}

/// 工作台底部悬浮批量操作栏容器
struct WorkspaceBatchActionBar: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var navigation: WorkspaceNavigation
    var data: WorkspaceBatchData
    @State private var pendingTrash: PendingTrash?

    private var todos: [TodoItem] { data.todos }
    private var routines: [DailyRoutine] { data.routines }
    private var checks: [RoutineCheck] { data.checks }
    private var projects: [ProjectItem] { data.projects }
    private var tags: [TagItem] { data.tags }

    var body: some View {
        BatchActionBar(
            selectedCount: navigation.selectedTaskIDs.count,
            schedule: BatchScheduleActions(
                onMoveToday: handleMoveToday,
                onMoveTomorrow: handleMoveTomorrow,
                onToggleDone: handleToggleDone
            ),
            classify: BatchClassifyActions(
                onSetProject: handleSetProject,
                onToggleTag: handleToggleTag,
                projects: projects,
                tags: tags
            ),
            lifecycle: BatchLifecycleActions(
                onTrash: handleTrash,
                onClear: handleClear
            )
        )
        .confirmMoveToTrash($pendingTrash)
    }

    private func handleMoveToday() {
        let today = DayClock.shared.todayKey
        guard DayBoardMutations.batchMoveTodos(navigation.selectedTaskIDs, to: today, todos: todos) else { return }
        navigation.clearSelection()
    }

    private func handleMoveTomorrow() {
        let tomorrow = DayKey.shifted(DayClock.shared.todayKey, by: 1)
        guard DayBoardMutations.batchMoveTodos(navigation.selectedTaskIDs, to: tomorrow, todos: todos) else { return }
        navigation.clearSelection()
    }

    private func handleToggleDone(_ markDone: Bool) {
        let ids = navigation.selectedTaskIDs
        let today = DayClock.shared.todayKey
        guard DayBoardMutations.batchSetCompletion(ids, markDone: markDone, on: today, context: modelContext) else { return }
        navigation.clearSelection()
    }

    private func handleSetProject(_ pid: UUID?) {
        guard DayBoardMutations.batchSetProject(
            navigation.selectedTaskIDs,
            projectID: pid,
            todos: todos,
            routines: routines
        ) else { return }
        navigation.clearSelection()
    }

    private func handleToggleTag(_ tid: UUID) {
        guard DayBoardMutations.batchToggleTag(
            navigation.selectedTaskIDs,
            tagID: tid,
            todos: todos,
            routines: routines
        ) else { return }
        navigation.clearSelection()
    }

    private func handleTrash() {
        let count = navigation.selectedTaskIDs.count
        pendingTrash = PendingTrash(title: "\(count)") {
            guard DayBoardMutations.batchTrash(
                navigation.selectedTaskIDs,
                todos: todos,
                routines: routines
            ) else { return }
            navigation.clearSelection()
        }
    }

    private func handleClear() {
        withAnimation(DaybookMotion.interactive) {
            navigation.clearSelection()
        }
    }
}
