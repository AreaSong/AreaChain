import AppKit
import SwiftData
import SwiftUI

enum BoardTab: String, CaseIterable, Identifiable {
    case tasks
    case diary
    case routines

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .tasks: "tab.tasks"
        case .diary: "tab.diary"
        case .routines: "tab.routines"
        }
    }
}

struct MenuBarPopoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    private var dayClock: DayClock { DayClock.shared }
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]

    @State private var tab: BoardTab = .tasks
    @State private var draft = ""
    @State private var captureDayKey = DayClock.shared.todayKey
    @State private var dayTick = Date()
    @FocusState private var captureFocused: Bool

    private var todayKey: String {
        _ = dayTick
        return dayClock.todayKey
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            CaptureField(
                text: $draft,
                dayKey: $captureDayKey,
                todayKey: todayKey,
                focus: $captureFocused,
                onTodo: addTodo,
                onDiary: addDiary
            )
            tabPicker
            Group {
                switch tab {
                case .tasks:
                    TasksPage(
                        todayKey: todayKey,
                        yesterdayKey: dayClock.yesterdayKey,
                        routines: routines,
                        checks: checks,
                        todos: todos
                    )
                case .diary:
                    DiaryPage(
                        todayKey: todayKey,
                        entries: diaries
                    )
                case .routines:
                    RoutinesPage(routines: routines)
                }
            }
            FooterBar()
        }
        .padding(14)
        .frame(width: DaybookTheme.popoverSize.width, height: DaybookTheme.popoverSize.height)
        .background(DaybookTheme.paper.opacity(0.92))
        .overlay(RuledPaper().opacity(0.35))
        .onAppear(perform: prepare)
        .onChange(of: todayKey) { _, key in
            if captureDayKey.isEmpty || captureDayKey < key {
                captureDayKey = key
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusCapture)) { _ in
            captureFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
    }

    private var todayRemaining: Int {
        DayBoardLogic.todayBadgeCount(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            dayKey: todayKey
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(DayKey.displayName(todayKey, locale: locale))
                    .font(.system(size: 20, weight: .regular, design: .serif).italic())
                    .foregroundStyle(DaybookTheme.ink)
                Text(todayRemaining == 0 ? "header.done" : "header.remaining \(todayRemaining)")
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.muted)
            }
            Spacer()
            Text("\(todayRemaining)")
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundStyle(DaybookTheme.stamp)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(DaybookTheme.stamp.opacity(0.7), lineWidth: 1.2)
                )
                .accessibilityLabel("a11y.remaining \(todayRemaining)")
        }
    }

    private var tabPicker: some View {
        Picker("tab.picker", selection: $tab) {
            ForEach(BoardTab.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private func prepare() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            HotKeyCenter.shared.start()
        }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            FirstLaunchSeeder.seedIfNeeded(context: modelContext, existingCount: routines.count)
        }
        captureFocused = true
        if captureDayKey.isEmpty {
            captureDayKey = todayKey
        }
    }

    private func addTodo() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let day = captureDayKey.isEmpty ? todayKey : captureDayKey
        modelContext.insert(TodoItem(title: title, dayKey: day))
        draft = ""
        captureDayKey = todayKey
        BoardEvents.changed()
    }

    private func addDiary() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        modelContext.insert(DiaryEntry(text: text, dayKey: todayKey))
        draft = ""
        tab = .diary
        BoardEvents.changed()
    }
}

struct FooterBar: View {
    @Environment(\.locale) private var locale
    @State private var hotKeyName = HotKeyCenter.shared.displayName()

    var body: some View {
        HStack {
            Button("footer.settings") {
                AppWindows.openSettings()
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(DaybookTheme.muted)
            Button("footer.diary") {
                AppWindows.openDiary()
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(DaybookTheme.muted)
            Spacer()
            Text("footer.hotkey \(hotKeyName)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DaybookTheme.muted)
            Button("footer.quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(DaybookTheme.muted)
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
            Text("今")
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
