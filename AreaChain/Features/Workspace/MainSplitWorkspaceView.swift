import SwiftData
import SwiftUI
import AppKit

/// 三栏工作台：侧栏、详情页与检查器抽屉。
struct MainSplitWorkspaceView: View {
    @Bindable private var navigation: WorkspaceNavigation
    var search: UnifiedSearchController?
    var hostContext: WorkspaceHostContext?

    init(navigation: WorkspaceNavigation = .shared, search: UnifiedSearchController? = nil,
         hostContext: WorkspaceHostContext? = nil) {
        self.navigation = navigation
        self.search = search
        self.hostContext = hostContext
    }

    private var searchRouter: WorkspaceSearchRouter? {
        guard hostContext?.navigation === navigation, search?.navigationRouter?.navigation === navigation else { return nil }
        return search?.navigationRouter
    }

    private var activeInspectorFocus: WorkspaceInspectorFocus { searchRouter?.inspectorFocus ?? inspectorFocus }
    @State private var inspectorWidth = WorkspaceLayout.inspectorIdealWidth
    @State private var inspectorFocus = WorkspaceInspectorFocus()

    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var todos: [TodoItem]
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query private var checks: [RoutineCheck]

    var body: some View {
        NavigationSplitView {
            sidebarColumn
        } detail: {
            detailColumn
        }
        .inspector(isPresented: Binding(
            get: { navigation.isInspectorPresented && navigation.canInspectSelectedTask },
            set: { navigation.isInspectorPresented = $0 }
        )) {
            TaskDetailDrawer(taskID: $navigation.selectedTaskID)
                .environment(\.workspaceInspectorFocus, activeInspectorFocus)
                .inspectorColumnWidth(min: WorkspaceLayout.inspectorMinWidth,
                                      ideal: WorkspaceLayout.inspectorIdealWidth,
                                      max: WorkspaceLayout.inspectorMaxWidth)
                .background(WorkspaceInspectorFocusMarker(owner: activeInspectorFocus))
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: WorkspaceColumnWidthsKey.self,
                                               value: .init(inspector: geometry.size.width))
                    }
                }
        }
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
        .onAppear { if search != nil { navigation.searchPresentation = true } }
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
        .ignoresSafeArea(.all, edges: .top)
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
    }

    private var detailColumn: some View {
        GeometryReader { geometry in
            ZStack {
                if navigation.isSearching {
                    if let search { UnifiedSearchWorkspaceContent(controller: search) }
                    else { WorkspaceGlobalSearchView(navigation: navigation, query: navigation.searchQuery) }
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
            .padding(.top, WorkspaceHeaderGeometry(width: geometry.size.width).height)
            .overlayPreferenceValue(WorkspaceHeaderContentKey.self, alignment: .top) { content in
                WorkspaceHeaderBar(navigation: navigation, tags: tags, searchController: search,
                                   content: navigation.isSearching ? WorkspaceHeaderContent() : content)
                    .frame(height: WorkspaceHeaderGeometry(width: geometry.size.width).height)
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
            // nil responder 会被系统布局恢复到隐藏字段；将实际详情焦点交给始终可见的原搜索入口。
            navigation.focusSearch()
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
        if navigation.isSearchFocused {
            return .ignored
        }
        if navigation.isSearching {
            navigation.searchQuery = ""
            return .handled
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
        guard !navigation.isSearching, !navigation.selectedTaskIDs.isEmpty else { return false }
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
        } else if let tid = navigation.selectedTagID, let tag = tags.first(where: { $0.id == tid && $0.deletedAt == nil }) {
            WorkspaceFilteredListView(tag: tag)
        } else {
            switch navigation.selectedTab {
            case .privacy:
                PrivacyUnlockSettingsView(vault: hostContext?.vault)
                    .disabled(hostContext != nil)
            case .dataBackup:
                DataBackupView()
                    .disabled(hostContext != nil)
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
                    .disabled(hostContext != nil)
            case .tags:
                TagManagementPage()
            case .trash:
                TrashPage()
            case .settings:
                SettingsView(observesSystemStatus: hostContext == nil)
                    .disabled(hostContext != nil)
            case .shortcuts:
                ShortcutsSettingsView(store: hostContext?.shortcuts)
                    .disabled(hostContext != nil)
            }
        }
    }

}

private extension View {
    @ViewBuilder
    func workspaceToolbarTitleHidden() -> some View {
        self.navigationTitle("")
    }
}
