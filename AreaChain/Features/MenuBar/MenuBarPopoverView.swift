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

    @State private var tab: BoardTab = .tasks
    @Bindable private var capture = CaptureSession.shared
    @State private var dayTick = Date()
    @FocusState private var captureFocused: Bool
    @State private var focusedTaskID: UUID? = nil

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
                .overlay(DaybookTheme.rule.opacity(0.45))
                .padding(.horizontal, -12)

            FooterBar()
        }
        .padding(12)
        .frame(width: DaybookTheme.popoverWidth, height: DaybookTheme.popoverHeight)
        .background(DaybookTheme.paper)
        .clipShape(Rectangle())
        .daybookHideInputChrome()
        .onAppear(perform: prepare)
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
                yesterdayKey: dayClock.yesterdayKey,
                routines: routines,
                checks: checks,
                todos: todos,
                focusedTaskID: $focusedTaskID,
                onReturnToInput: {
                    focusedTaskID = nil
                    captureFocused = true
                }
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
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(DayKey.displayName(todayKey, locale: locale))
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookTheme.ink)
                Text(headerSubtitle)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookTheme.muted)
            }

            Spacer(minLength: 8)

            HStack(alignment: .center, spacing: 4) {
                DaybookQuietTabBar(
                    selection: $tab,
                    tasksCount: todayRemaining,
                    diariesCount: todayDiariesCount
                )

                Button {
                    AppWindows.openWorkspace(tab: tab == .tasks ? .today : .diary)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DaybookTheme.muted)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(DaybookQuietButtonStyle())
                .help(L10n.string("window.workspace", locale: locale))
            }
            .padding(.top, 2)
        }
    }

    private func prepare() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            HotKeyCenter.shared.start()
        }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            FirstLaunchSeeder.seedIfNeeded(context: modelContext, existingCount: routines.count)
        }
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
        HStack(spacing: 10) {
            ForEach(BoardTab.allCases) { item in
                tabButton(item)
            }
        }
    }

    private func tabButton(_ item: BoardTab) -> some View {
        let isSelected = selection == item
        let count = item == .tasks ? tasksCount : diariesCount
        let ink = isSelected ? DaybookTheme.stamp : DaybookTheme.muted
        let underline = isSelected ? DaybookTheme.stamp : Color.clear
        return Button {
            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                selection = item
            }
        } label: {
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(DaybookType.caption.weight(isSelected ? .semibold : .medium))
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                }
                .foregroundStyle(ink)

                Rectangle()
                    .fill(underline)
                    .frame(height: 1.2)
            }
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
        HStack(spacing: 6) {
            Text(hotKeyName)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(DaybookTheme.muted)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(DaybookTheme.ink.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(DaybookTheme.rule.opacity(0.5), lineWidth: 0.8)
                        )
                )
                .help("footer.hotkey \(hotKeyName)")

            Spacer(minLength: 8)

            Menu {
                Button("window.settings") {
                    AppWindows.openWorkspace(tab: .settings)
                }
                Divider()
                Button("footer.quit", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .help("footer.more")
            .accessibilityLabel("footer.more")
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
