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
        VStack(spacing: 8) {
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
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: tab)

            Divider()
                .overlay(DaybookTheme.rule.opacity(0.35))
                .padding(.horizontal, -12)

            FooterBar()
        }
        .padding(12)
        .frame(width: DaybookTheme.popoverWidth, height: DaybookTheme.popoverHeight)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                DaybookTheme.paper.opacity(0.25)
            }
        }
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
            showsComposer: true
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
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(DayKey.displayName(todayKey, locale: locale))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DaybookTheme.ink)
                Text(headerSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.muted)
            }

            Spacer(minLength: 4)

            DaybookMicroPillTabBar(
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
            }
            .buttonStyle(DaybookQuietButtonStyle())
            .help(L10n.string("window.workspace", locale: locale))
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
        let parsed = NaturalLanguageParser.parse(raw)
        let item = TodoItem(
            title: parsed.cleanTitle,
            dayKey: todayKey,
            remindMinutes: parsed.remindMinutes,
            isImportant: parsed.isImportant,
            isUrgent: parsed.isUrgent,
            sourceBundleID: CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp)
        )
        if let tagName = parsed.tagName {
            let tagDescriptor = FetchDescriptor<TagItem>(predicate: #Predicate { $0.name == tagName && $0.deletedAt == nil })
            if let existingTag = try? modelContext.fetch(tagDescriptor).first {
                item.tagIDs = TagIDList.toggling(item.tagIDs, existingTag.id)
            } else {
                let newTag = TagItem(name: tagName, sortOrder: 0)
                modelContext.insert(newTag)
                item.tagIDs = TagIDList.toggling(item.tagIDs, newTag.id)
            }
        }
        modelContext.insert(item)
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

struct DaybookMicroPillTabBar: View {
    @Binding var selection: BoardTab
    var tasksCount: Int = 0
    var diariesCount: Int = 0
    @Namespace private var tabNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(BoardTab.allCases) { item in
                let isSelected = selection == item
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.76)) {
                        selection = item
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item == .tasks ? "checklist" : "note.text")
                            .font(.system(size: 9, weight: isSelected ? .bold : .medium))

                        Text(item.title)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))

                        let count = item == .tasks ? tasksCount : diariesCount
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.muted)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule()
                                        .fill(
                                            isSelected
                                                ? DaybookTheme.stamp.opacity(0.14)
                                                : DaybookTheme.ink.opacity(0.06)
                                        )
                                )
                        }
                    }
                    .foregroundStyle(isSelected ? DaybookTheme.ink : DaybookTheme.muted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(DaybookTheme.surface)
                                .shadow(color: Color.black.opacity(0.06), radius: 2, y: 1)
                                .matchedGeometryEffect(id: "activePillTab", in: tabNamespace)
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
            Capsule()
                .fill(DaybookTheme.hoverFill)
        )
    }
}

struct DaybookTabBar: View {
    @Binding var selection: BoardTab
    var tasksCount: Int = 0
    var diariesCount: Int = 0

    var body: some View {
        DaybookMicroPillTabBar(
            selection: $selection,
            tasksCount: tasksCount,
            diariesCount: diariesCount
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

            Button(action: { AppWindows.openSettings() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
            }
            .buttonStyle(DaybookQuietButtonStyle())
            .help("footer.settings")
            .accessibilityLabel("footer.settings")

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
