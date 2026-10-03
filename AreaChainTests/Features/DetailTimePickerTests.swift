import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DetailTimePickerTests {
    typealias Native = SettingsButtonTestSupport
    typealias Detail = DetailTimeSupport

    @Test(arguments: [false, true])
    func emptyOpenCloseAndMidnight(routine: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: nil)
        defer { fixture.cleanup() }
        let window = Detail.window(fixture, routine: routine)
        defer { SystemPageHost.release(window) }
        for due in routine ? [false] : [false, true] {
            let picker = try await Detail.open(due: due, in: window)
            #expect(picker.accessibilityHelp() == "Not set")
            try await fixture.close(picker)
            #expect(fixture.todo.remindMinutes == nil && fixture.todo.dueMinutes == nil)
            #expect(fixture.routine.remindMinutes == nil && fixture.repository.reminderWrites.isEmpty)
            let reopened = try await Detail.open(due: due, in: window)
            try fixture.assign(0, to: reopened)
            try await SystemPageHost.settle(window)
            #expect(Detail.displayed(reopened) == 0)
            #expect((routine ? fixture.routine.remindMinutes : due ? fixture.todo.dueMinutes : fixture.todo.remindMinutes) == 0)
            try await fixture.close(reopened)
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await Native.click(Detail.button("row.time.clear", due: due, locale: "en", in: window), in: window)
        }
        #expect(fixture.todo.remindMinutes == nil && fixture.todo.dueMinutes == nil)
        #expect(fixture.routine.remindMinutes == nil)
    }

    @Test(arguments: [false, true])
    func shortcutsToggleAndOriginalClear(routine: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: nil)
        defer { fixture.cleanup() }
        let window = Detail.window(fixture, routine: routine)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        for minute in [540, 720, 900, 1080, 1200] {
            let label = String(format: "%02d:00", minute / 60)
            let candidates = Native.buttons(in: window).filter { Detail.matches($0, label) }
            try #require(candidates.count == 1)
            try await Native.click(candidates[0], in: window)
            #expect((routine ? fixture.routine.remindMinutes : fixture.todo.remindMinutes) == minute)
            try await Native.click(candidates[0], in: window)
            #expect((routine ? fixture.routine.remindMinutes : fixture.todo.remindMinutes) == nil)
        }
        #expect(fixture.todo.dueMinutes == nil && fixture.todo.dayKey == "2026-10-02")
        if routine { #expect(fixture.repository.reminderWrites.count == 10) }
    }

    @Test(arguments: [(false, false), (false, true), (true, false)])
    func saveAndFailureAutomaticallyRestore(routine: Bool, due: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: 720)
        defer { fixture.cleanup() }
        fixture.todo.dueMinutes = 600
        try fixture.native.container.mainContext.save()
        let window = Detail.window(fixture, routine: routine)
        defer { SystemPageHost.release(window) }
        let picker = try await Detail.open(due: due, in: window)
        let old = due ? 600 : 720
        let eventID = fixture.todo.calendarEventID
        let calendarBefore = try CalendarSyncStorage.local(context: fixture.native.container.mainContext).load()
        let reminderBefore = ReminderPlanning.catalog(routines: [], checks: [],
            todos: [fixture.todo.snapshot], todayKey: fixture.todo.dayKey)
        if routine {
            fixture.repository.fail = true
            try fixture.assign(900, to: picker)
            fixture.repository.fail = false
        } else {
            let result = ModelChanges.perform(in: fixture.native.container.mainContext,
                save: { _ in throw CocoaError(.fileWriteNoPermission) }) {
                try fixture.assign(900, to: picker)
            }
            #expect(!result)
        }
        try await SystemPageHost.settle(window)
        #expect(Detail.displayed(picker) == old, "原宿主自然更新后必须回显旧值")
        #expect(fixture.todo.remindMinutes == 720 && fixture.todo.dueMinutes == 600)
        #expect(fixture.routine.remindMinutes == 720)
        try fixture.assign(1439, to: picker)
        try await SystemPageHost.settle(window)
        #expect(Detail.displayed(picker) == 1439)
        #expect((routine ? fixture.routine.remindMinutes : due ? fixture.todo.dueMinutes : fixture.todo.remindMinutes) == 1439)
        #expect(fixture.todo.dayKey == "2026-10-02" && fixture.todo.calendarEventID == eventID)
        if due {
            #expect(fixture.todo.remindMinutes == 720)
            #expect(try CalendarSyncStorage.local(context: fixture.native.container.mainContext).load() == calendarBefore)
            #expect(ReminderPlanning.catalog(routines: [], checks: [], todos: [fixture.todo.snapshot],
                todayKey: fixture.todo.dayKey) == reminderBefore)
        }
        else { #expect(fixture.todo.dueMinutes == 600) }
        try await fixture.close(picker)
        let context = ModelContext(fixture.native.container)
        if routine { #expect(try context.fetch(FetchDescriptor<DailyRoutine>()).first?.remindMinutes == 1439) }
        else {
            let saved = try #require(context.fetch(FetchDescriptor<TodoItem>()).first)
            #expect((due ? saved.dueMinutes : saved.remindMinutes) == 1439)
        }
    }

    @Test(arguments: [false, true])
    func nativePendingBlurEscapeExternalAndReopen(due: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: 720)
        defer { fixture.cleanup() }
        fixture.todo.dueMinutes = 720
        try fixture.native.container.mainContext.save()
        let window = Detail.window(fixture, routine: false, locale: "zh-Hans")
        defer { SystemPageHost.release(window) }
        let picker = try await Detail.open(due: due, locale: "zh-Hans", in: window)
        try await Detail.partial(picker)
        #expect((due ? fixture.todo.dueMinutes : fixture.todo.remindMinutes) == 720)
        let popup = try #require(picker.window)
        popup.makeFirstResponder(nil)
        try await SystemPageHost.settle(popup)
        #expect((due ? fixture.todo.dueMinutes : fixture.todo.remindMinutes) == 724)
        if due { fixture.todo.dueMinutes = 0 } else { fixture.todo.remindMinutes = 0 }
        try fixture.native.container.mainContext.save()
        try await SystemPageHost.settle(popup)
        #expect(Detail.displayed(picker) == 0)
        try await Detail.partial(picker)
        try await fixture.close(picker)
        try fixture.assign(900, to: picker)
        #expect((due ? fixture.todo.dueMinutes : fixture.todo.remindMinutes) == 0)
        let reopened = try await Detail.open(due: due, locale: "zh-Hans", in: window)
        #expect(Detail.displayed(reopened) == 0)
        try await fixture.close(reopened)
    }

    @Test(arguments: [(false, false), (false, true), (true, false)])
    func failedClearKeepsOriginalDisplay(routine: Bool, due: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: 720)
        defer { fixture.cleanup() }
        fixture.todo.dueMinutes = 600
        try fixture.native.container.mainContext.save()
        let window = Detail.window(fixture, routine: routine)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let clear = try Detail.button("row.time.clear", due: due, locale: "en", in: window)
        let press = NSSelectorFromString("accessibilityPerformPress")
        try #require(clear.responds(to: press))
        if routine {
            fixture.repository.fail = true
            _ = clear.perform(press)
            fixture.repository.fail = false
            #expect(fixture.repository.reminderWrites == [nil])
        } else {
            #expect(!ModelChanges.perform(in: fixture.native.container.mainContext,
                save: { _ in throw CocoaError(.fileWriteNoPermission) }) { _ = clear.perform(press) })
        }
        try await SystemPageHost.settle(window)
        #expect(fixture.todo.remindMinutes == 720 && fixture.todo.dueMinutes == 600)
        #expect(fixture.routine.remindMinutes == 720)
        if routine {
            _ = try Detail.button("row.time.clear", due: due, locale: "en", in: window)
            let picker = try await Detail.open(due: due, in: window)
            #expect(Detail.displayed(picker) == 720)
            try await fixture.close(picker)
        } else {
            withKnownIssue("第五阶段 B 原版/迁移版均复现：外层事务清除失败后详情未自然刷新，见工程记录") {
                _ = try Detail.button("row.time.clear", due: due, locale: "en", in: window)
            }
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func actualDetailLayoutAndLocale(locale: String, dark: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: nil)
        defer { fixture.cleanup() }
        for (routine, width) in [(false, 280.0), (false, 400.0), (true, 280.0), (true, 400.0)] {
            let window = Detail.window(fixture, routine: routine, locale: locale, dark: dark, width: width)
            defer { SystemPageHost.release(window) }
            for due in routine ? [false] : [false, true] {
                let picker = try await Detail.open(due: due, locale: locale, in: window)
                #expect(picker.locale?.identifier == locale)
                #expect(picker.bounds.width > 40)
                let popup = try #require(picker.window)
                try Native.snapshot(window, name: "detail-time-\(Int(width))-\(routine)-\(due)-\(locale)-\(dark)")
                try Native.snapshot(popup, name: "detail-time-popup-\(Int(width))-\(routine)-\(due)-\(locale)-\(dark)")
                try await fixture.close(picker)
            }
        }
    }
}
