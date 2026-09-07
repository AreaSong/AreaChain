import AppKit
import SwiftData
import SwiftUI

enum BoardTab: String, CaseIterable, Identifiable {
    case tasks = "任务"
    case diary = "日记"

    var id: String { rawValue }
}

struct MenuBarPopoverView: View {
    @Environment(\.modelContext) private var modelContext
    private var dayClock: DayClock { DayClock.shared }
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]

    @State private var tab: BoardTab = .tasks
    @State private var draft = ""
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
                        yesterdayKey: dayClock.yesterdayKey,
                        entries: diaries
                    )
                }
            }
            FooterBar()
        }
        .padding(14)
        .frame(width: DaybookTheme.popoverSize.width, height: DaybookTheme.popoverSize.height)
        .background(DaybookTheme.paper.opacity(0.92))
        .overlay(RuledPaper().opacity(0.35))
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

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(DayKey.displayName(todayKey))
                    .font(.system(size: 20, weight: .regular, design: .serif).italic())
                    .foregroundStyle(DaybookTheme.ink)
                Text(todayRemaining == 0 ? "今天的都勾完了" : "今天还剩 \(todayRemaining) 条")
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
                .accessibilityLabel("今天未完成 \(todayRemaining) 条")
        }
    }

    private var tabPicker: some View {
        Picker("页面", selection: $tab) {
            ForEach(BoardTab.allCases) { item in
                Text(item.rawValue).tag(item)
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
    }

    private func addTodo() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        modelContext.insert(TodoItem(title: title, dayKey: todayKey))
        draft = ""
    }

    private func addDiary() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        modelContext.insert(DiaryEntry(text: text, dayKey: todayKey))
        draft = ""
        tab = .diary
    }
}

struct FooterBar: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack {
            SettingsLink {
                Text("设置")
            }
            .font(.system(size: 11))
            Button("日记窗") {
                openWindow(id: "diary")
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(DaybookTheme.muted)
            Spacer()
            Text("⌘⇧A")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DaybookTheme.muted)
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(DaybookTheme.muted)
        }
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
        .accessibilityLabel(count > 0 ? "AreaChain，今天还剩 \(count) 条" : "AreaChain")
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
    }
}

struct WindowOpener: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onReceive(NotificationCenter.default.publisher(for: .openBoardWindow)) { _ in
                openWindow(id: "board")
            }
    }
}
