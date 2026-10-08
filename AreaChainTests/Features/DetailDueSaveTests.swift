import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DetailDueSaveTests {
    typealias Detail = DetailTimeSupport

    // A：真实详情自身最终保存依赖失败；不以外层事务包住 AX 或原生事件。
    @Test(arguments: [false, true])
    func ordinaryFailureRestoresAndRetries(native: Bool) async throws {
        let fixture = try Detail.failureFixture()
        defer { fixture.cleanup() }
        let probe = DetailDueSaveProbe(fixture)
        defer { probe.stop() }
        let window = probe.window(fixture)
        defer { SystemPageHost.release(window) }
        let hosting = try #require(window.contentView)
        let modelID = ObjectIdentifier(fixture.todo)
        let persistentID = fixture.todo.persistentModelID
        let context = probe.context
        let calendar = try CalendarSyncStorage.local(context: context).load()
        let reminders = ReminderPlanning.catalog(routines: [], checks: [],
            todos: [fixture.todo.snapshot], todayKey: fixture.todo.dayKey)
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try Detail.expectDisplay(600, due: true, in: window)
        try Detail.expectDisplay(720, due: false, in: window)
        try clear(probe, native: native, window: window)
        probe.expectCounts([nil], failures: 1, saves: 0, publications: 0)
        #expect(window.contentView === hosting && hosting.window === window && ObjectIdentifier(fixture.todo) == modelID)
        try await SystemPageHost.settle(window)
        try Detail.expectDisplay(600, due: true, in: window)
        try await failedAssignment(fixture, probe: probe, window: window)
        #expect(window.contentView === hosting && fixture.todo.persistentModelID == persistentID)
        probe.fails = false
        try await NativeSyntaxUI.prepareFocus(in: window)
        try clear(probe, native: native, window: window)
        probe.expectCounts([nil, 900, nil], failures: 2, saves: 1, publications: 1)
        try await SystemPageHost.settle(window)
        #expect(try Detail.buttons("row.time.clear", due: true, in: window).isEmpty)
        let reopened = try await Detail.open(due: true, in: window)
        #expect(reopened.accessibilityHelp() == "Not set")
        try await fixture.close(reopened)
        probe.expectCounts([nil, 900, nil], failures: 2, saves: 1, publications: 1)
        #expect(window.contentView === hosting && hosting.window === window && window.isVisible)
        #expect(ObjectIdentifier(fixture.todo) == modelID && fixture.todo.persistentModelID == persistentID)
        #expect(fixture.todo.modelContext === context && fixture.todo.remindMinutes == 720)
        #expect(fixture.todo.dayKey == "2026-10-02" && fixture.routine.remindMinutes == 720)
        #expect(try CalendarSyncStorage.local(context: context).load() == calendar)
        #expect(ReminderPlanning.catalog(routines: [], checks: [],
            todos: [fixture.todo.snapshot], todayKey: fixture.todo.dayKey) == reminders)
        let saved = try #require(ModelContext(context.container).fetch(FetchDescriptor<TodoItem>()).first)
        #expect(saved.dueMinutes == nil && saved.remindMinutes == 720 && saved.dayKey == fixture.todo.dayKey)
        #expect(saved.calendarEventID == fixture.todo.calendarEventID)
        #expect(probe.stages == [
            "request:nil", "assigned/save:nil", "synthetic-throw", "synchronous-return:due=Optional(600),failures=1",
            "request:Optional(900)", "assigned/save:Optional(900)", "synthetic-throw", "synchronous-return:due=Optional(600),failures=2",
            "request:nil", "assigned/save:nil", "context.save-call", "context.save-return", "publish", "synchronous-return:due=nil,failures=2"
        ])
    }

    private func clear(_ probe: DetailDueSaveProbe, native: Bool, window: NSWindow) throws {
        let button = try Detail.button("row.time.clear", due: true, locale: "en", in: window)
        try probe.dispatch(nil) { try Detail.press(button, native: native, in: window) }
    }

    private func failedAssignment(_ fixture: TimePickerConsumerFixture,
                                  probe: DetailDueSaveProbe, window: NSWindow) async throws {
        let picker = try await Detail.open(due: true, in: window)
        #expect(Detail.displayed(picker) == 600 && picker.accessibilityHelp() != "Not set")
        try probe.dispatch(900) { try fixture.assign(900, to: picker) }
        probe.expectCounts([nil, 900], failures: 2, saves: 0, publications: 0)
        try await SystemPageHost.settle(window)
        #expect(Detail.displayed(picker) == 600)
        try Detail.expectDisplay(600, due: true, in: window)
        try await fixture.close(picker)
        probe.expectCounts([nil, 900], failures: 2, saves: 0, publications: 0)
    }

    // 与 UI 事件证据分开：直接调用同一个生产父 View 生成的 Void 回调，不声称取得 Bool。
    @Test func productionVoidCallbackReturnsAfterRecovery() throws {
        let fixture = try Detail.failureFixture()
        defer { fixture.cleanup() }
        let probe = DetailDueSaveProbe(fixture)
        defer { probe.stop() }
        let body = TodoScheduleSectionView(todo: fixture.todo, saveDue: probe.save).body
        let control = try #require(DetailDueSaveProbe.dueControl(in: body))
        probe.dispatch(nil) { control.onSelectMinutes(nil) }
        probe.expectCounts([nil], failures: 1, saves: 0, publications: 0)
        #expect(probe.stages == ["request:nil", "assigned/save:nil", "synthetic-throw",
                                "synchronous-return:due=Optional(600),failures=1"])
    }

    @Test func directBoolAndLegacyFunctionReferences() throws {
        let fixture = try Detail.failureFixture()
        defer { fixture.cleanup() }
        let probe = DetailDueSaveProbe(fixture)
        defer { probe.stop() }
        probe.dispatch(nil) { #expect(!DayBoardMutations.setDue(fixture.todo, minutes: nil, save: probe.save)) }
        probe.expectCounts([nil], failures: 1, saves: 0, publications: 0)
        let setDue: (TodoItem, Int?) -> Bool = DayBoardMutations.setDue
        let persist: (ModelContext?, () throws -> Void) -> Bool = DayBoardMutations.persist
        #expect(setDue(fixture.todo, -1) && fixture.todo.dueMinutes == nil)
        #expect(setDue(fixture.todo, 1440) && fixture.todo.dueMinutes == nil)
        #expect(setDue(fixture.todo, nil) && fixture.todo.dueMinutes == nil)
        #expect(persist(probe.context, { fixture.todo.dueMinutes = 600 }))
        #expect(fixture.todo.dueMinutes == 600 && probe.saves.count == 4 && probe.publications == 4)
        #expect(probe.failures == 1 && probe.attempted == [nil])
        #expect(!persist(probe.context, {
            fixture.todo.dueMinutes = 900
            throw DetailDueSaveProbe.Failure.syntheticFinalSave
        }))
        #expect(fixture.todo.dueMinutes == 600 && probe.failures == 2)
        #expect(probe.saves.count == 4 && probe.publications == 4)
    }

    @Test func defaultDetailAssignClearMidnightAndReopen() async throws {
        let fixture = try Detail.failureFixture()
        defer { fixture.cleanup() }
        // 记录器只观察；原宿主不接 saveDue 参数，验证生产默认保存与发布。
        let probe = DetailDueSaveProbe(fixture)
        defer { probe.stop() }
        let window = Detail.window(fixture, routine: false)
        defer { SystemPageHost.release(window) }
        let hosting = window.contentView
        for (index, minute) in [Int?(900), nil, 0].enumerated() {
            if let minute {
                let picker = try await Detail.open(due: true, in: window)
                try fixture.assign(minute, to: picker)
                try await fixture.close(picker)
            } else {
                try await NativeSyntaxUI.prepareFocus(in: window)
                try Detail.press(Detail.button("row.time.clear", due: true, locale: "en", in: window), native: true, in: window)
            }
            #expect(fixture.todo.dueMinutes == minute)
            let reopened = try await Detail.open(due: true, in: window)
            if let minute { #expect(Detail.displayed(reopened) == minute && reopened.accessibilityHelp() != "Not set") }
            else { #expect(reopened.accessibilityHelp() == "Not set") }
            try await fixture.close(reopened)
            #expect(probe.saves.count == index + 1 && probe.publications == index + 1)
        }
        #expect(probe.failures == 0 && probe.attempted.isEmpty && window.contentView === hosting)
        #expect(fixture.todo.remindMinutes == 720 && fixture.todo.dayKey == "2026-10-02")
        let saved = try #require(ModelContext(probe.context.container).fetch(FetchDescriptor<TodoItem>()).first)
        #expect(saved.dueMinutes == 0 && saved.remindMinutes == 720)
    }

    @Test func pendingChangesPreSaveRemainsSeparate() throws {
        let fixture = try Detail.failureFixture()
        defer { fixture.cleanup() }
        let probe = DetailDueSaveProbe(fixture)
        defer { probe.stop() }
        fixture.todo.title = "Synthetic pending title"
        probe.requested.append(nil)
        #expect(!DayBoardMutations.setDue(fixture.todo, minutes: nil, save: probe.save))
        #expect(fixture.todo.dueMinutes == 600 && fixture.todo.title == "Synthetic pending title")
        probe.expectCounts([nil], failures: 1, saves: 1, publications: 0)
        let saved = try #require(ModelContext(probe.context.container).fetch(FetchDescriptor<TodoItem>()).first)
        #expect(saved.title == "Synthetic pending title" && saved.dueMinutes == 600)
    }

    @Test(arguments: [false, true])
    func nestedDueCannotReplaceOuterCommitter(fail: Bool) throws {
        let fixture = try Detail.failureFixture()
        defer { fixture.cleanup() }
        let probe = DetailDueSaveProbe(fixture)
        defer { probe.stop() }
        var outerSaves = 0
        let result = ModelChanges.perform(in: probe.context, save: { context in
            outerSaves += 1
            #expect(context === probe.context && fixture.todo.dueMinutes == nil)
            if fail { throw DetailDueSaveProbe.Failure.syntheticFinalSave }
            try context.save()
        }) {
            #expect(DayBoardMutations.setDue(fixture.todo, minutes: nil, save: probe.save))
            #expect(probe.attempted.isEmpty && outerSaves == 0 && fixture.todo.dueMinutes == nil)
        }
        #expect(result == !fail && outerSaves == 1 && probe.attempted.isEmpty)
        #expect(fixture.todo.dueMinutes == (fail ? 600 : nil))
        #expect(probe.failures == (fail ? 1 : 0) && probe.publications == (fail ? 0 : 1))
        #expect(probe.saves.count == (fail ? 0 : 1))
    }

    @Test func independentDetailsDoNotShareSaveDependency() async throws {
        let first = try Detail.failureFixture()
        defer { first.cleanup() }
        let second = try Detail.failureFixture()
        defer { second.cleanup() }
        let failing = DetailDueSaveProbe(first)
        let succeeding = DetailDueSaveProbe(second)
        defer { succeeding.stop(); failing.stop() }
        succeeding.fails = false
        let firstWindow = failing.window(first)
        let secondWindow = succeeding.window(second)
        defer { SystemPageHost.release(secondWindow); SystemPageHost.release(firstWindow) }
        try await NativeSyntaxUI.prepareFocus(in: firstWindow)
        try await SystemPageHost.settle(firstWindow)
        try clear(failing, native: true, window: firstWindow)
        #expect(succeeding.attempted.isEmpty && second.todo.dueMinutes == 600)
        try await NativeSyntaxUI.prepareFocus(in: secondWindow)
        try await SystemPageHost.settle(secondWindow)
        try clear(succeeding, native: true, window: secondWindow)
        #expect(first.todo.dueMinutes == 600 && second.todo.dueMinutes == nil)
        #expect(failing.attempted == [nil] && succeeding.attempted == [nil])
        #expect(failing.saves.count == 0 && succeeding.saves.count == 1 && failing.failures == 1)
        try await SystemPageHost.settle(firstWindow)
        try Detail.expectDisplay(600, due: true, in: firstWindow)
        #expect(try Detail.buttons("row.time.clear", due: true, in: secondWindow).isEmpty)
    }
}
