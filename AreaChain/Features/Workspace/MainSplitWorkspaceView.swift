import SwiftData
import SwiftUI
import AppKit

/// 三栏工作台：侧栏、详情页与检查器抽屉。
struct MainSplitWorkspaceView: View {
    @Bindable private var navigation = WorkspaceNavigation.shared

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
        .inspector(isPresented: $navigation.isInspectorPresented) {
            TaskDetailDrawer(taskID: $navigation.selectedTaskID)
                .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
        }
        .workspaceToolbarTitleHidden()
        .syntaxOverlayHost()
        .environment(\.workspaceEmbedded, true)
        .ignoresSafeArea(.container, edges: .top)
    }

    private var sidebarColumn: some View {
        WorkspaceSidebarView(
            navigation: navigation,
            tags: tags,
            todos: todos
        )
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
    }

    private var detailColumn: some View {
        ZStack {
            if navigation.isSearching {
                WorkspaceGlobalSearchView(
                    navigation: navigation,
                    query: navigation.searchQuery
                )
                .transition(.opacity)
            } else {
                detailView
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .workspaceToolbar(
            navigation: navigation,
            tags: tags
        )
        .overlay(alignment: .bottom) {
            if !navigation.selectedTaskIDs.isEmpty {
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

    private func handleEscapeKey() -> KeyPress.Result {
        if navigation.isSearching || navigation.isSearchFocused {
            navigation.clearSearch()
            NSApp.keyWindow?.makeFirstResponder(nil)
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
            BoardSelection.shared.markEscapeCancelsEdits()
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

    // MARK: - Detail Router

    @ViewBuilder
    private var detailView: some View {
        if let tid = navigation.selectedTagID, let tag = tags.first(where: { $0.id == tid && $0.deletedAt == nil }) {
            WorkspaceFilteredListView(tag: tag)
        } else {
            switch navigation.selectedTab {
            case .dashboard, .pending, .allItems, .privacy, .dataBackup:
                WorkspaceSectionPlaceholderView(tab: navigation.selectedTab)
            case .today:
                WorkspaceTodayView()
            case .calendar:
                CalendarStandaloneView()
            case .quadrant:
                QuadrantStandaloneView()
            case .gantt:
                GanttStandaloneView()
            case .diary:
                DiaryStandaloneView()
            case .attachments:
                AttachmentBrowserPage()
            case .tags:
                TagManagementPage()
            case .search:
                SearchPage()
            case .trash:
                TrashPage()
            case .settings:
                SettingsView(resignsChromeOnDisappear: false)
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
