import AppKit
import SwiftData
import SwiftUI

/// 今日页“昨天／即将”两个可展开区的状态。工作台由宿主持有（合并批 M-1 C，tasks.sections 与页面共用这一份）；
/// 其他宿主仍用页面自己的状态。initialized 记录首次出现时的默认展开只做一次。
struct TasksPageSections: Equatable {
    var yesterday = false
    var upcoming = false
    var initialized = false
}

/// 待办页面配置选项（<= 5 属性）
struct TasksPageConfig {
    var yesterdayKey: String? = nil
    var maxScrollHeight: CGFloat? = nil
    var interaction: DayBoardInteraction = DayBoardInteraction()
    var externalFilter: Binding<BoardFilter>? = nil
    var externalSections: Binding<TasksPageSections>? = nil

    init(
        yesterdayKey: String? = nil,
        maxScrollHeight: CGFloat? = nil,
        interaction: DayBoardInteraction = DayBoardInteraction(),
        externalFilter: Binding<BoardFilter>? = nil,
        externalSections: Binding<TasksPageSections>? = nil
    ) {
        self.yesterdayKey = yesterdayKey
        self.maxScrollHeight = maxScrollHeight
        self.interaction = interaction
        self.externalFilter = externalFilter
        self.externalSections = externalSections
    }

    var focusedTaskID: Binding<UUID?>? { interaction.focusedTaskID }
    var highlightedTaskID: UUID? { interaction.highlightedTaskID }
    var onInspect: ((UUID) -> Void)? { interaction.onInspect }
    var onReturnToInput: (() -> Void)? { interaction.onReturnToInput }
}

struct TasksPage: View {
    @WorkspaceNavigationContext var workspaceNavigation
    @WorkspaceBoardContext var boardSelection
    @Environment(\.modelContext) var modelContext
    @Environment(\.locale) var locale
    @Environment(\.workspaceEmbedded) var embedded
    @Environment(\.workspaceHostContext) private var hostContext

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

    @State private var localSections = TasksPageSections()
    @State var pendingTrash: PendingTrash?
    @State var boardFilter = BoardFilter()
    @State var taskSelection = TaskSelection()
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var effectiveFilter: BoardFilter {
        config.externalFilter?.wrappedValue ?? boardFilter
    }

    /// 有外部绑定时读写宿主那一份，否则用页面自己的状态；两者不会同时生效。
    var sections: TasksPageSections {
        get { config.externalSections?.wrappedValue ?? localSections }
        nonmutating set {
            if let external = config.externalSections { external.wrappedValue = newValue } else { localSections = newValue }
        }
    }
    var showYesterday: Bool {
        get { sections.yesterday }
        nonmutating set { sections.yesterday = newValue }
    }
    var showUpcoming: Bool {
        get { sections.upcoming }
        nonmutating set { sections.upcoming = newValue }
    }

    var body: some View {
        let page = makePageModel()
        VStack(alignment: .leading, spacing: 4) {
            headerBar(page)
            ScrollViewReader { scrollProxy in
                // 视口高度只作为内容的下限。固定成视口高度时，多出来的任务会被裁掉，滚动视图也认为没有可滚距离。
                GeometryReader { viewport in
                    let minimumHeight = max(viewport.size.height - 4, 120)
                    let centersYesterday = page.isTodayEmpty && showYesterday && !page.yesterdayItems.isEmpty
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            if centersYesterday {
                                centeredYesterdaySection(page)
                                    .zIndex(1)
                            } else {
                                yesterdaySection(page)
                                    .zIndex(1)
                                upcomingSection(page)
                            }
                            dayBoardView(page)
                                .zIndex(0)

                            blankClickArea
                        }
                        .padding(.top, 2)
                        .padding(.bottom, 24) // control: 预留底部安全距离，确保滚动到底部时卡片及阴影完整展现
                        .padding(.trailing, 2) // control: 预留右侧微间隙，避免右边框与悬浮滚动条重叠
                        .background(alignment: .top) {
                            scrollOffsetTracker
                        }
                        .frame(
                            maxWidth: .infinity,
                            minHeight: minimumHeight,
                            alignment: centersYesterday ? .center : .topLeading
                        )
                        .background(
                            BlankClickArea(onClick: clearSelection)
                        )
                    }
                    .coordinateSpace(name: "tasks_page_scroll")
                    .onPreferenceChange(TasksPageScrollOffsetKey.self) { offset in
                        let shouldCollapse = offset < -32
                        if workspaceNavigation.isInlineTitleVisible != shouldCollapse {
                            workspaceNavigation.isInlineTitleVisible = shouldCollapse
                        }
                    }
                    .scrollIndicators(.hidden)
                    .daybookScroll(featherEdges: true, featherHeight: 12) // control
                    .daybookTopScrollBlur(height: 18)
                    .onChange(of: focusedTaskID?.wrappedValue) { _, newValue in
                        if let newValue {
                            withAnimation(DaybookMotion.interactive) {
                                scrollProxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: maxScrollHeight ?? .infinity)
                .background(
                    BlankClickArea(onClick: clearSelection)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .workspaceInspectorTargets(page.inspectorIDs(dayKey: todayKey, filter: effectiveFilter, showYesterday: showYesterday, showUpcoming: showUpcoming))
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
        .onAppear {
            if !sections.initialized {
                var next = sections
                next.initialized = true
                if page.totalOpenTodosCount == 0 && !page.yesterdayItems.isEmpty {
                    next.yesterday = true
                }
                sections = next
            }
        }
        .onDisappear {
            workspaceNavigation.isInlineTitleVisible = false
        }
    }

    func makePageModel() -> TasksPageViewModel {
        TasksPageViewModel.make(
            todayKey: todayKey,
            yesterdayKey: yesterdayKey,
            routines: routines,
            checks: checks,
            todos: todos,
            catalogs: TaskCatalogContext(tags: tags, attachments: attachments, context: modelContext,
                                         attachmentStorage: .resolve(hostContext)),
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

    override func scrollWheel(with event: NSEvent) {
        guard let scrollView = enclosingScrollView else {
            super.scrollWheel(with: event)
            return
        }
        scrollView.scrollWheel(with: event)
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

    func boardSortKey(listDay: String?) -> BoardSortKey {
        switch self {
        case .resident(let item):
            BoardSortKey(
                sortOrder: item.sortOrder,
                dayKey: listDay ?? "",
                isImportant: item.isImportant,
                isUrgent: item.isUrgent,
                remindMinutes: item.remindMinutes,
                createdAt: item.createdAt,
                hasSubtasks: !item.subtaskTemplates.isEmpty
            )
        case .todo(let item):
            BoardSortKey(
                sortOrder: item.sortOrder,
                dayKey: listDay ?? item.dayKey,
                isImportant: item.isImportant,
                isUrgent: item.isUrgent,
                remindMinutes: item.remindMinutes,
                createdAt: item.createdAt,
                hasSubtasks: !item.isDone && item.subtasks.contains(where: { $0.deletedAt == nil })
            )
        }
    }

    var boardSortKey: BoardSortKey { boardSortKey(listDay: nil) }
}
