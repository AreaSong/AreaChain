import SwiftData
import SwiftUI
import AppKit

/// 三栏工作台：侧栏、详情页与检查器抽屉。
@MainActor
struct MainSplitWorkspaceView: View {
    @Bindable private var navigation: WorkspaceNavigation
    var search: UnifiedSearchController?
    var hostContext: WorkspaceHostContext?
    /// 隔离宿主一出现就显示搜索页；正式版（M-6）由 UnifiedSearchProduction 按当前查询决定，打开工作台仍落在原页面。
    var presentsSearchOnAppear = true

    init(navigation: WorkspaceNavigation? = nil, search: UnifiedSearchController? = nil,
         hostContext: WorkspaceHostContext? = nil, presentsSearchOnAppear: Bool = true) {
        self.navigation = navigation ?? .shared
        self.search = search
        self.hostContext = hostContext
        self.presentsSearchOnAppear = presentsSearchOnAppear
    }

    private var searchRouter: WorkspaceSearchRouter? {
        guard hostContext?.navigation === navigation, search?.navigationRouter?.navigation === navigation else { return nil }
        return search?.navigationRouter
    }

    private var activeInspectorFocus: WorkspaceInspectorFocus { searchRouter?.inspectorFocus ?? inspectorFocus }
    private var isIsolatedHost: Bool { hostContext?.isIsolated == true }
    @State private var inspectorWidth = WorkspaceLayout.inspectorIdealWidth
    @State private var inspectorFocus = WorkspaceInspectorFocus()

    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var todos: [TodoItem]
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query private var checks: [RoutineCheck]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isInspectorVisible: Bool {
        navigation.isInspectorPresented && navigation.canInspectSelectedTask
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebarColumn
            detailColumn
            if isInspectorVisible {
                inspectorColumn
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor)) // token-exempt: 三栏工作台统一窗口底板
        .onPreferenceChange(WorkspaceColumnWidthsKey.self, perform: updateInspectorSpace)
        .onChange(of: navigation.isInspectorPresented) { _, presented in
            if presented { activeInspectorFocus.beginPresentation() }
        }
        .onDisappear { navigation.updateInspectorSpace(available: true) }
        .onChange(of: tags.filter { $0.deletedAt == nil }.map(\.id)) { _, ids in
            if let tagID = navigation.selectedTagID, !ids.contains(tagID) { navigation.selectedTagID = nil }
        }
        .workspaceToolbarTitleHidden()
        .syntaxOverlayHost()
        .environment(\.workspaceEmbedded, true)
        .environment(\.workspaceHostContext, hostContext)
        .environment(\.workspaceSearchRouter, searchRouter)
        .background(WorkspaceNavigationProbe(router: searchRouter, key: "host"))
        .unifiedSearchOverlayHost()
        .onAppear { if search != nil && presentsSearchOnAppear { navigation.searchPresentation = true } }
        .onChange(of: navigation.searchPresentation) { _, value in
            if value == nil, let hostContext { search?.ordinaryWorkspaceVisit(hostContext, pendingLane: WorkspacePendingPageModel.make(
                routines: routines, todos: todos, checks: checks, todayKey: DayClock.shared.todayKey,
                navigation: navigation).lane) }
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private var sidebarColumn: some View {
        WorkspaceSidebarView(
            navigation: navigation,
            tags: tags,
            todos: todos
        )
        .frame(width: WorkspaceLayout.sidebarWidth)
        .frame(maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .top)
    }

    private var inspectorColumn: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor) // token-exempt: 右侧内嵌面板外框与主画布共用系统灰底
                .ignoresSafeArea(.all, edges: .top)

            ZStack(alignment: .top) {
                DaybookPalette.sidebarFill

                if navigation.isShowingShellPreview {
                    WorkspaceShellInspectorPlaceholderView()
                } else {
                    TaskDetailDrawer(taskID: $navigation.selectedTaskID)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.panel, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DaybookRadius.panel, style: .continuous)
                    .strokeBorder(DaybookPalette.sidebarBorder, lineWidth: 1)
            }
            .daybookElevation(.panel)
            .padding(.leading, 8)
            .padding(.top, 9)
            .padding(.bottom, 9)
            .padding(.trailing, 9)
        }
        .environment(\.workspaceInspectorFocus, activeInspectorFocus)
        .frame(width: WorkspaceLayout.inspectorIdealWidth)
        .frame(maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .top)
        .background(WorkspaceInspectorFocusMarker(owner: activeInspectorFocus))
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: WorkspaceColumnWidthsKey.self,
                                       value: .init(inspector: geometry.size.width))
            }
        }
    }

    // MARK: - 右侧区域（上下分为「第 2 块：右上固定顶栏空间」与「第 3 块：右下主内容代码插入槽」）

    private var detailColumn: some View {
        GeometryReader { geometry in
            let headerHeight = WorkspaceHeaderGeometry(width: geometry.size.width).height
            bottomContentSlot
                .padding(.top, headerHeight)
                .overlayPreferenceValue(WorkspaceHeaderContentKey.self, alignment: .top) { content in
                    topHeaderSlot(content: content, height: headerHeight)
                }
        }
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: WorkspaceColumnWidthsKey.self,
                                       value: .init(main: geometry.size.width))
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .overlay(alignment: .bottom) {
            if showsBatchBar {
                WorkspaceBatchActionBar(
                    navigation: navigation,
                    data: WorkspaceBatchData(
                        todos: todos,
                        routines: routines,
                        checks: checks,
                        tags: tags
                    )
                )
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onKeyPress(.escape) {
            handleEscapeKey()
        }
        .background(Color(nsColor: .windowBackgroundColor)) // token-exempt: detail 列全局原生系统灰底
        .ignoresSafeArea(.all, edges: .top)
    }

    /// 第 2 块公用空间：右上固定顶栏（左边标题、中间搜索、右边功能，固定在顶部不滚动）
    private func topHeaderSlot(content: WorkspaceHeaderContent, height: CGFloat) -> some View {
        WorkspaceHeaderBar(
            navigation: navigation,
            tags: tags,
            searchController: search,
            content: navigation.isSearching && search != nil ? WorkspaceHeaderContent() : content
        )
        .frame(height: height)
    }

    /// 第 3 块公用空间：右下主内容区（各页面代码插入槽，独立占满顶栏下方剩余空间）
    private var bottomContentSlot: some View {
        ZStack {
            if navigation.isSearching, let search {
                UnifiedSearchWorkspaceContent(controller: search)
            } else {
                VStack(spacing: 0) {
                    if let search { UnifiedSearchReturnBar(controller: search) }
                    detailView
                        .background(WorkspaceNavigationProbe(router: searchRouter,
                                                             key: "page." + navigation.selectedTab.rawValue))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.daybookScrollTopEdge, true)
    }

    private func updateInspectorSpace(_ widths: WorkspaceColumnWidths) {
        guard let main = widths.main, main > 0 else { return }
        let visible = navigation.isInspectorPresented && navigation.canInspectSelectedTask
        if let measured = widths.inspector, visible, measured >= WorkspaceLayout.inspectorMinWidth {
            inspectorWidth = measured
        }
        // 收起后按原详情实际宽度预算，额外恢复余量避免阈值附近反复开关。
        let required = WorkspaceLayout.inspectorMainMinWidth
            + (visible ? 0 : inspectorWidth + WorkspaceLayout.inspectorReopenMargin)
        let available = main >= required
        if visible && !available && activeInspectorFocus.releaseFocus() {
            // nil responder 会被系统布局恢复到隐藏字段；将实际详情焦点交给始终可见的统一搜索框（装配失败时没有可接的输入）。
            search?.requestInputFocus()
        }
        navigation.updateInspectorSpace(available: available)
    }

    private func handleEscapeKey() -> KeyPress.Result {
        if let search {
            if search.inputFocused { return .ignored }
            if navigation.isSearching {
                search.intent(.escape, source: search.buffer)
                return .handled
            }
        }
        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView {
            if editor.hasMarkedText() { return .ignored }
            if let state = SyntaxAutocompleteState.forResponder(editor), state.hasPresentation {
                state.dismiss()
                return .handled
            }
        }
        if (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true {
            navigation.boardSelection.markEscapeCancelsEdits()
            NSApp.keyWindow?.makeFirstResponder(nil)
            return .handled
        }
        if navigation.isInspectorPresented {
            navigation.closeInspector()
            return .handled
        }
        if navigation.selectedTaskID != nil {
            navigation.selectedTaskID = nil
            return .handled
        }
        if !navigation.selectedTaskIDs.isEmpty {
            navigation.clearSelection()
            return .handled
        }
        return .ignored
    }

    private var showsBatchBar: Bool {
        guard !navigation.isSearching, !navigation.isShowingShellPreview, !navigation.selectedTaskIDs.isEmpty else { return false }
        if navigation.selectedTagID != nil { return true }
        switch navigation.selectedTab {
        case .pending, .allItems:
            return true
        default:
            return false
        }
    }

    // MARK: - Detail Router

    @ViewBuilder
    private var detailView: some View {
        if let search, let router = searchRouter, let contents = router.contents,
           case .content(let object) = router.destination {
            WorkspaceReadOnlyContentView(session: contents, object: object, controller: search)
        } else if navigation.isShowingShellPreview {
            WorkspaceShellPreviewPage()
        } else if let tid = navigation.selectedTagID, let tag = tags.first(where: { $0.id == tid && $0.deletedAt == nil }) {
            WorkspaceFilteredListView(tag: tag)
        } else {
            switch navigation.selectedTab {
            case .privacy:
                PrivacyUnlockSettingsView(vault: hostContext?.vault)
                    .disabled(isIsolatedHost)
            case .dataBackup:
                DataBackupView()
                    .disabled(isIsolatedHost)
            case .dashboard:
                DashboardView()
            case .today:
                WorkspaceTodayView()
            case .pending:
                WorkspacePendingView()
            case .allItems:
                WorkspaceAllItemsView()
            case .calendar:
                CalendarStandaloneView()
            case .quadrant:
                QuadrantStandaloneView()
            case .gantt:
                GanttStandaloneView()
            case .diary:
                DiaryStandaloneView(vault: hostContext?.vault)
            case .attachments:
                AttachmentBrowserPage()
            case .clipboard:
                ClipboardHistoryPage(session: hostContext?.clipboard ?? .shared)
                    .disabled(isIsolatedHost)
            case .tags:
                TagManagementPage()
            case .trash:
                TrashPage()
            case .settings:
                SettingsView(observesSystemStatus: !isIsolatedHost)
                    .disabled(isIsolatedHost)
            case .shortcuts:
                ShortcutsSettingsView(store: hostContext?.shortcuts)
                    .disabled(isIsolatedHost)
            }
        }
    }

}

private extension View {
    @ViewBuilder
    func workspaceToolbarTitleHidden() -> some View {
        if #available(macOS 15.0, *) {
            self
                .toolbar(removing: .title)
                .navigationTitle("")
        } else {
            self
                .navigationTitle("")
        }
    }
}

@MainActor
private enum WorkspacePreviewSeed {
    static func makeContainer() -> ModelContainer {
        guard let container = try? AppStartup.memoryContainer() else {
            fatalError("无法创建预览内存容器")
        }
        let context = container.mainContext
        let today = DayClock.shared.todayKey
        let tags = ["工作", "生活", DiaryMemoTags.idea, DiaryMemoTags.journal, DiaryMemoTags.password]
            .enumerated()
            .map { TagItem(name: $0.element, sortOrder: $0.offset) }
        tags.forEach { context.insert($0) }
        seedTodos(in: context, today: today, workTag: tags[0], lifeTag: tags[1])
        seedRoutinesAndNotes(in: context, today: today, tags: tags)
        try? context.save()
        return container
    }

    private static func seedTodos(in context: ModelContext, today: String, workTag: TagItem, lifeTag: TagItem) {
        let primary = TodoItem(
            title: "核对工作台的公共组件",
            dayKey: today,
            remindMinutes: 10 * 60 + 30,
            tagIDs: workTag.id.uuidString,
            isImportant: true,
            isUrgent: true,
            notes: "支持在 Xcode Canvas 中点击左侧栏实时切换全部 16 个页面，并点击事项打开右侧检查器。"
        )
        context.insert(primary)
        context.insert(SubtaskItem(
            title: "检查浅色与深色模式表现",
            isDone: true,
            sortOrder: 0,
            tagIDs: workTag.id.uuidString,
            todo: primary
        ))
        context.insert(SubtaskItem(title: "核对三栏宽度与检查器联动", isDone: false, sortOrder: 1, todo: primary))
        context.insert(TodoItem(
            title: "整理本周排期与里程碑",
            dayKey: DayKey.shifted(today, by: 1),
            remindMinutes: 14 * 60,
            tagIDs: workTag.id.uuidString,
            isImportant: true
        ))
        context.insert(TodoItem(title: "采购周末阅读书单", dayKey: today, tagIDs: lifeTag.id.uuidString, isUrgent: true))
        context.insert(TodoItem(
            title: "补充昨日会议纪要（逾期示例）",
            dayKey: DayKey.shifted(today, by: -1),
            tagIDs: workTag.id.uuidString
        ))
        context.insert(TodoItem(title: "已完成示例事项", isDone: true, dayKey: today, tagIDs: lifeTag.id.uuidString))
        let trashed = TodoItem(title: "回收站中的示例待办", dayKey: today)
        trashed.deletedAt = .now
        context.insert(trashed)
    }

    private static func seedRoutinesAndNotes(in context: ModelContext, today: String, tags: [TagItem]) {
        let reading = DailyRoutine(title: "每日阅读 20 分钟", sortOrder: 0, createdDayKey: DayKey.shifted(today, by: -2))
        context.insert(reading)
        context.insert(RoutineCheck(dayKey: DayKey.shifted(today, by: -1), isDone: true, routine: reading))
        context.insert(DailyRoutine(title: "晚间复盘与整理", sortOrder: 1, createdDayKey: today))
        let idea = DiaryEntry(
            text: "工作台全页面预览已就绪\n在右侧 Canvas 画布中可直接点击左侧导航栏，实时切换全部页面。",
            dayKey: today
        )
        idea.tagIDs = tags[2].id.uuidString
        idea.isPinned = true
        context.insert(idea)
        let journal = DiaryEntry(text: "把事情写下来以后，脑子里安静了很多。", dayKey: today)
        journal.tagIDs = tags[3].id.uuidString
        context.insert(journal)
    }

    static func makeView(isDark: Bool) -> some View {
        let suite = "AreaChain.Preview." + (isDark ? "dark" : "light")
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: suite) ?? .standard)
        prefs.appearance = isDark ? .dark : .light
        return MainSplitWorkspaceView()
            .modifier(AppChrome(prefs: prefs))
            .modelContainer(makeContainer())
            .background(WorkspacePreviewWindowConfigurator(isDark: isDark))
            .frame(width: DaybookMetrics.Window.workspaceSize.width,
                   height: DaybookMetrics.Window.workspaceSize.height)
    }
}

private struct WorkspacePreviewWindowConfigurator: NSViewRepresentable {
    var isDark: Bool

    func makeNSView(context: Context) -> WorkspacePreviewChromeNSView {
        let view = WorkspacePreviewChromeNSView()
        view.isDark = isDark
        return view
    }

    func updateNSView(_ nsView: WorkspacePreviewChromeNSView, context: Context) {
        nsView.isDark = isDark
        nsView.applyWindowChrome()
    }
}

private final class WorkspacePreviewChromeNSView: NSView {
    var isDark = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyWindowChrome()
        DispatchQueue.main.async { [weak self] in
            self?.applyWindowChrome()
        }
    }

    override func layout() {
        super.layout()
        applyWindowChrome()
    }

    func applyWindowChrome() {
        UserDefaults.standard.register(defaults: [
            "NSSplitViewItemSidebarDefaultsToFloatingAppearance": false
        ])
        guard let window else { return }
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.toolbarStyle = .unified
        if window.toolbar == nil {
            window.toolbar = NSToolbar(identifier: "AreaChainWorkspaceToolbar")
        }
        window.title = ""
        window.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    }
}

#Preview("工作台全页面（深色）") {
    WorkspacePreviewSeed.makeView(isDark: true)
}

#Preview("工作台全页面（浅色）") {
    WorkspacePreviewSeed.makeView(isDark: false)
}
