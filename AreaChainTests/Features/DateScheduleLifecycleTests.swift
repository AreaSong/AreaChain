import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DateScheduleLifecycleTests {
    typealias Native = SettingsButtonTestSupport
    typealias DateUI = DatePickerTestSupport

    @Test(arguments: ["en", "zh-Hans"])
    func detailCancelReopenAndOriginalSave(locale: String) async throws {
        let f = try TimePickerConsumerFixture(minutes: 720)
        defer { f.cleanup() }
        let window = f.native.window(TodoScheduleSectionView(todo: f.todo), locale: locale)
        defer { SystemPageHost.release(window) }
        let originalTitle = f.todo.title
        for cancel in [true, false] {
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await SystemPageHost.settle(window)
            try await Native.click(Native.button("day.pick", locale: locale, in: window), in: window)
            let popup = try DateUI.popup(excluding: window)
            try await NativeSyntaxUI.prepareFocus(in: popup)
            #expect(try DateUI.selected("2026-10-02", in: popup))
            #expect(MenuButtonTestSupport.labels(in: popup).contains(locale == "en" ? "October 2026" : "2026年10月"))
            try await DateUI.select("2026-10-18", in: popup)
            #expect(f.todo.dayKey == "2026-10-02")
            try await DatePickerTestSupport.key(36, "\r", in: popup)
            #expect(f.todo.dayKey == "2026-10-02")
            if cancel {
                try await DatePickerTestSupport.key(53, "\u{1B}", in: popup)
                #expect(f.todo.dayKey == "2026-10-02")
            } else {
                try await Native.click(Native.button("day.confirm", locale: locale, in: popup), in: popup)
                #expect(f.todo.dayKey == "2026-10-18")
                let context = ModelContext(f.native.container)
                #expect(try context.fetch(FetchDescriptor<TodoItem>()).first?.dayKey == "2026-10-18")
            }
            try await SystemPageHost.settle(window)
            #expect(!popup.isVisible)
        }
        #expect(f.todo.title == originalTitle && f.todo.remindMinutes == 720 && f.todo.dueMinutes == nil)
        #expect(f.todo.tagIDs.isEmpty && !f.todo.isDone)
    }

    @Test func externalClickClosesWithoutSavingAndReopensOriginal() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        var commits: [String] = []
        let window = fixture.window(TaskDetailDateChips(dayKey: "2026-10-01") { commits.append($0) })
        defer { SystemPageHost.release(window) }
        for _ in 0..<2 {
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await SystemPageHost.settle(window)
            try await Native.click(Native.button("day.pick", in: window), in: window)
            let popup = try DateUI.popup(excluding: window)
            try await NativeSyntaxUI.prepareFocus(in: popup)
            #expect(try DateUI.selected("2026-10-01", in: popup))
            try await DateUI.select("2026-10-18", in: popup)
            // 给原宿主空白区域派发鼠标事件，由系统弹出层处理外部关闭。
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                NSApp.postEvent(try MenuButtonTestSupport.mouse(type, at: NSPoint(x: 10, y: 10), in: window), atStart: false)
            }
            try await SystemPageHost.settle(window)
            #expect(!popup.isVisible && commits.isEmpty)
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func taskRowOriginalDispatchAndFailure(locale: String, fail: Bool) async throws {
        let f = try TimePickerConsumerFixture(minutes: 720)
        defer { f.cleanup() }
        f.fail = fail
        let window = f.native.window(DateScheduleTaskRow(fixture: f), locale: locale)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let menu = try await MenuButtonTestSupport.openAndEscape(
            MenuButtonTestSupport.menu("row.more", locale: locale, in: window), in: window)
        try MenuButtonTestSupport.dispatch(MenuButtonTestSupport.localized("day.pick", locale), in: menu)
        try await SystemPageHost.settle(window)
        let popup = try DateUI.popup(excluding: window)
        try await NativeSyntaxUI.prepareFocus(in: popup)
        #expect(try DateUI.selected("2026-10-02", in: popup))
        try await DateUI.select("2026-10-18", in: popup)
        #expect(f.actions.isEmpty && f.todo.dayKey == "2026-10-02")
        try await Native.click(Native.button("day.confirm", locale: locale, in: popup), in: popup)
        #expect(f.actions.count == 1)
        if case .moveToDay(let key) = try #require(f.actions.first) { #expect(key == "2026-10-18") }
        else { Issue.record("只能派发原 moveToDay") }
        #expect(f.todo.dayKey == (fail ? "2026-10-02" : "2026-10-18"))
        #expect(f.todo.remindMinutes == 720 && f.todo.dueMinutes == nil && f.todo.tagIDs.isEmpty)
        #expect(f.todo.title == "Synthetic time task" && !f.todo.isDone)
        try await SystemPageHost.settle(window)
        #expect(!popup.isVisible, "原回调即使保存失败也关闭；公共层不改变此策略")
    }

    @Test(arguments: ["en", "zh-Hans"])
    func diarySummaryOriginalSaveAndClose(locale: String) async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let prefs = try Native()
        defer { prefs.cleanup() }
        let note = try f.repository.addDiary(text: "Synthetic date note", dayKey: "2026-10-01", tagIDs: [])
        let window = SystemPageHost.window(DiarySummaryRow(entry: note, isSelected: true, onDelete: {}),
            container: f.container, scheme: .dark, locale: locale, size: NSSize(width: 420, height: 200), prefs: prefs.prefs)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let menu = try await MenuButtonTestSupport.openAndEscape(
            MenuButtonTestSupport.menu("footer.more", locale: locale, in: window), in: window)
        let schedule = try #require(menu.items.first {
            $0.title == MenuButtonTestSupport.localized("diary.quick.schedule", locale)
        }?.submenu)
        schedule.update()
        try MenuButtonTestSupport.dispatch(MenuButtonTestSupport.localized("diary.schedule.custom", locale), in: schedule)
        try await SystemPageHost.settle(window)
        let popup = try DateUI.popup(excluding: window)
        try await NativeSyntaxUI.prepareFocus(in: popup)
        #expect(try DateUI.selected("2026-10-01", in: popup))
        try await DateUI.select("2026-10-18", in: popup)
        #expect(note.dayKey == "2026-10-01")
        try await Native.click(Native.button("day.confirm", locale: locale, in: popup), in: popup)
        #expect(note.dayKey == "2026-10-18" && !f.context.hasChanges)
        #expect(note.text == "Synthetic date note" && note.tagIDs.isEmpty && !note.isPrivate)
        try await SystemPageHost.settle(window)
        #expect(!popup.isVisible)
    }
}

private struct DateScheduleTaskRow: View {
    let fixture: TimePickerConsumerFixture
    var body: some View {
        let original = TaskRowFactory.todo(TodoRowContext(todo: fixture.todo, todayKey: "2026-10-02",
            catalogs: TaskCatalogContext(tags: [], attachments: [], context: fixture.native.container.mainContext),
            display: TodoRowDisplayOptions(isDone: false, isSelected: true),
            actions: TodoRowActions(onSelect: { _ in }, onDelete: {})))
        return TaskRow(state: original.state, onSaveTitle: original.onSaveTitle) { action in
            fixture.actions.append(action)
            if fixture.fail {
                ModelChanges.perform(in: fixture.native.container.mainContext,
                    save: { _ in throw CocoaError(.fileWriteNoPermission) }) { original.dispatch(action) }
            } else { original.dispatch(action) }
        }.padding(12)
    }
}
