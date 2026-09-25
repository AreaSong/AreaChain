import SwiftData
import SwiftUI

/// 工作台批量操作数据源
struct WorkspaceBatchData {
    var todos: [TodoItem]
    var routines: [DailyRoutine]
    var checks: [RoutineCheck]
    var tags: [TagItem]

    init(
        todos: [TodoItem] = [],
        routines: [DailyRoutine] = [],
        checks: [RoutineCheck] = [],
        tags: [TagItem] = []
    ) {
        self.todos = todos
        self.routines = routines
        self.checks = checks
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
                onApplyTag: handleApplyTag,
                tags: tags
            ),
            lifecycle: BatchLifecycleActions(
                onTrash: handleTrash,
                onClear: handleClear
            ),
            showsSchedule: capability.canReschedule,
            showsStatus: capability.canComplete,
            showsEnable: capability.canToggleEnabled,
            onSetEnabled: handleSetEnabled,
            noteKey: capability.noteKey.map { LocalizedStringKey($0) }
        )
        .confirmMoveToTrash($pendingTrash)
    }

    private var capability: BatchCapability {
        AgendaProjection.capability(
            ids: navigation.selectedTaskIDs,
            todos: todos.map(\.snapshot),
            routines: routines.map(\.snapshot),
            todayKey: DayClock.shared.todayKey
        )
    }

    private func handleMoveToday() {
        guard capability.canReschedule else { return }
        let today = DayClock.shared.todayKey
        guard DayBoardMutations.batchMoveTodos(navigation.selectedTaskIDs, to: today, todos: todos) else { return }
        navigation.clearSelection()
    }

    private func handleMoveTomorrow() {
        guard capability.canReschedule else { return }
        let tomorrow = DayKey.shifted(DayClock.shared.todayKey, by: 1)
        guard DayBoardMutations.batchMoveTodos(navigation.selectedTaskIDs, to: tomorrow, todos: todos) else { return }
        navigation.clearSelection()
    }

    private func handleToggleDone(_ markDone: Bool) {
        guard capability.canComplete else { return }
        let ids = navigation.selectedTaskIDs
        let today = DayClock.shared.todayKey
        let saved: Bool
        if capability.kind == .routinesOnly {
            saved = DayBoardMutations.batchSetRoutineChecks(
                ids, markDone: markDone, on: today, routines: routines, context: modelContext
            )
        } else {
            saved = DayBoardMutations.batchToggleDone(ids, markDone: markDone, todos: todos)
        }
        guard saved else { return }
        navigation.clearSelection()
    }

    private func handleSetEnabled(_ enabled: Bool) {
        guard capability.canToggleEnabled else { return }
        guard DayBoardMutations.batchSetRoutineEnabled(
            navigation.selectedTaskIDs,
            enabled: enabled,
            todayKey: DayClock.shared.todayKey,
            routines: routines
        ) else { return }
        navigation.clearSelection()
    }

    private func handleApplyTag(_ tid: UUID, _ present: Bool) {
        guard DayBoardMutations.batchApplyTag(
            navigation.selectedTaskIDs,
            tagID: tid,
            present: present,
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
