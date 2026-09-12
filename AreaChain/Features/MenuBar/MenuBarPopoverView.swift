import AppKit
import SwiftData
import SwiftUI

enum BoardTab: String, CaseIterable, Identifiable {
    case tasks
    case diary

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .tasks: "tab.tasks"
        case .diary: "tab.diary"
        }
    }
}

struct MenuBarPopoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var dayClock: DayClock { DayClock.shared }
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query(sort: \ProjectItem.sortOrder) private var projects: [ProjectItem]

    @State private var tab: BoardTab = .tasks
    @Bindable private var capture = CaptureSession.shared
    @State private var dayTick = Date()
    @FocusState private var captureFocused: Bool
    @State private var focusedTaskID: UUID? = nil
    @State private var showingSyntaxHelp = false
    @State private var helpContext: SyntaxInputContext = .capture
    @State private var toolbar: MenuBarToolbarState
    @State private var hostWindow: NSWindow?
    @State private var tabKeyMonitor: Any? = nil
    @State private var boardFilter = BoardFilter()
    @State private var diaryFilterTagID: UUID? = nil
    @State private var diaryComposerDraft = DiaryComposerDraft()

    init(toolbar: MenuBarToolbarState? = nil) {
        _toolbar = State(initialValue: toolbar ?? MenuBarToolbarState())
    }

    private var todayKey: String {
        _ = dayTick
        return dayClock.todayKey
    }

    private var todayDiariesCount: Int {
        DayBoardLogic.diaries(for: todayKey, in: diaries.map(\.snapshot)).count
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
                return " "
            }
            return "header.diary.count \(count)"
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 10) {
                integratedHeader

                Group {
                    if toolbar.isSearching {
                        MenuBarSearchResults(
                            query: toolbar.searchText,
                            filter: tab == .tasks ? boardFilter : BoardFilter(tagID: diaryFilterTagID),
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

                Divider()
                    .overlay(DaybookTheme.rule.opacity(0.25))
                    .padding(.horizontal, -12)

                FooterBar(
                    tab: tab,
                    toolbar: toolbar,
                    filter: $boardFilter,
                    diaryFilterTagID: $diaryFilterTagID,
                    tags: Array(tags),
                    onShowSyntaxHelp: showSyntaxHelp
                )
                .zIndex(10)
            }
            .padding(12)
            .frame(width: DaybookTheme.popoverWidth, height: DaybookTheme.popoverHeight)
            .background(DaybookTheme.paper)
            .clipShape(Rectangle())
            .daybookHideInputChrome()

            if showingSyntaxHelp {
                if showingSyntaxHelp {
                    Color.black.opacity(0.30)
                        .frame(width: DaybookTheme.popoverWidth, height: DaybookTheme.popoverHeight)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                showingSyntaxHelp = false
                            }
                        }
                        .transition(.opacity)
                        .zIndex(20)
                }

                SyntaxExpandableCard(
                    isExpanded: $showingSyntaxHelp,
                    context: helpContext,
                    onSelectToken: { token in
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            showingSyntaxHelp = false
                        }
                        handleSyntaxTokenSelection(token)
                    }
                )
                .padding(.top, 40)
                .padding(.trailing, 12)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.88, anchor: .topTrailing).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(21)
            }
        }
        .overlayPreferenceValue(MenuBarSearchAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor, toolbar.searchIsFocused, toolbar.autocomplete.isActive,
                   !toolbar.isFiltering, !showingSyntaxHelp {
                    let bounds = proxy[anchor]
                    // 候选挂在浮层根部，避免底栏的窄命中区域挡住上方候选的鼠标事件。
                    MenuBarSearchSuggestions(toolbar: toolbar)
                        .frame(width: 240)
                        .frame(width: 240, height: max(0, bounds.minY - 6), alignment: .bottomLeading)
                        .offset(x: max(12, min(bounds.minX, proxy.size.width - 252)))
                }
            }
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
    }

    private var tasksView: some View {
        VStack(alignment: .leading, spacing: 6) {
            CaptureField(
                text: $capture.draft,
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
                    externalFilter: $boardFilter
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
                externalSelectedTagID: $diaryFilterTagID,
                composerDraft: $diaryComposerDraft
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
                    .foregroundStyle(DaybookTheme.ink)
                HStack(spacing: 4) {
                    Circle()
                        .fill(todayRemaining > 0 ? Color.orange : DaybookTheme.stamp)
                        .frame(width: 5, height: 5)
                    Text(headerSubtitle)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookTheme.muted)
                }
            }

            Spacer(minLength: 8)

            DaybookQuietTabBar(
                selection: $tab,
                tasksCount: todayRemaining,
                diariesCount: todayDiariesCount
            )
            .padding(.top, 1)

        }
    }

    private func showSyntaxHelp() {
        helpContext = toolbar.isSearching || toolbar.searchIsFocused ? .search : .capture
        toolbar.autocomplete.dismiss()
        showingSyntaxHelp = true
    }

    private func clearCurrentFilter() {
        if tab == .tasks { boardFilter = BoardFilter() }
        else { diaryFilterTagID = nil }
    }

    private func handleSyntaxTokenSelection(_ token: String) {
        showingSyntaxHelp = false
        if helpContext == .search {
            guard token == "#" || token == "!" else { return }
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
            let draft = capture.draft
            let prefix = (draft.isEmpty || draft.hasSuffix(" ") || draft.hasSuffix("\n")) ? "" : " "
            if token == "⌘↩" {
                if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    addDiary()
                } else {
                    captureFocused = true
                }
            } else if token == "⇧↩" {
                capture.draft = draft + "\n"
                captureFocused = true
            } else {
                capture.draft = draft + prefix + token
                captureFocused = true
            }
        }
    }

    private func prepare() {
        setupTabKeyMonitor()
        focusCurrentInput()
    }

    private func focusCurrentInput() {
        if toolbar.isSearching { toolbar.focusSearch() }
        else if tab == .tasks { captureFocused = true }
    }

    private func setupTabKeyMonitor() {
        guard tabKeyMonitor == nil else { return }
        tabKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            handleTabKeyDown(event)
        }
    }

    private func tearDownTabKeyMonitor() {
        if let monitor = tabKeyMonitor {
            NSEvent.removeMonitor(monitor)
            tabKeyMonitor = nil
        }
    }

    private func handleTabKeyDown(_ event: NSEvent) -> NSEvent? {
        guard event.window === hostWindow || (event.window == nil && NSApp.keyWindow === hostWindow) else { return event }
        // macOS 方向键会自动附加 .numericPad 与 .function 标记，仅提取核心修饰键进行 Command 判定
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard modifiers == .command else { return event }
        if event.charactersIgnoringModifiers?.lowercased() == "f" {
            toolbar.focusSearch()
            return nil
        }
        guard !toolbar.searchIsFocused else { return event }

        // keyCode 123: Left Arrow (← 任务), 124: Right Arrow (→ 日记)
        if event.keyCode == 123 {
            if tab != .tasks {
                withAnimation(DaybookMotion.animation(reduceMotion)) {
                    tab = .tasks
                }
            } else {
                captureFocused = true
            }
            return nil
        } else if event.keyCode == 124 {
            if tab != .diary {
                withAnimation(DaybookMotion.animation(reduceMotion)) {
                    tab = .diary
                }
            }
            return nil
        }

        return event
    }

    private func addTodo() {
        guard DayBoardMutations.addCapturedTodo(text: capture.draft, dayKey: todayKey, context: modelContext) else { return }
        capture.draft = ""
    }

    private func addDiary() {
        let text = capture.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard DayBoardMutations.addDiary(
            text: text,
            dayKey: todayKey,
            tags: Array(tags),
            context: modelContext
        ) else { return }
        capture.draft = ""
        withAnimation(DaybookMotion.animation(reduceMotion)) {
            tab = .diary
        }
    }
}
