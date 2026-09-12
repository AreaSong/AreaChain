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
    @State private var isHoveringSyntaxButton = false
    @State private var hoverDismissWorkItem: DispatchWorkItem? = nil
    @State private var tabKeyMonitor: Any? = nil
    @State private var boardFilter = BoardFilter()
    @State private var diaryFilterTagID: UUID? = nil

    private var todayKey: String {
        _ = dayTick
        return dayClock.todayKey
    }

    private var todayDiariesCount: Int {
        DayBoardLogic.diaries(for: todayKey, in: diaries.map(\.snapshot)).count
    }

    private var headerSubtitle: LocalizedStringKey {
        switch tab {
        case .tasks:
            if todayRemaining == 0 && todayCompleted > 0 {
                return " "
            }
            if todayCompleted > 0 {
                return "header.progress \(todayRemaining) \(todayCompleted)"
            }
            if todayRemaining > 0 {
                return "header.remaining \(todayRemaining)"
            }
            return " "
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
                    switch tab {
                    case .tasks:
                        tasksView
                    case .diary:
                        diaryView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(DaybookMotion.interactive(reduceMotion), value: tab)

                Divider()
                    .overlay(DaybookTheme.rule.opacity(0.25))
                    .padding(.horizontal, -12)

                FooterBar(
                    tab: tab,
                    filter: $boardFilter,
                    diaryFilterTagID: $diaryFilterTagID,
                    tags: Array(tags),
                    diaryCount: todayDiariesCount,
                    completedCount: todayCompleted,
                    totalCount: todayRemaining + todayCompleted
                )
            }
            .padding(12)
            .frame(width: DaybookTheme.popoverWidth, height: DaybookTheme.popoverHeight)
            .background(DaybookTheme.paper)
            .clipShape(Rectangle())
            .daybookHideInputChrome()

            if isHoveringSyntaxButton || showingSyntaxHelp {
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
                .onHover { hovering in
                    handleSyntaxButtonHover(hovering)
                }
                .zIndex(21)
            }
        }
        .animation(DaybookMotion.interactive(reduceMotion), value: showingSyntaxHelp)
        .onAppear {
            prepare()
        }
        .onDisappear {
            tearDownTabKeyMonitor()
        }
        .onChange(of: tab) { _, newTab in
            if newTab == .tasks {
                captureFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusCapture)) { _ in
            if tab == .tasks {
                captureFocused = true
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
                onDiary: addDiary
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
                        }
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
            showsComposer: true,
            showsPageHeader: false,
            externalSelectedTagID: $diaryFilterTagID
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

            Button {
                hoverDismissWorkItem?.cancel()
                isHoveringSyntaxButton = true
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    showingSyntaxHelp.toggle()
                }
            } label: {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle((showingSyntaxHelp || isHoveringSyntaxButton) ? DaybookTheme.stamp : DaybookTheme.muted)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(DaybookTheme.ink.opacity((showingSyntaxHelp || isHoveringSyntaxButton) ? 0.10 : 0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(DaybookTheme.rule.opacity((showingSyntaxHelp || isHoveringSyntaxButton) ? 0.7 : 0.35), lineWidth: 0.6)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(DaybookQuietButtonStyle())
            .help("快捷语法指南")
            .accessibilityLabel("快捷语法指南")
            .onHover { hovering in
                handleSyntaxButtonHover(hovering)
            }
            .padding(.top, 1)
        }
    }

    private func handleSyntaxButtonHover(_ hovering: Bool) {
        if hovering {
            hoverDismissWorkItem?.cancel()
            hoverDismissWorkItem = nil
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isHoveringSyntaxButton = true
            }
        } else {
            if showingSyntaxHelp { return }
            let task = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.15)) {
                    isHoveringSyntaxButton = false
                }
            }
            hoverDismissWorkItem = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: task)
        }
    }

    private func handleSyntaxTokenSelection(_ token: String) {
        showingSyntaxHelp = false

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
        if tab == .tasks {
            captureFocused = true
        }
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
        // macOS 方向键会自动附加 .numericPad 与 .function 标记，仅提取核心修饰键进行 Command 判定
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard modifiers == .command else { return event }

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
