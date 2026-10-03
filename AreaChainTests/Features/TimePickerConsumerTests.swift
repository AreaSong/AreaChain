import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TimePickerConsumerTests {
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: [false, true], [false, true])
    func realConsumersInitializeOnceSaveClearAndClose(resident: Bool, empty: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: empty ? nil : 720)
        defer { fixture.cleanup() }
        let window = fixture.window(resident: resident)
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let before = RemindMinutes.from(date: .now)
        let picker = try await fixture.open(resident: resident, in: window)
        defer { if let popup = picker.window { popup.orderOut(nil) } }
        let writes = resident ? fixture.repository.reminderWrites : fixture.taskMinutesWrites
        #expect(writes.count == (empty ? 1 : 0))
        if empty {
            #expect([before, RemindMinutes.from(date: .now)].contains(try #require(writes.first ?? nil)))
        }
        try fixture.assign(1439, to: picker)
        try await SystemPageHost.settle(window)
        #expect((resident ? fixture.routine.remindMinutes : fixture.todo.remindMinutes) == 1439)
        #expect(displayed(picker) == 1439)
        try await fixture.close(picker)
        #expect((resident ? fixture.repository.reminderWrites : fixture.taskMinutesWrites).count == writes.count + 1)
        let savedContext = ModelContext(fixture.native.container)
        if resident {
            #expect(try savedContext.fetch(FetchDescriptor<DailyRoutine>()).first?.remindMinutes == 1439)
        } else {
            #expect(try savedContext.fetch(FetchDescriptor<TodoItem>()).first?.remindMinutes == 1439)
        }
        try await fixture.clear(resident: resident, in: window)
        #expect((resident ? fixture.routine.remindMinutes : fixture.todo.remindMinutes) == nil)
        #expect((resident ? fixture.repository.reminderWrites : fixture.taskMinutesWrites).last == .some(nil))
    }

    @Test(arguments: [false, true])
    func saveFailureMeasuresAutomaticDisplayRecovery(resident: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: 720)
        defer { fixture.cleanup() }
        let window = fixture.window(resident: resident)
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let picker = try await fixture.open(resident: resident, in: window)
        defer { if let popup = picker.window { popup.orderOut(nil) } }
        fixture.fail = true
        fixture.repository.fail = true
        try fixture.assign(900, to: picker)
        try await SystemPageHost.settle(window)
        #expect((resident ? fixture.routine.remindMinutes : fixture.todo.remindMinutes) == 720)
        print("TIME_CONSUMER_FAILURE resident=\(resident) automaticDisplay=\(displayed(picker)) expected=720")
        #expect(displayed(picker) == 720, "必须自动恢复；不能用手动重建冒充")
        fixture.fail = false
        fixture.repository.fail = false
        try fixture.assign(815, to: picker)
        try await SystemPageHost.settle(window)
        #expect((resident ? fixture.routine.remindMinutes : fixture.todo.remindMinutes) == 815)
        #expect(displayed(picker) == 815)
        try await fixture.close(picker)
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func popoverLanguageAppearanceAndDimensions(locale: String, dark: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: 0)
        defer { fixture.cleanup() }
        for resident in [false, true] {
            let window = fixture.window(resident: resident, locale: locale, dark: dark)
            defer { SystemPageHost.release(window) }
            try await SystemPageHost.settle(window)
            let picker = try await fixture.open(resident: resident, locale: locale, in: window)
            let popup = try #require(picker.window)
            #expect(picker.accessibilityLabel() == L10n.string("row.time", locale: Locale(identifier: locale)))
            #expect(picker.bounds.width > 40)
            #expect(try #require(popup.contentView).bounds.width >= 180)
            try Native.snapshot(popup, name: "time-consumer-\(resident)-\(locale)-\(dark)")
            try await fixture.close(picker)
        }
    }

    func displayed(_ picker: NSDatePicker) -> Int {
        RemindMinutes.from(date: picker.dateValue, calendar: picker.calendar ?? .current)
    }
}
