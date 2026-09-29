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
        let page = makePageModel()
        VStack(alignment: .leading, spacing: 10) {
            headerBar(page)
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        scrollOffsetTracker

                        if page.isTodayEmpty && showYesterday && !page.yesterdayItems.isEmpty {
                            centeredYesterdaySection(page)
                        } else {
                            yesterdaySection(page)
                            upcomingSection(page)
                        }
                        dayBoardView(page)

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
        .onChange(of: page.allVisibleIDs(showYesterday: showYesterday, showUpcoming: showUpcoming)) { previous, next in
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

    func makePageModel() -> TasksPageViewModel {
        TasksPageViewModel.make(
            todayKey: todayKey,
            yesterdayKey: yesterdayKey,
            routines: routines,
            checks: checks,
            todos: todos,
            catalogs: TaskCatalogContext(tags: tags, attachments: attachments, context: modelContext),
            filter: effectiveFilter
        )
    }

    private func dayBoardView(_ page: TasksPageViewModel) -> some View {
        DayBoardList(
            dayKey: todayKey,
            routines: routines,
            checks: checks,
            todos: todos,
            config: DayBoardListConfig(
                todayKey: todayKey,
                filter: effectiveFilter,
                dayKeyForID: { id in
                    page.dayKey(for: id, listDayKey: todayKey, yesterdayKey: yesterdayKey)
                },
                interaction: config.interaction,
                yesterdayUnfinishedCount: page.yesterdayItems.count,
                isYesterdayExpanded: showYesterday,
                selection: $taskSelection,
                onToggleYesterday: { showYesterday.toggle() }
            )
        )
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
