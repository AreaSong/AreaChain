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
                return "header.done"
            }
            if todayCompleted > 0 {
                return "header.progress \(todayRemaining) \(todayCompleted)"
            }
            if todayRemaining > 0 {
                return "header.remaining \(todayRemaining)"
            }
            return "empty.todos"
        case .diary:
            let count = todayDiariesCount
            if count == 0 {
                return "header.diary.empty"
            }
            return "header.diary.count \(count)"
        }
    }

    var body: some View {
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

            FooterBar()
        }
        .padding(12)
        .frame(width: DaybookTheme.popoverWidth, height: DaybookTheme.popoverHeight)
        .background(DaybookTheme.paper)
        .clipShape(Rectangle())
        .daybookHideInputChrome()
        .onAppear {
            prepare()
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
                    )
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
            showsPageHeader: false
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

            syntaxHelpButton
                .padding(.top, 1)
        }
    }

    private var syntaxHelpButton: some View {
        Button {
            showingSyntaxHelp.toggle()
        } label: {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(showingSyntaxHelp ? DaybookTheme.stamp : DaybookTheme.muted)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(DaybookTheme.ink.opacity(showingSyntaxHelp ? 0.08 : 0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(DaybookTheme.rule.opacity(showingSyntaxHelp ? 0.6 : 0.35), lineWidth: 0.6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(DaybookQuietButtonStyle())
        .help("快捷语法指南")
        .accessibilityLabel("快捷语法指南")
        .popover(isPresented: $showingSyntaxHelp, arrowEdge: .bottom) {
            SyntaxCheatSheetPopover { token in
                handleSyntaxTokenSelection(token)
            }
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
        if tab == .tasks {
            captureFocused = true
        }
    }

    private func addTodo() {
        let raw = capture.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let parsed = NaturalLanguageParser.parseTaskCapture(raw)
        let item = TodoItem(
            title: parsed.cleanTitle,
            dayKey: todayKey,
            remindMinutes: parsed.remindMinutes,
            isImportant: parsed.isImportant,
            isUrgent: parsed.isUrgent,
            sourceBundleID: CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp),
            notes: parsed.notes
        )
        if let tagName = parsed.tagName,
           let tag = DayBoardMutations.resolveTaskTag(named: tagName, among: tags, context: modelContext)
        {
            item.tagIDs = TagIDList.toggling(item.tagIDs, tag.id)
        }
        modelContext.insert(item)
        capture.draft = ""
        BoardEvents.changed()
        DayBoardMutations.requestReminderAccessIfNeeded(parsed.remindMinutes)
    }

    private func addDiary() {
        let text = capture.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        DayBoardMutations.addDiary(
            text: text,
            dayKey: todayKey,
            tags: Array(tags),
            context: modelContext
        )
        capture.draft = ""
        withAnimation(DaybookMotion.animation(reduceMotion)) {
            tab = .diary
        }
    }
}

struct DaybookQuietTabBar: View {
    @Binding var selection: BoardTab
    var tasksCount: Int = 0
    var diariesCount: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(BoardTab.allCases) { item in
                tabButton(item)
            }
        }
        .padding(2.5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(DaybookTheme.ink.opacity(0.05))
        )
    }

    private func tabButton(_ item: BoardTab) -> some View {
        let isSelected = selection == item
        let count = item == .tasks ? tasksCount : diariesCount
        let ink = isSelected ? DaybookTheme.ink : DaybookTheme.muted
        return Button {
            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                selection = item
            }
        } label: {
            HStack(spacing: 3.5) {
                Text(item.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 0.5)
                        .background(
                            isSelected ? DaybookTheme.stamp.opacity(0.18) : DaybookTheme.ink.opacity(0.08)
                        )
                        .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.muted)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(DaybookTheme.paper)
                            .shadow(color: Color.black.opacity(0.07), radius: 1.5, x: 0, y: 0.5)
                    }
                }
            )
            .foregroundStyle(ink)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct FooterBar: View {
    @Environment(\.locale) private var locale
    @State private var hotKeyName = HotKeyCenter.shared.displayName()

    var body: some View {
        HStack(spacing: 8) {
            Text(hotKeyName)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(DaybookTheme.muted)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(DaybookTheme.ink.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(DaybookTheme.rule.opacity(0.4), lineWidth: 0.7)
                        )
                )
                .help("footer.hotkey \(hotKeyName)")

            Spacer(minLength: 8)

            Menu {
                Button {
                    AppWindows.openWorkspace(tab: .settings)
                } label: {
                    Label("window.settings", systemImage: "gearshape")
                }
                Divider()
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("footer.quit", systemImage: "power")
                }
            } label: {
                Image(systemName: "macwindow")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(DaybookTheme.ink.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(DaybookTheme.rule.opacity(0.35), lineWidth: 0.6)
                    )
                    .contentShape(Rectangle())
            } primaryAction: {
                AppWindows.openWorkspace(tab: .today)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(DaybookQuietButtonStyle())
            .help("window.workspace")
            .accessibilityLabel("window.workspace")
        }
        .onAppear { refreshHotKey() }
        .onChange(of: locale.identifier) { _, _ in refreshHotKey() }
        .onReceive(NotificationCenter.default.publisher(for: .hotKeyDidChange)) { _ in
            refreshHotKey()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appPreferencesDidChange)) { _ in
            refreshHotKey()
        }
    }

    private func refreshHotKey() {
        hotKeyName = HotKeyCenter.shared.displayName(locale: locale)
    }
}

struct MenuBarLabel: View {
    private var dayClock: DayClock { DayClock.shared }
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @State private var dayTick = Date()

    var body: some View {
        let todayKey: String = {
            _ = dayTick
            return dayClock.todayKey
        }()
        let count = DayBoardLogic.todayBadgeCount(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            dayKey: todayKey
        )
        return HStack(spacing: 2) {
            Image(systemName: "book.closed.fill")
                .accessibilityHidden(true)
            Text("menubar.today.mark")
                .font(.system(size: 11, weight: .bold, design: .serif))
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
        }
        .accessibilityLabel(count > 0 ? "a11y.app.remaining \(count)" : "a11y.app")
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
    }
}
