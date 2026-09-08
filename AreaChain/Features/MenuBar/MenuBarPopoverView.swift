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

    @State private var tab: BoardTab = .tasks
    @Bindable private var capture = CaptureSession.shared
    @State private var dayTick = Date()
    @FocusState private var captureFocused: Bool

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
            if todayRemaining == 0 {
                return "header.done"
            }
            if todayCompleted > 0 {
                return "header.progress \(todayRemaining) \(todayCompleted)"
            }
            return "header.remaining \(todayRemaining)"
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
            header
            DaybookTabBar(
                selection: $tab,
                tasksCount: todayRemaining,
                diariesCount: todayDiariesCount
            )
            Group {
                switch tab {
                case .tasks:
                    VStack(alignment: .leading, spacing: 8) {
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
                            todos: todos
                        )
                    }
                case .diary:
                    DiaryPage(
                        todayKey: todayKey,
                        entries: diaries,
                        showsComposer: true
                    )
                }
            }
            .animation(DaybookMotion.animation(reduceMotion), value: tab)
            .frame(maxHeight: .infinity, alignment: .top)

            Divider()
                .overlay(DaybookTheme.rule.opacity(0.35))
                .padding(.horizontal, -14)

            FooterBar()
        }
        .padding(14)
        .frame(width: DaybookTheme.popoverSize.width, height: DaybookTheme.popoverSize.height)
        .background(DaybookTheme.paper.opacity(0.96))
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

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(DayKey.displayName(todayKey, locale: locale))
                    .font(.system(size: 19, weight: .regular, design: .serif).italic())
                    .foregroundStyle(DaybookTheme.ink)
                Text(headerSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
            }
            Spacer()
            Button {
                AppWindows.openWorkspace(tab: tab == .tasks ? .today : .diary)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(DaybookTheme.hoverFill)
                    )
            }
            .buttonStyle(.plain)
            .help("window.workspace")
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
        withAnimation(DaybookMotion.animation(reduceMotion)) {
            tab = .diary
        }
        BoardEvents.changed()
    }
}

struct DaybookTabBar: View {
    @Binding var selection: BoardTab
    var tasksCount: Int = 0
    var diariesCount: Int = 0
    @Namespace private var tabNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BoardTab.allCases) { item in
                let isSelected = selection == item
                Button {
                    withAnimation(DaybookMotion.animation(reduceMotion)) {
                        selection = item
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))

                        let count = item == .tasks ? tasksCount : diariesCount
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.muted)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? DaybookTheme.stamp.opacity(0.15) : DaybookTheme.ink.opacity(0.06))
                                )
                        }
                    }
                    .foregroundStyle(isSelected ? DaybookTheme.ink : DaybookTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(DaybookTheme.paper)
                                .shadow(
                                    color: Color.black.opacity(0.08),
                                    radius: 2,
                                    x: 0,
                                    y: 1
                                )
                                .matchedGeometryEffect(id: "activeTabBackground", in: tabNamespace)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DaybookTheme.ink.opacity(0.06))
        )
    }
}

struct FooterBar: View {
    @Environment(\.locale) private var locale
    @State private var hotKeyName = HotKeyCenter.shared.displayName()

    var body: some View {
        HStack(spacing: 6) {
            Button(action: { AppWindows.openWorkspace() }) {
                HStack(spacing: 4) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 11))
                    Text("footer.workspace")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(DaybookQuietButtonStyle(prominent: true))
            .help("footer.workspace")

            Spacer(minLength: 8)

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
