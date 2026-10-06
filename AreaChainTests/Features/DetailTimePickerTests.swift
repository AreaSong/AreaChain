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
        try Detail.expectDisplay(old, due: due, in: window)
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

    // A：仓储真实修改之后，失败恢复在 UI 回调返回前完成；不代表磁盘 save 故障。
    @Test(arguments: [false, true], [false, true])
    func callbackFailureRestoresDisplayAndRetries(routine: Bool, native: Bool) async throws {
        let fixture = try Detail.failureFixture()
        defer { fixture.cleanup() }
        let previous = DayBoardMutations.taskRepositoryProvider
        defer { DayBoardMutations.taskRepositoryProvider = previous }
        let repository = DetailTimeFailureRepository(fixture.native.container.mainContext)
        if !routine { DayBoardMutations.taskRepositoryProvider = { _ in repository } }
        let window = Detail.window(fixture, routine: routine)
        defer { SystemPageHost.release(window) }
        let saves = DetailTimeSaveCounter(fixture.native.container.mainContext)
        defer { saves.stop() }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try Detail.expectDisplay(720, due: false, in: window)
        fixture.repository.fail = true
        repository.fails = true
        defer { fixture.repository.fail = false; repository.fails = false }
        let feedback = MutationFeedback.shared.failureCount
        try Detail.press(Detail.button("row.time.clear", due: false, locale: "en", in: window), native: native, in: window)
        try await SystemPageHost.settle(window)
        #expect(fixture.todo.remindMinutes == 720 && fixture.routine.remindMinutes == 720)
        #expect(MutationFeedback.shared.failureCount == feedback + 1)
        try Detail.expectDisplay(720, due: false, in: window)
        #expect((routine ? fixture.repository.reminderWrites : repository.calls) == [nil])
        #expect((routine ? fixture.repository.reminderSaveBoundaries : repository.saveBoundaries) == 1 && saves.count == 0)
        let picker = try await Detail.open(in: window)
        #expect(Detail.displayed(picker) == 720 && picker.accessibilityHelp() != "Not set")
        try fixture.assign(900, to: picker)
        try await SystemPageHost.settle(window)
        #expect(Detail.displayed(picker) == 720)
        #expect(fixture.todo.remindMinutes == 720 && fixture.routine.remindMinutes == 720)
        try Detail.expectDisplay(720, due: false, in: window)
        try await fixture.close(picker)
        #expect((routine ? fixture.repository.reminderWrites : repository.calls) == [nil, 900])
        #expect((routine ? fixture.repository.reminderSaveBoundaries : repository.saveBoundaries) == 2 && saves.count == 0)
        fixture.repository.fail = false
        repository.fails = false
        try Detail.press(Detail.button("row.time.clear", due: false, locale: "en", in: window), native: native, in: window)
        try await SystemPageHost.settle(window)
        #expect((routine ? fixture.routine.remindMinutes : fixture.todo.remindMinutes) == nil)
        #expect(try Detail.buttons("row.time.clear", due: false, in: window).isEmpty)
        let cleared = try await Detail.open(in: window)
        #expect(cleared.accessibilityHelp() == "Not set")
        try await fixture.close(cleared)
        #expect((routine ? fixture.repository.reminderWrites : repository.calls) == [nil, 900, nil])
        #expect((routine ? fixture.repository.reminderSaveBoundaries : repository.saveBoundaries) == 3 && saves.count == 1)
        #expect((routine ? repository.calls : fixture.repository.reminderWrites).isEmpty)
        #expect(fixture.todo.dueMinutes == 600 && fixture.todo.dayKey == "2026-10-02")
        #expect((routine ? fixture.todo.remindMinutes : fixture.routine.remindMinutes) == 720)
    }

    // B：原 failedClearKeepsOriginalDisplay 的两个待办参数；known issue 只包原显示要求。
    @Test(arguments: [false, true])
    func outerTransactionAXClearRequiresOriginalDisplay(due: Bool) async throws {
        try await outerTransactionClear(due: due, native: false)
    }

    // C：与 B 同数据、同外层失败边界，只改事件派发。
    @Test(arguments: [false, true])
    func outerTransactionNativeClearRestoresAndRetries(due: Bool) async throws {
        try await outerTransactionClear(due: due, native: true)
    }

    private func outerTransactionClear(due: Bool, native: Bool) async throws {
        let fixture = try Detail.failureFixture()
        defer { fixture.cleanup() }
        let window = Detail.window(fixture, routine: false)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let old = due ? 600 : 720
        try Detail.expectDisplay(old, due: due, in: window)
        let counter = DetailTimeSaveCounter(fixture.native.container.mainContext)
        defer { counter.stop() }
        let clear = try Detail.button("row.time.clear", due: due, locale: "en", in: window)
        var boundaries = 0
        // 请求数只计派发；生产 Void 回调未替换，不能宣称直接捕获其返回或调用次数。
        var requests = 0
        #expect(!ModelChanges.perform(in: fixture.native.container.mainContext, save: { _ in
            boundaries += 1
            throw CocoaError(.fileWriteNoPermission)
        }) {
            requests += 1
            try Detail.press(clear, native: native, in: window)
        })
        try await SystemPageHost.settle(window)
        #expect(requests == 1 && boundaries == 1 && counter.count == 0)
        #expect(fixture.todo.remindMinutes == 720 && fixture.todo.dueMinutes == 600)
        #expect(fixture.routine.remindMinutes == 720 && fixture.todo.dayKey == "2026-10-02")
        if !native {
            withKnownIssue("第五阶段 B 两项旧问题：仅外层失败事务＋AX 同步提前渲染 nil 后未自然回显；未修复，见第十阶段 H") {
                _ = try Detail.button("row.time.clear", due: due, locale: "en", in: window)
            }
            // 若按钮已恢复，文字要求仍是普通断言，不扩充旧 known issue 去吸收新失败。
            if try Detail.buttons("row.time.clear", due: due, in: window).count == 1 {
                try Detail.expectDisplay(old, due: due, in: window)
            }
            return
        }
        try Detail.expectDisplay(old, due: due, in: window)
        let picker = try await Detail.open(due: due, in: window)
        #expect(Detail.displayed(picker) == old && picker.accessibilityHelp() != "Not set")
        try await fixture.close(picker)
        #expect(requests == 1 && boundaries == 1 && counter.count == 0)
        let retry = try Detail.button("row.time.clear", due: due, locale: "en", in: window)
        #expect(ModelChanges.perform(in: fixture.native.container.mainContext, save: { context in
            boundaries += 1
            try context.save()
        }) {
            requests += 1
            try Detail.press(retry, native: native, in: window)
        })
        try await SystemPageHost.settle(window)
        #expect((due ? fixture.todo.dueMinutes : fixture.todo.remindMinutes) == nil)
        #expect(try Detail.buttons("row.time.clear", due: due, in: window).isEmpty)
        let cleared = try await Detail.open(due: due, in: window)
        #expect(cleared.accessibilityHelp() == "Not set")
        try await fixture.close(cleared)
        #expect(requests == 2 && boundaries == 2 && counter.count == 1)
        #expect((due ? fixture.todo.remindMinutes : fixture.todo.dueMinutes) == (due ? 720 : 600))
        #expect(fixture.routine.remindMinutes == 720 && fixture.todo.dayKey == "2026-10-02")
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
