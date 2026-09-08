import Foundation
import Testing
@testable import AreaChain

struct BoardSearchTests {
    @Test func emptyOrBlankQueryReturnsNothing() {
        let todo = TodoSnapshot(id: UUID(), title: "修角标", isDone: false, dayKey: "2026-09-07")
        #expect(BoardSearch.hits(query: "", todos: [todo], diaries: [], routines: []).isEmpty)
        #expect(BoardSearch.hits(query: "   ", todos: [todo], diaries: [], routines: []).isEmpty)
    }

    @Test func matchesTitleAndDiaryAndSkipsDeleted() {
        let keep = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let gone = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let note = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let todos = [
            TodoSnapshot(id: keep, title: "修角标", isDone: true, dayKey: "2026-09-07"),
            TodoSnapshot(
                id: gone,
                title: "修角标旧",
                isDone: false,
                dayKey: "2026-09-06",
                deletedAt: Date(timeIntervalSince1970: 1)
            )
        ]
        let diaries = [
            DiarySnapshot(id: note, text: "角标好了", dayKey: "2026-09-05", createdAt: Date(timeIntervalSince1970: 2))
        ]
        let hits = BoardSearch.hits(query: "角标", todos: todos, diaries: diaries, routines: [])
        #expect(hits.map(\.id) == [keep, note])
        #expect(hits.map(\.kind) == [.todo, .diary])
        let groups = BoardSearch.grouped(hits)
        #expect(groups.map(\.dayKey) == ["2026-09-07", "2026-09-05"])
    }

    @Test func routinesMatchTitleAndIgnoreCase() {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let routine = RoutineSnapshot(
            id: id,
            title: "写日报",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2026-09-01"
        )
        let hits = BoardSearch.hits(query: "日报", todos: [], diaries: [], routines: [routine])
        #expect(hits.map(\.id) == [id])
        #expect(hits.first?.kind == .routine)
        #expect(BoardSearch.hits(query: "xyz", todos: [], diaries: [], routines: [routine]).isEmpty)
    }
}

struct FeedbackCopyTests {
    @Test func syncAndCaptureKeysStayStable() {
        #expect(CalendarSyncPhase.off.messageKey == "settings.calendar.sync.status.off")
        #expect(CalendarSyncPhase.denied.messageKey == "settings.calendar.sync.status.denied")
        #expect(CalendarSyncPhase.unavailable.messageKey == "settings.calendar.sync.status.unavailable")
        #expect(CalendarSyncPhase.synced.messageKey == "settings.calendar.sync.status.ok")
        #expect(CalendarSyncPhase.failed.messageKey == "settings.calendar.sync.status.failed")
        #expect(ScreenCaptureFailure.noDisplay.messageKey == "screen.capture.fail.display")
        #expect(ScreenCaptureFailure.permission.messageKey == "screen.capture.fail.permission")
        #expect(ScreenCaptureFailure.encode.messageKey == "screen.capture.fail.encode")
        #expect(ScreenCaptureFailure.unknown.messageKey == "screen.capture.fail.unknown")
    }

    @Test func captureClassifyReadsPermissionWording() {
        #expect(ScreenCaptureFailure.classify(NSError(domain: "tcc", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "User declined screen capture"
        ])) == .permission)
        #expect(ScreenCaptureFailure.classify(NSError(domain: "other", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "device missing"
        ])) == .unknown)
    }

    @Test func diaryLocalizationKeysResolve() {
        let zh = Locale(identifier: "zh-Hans")
        let en = Locale(identifier: "en")
        #expect(L10n.string("header.diary.empty", locale: zh) == "记录即刻灵感与生活")
        #expect(L10n.string("header.diary.empty", locale: en) == "Capture thoughts & moments")
        #expect(L10n.string("header.diary.count \(3)", locale: zh) == "今日已记录 3 条随笔")
        #expect(L10n.string("header.diary.count \(3)", locale: en) == "3 notes today")
        #expect(L10n.format("diary.count_format", locale: zh, 5) == "共 5 条")
        #expect(L10n.format("diary.count_format", locale: en, 5) == "5 notes")
    }
}

