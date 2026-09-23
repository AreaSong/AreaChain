import AppKit
import SwiftData
import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    private var dayClock: DayClock { DayClock.shared }
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]
    @Query(sort: \TagItem.sortOrder) var tags: [TagItem]
    @Query(sort: \ProjectItem.sortOrder) var projects: [ProjectItem]

    @State var tab: BoardTab = .tasks
    @State var filters = BoardFilters()
    @Bindable private var composer: BoardComposerSession
    @State private var dayTick = Date()
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
    init(toolbar: MenuBarToolbarState? = nil, composer: BoardComposerSession? = nil) {
        _toolbar = State(initialValue: toolbar ?? MenuBarToolbarState())
        self.composer = composer ?? .shared
    }

    private var todayKey: String {
        _ = dayTick
        return dayClock.todayKey
    }

    private var todayDiariesCount: Int {
        DayBoardLogic.diaries(for: todayKey, in: diaries.map(\.snapshot)).count
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

    var taskProjectCounts: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        let activeTodos = todos.filter { $0.deletedAt == nil && !$0.isDone && $0.dayKey == todayKey }
        for todo in activeTodos {
            if let pid = todo.projectID {
                counts[pid, default: 0] += 1
            }
        }
        if !projects.isEmpty {
            for project in projects {
                let subtrees = ProjectTree.subtreeIDs(root: project.id, in: projects)
                if subtrees.count > 1 {
                    let sum = subtrees.reduce(0) { $0 + (counts[$1] ?? 0) }
                    if sum > 0 {
                        counts[project.id] = sum
                    }
                }
            }
        }
        return counts
    }

    var unclassifiedTodosCount: Int {
        todos.filter { $0.deletedAt == nil && !$0.isDone && $0.dayKey == todayKey && $0.projectID == nil }.count
    }

    private var headerSubtitle: LocalizedStringKey {
        if toolbar.isSearching { return "search.scope.all" }
        switch tab {
        case .tasks:
            if todayRemaining > 0 { return "header.today.remaining \(todayRemaining)" }
            return todayCompleted > 0 ? "header.today.done" : "header.today.empty"
        case .diary:
            let count = todayDiariesCount
            if count == 0 {
                return "header.diary.empty"
            }
            return "header.diary.count \(count)"
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
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
                    filters: $filters,
                    projects: projects.filter { $0.deletedAt == nil },
                    projectCounts: taskProjectCounts,
                    unclassifiedCount: unclassifiedTodosCount,
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

            if showingSyntaxHelp {
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
                .zIndex(21)
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

    private var todayRemaining: Int {
        DayBoardLogic.todayBadgeCount(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            dayKey: todayKey
        )
    }

    private var todayCompleted: Int {
        DayBoardLogic.completedRoutines(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            dayKey: todayKey
        ).count
            + DayBoardLogic.completedTodos(todos: todos.map(\.snapshot), dayKey: todayKey).count
    }

    private var integratedHeader: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                Text(DayKey.displayName(todayKey, locale: locale))
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookPalette.text.primary)
                HStack(spacing: 4) {
                    headerIndicator
                        .animation(DaybookMotion.interactive(reduceMotion), value: tab)
                        .animation(DaybookMotion.interactive(reduceMotion), value: todayRemaining)
                        .animation(DaybookMotion.interactive(reduceMotion), value: todayDiariesCount)

                    Text(headerSubtitle)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .contentTransition(.numericText())
                        .animation(DaybookMotion.interactive(reduceMotion), value: tab)
                        .animation(DaybookMotion.interactive(reduceMotion), value: todayRemaining)
                        .animation(DaybookMotion.interactive(reduceMotion), value: todayDiariesCount)
                }
            }

            Spacer(minLength: 8)

            DaybookSegmentedBar(
                selection: $tab,
                tasksCount: todayRemaining,
                diariesCount: todayDiariesCount
            )
            .padding(.top, 1)

        }
    }

    @ViewBuilder
    private var headerIndicator: some View {
        if toolbar.isSearching {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 7, weight: .bold)) // token-exempt: 头部状态图标小于 9pt
                .foregroundStyle(DaybookPalette.text.secondary)
                .transition(.scale.combined(with: .opacity))
        } else {
            switch tab {
            case .tasks:
                if todayRemaining > 0 {
                    Circle()
                        .fill(DaybookPalette.status.pending)
                        .frame(width: 5, height: 5)
                        .transition(.scale.combined(with: .opacity))
                } else if todayCompleted > 0 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold)) // token-exempt: 头部状态图标小于 9pt
                        .foregroundStyle(DaybookPalette.accent.base)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold)) // token-exempt: 头部状态图标小于 9pt
                        .foregroundStyle(DaybookPalette.text.tertiary)
                        .transition(.scale.combined(with: .opacity))
                }
            case .diary:
                if todayDiariesCount > 0 {
                    Circle()
                        .fill(DaybookPalette.accent.base)
                        .frame(width: 5, height: 5)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "feather")
                        .font(.system(size: 8, weight: .semibold)) // token-exempt: 头部状态图标小于 9pt
                        .foregroundStyle(DaybookPalette.text.tertiary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
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

    private var taskFilter: Binding<BoardFilter> {
        Binding(
            get: { filters.tasks },
            set: { filters.write($0, for: .tasks) }
        )
    }

    private var diaryFilter: Binding<BoardFilter> {
        Binding(
            get: { filters.diary },
            set: { filters.write($0, for: .diary) }
        )
    }

    private func setTaskText(_ text: String) {
        var draft = composer.tasks
        draft.text = text
        composer.tasks = draft
    }

    private func clearCurrentFilter() {
        filters.clear(tab)
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
