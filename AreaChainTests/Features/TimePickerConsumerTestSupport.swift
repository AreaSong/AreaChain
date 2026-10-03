import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@MainActor @Observable
final class TimePickerConsumerFixture {
    let native: SettingsButtonTestSupport
    let todo: TodoItem
    let routine: DailyRoutine
    let repository: RecurringToggleRepository
    var actions: [TaskRowAction] = []
    var fail = false
    var refresh = 0
    private var oldRoutineProvider: ((ModelContext?) -> any RoutineRepositoryProtocol)?
    private let restoreNavigation: () -> Void

    init(minutes: Int?) throws {
        try #require(NotificationScheduler.isRunningTests)
        native = try SettingsButtonTestSupport()
        restoreNavigation = MenuButtonTestSupport.preserveListingNavigation()
        let context = native.container.mainContext
        todo = TodoItem(title: "Synthetic time task", dayKey: "2026-10-02", remindMinutes: minutes)
        routine = DailyRoutine(title: "Synthetic time routine", sortOrder: 0)
        routine.remindMinutes = minutes
        context.insert(todo)
        context.insert(routine)
        try context.save()
        repository = RecurringToggleRepository(context)
        oldRoutineProvider = DayBoardMutations.routineRepositoryProvider
        let repo = repository
        DayBoardMutations.routineRepositoryProvider = { _ in repo }
        try #require(DayBoardMutations.taskRepositoryProvider == nil)
    }

    func cleanup() {
        DayBoardMutations.routineRepositoryProvider = oldRoutineProvider
        restoreNavigation()
        native.cleanup()
    }

    func window(resident: Bool, locale: String = "en", dark: Bool = false) -> NSWindow {
        native.window(Group {
            if resident { ResidentsPage() }
            else { TimePickerTaskConsumer(fixture: self) }
        }, locale: locale, scheme: dark ? .dark : .light, size: NSSize(width: 440, height: 320))
    }

    func open(resident: Bool, locale: String = "en", in window: NSWindow) async throws -> NSDatePicker {
        try await NativeSyntaxUI.prepareFocus(in: window)
        if resident {
            try await SettingsButtonTestSupport.click(
                SettingsButtonTestSupport.button("row.time.set", locale: locale, in: window), in: window)
        } else {
            let node = try MenuButtonTestSupport.menu("row.more", locale: locale, in: window)
            let menu = try await MenuButtonTestSupport.openAndEscape(node, in: window)
            try MenuButtonTestSupport.dispatch(MenuButtonTestSupport.localized("row.time.set", locale), in: menu)
        }
        try await SystemPageHost.settle(window)
        return try #require(NSApp.windows.filter(\.isVisible).flatMap {
            SettingsButtonTestSupport.elements($0.contentView).compactMap { $0 as? NSDatePicker }
        }.first)
    }

    func close(_ picker: NSDatePicker) async throws {
        let popup = try #require(picker.window)
        try await NativeSyntaxUI.prepareFocus(in: popup)
        try await TimePickerNativeTestSupport.key(53, "\u{1B}", in: popup)
        try await SystemPageHost.settle(popup)
        #expect(!popup.isVisible, "Escape 应关闭原提醒弹出层")
    }

    func assign(_ value: Int, to picker: NSDatePicker) throws {
        picker.dateValue = try #require(RemindMinutes.date(minutes: value, calendar: picker.calendar ?? .current))
        picker.sendAction(picker.action, to: picker.target)
    }

    func clear(resident: Bool, locale: String = "en", in window: NSWindow) async throws {
        try await NativeSyntaxUI.prepareFocus(in: window)
        if resident {
            try await SettingsButtonTestSupport.click(
                SettingsButtonTestSupport.button("row.time.clear", locale: locale, in: window), in: window)
        } else {
            let menu = try await MenuButtonTestSupport.openAndEscape(
                MenuButtonTestSupport.menu("row.more", locale: locale, in: window), in: window)
            try MenuButtonTestSupport.dispatch(MenuButtonTestSupport.localized("row.time.clear", locale), in: menu)
        }
        try await SystemPageHost.settle(window)
    }

    var taskMinutesWrites: [Int?] {
        actions.compactMap { action -> Int?? in
            if case .setRemindMinutes(let value) = action { return .some(value) }
            return nil
        }
    }
}

private struct TimePickerTaskConsumer: View {
    let fixture: TimePickerConsumerFixture

    var body: some View {
        _ = fixture.refresh
        let original = TaskRowFactory.todo(TodoRowContext(todo: fixture.todo, todayKey: "2026-10-02",
            catalogs: TaskCatalogContext(tags: [], attachments: [], context: fixture.native.container.mainContext),
            display: TodoRowDisplayOptions(isDone: false, isSelected: true),
            actions: TodoRowActions(onSelect: { _ in }, onDelete: {})))
        return TaskRow(state: original.state, onSaveTitle: original.onSaveTitle) { action in
            fixture.actions.append(action)
            if fixture.fail {
                // 沿既有 ModelChanges 失败注入，真实 Factory → Mutations → 仓储仍完整执行。
                ModelChanges.perform(in: fixture.native.container.mainContext,
                    save: { _ in throw CocoaError(.fileWriteNoPermission) }) { original.dispatch(action) }
            } else { original.dispatch(action) }
        }.padding(12)
    }
}
