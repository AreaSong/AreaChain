import SwiftData
import SwiftUI

/// 待办页面配置选项（<= 5 属性）
struct TasksPageConfig {
    var yesterdayKey: String? = nil
    var maxScrollHeight: CGFloat? = nil
    var interaction: DayBoardInteraction = DayBoardInteraction()

    init(
        yesterdayKey: String? = nil,
        maxScrollHeight: CGFloat? = nil,
        interaction: DayBoardInteraction = DayBoardInteraction()
    ) {
        self.yesterdayKey = yesterdayKey
        self.maxScrollHeight = maxScrollHeight
        self.interaction = interaction
    }

    var focusedTaskID: Binding<UUID?>? { interaction.focusedTaskID }
    var highlightedTaskID: UUID? { interaction.highlightedTaskID }
    var onInspect: ((UUID) -> Void)? { interaction.onInspect }
    var onReturnToInput: (() -> Void)? { interaction.onReturnToInput }
}

struct TasksPage: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.locale) var locale

    var todayKey: String
    var routines: [DailyRoutine]
    var checks: [RoutineCheck]
    var todos: [TodoItem]
    var config: TasksPageConfig

    @Query(sort: \ProjectItem.sortOrder) var projects: [ProjectItem]
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerBar
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        dayBoardView
                        upcomingSection
                        yesterdaySection
                    }
                    .padding(.vertical, 2)
                }
                .daybookScroll()
                .frame(maxWidth: .infinity, maxHeight: maxScrollHeight ?? .infinity)
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
        .animation(DaybookMotion.interactive, value: boardFilter)
        .animation(DaybookMotion.interactive, value: showUpcoming)
        .animation(DaybookMotion.interactive, value: showYesterday)
    }

    private var headerBar: some View {
        let hasChips = yesterdayItems.count > 0 || upcomingModels.count > 0
        let hasFilters = !projects.isEmpty || !tags.isEmpty || !todayBundleIDs.isEmpty
        return Group {
            if hasChips || hasFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if hasChips {
                            LeftoverChipsBar(
                                config: LeftoverChipsBarConfig(
                                    yesterday: LeftoverChipState(
                                        count: yesterdayItems.count,
                                        isExpanded: showYesterday,
                                        onToggle: { showYesterday.toggle() }
                                    ),
                                    upcoming: LeftoverChipState(
                                        count: upcomingModels.count,
                                        isExpanded: showUpcoming,
                                        onToggle: { showUpcoming.toggle() }
                                    )
                                )
                            )
                        }
                        if hasFilters {
                            BoardFilterBar(
                                filter: boardFilter,
                                projects: CatalogChoices.projects(projects),
                                tags: CatalogChoices.tags(tags),
                                bundleIDs: todayBundleIDs,
                                onChange: { boardFilter = $0 }
                            )
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.top, 2)
                    .padding(.bottom, 6)
                }
            }
        }
    }

    private var dayBoardView: some View {
        DayBoardList(
            dayKey: todayKey,
            routines: routines,
            checks: checks,
            todos: todos,
            config: DayBoardListConfig(
                todayKey: todayKey,
                filter: boardFilter,
                dayKeyForID: { [yesterdayKey] id in
                    resolveDayKey(for: id, yesterdayKey: yesterdayKey)
                },
                interaction: config.interaction
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
        )
    }

    var upcomingModels: [TodoItem] {
        let ids = Set(DayBoardLogic.upcomingTodos(todos: snapshots.2, todayKey: todayKey).map(\.id))
        return todos
            .filter { ids.contains($0.id) }
            .sorted {
                if $0.dayKey != $1.dayKey { return $0.dayKey < $1.dayKey }
                return $0.createdAt < $1.createdAt
            }
    }

    var todayBundleIDs: [String] {
        let routineIDs = DayBoardLogic.routines(for: todayKey, in: snapshots.0).map(\.sourceBundleID)
        let todoIDs = DayBoardLogic.todos(for: todayKey, in: snapshots.2).map(\.sourceBundleID)
        return Array(Set((routineIDs + todoIDs).filter { !$0.isEmpty })).sorted()
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
