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
    private var dayClock: DayClock { DayClock.shared }
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]

    @State private var tab: BoardTab = .tasks
    @Bindable private var capture = CaptureSession.shared
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
                text: $capture.draft,
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
                        entries: diaries,
                        showsComposer: true
                    )
                }
            }
            FooterBar()
        }
        .padding(14)
        .frame(width: DaybookTheme.popoverSize.width, height: DaybookTheme.popoverSize.height)
        .background(DaybookTheme.paper.opacity(0.92))
        .overlay(RuledPaper().opacity(0.35))
        .clipShape(Rectangle())
        .daybookHideInputChrome()
        .onAppear(perform: prepare)
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

    private var todayCompleted: Int {
        DayBoardLogic.completedRoutines(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            dayKey: todayKey
        ).count
            + DayBoardLogic.completedTodos(todos: todos.map(\.snapshot), dayKey: todayKey).count
    }

    private var headerStatus: LocalizedStringKey {
        if todayRemaining == 0 {
            return "header.done"
        }
        if todayCompleted > 0 {
            return "header.progress \(todayRemaining) \(todayCompleted)"
        }
        return "header.remaining \(todayRemaining)"
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(DayKey.displayName(todayKey, locale: locale))
                    .font(.system(size: 20, weight: .regular, design: .serif).italic())
                    .foregroundStyle(DaybookTheme.ink)
                Text(headerStatus)
                    .font(.system(size: 12))
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
                        .stroke(DaybookTheme.stamp.opacity(0.85), lineWidth: 1.2)
                )
                .accessibilityElement()
                .accessibilityLabel("a11y.remaining \(todayRemaining)")
                .accessibilityAddTraits(.updatesFrequently)
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
        .accessibilityLabel("tab.picker")
    }

    private func prepare() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            HotKeyCenter.shared.start()
        }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            FirstLaunchSeeder.seedIfNeeded(context: modelContext, existingCount: routines.count)
        }
        captureFocused = true
    }

    private func addTodo() {
        let title = capture.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        modelContext.insert(
            TodoItem(
                title: title,
                dayKey: todayKey,
                sourceBundleID: CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp)
            )
        )
        capture.draft = ""
        BoardEvents.changed()
    }

    private func addDiary() {
        let text = capture.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        modelContext.insert(DiaryEntry(text: text, dayKey: todayKey))
        capture.draft = ""
        BoardEvents.changed()
    }
}

struct FooterBar: View {
    @Environment(\.locale) private var locale
    @State private var hotKeyName = HotKeyCenter.shared.displayName()

    var body: some View {
        HStack(spacing: 2) {
            footerButton("footer.settings", action: AppWindows.openSettings)
            footerButton("footer.calendar", action: AppWindows.openCalendar)
            Menu("footer.more") {
                Button("footer.search") { AppWindows.openSearch() }
                Button("footer.diary") { AppWindows.openDiary() }
                Button("footer.attachments") { AppWindows.openAttachments() }
                Button("footer.quadrant") { AppWindows.openQuadrant() }
                Button("footer.gantt") { AppWindows.openGantt() }
                Button("footer.trash") { AppWindows.openTrash() }
            }
            .font(.system(size: 11, weight: .medium))
            .buttonStyle(DaybookQuietButtonStyle())
            .help("footer.more")
            Spacer(minLength: 8)
            Text("footer.hotkey \(hotKeyName)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DaybookTheme.muted)
                .lineLimit(1)
                .layoutPriority(-1)
            Button("footer.quit", action: { NSApplication.shared.terminate(nil) })
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(DaybookQuietButtonStyle(destructive: true))
                .help("footer.quit")
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

    private func footerButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 11, weight: .medium))
            .buttonStyle(DaybookQuietButtonStyle())
            .help(title)
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
