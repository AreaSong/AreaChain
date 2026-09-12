import Foundation
import Testing
@testable import AreaChain

@MainActor
struct CalendarSyncEngineTests {
    @Test(arguments: [false, true])
    func normalizedMissingClockTimeConvergesAndRetriesWithoutConflict(partialFailure: Bool) async throws {
        let fixture = CalendarSyncFixture()
        fixture.seedBound()
        fixture.calendar = Calendar(identifier: .gregorian)
        fixture.calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        fixture.tasks[0].state.content.dayKey = "2026-03-08"
        fixture.tasks[0].state.content.remindMinutes = 150
        fixture.tasks[0].eventID = ""
        fixture.client.remote = [:]
        fixture.checkpoint = CalendarSyncLedger()
        fixture.client.normalize = { content in
            var value = content
            if value.dayKey == "2026-03-08", value.remindMinutes == 150 { value.remindMinutes = 180 }
            return value
        }
        fixture.failLocalSave = partialFailure
        let first = await fixture.engine.synchronize(isCurrent: { true })
        #expect(first.phase == (partialFailure ? .failed : .synced))
        fixture.failLocalSave = false
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .synced)
        #expect(fixture.client.createCount == 1)
        #expect(fixture.tasks[0].state.content.remindMinutes == 150)
        let eventID = try #require(fixture.client.remote.keys.first)
        #expect(fixture.client.remote[eventID]?.content.remindMinutes == 180)
        fixture.client.remote[eventID]?.content.title = "只改标题"
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .synced)
        #expect(fixture.tasks[0].state.content.title == "只改标题")
        #expect(fixture.tasks[0].state.content.remindMinutes == 150)
    }

    @Test func fallbackAndReadFailuresNeverCreateCalendarsOrWriteRemoteEvents() async {
        let fixture = CalendarSyncFixture()
        fixture.seedBound()
        fixture.healthy = false
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .localUnavailable)
        #expect(fixture.client.authorizationCount == 0)
        fixture.healthy = true
        fixture.failLoad = true
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .failed)
        #expect(fixture.client.calendarCount == 0)
        #expect(fixture.client.batchCount == 0)
        #expect(fixture.client.remote.count == 1)
        #expect(fixture.ledgerSaveCount == 0)
    }

    @Test func corruptLedgerDoesNotBecomeAnEmptyFirstRun() async {
        let fixture = CalendarSyncFixture()
        fixture.seedBound()
        fixture.failLedgerLoad = true
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .failed)
        #expect(fixture.client.authorizationCount == 0)
        #expect(fixture.client.batchCount == 0)
    }

    @Test func restartPullsOnlyRemoteChangesAndPushesOnlyLocalChanges() async {
        let fixture = CalendarSyncFixture()
        fixture.seedBound()
        fixture.client.remote["event"]?.content.title = "关闭期间的日历修改"
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .synced)
        #expect(fixture.tasks[0].state.content.title == "关闭期间的日历修改")
        #expect(fixture.client.batchCount == 0)
        fixture.tasks[0].state.content.title = "刚保存的本地修改"
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .synced)
        #expect(fixture.client.remote["event"]?.content.title == "刚保存的本地修改")
        #expect(fixture.client.createCount == 0)
    }

    @Test func conflictingEditsArePreservedUntilUserAlignsBothSides() async {
        let fixture = CalendarSyncFixture()
        let id = fixture.seedBound()
        let oldLedger = fixture.checkpoint
        fixture.tasks[0].state.content.title = "本地修改"
        fixture.client.remote["event"]?.content.title = "远端修改"
        let outcome = await fixture.engine.synchronize(isCurrent: { true })
        #expect(outcome.phase == .conflict && outcome.conflicts == [id])
        #expect(fixture.client.batchCount == 0 && fixture.localSaveCount == 0)
        #expect(fixture.checkpoint == oldLedger)
        fixture.client.remote["event"]?.content = fixture.tasks[0].state.content
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .synced)
        #expect(fixture.client.batchCount == 0)
    }

    @Test func legacyBindingWithoutBaselineNeverChoosesAnArbitraryWinner() async {
        let fixture = CalendarSyncFixture()
        fixture.seedBound()
        fixture.checkpoint = CalendarSyncLedger()
        fixture.client.remote["event"]?.content.title = "旧绑定远端修改"
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .conflict)
        #expect(fixture.client.batchCount == 0)
        #expect(fixture.tasks[0].state.content.title == "原内容")
    }

    @Test func deletedRemoteStaysDetachedAcrossUnrelatedEditsAndRestart() async {
        let fixture = CalendarSyncFixture()
        let id = fixture.seedBound()
        fixture.client.remote = [:]
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .synced)
        #expect(fixture.tasks.count == 1 && fixture.tasks[0].eventID.isEmpty)
        #expect(fixture.checkpoint.records[id.uuidString]?.detached == true)
        fixture.tasks[0].state.content.title = "解绑后的普通编辑"
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .synced)
        #expect(fixture.client.createCount == 0)
        fixture.tasks[0].state.isPublished = false
        _ = await fixture.engine.synchronize(isCurrent: { true })
        fixture.tasks[0].state.isPublished = true
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .synced)
        #expect(fixture.client.createCount == 1)
    }

    @Test func completionDeletesOnlyAnUnchangedBoundEvent() async {
        let fixture = CalendarSyncFixture()
        fixture.seedBound()
        fixture.tasks[0].state.isPublished = false
        fixture.client.remote["event"]?.content.title = "远端修改"
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .conflict)
        #expect(fixture.client.remote.count == 1)
        fixture.client.remote["event"]?.content.title = "原内容"
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .synced)
        #expect(fixture.client.remote.isEmpty && fixture.tasks[0].eventID.isEmpty)
    }

    @Test func unknownEventsArePreservedEvenWhenLocalDatabaseIsEmpty() async {
        let fixture = CalendarSyncFixture()
        fixture.client.remote["unknown"] = CalendarRemoteItem(
            id: "unknown", calendarID: "owned", content: CalendarContent(title: "手动事件", dayKey: "2026-09-11")
        )
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .synced)
        #expect(fixture.client.remote.count == 1 && fixture.client.batchCount == 0)
    }

    @Test func foreignCalendarBindingAndDuplicateTokensAreConflicts() async {
        let fixture = CalendarSyncFixture()
        fixture.seedBound()
        fixture.client.remote["event"]?.calendarID = "other-calendar"
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .conflict)
        #expect(fixture.client.batchCount == 0)
        fixture.client.remote["event"]?.calendarID = "owned"
        var duplicate = fixture.client.remote["event"]!
        duplicate.id = "duplicate"
        fixture.client.remote[duplicate.id] = duplicate
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .conflict)
        #expect(fixture.client.batchCount == 0)
    }

    @Test func failedRemoteCommitRetainsBindingAndBaseline() async {
        let fixture = CalendarSyncFixture()
        fixture.seedBound()
        let oldLedger = fixture.checkpoint
        fixture.tasks[0].state.isPublished = false
        fixture.client.failApply = true
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase != .synced)
        #expect(fixture.tasks[0].eventID == "event")
        #expect(fixture.checkpoint == oldLedger)
    }

    @Test(arguments: [true, false])
    func retryAfterPartialCommitNeverCreatesDuplicateEvents(failLocal: Bool) async {
        let fixture = CalendarSyncFixture()
        fixture.seedBound()
        fixture.tasks[0].eventID = ""
        fixture.checkpoint = CalendarSyncLedger()
        fixture.client.remote = [:]
        fixture.failLocalSave = failLocal
        fixture.failLedgerSave = !failLocal
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .failed)
        #expect(fixture.client.createCount == 1)
        fixture.failLocalSave = false
        fixture.failLedgerSave = false
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .synced)
        #expect(fixture.client.createCount == 1 && fixture.client.remote.count == 1)
        #expect(!fixture.tasks[0].eventID.isEmpty)
    }

    @Test func movedOutOfWindowEventIsResolvedByItsBindingID() async {
        let fixture = CalendarSyncFixture()
        fixture.seedBound()
        fixture.client.remote["event"]?.content.dayKey = "2040-01-01"
        #expect(await fixture.engine.synchronize(isCurrent: { true }).phase == .synced)
        #expect(fixture.client.lookupCount == 1)
        #expect(fixture.tasks[0].state.content.dayKey == "2040-01-01")
    }

    @Test func disabledWhileAuthorizationAwaitsCannotResumeWriting() async {
        let fixture = CalendarSyncFixture()
        fixture.seedBound()
        var enabled = true
        fixture.client.authorizationStep = { enabled = false }
        #expect(await fixture.engine.synchronize(isCurrent: { enabled }).phase == .off)
        #expect(fixture.client.calendarCount == 0 && fixture.client.batchCount == 0)
    }

    @Test func annualWindowsCoverActualDatesWithoutGapsOrFourYearTruncation() throws {
        let now = try #require(DayKey.date(from: "2026-09-11"))
        let keys = ["2010-01-01", "2040-01-01"]
        let bounds = CalendarEventPolicy.eventQueryBounds(now: now, dayKeys: keys)
        let windows = CalendarEventPolicy.eventQueryWindows(now: now, dayKeys: keys)
        #expect(windows.first?.start == bounds.start && windows.last?.end == bounds.end)
        #expect(windows.allSatisfy { $0.duration > 0 && $0.duration <= 367 * 86_400 })
        #expect(zip(windows, windows.dropFirst()).allSatisfy { $0.end == $1.start })
    }

    @Test func coordinatorCoalescesOwnStoreChangeWithoutAnInfiniteWriteLoop() async throws {
        let fixture = CalendarSyncFixture()
        fixture.seedBound()
        fixture.tasks[0].state.content.title = "本地修改"
        var outcomes: [CalendarSyncOutcome] = []
        let coordinator = CalendarSyncCoordinator(engine: fixture.engine, enabled: { true }, publish: { outcomes.append($0) })
        fixture.client.didApply = { coordinator.request() }
        let task = try #require(coordinator.request())
        _ = coordinator.request()
        await task.value
        #expect(fixture.client.batchCount == 1)
        #expect(outcomes.last?.phase == .synced)
        #expect(fixture.client.authorizationCount <= 2)
    }

    @Test func cancelledOldAuthorizationCannotOverwriteAReenabledSync() async throws {
        let fixture = CalendarSyncFixture()
        fixture.seedBound()
        fixture.tasks[0].state.content.title = "等待期间的本地修改"
        fixture.client.holdAuthorization = true
        var enabled = true
        var outcomes: [CalendarSyncOutcome] = []
        let coordinator = CalendarSyncCoordinator(engine: fixture.engine, enabled: { enabled }, publish: { outcomes.append($0) })
        let oldTask = try #require(coordinator.request())
        for _ in 0..<50 where fixture.client.pendingAuthorization == nil { await Task.yield() }
        let continuation = try #require(fixture.client.pendingAuthorization)
        fixture.client.pendingAuthorization = nil
        enabled = false
        coordinator.stop()
        enabled = true
        fixture.client.holdAuthorization = false
        let newTask = try #require(coordinator.request())
        await newTask.value
        continuation.resume(returning: true)
        await oldTask.value
        #expect(fixture.client.batchCount == 1)
        #expect(fixture.client.remote["event"]?.content.title == "等待期间的本地修改")
        #expect(outcomes.last?.phase == .synced)
    }
}
