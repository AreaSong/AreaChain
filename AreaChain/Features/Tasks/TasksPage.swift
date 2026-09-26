import AppKit
import SwiftData
import SwiftUI

/// 待办页面配置选项（<= 5 属性）
struct TasksPageConfig {
    var yesterdayKey: String? = nil
    var maxScrollHeight: CGFloat? = nil
    var interaction: DayBoardInteraction = DayBoardInteraction()
    var externalFilter: Binding<BoardFilter>? = nil

    init(
        yesterdayKey: String? = nil,
        maxScrollHeight: CGFloat? = nil,
        interaction: DayBoardInteraction = DayBoardInteraction(),
        externalFilter: Binding<BoardFilter>? = nil
    ) {
        self.yesterdayKey = yesterdayKey
        self.maxScrollHeight = maxScrollHeight
        self.interaction = interaction
        self.externalFilter = externalFilter
    }

    var focusedTaskID: Binding<UUID?>? { interaction.focusedTaskID }
    var highlightedTaskID: UUID? { interaction.highlightedTaskID }
    var onInspect: ((UUID) -> Void)? { interaction.onInspect }
    var onReturnToInput: (() -> Void)? { interaction.onReturnToInput }
}

struct TasksPage: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.locale) var locale
    @Environment(\.workspaceEmbedded) var embedded

    var todayKey: String
    var routines: [DailyRoutine]
    var checks: [RoutineCheck]
    var todos: [TodoItem]
    var config: TasksPageConfig

    @Query(sort: \TagItem.sortOrder) var tags: [TagItem]
    @Query var attachments: [AttachmentItem]

    // 兼容现有内部属性与扩展访问
    var yesterdayKey: String {
        config.yesterdayKey ?? DayKey.shifted(todayKey, by: -1)
    }
    var maxScrollHeight: CGFloat? { config.maxScrollHeight }
    var focusedTaskID: Binding<UUID?>? { config.interaction.focusedTaskID }
    var highlightedTaskID: UUID? { config.interaction.highlightedTaskID }
    var onInspect: ((UUID) -> Void)? { config.interaction.onInspect }
    var onReturnToInput: (() -> Void)? { config.interaction.onReturnToInput }

    init(
        todayKey: String,
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        todos: [TodoItem],
        config: TasksPageConfig = TasksPageConfig()
    ) {
        self.todayKey = todayKey
        self.routines = routines
        self.checks = checks
        self.todos = todos
        self.config = config
    }

    @State var showYesterday = false
    @State var showUpcoming = false
    @State var pendingTrash: PendingTrash?
    @State var boardFilter = BoardFilter()
    @State var taskSelection = TaskSelection()

    var effectiveFilter: BoardFilter {
        config.externalFilter?.wrappedValue ?? boardFilter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerBar
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        scrollOffsetTracker

                        if isTodayEmpty && showYesterday && !yesterdayItems.isEmpty {
                            centeredYesterdaySection
                        } else {
                            yesterdaySection
                            upcomingSection
                        }
                        dayBoardView

                        blankClickArea
                    }
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .containerRelativeFrame(.vertical, alignment: .topLeading) { length, _ in
                        max(length - 4, 120)
                    }
                    .background(
                        BlankClickArea(onClick: clearSelection)
                    )
                }
                .coordinateSpace(name: "tasks_page_scroll")
                .onPreferenceChange(TasksPageScrollOffsetKey.self) { offset in
                    let shouldCollapse = offset < -32
                    if WorkspaceNavigation.shared.isInlineTitleVisible != shouldCollapse {
                        WorkspaceNavigation.shared.isInlineTitleVisible = shouldCollapse
                    }
                }
                .daybookScroll(featherEdges: true)
                .frame(maxWidth: .infinity, maxHeight: maxScrollHeight ?? .infinity)
                .background(
                    BlankClickArea(onClick: clearSelection)
                )
                .onChange(of: focusedTaskID?.wrappedValue) { _, newValue in
                    if let newValue {
                        withAnimation(DaybookMotion.interactive) {
                            scrollProxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmMoveToTrash($pendingTrash)
        .animation(DaybookMotion.interactive, value: effectiveFilter)
        .animation(DaybookMotion.interactive, value: showUpcoming)
        .animation(DaybookMotion.interactive, value: showYesterday)
        .onChange(of: allVisibleIDs) { previous, next in
            taskSelection.dropRemoved(from: previous, to: next)
        }
        .onChange(of: focusedTaskID?.wrappedValue) { _, id in
            if let id, taskSelection.ids.contains(id) { return }
            taskSelection.focus(id)
        }
        .onDisappear {
            WorkspaceNavigation.shared.isInlineTitleVisible = false
        }
    }

    var untaggedTodosCount: Int {
        todos.filter { $0.deletedAt == nil && !$0.isDone && $0.dayKey == todayKey && TagIDList.parse($0.tagIDs).isEmpty }.count
    }

    var totalOpenTodosCount: Int {
        todos.filter { $0.deletedAt == nil && !$0.isDone && $0.dayKey == todayKey }.count
    }

    private var dayBoardView: some View {
        DayBoardList(
            dayKey: todayKey,
            routines: routines,
            checks: checks,
            todos: todos,
            config: DayBoardListConfig(
                todayKey: todayKey,
                filter: effectiveFilter,
                dayKeyForID: { [yesterdayKey] id in
                    resolveDayKey(for: id, yesterdayKey: yesterdayKey)
                },
                interaction: config.interaction,
                yesterdayUnfinishedCount: yesterdayItems.count,
                isYesterdayExpanded: showYesterday,
                selection: $taskSelection,
                onToggleYesterday: { showYesterday.toggle() }
            )
        )
    }

    private func resolveDayKey(for id: UUID, yesterdayKey: String) -> String {
        BoardFocusDay.key(
            for: id,
            listDayKey: todayKey,
            yesterdayKey: yesterdayKey,
            yesterdayIDs: Set(yesterdayItems.map(\.id)),
            upcomingDayKeys: Dictionary(
                uniqueKeysWithValues: upcomingModels.map { ($0.id, $0.dayKey) }
            )
        )
    }

    var snapshots: ([RoutineSnapshot], [CheckSnapshot], [TodoSnapshot]) {
        (routines.map(\.snapshot), checks.compactMap(\.snapshot), todos.map(\.snapshot))
    }

    var yesterdayItems: [UnfinishedItem] {
        DayBoardLogic.yesterdayUnfinished(
            routines: snapshots.0,
            checks: snapshots.1,
            todos: snapshots.2,
            yesterdayKey: yesterdayKey
        ).filter { item in
            if let todo = todos.first(where: { $0.id == item.id }), item.kind == .todo {
                return matchesListed(todo)
            }
            return routines.first(where: { $0.id == item.id }).map {
                matchesListed($0, on: yesterdayKey)
            } ?? false
        }
    }

    var upcomingModels: [TodoItem] {
        let ordered = DayBoardLogic.upcomingTodos(todos: snapshots.2, todayKey: todayKey)
        let byID = Dictionary(uniqueKeysWithValues: todos.map { ($0.id, $0) })
        return ordered.compactMap { byID[$0.id] }.filter(matchesListed)
    }

    var todayBundleIDs: [String] {
        let routineIDs = DayBoardLogic.routines(for: todayKey, in: snapshots.0).map(\.sourceBundleID)
        let todoIDs = DayBoardLogic.todos(for: todayKey, in: snapshots.2).map(\.sourceBundleID)
        return Array(Set((routineIDs + todoIDs).filter { !$0.isEmpty })).sorted()
    }

    private func matchesListed(_ todo: TodoItem) -> Bool {
        Classification.matchesListedRow(
            todo.classifyBits,
            dayKey: todo.dayKey,
            isDone: todo.isDone,
            remindMinutes: todo.remindMinutes,
            todayKey: todayKey,
            filter: effectiveFilter
        )
    }

    private func matchesListed(_ routine: DailyRoutine, on dayKey: String) -> Bool {
        let done = DayBoardLogic.isRoutineDone(routine.snapshot, checks: snapshots.1, on: dayKey)
        return Classification.matchesListedRow(
            routine.classifyBits,
            dayKey: dayKey,
            isDone: done,
            remindMinutes: routine.remindMinutes,
            todayKey: todayKey,
            filter: effectiveFilter
        )
    }

    var todayVisibleIDs: [UUID] {
        DayBoardLogic.openBoardItems(
            routines: snapshots.0,
            checks: snapshots.1,
            todos: snapshots.2,
            dayKey: todayKey
        ).filter { reference in
            switch reference {
            case .todo(let id):
                guard let todo = todos.first(where: { $0.id == id }) else { return false }
                return matchesListed(todo)
            case .recurring(let id):
                guard let routine = routines.first(where: { $0.id == id }) else { return false }
                return matchesListed(routine, on: todayKey)
            }
        }.map(\.modelID)
    }

    var allVisibleIDs: [UUID] {
        var ids: [UUID] = []
        if showYesterday {
            ids.append(contentsOf: yesterdayItems.map(\.id))
        }
        if showUpcoming {
            ids.append(contentsOf: upcomingModels.map(\.id))
        }
        ids.append(contentsOf: todayVisibleIDs)
        return ids
    }

    var isTodayEmpty: Bool {
        guard todayVisibleIDs.isEmpty else { return false }
        let (routineSnaps, checkSnaps, todoSnaps) = snapshots
        let hasClosedTodos = !DayBoardLogic.completedTodos(todos: todoSnaps, dayKey: todayKey).isEmpty
        let hasClosedRoutines = !DayBoardLogic.completedRoutines(
            routines: routineSnaps, checks: checkSnaps, dayKey: todayKey
        ).isEmpty
        return !hasClosedTodos && !hasClosedRoutines
    }

    private var blankClickArea: some View {
        BlankClickArea(onClick: clearSelection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 48)
    }

    func clearSelection() {
        taskSelection.focus(nil)
        focusedTaskID?.wrappedValue = nil
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    private var scrollOffsetTracker: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: TasksPageScrollOffsetKey.self,
                value: proxy.frame(in: .named("tasks_page_scroll")).minY
            )
        }
        .frame(height: 0)
    }
}

private struct TasksPageScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// 任务列表下方空白区域的原生点击接收器：点击立即取消选中，0 延迟且绝不被滚动视图手势吞噬
struct BlankClickArea: NSViewRepresentable {
    var onClick: () -> Void

    func makeNSView(context: Context) -> BlankClickNSView {
        let view = BlankClickNSView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ view: BlankClickNSView, context: Context) {
        view.onClick = onClick
    }
}

final class BlankClickNSView: NSView {
    var onClick: (() -> Void)?

    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?()
        super.mouseDown(with: event)
    }
}

enum BoardRow: Identifiable {
    case resident(DailyRoutine)
    case todo(TodoItem)

    var id: UUID {
        switch self {
        case .resident(let item): item.id
        case .todo(let item): item.id
        }
    }

    var reference: BoardItemReference {
        switch self {
        case .resident(let item): .recurring(item.id)
        case .todo(let item): .todo(item.id)
        }
    }

    var listID: String { reference.id }

    var boardSortKey: BoardSortKey {
        switch self {
        case .resident(let item):
            BoardSortKey(
                isImportant: item.isImportant,
                isUrgent: item.isUrgent,
                remindMinutes: item.remindMinutes,
                createdAt: item.createdAt
            )
        case .todo(let item):
            BoardSortKey(
                isImportant: item.isImportant,
                isUrgent: item.isUrgent,
                remindMinutes: item.remindMinutes,
                createdAt: item.createdAt
            )
        }
    }
}
