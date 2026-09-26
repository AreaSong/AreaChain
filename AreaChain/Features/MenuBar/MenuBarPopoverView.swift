import AppKit
import SwiftData
import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) var locale
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var dayClock: DayClock { DayClock.shared }
    @Query(sort: \DailyRoutine.sortOrder) var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) var todos: [TodoItem]
    @Query var checks: [RoutineCheck]
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) var diaries: [DiaryEntry]
    @Query(sort: \TagItem.sortOrder) var tags: [TagItem]
    @State var tab: BoardTab = .tasks
    @Bindable private var filterSession: BoardFilterSession
    @Bindable private var composer: BoardComposerSession
    @State var dayTick = Date()
    @State var captureFocused = false
    @State private var focusedTaskID: UUID? = nil
    @State private var showingSyntaxHelp = false
    @State private var helpContext: SyntaxInputContext = .capture
    @State var toolbar: MenuBarToolbarState
    @State var hostWindow: NSWindow?
    @State var tabKeyMonitor: Any? = nil
    @State var isFilterDrawerPresented = false
    @State var hoverOpenWorkItem: DispatchWorkItem? = nil
    @State var hoverCloseWorkItem: DispatchWorkItem? = nil
    @State var filterCategory: FilterCategory = .date
    init(
        toolbar: MenuBarToolbarState? = nil,
        composer: BoardComposerSession? = nil,
        filterSession: BoardFilterSession? = nil
    ) {
        _toolbar = State(initialValue: toolbar ?? MenuBarToolbarState())
        self.composer = composer ?? .shared
        self.filterSession = filterSession ?? .shared
    }

    private var filters: BoardFilters {
        get { filterSession.filters }
        nonmutating set { filterSession.filters = newValue }
    }

    var currentTabTagCounts: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        switch tab {
        case .tasks:
            let activeTodos = todos.filter { $0.deletedAt == nil && ($0.dayKey == todayKey || ($0.dayKey < todayKey && !$0.isDone)) }
            for todo in activeTodos {
                for id in TagIDList.parse(todo.tagIDs) {
                    counts[id, default: 0] += 1
                }
            }
            let dueRoutines = routines.filter { $0.deletedAt == nil && DayBoardLogic.isRoutineDue($0.snapshot, on: todayKey) }
            for routine in dueRoutines {
                for id in TagIDList.parse(routine.tagIDs) {
                    counts[id, default: 0] += 1
                }
            }
        case .diary:
            let todayDiaries = diaries.filter { $0.deletedAt == nil && $0.dayKey == todayKey }
            for diary in todayDiaries {
                for id in TagIDList.parse(diary.tagIDs) {
                    counts[id, default: 0] += 1
                }
            }
        }
        return counts
    }

    var body: some View {
        ZStack(alignment: .top) {
            mainContentStack

            if showingSyntaxHelp {
                syntaxHelpOverlay
            }

            if isFilterDrawerPresented {
                filterDrawerOverlay
            }
        }
        .syntaxOverlayHost(enabled: !showingSyntaxHelp)
        .background(KeyWindowHost { hostWindow = $0 })
        .animation(DaybookMotion.interactive(reduceMotion), value: showingSyntaxHelp)
        .onAppear {
            prepare()
        }
        .onDisappear {
            tearDownTabKeyMonitor()
        }
        .onChange(of: tab) { _, newTab in
            if newTab == .tasks && !toolbar.isSearching { captureFocused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusCapture)) { _ in
            focusCurrentInput()
        }
        .onChange(of: toolbar.isSearching) { _, searching in
            if searching {
                focusedTaskID = nil
            }
        }
        .onChange(of: toolbar.searchIsFocused) { _, focused in
            if focused {
                // 搜索请求优先于尚未完成的捕获框自动聚焦，避免两个输入框反复抢焦点。
                captureFocused = false
                focusedTaskID = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
    }

    private var mainContentStack: some View {
        VStack(spacing: 10) {
            integratedHeader

            Group {
                if toolbar.isSearching {
                    MenuBarSearchResults(
                        query: toolbar.searchText,
                        filter: filters.selection(for: tab),
                        onClearSearch: { toolbar.clearSearch() },
                        onClearFilter: clearCurrentFilter
                    )
                } else {
                    switch tab {
                    case .tasks: tasksView
                    case .diary: diaryView
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(DaybookMotion.interactive(reduceMotion), value: tab)

            DaybookDivider(opacity: 0.25)
                .padding(.horizontal, -12)

            FooterBar(
                tab: tab,
                toolbar: toolbar,
                filters: filtersBinding,
                tags: Array(tags),
                tagCounts: currentTabTagCounts,
                onShowSyntaxHelp: showSyntaxHelp,
                isFilterDrawerPresented: $isFilterDrawerPresented,
                onTriggerClick: toggleFilterDrawer,
                activeCategory: $filterCategory
            )
            .zIndex(10)
        }
        .padding(12)
        .frame(width: DaybookMetrics.Window.popoverWidth, height: DaybookMetrics.Window.popoverHeight)
        .background(DaybookPalette.fill.page)
        .clipShape(Rectangle())
        .daybookHideInputChrome()
    }

    @ViewBuilder
    private var syntaxHelpOverlay: some View {
        // 透明点击感知层：点击气泡外部任意处轻巧收起，保持底层清晰通透
        DaybookPalette.fill.scrim
            .frame(width: DaybookMetrics.Window.popoverWidth, height: DaybookMetrics.Window.popoverHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    showingSyntaxHelp = false
                }
            }
            .zIndex(20)

        SyntaxExpandableCard(
            isExpanded: $showingSyntaxHelp,
            context: helpContext,
            onSelectToken: { token in
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    showingSyntaxHelp = false
                }
                handleSyntaxTokenSelection(token)
            },
            onSelectExample: helpContext == .search ? nil : { snippet in
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    showingSyntaxHelp = false
                }
                setTaskText(snippet)
                captureFocused = true
            }
        )
        .padding(.top, 92)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity).combined(with: .offset(y: -6)),
            removal: .scale(scale: 0.98, anchor: .top).combined(with: .opacity)
        ))
    }

    private var tasksView: some View {
        VStack(alignment: .leading, spacing: 6) {
            CaptureField(
                text: taskText,
                focus: $captureFocused,
                onTodo: addTodo,
                onDiary: addDiary,
                allowsDiaryShortcut: !toolbar.searchIsFocused && !toolbar.isSearching && !toolbar.isFiltering
            )
            TasksPage(
                todayKey: todayKey,
                routines: routines,
                checks: checks,
                todos: todos,
                config: TasksPageConfig(
                    yesterdayKey: dayClock.yesterdayKey,
                    interaction: DayBoardInteraction(
                        focusedTaskID: $focusedTaskID,
                        onReturnToInput: {
                            focusedTaskID = nil
                            captureFocused = true
                        },
                        isKeyboardEnabled: { !toolbar.searchIsFocused && !toolbar.isSearching && !toolbar.isFiltering }
                    ),
                    externalFilter: taskFilter
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var diaryView: some View {
        DiaryPage(
            todayKey: todayKey,
            entries: diaries,
            options: DiaryPageOptions(
                showsComposer: true,
                showsPageHeader: false,
                externalFilter: diaryFilter,
                composerDraft: $composer.diary
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func showSyntaxHelp() {
        if tab != .tasks {
            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                tab = .tasks
            }
        }
        helpContext = toolbar.isSearching || toolbar.searchIsFocused ? .search : .capture
        toolbar.autocomplete.dismiss()
        captureFocused = true
        showingSyntaxHelp = true
    }

    private var taskText: Binding<String> {
        Binding(get: { composer.tasks.text }, set: { setTaskText($0) })
    }

    var filtersBinding: Binding<BoardFilters> {
        Binding(get: { filterSession.filters }, set: { filterSession.filters = $0 })
    }

    private var taskFilter: Binding<BoardFilter> {
        Binding(
            get: { filterSession.filters.tasks },
            set: { writeFilter($0, for: .tasks) }
        )
    }

    private var diaryFilter: Binding<BoardFilter> {
        Binding(
            get: { filterSession.filters.diary },
            set: { writeFilter($0, for: .diary) }
        )
    }

    private func setTaskText(_ text: String) {
        var draft = composer.tasks
        draft.text = text
        composer.tasks = draft
    }

    private func clearCurrentFilter() {
        var next = filterSession.filters
        next.clear(tab)
        filterSession.filters = next
    }

    private func writeFilter(_ filter: BoardFilter, for tab: BoardTab) {
        var next = filterSession.filters
        next.write(filter, for: tab)
        filterSession.filters = next
    }

    private func handleSyntaxTokenSelection(_ token: String) {
        showingSyntaxHelp = false
        if helpContext == .search {
            guard token == "#" || token == "!" || token == "@" else { return }
            let prefix = toolbar.searchText.isEmpty || toolbar.searchText.hasSuffix(" ") ? "" : " "
            toolbar.searchText += prefix + token
            toolbar.focusSearch()
            return
        }

        if token == "#" && tab == .diary {
            NotificationCenter.default.post(name: .diaryAppendToken, object: "#")
            return
        }

        if tab != .tasks {
            withAnimation(DaybookMotion.animation(reduceMotion)) {
                tab = .tasks
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let draft = composer.tasks.text
            let prefix = (draft.isEmpty || draft.hasSuffix(" ") || draft.hasSuffix("\n")) ? "" : " "
            if token == "⌘↩" {
                if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    addDiary()
                } else {
                    captureFocused = true
                }
            } else if token == "⇧↩" {
                setTaskText(draft + "\n")
                captureFocused = true
            } else {
                setTaskText(draft + prefix + token)
                captureFocused = true
            }
        }
    }

    private func prepare() {
        setupTabKeyMonitor()
        focusCurrentInput()
    }

    private func focusCurrentInput() {
        if toolbar.isSearching || toolbar.searchIsFocused {
            captureFocused = false
            toolbar.focusSearch()
        }
        else if tab == .tasks { captureFocused = true }
    }

    private func addTodo() {
        if showingSyntaxHelp { showingSyntaxHelp = false }
        guard DayBoardMutations.addCapturedTodo(text: composer.tasks.text, dayKey: todayKey, context: modelContext) else { return }
        setTaskText("")
    }

    private func addDiary() {
        if showingSyntaxHelp { showingSyntaxHelp = false }
        let text = composer.tasks.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let context = modelContext
        let dayKey = todayKey
        do {
            let requiresUnlock = try DiaryContent.requiresProtection(text: text, tagIDs: [], context: context)
            PrivacyAccess.perform(requiresUnlock: requiresUnlock) {
                guard composer.tasks.text.trimmingCharacters(in: .whitespacesAndNewlines) == text,
                      try DiaryContent.requiresProtection(text: text, tagIDs: [], context: context) == requiresUnlock else {
                    throw PrivacyError.staleOperation
                }
                guard DayBoardMutations.addDiary(text: text, dayKey: dayKey, context: context) else { return }
                setTaskText("")
                withAnimation(DaybookMotion.animation(reduceMotion)) { tab = .diary }
            }
        } catch {
            MutationFeedback.shared.reportFailure(error)
        }
    }
}
