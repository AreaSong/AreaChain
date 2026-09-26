import Foundation
import Testing
@testable import AreaChain

struct BoardSearchTests {
    @Test func toolbarFiltersNarrowDiariesWithoutInventingTaskProperties() {
        let tagID = UUID()
        let tagged = DiarySnapshot(id: UUID(), text: "会议想法", dayKey: "2026-09-01", createdAt: .now, tagIDs: tagID.uuidString)
        let other = DiarySnapshot(id: UUID(), text: "会议记录", dayKey: "2026-09-10", createdAt: .now)
        let entries = [tagged, other]
        #expect(BoardSearch.filteredDiaries(entries, filter: BoardFilter()) == entries)
        #expect(BoardSearch.filteredDiaries(entries, filter: BoardFilter(tagID: tagID)) == [tagged])
        #expect(BoardSearch.filteredDiaries(entries, filter: BoardFilter(isHighPriorityOnly: true)).isEmpty)
        #expect(BoardSearch.filteredDiaries(entries, filter: BoardFilter(tagID: UUID())).isEmpty)
        #expect(BoardSearch.filteredDiaries(entries, filter: BoardFilter(bundleID: "sample.app")).isEmpty)
    }

    @Test func toolbarFilterAndSyntaxQueryAreIntersectedAcrossDates() {
        let tagID = UUID()
        let old = TodoSnapshot(
            id: UUID(), title: "会议记录", isDone: true, dayKey: "2026-08-01",
            tagIDs: tagID.uuidString, isImportant: true, isUrgent: true
        )
        let other = TodoSnapshot(id: UUID(), title: "会议安排", isDone: false, dayKey: "2026-09-12")
        let filtered = [old, other].filter {
            Classification.matches($0.classifyBits, filter: BoardFilter(tagID: tagID, isHighPriorityOnly: true))
        }
        let hits = BoardSearch.hits(
            query: "会议 #工作 !p1", todos: filtered, diaries: [], routines: [], tagMap: [tagID: "工作"]
        )
        #expect(hits.map(\.id) == [old.id])
        #expect(old.isDone)
    }

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

    @Test func todosMatchNotesWithoutMatchingTitle() {
        let id = UUID()
        let todo = TodoSnapshot(
            id: id, title: "买菜", isDone: false, dayKey: "2026-09-07", notes: "记得带角标贴纸"
        )
        let hits = BoardSearch.hits(query: "角标", todos: [todo], diaries: [], routines: [])
        #expect(hits.map(\.id) == [id])
        #expect(hits.first?.kind == .todo)
        #expect(hits.first?.title == "买菜")
        #expect(
            BoardSearch.hits(
                query: "角标",
                todos: [TodoSnapshot(id: UUID(), title: "买菜", isDone: false, dayKey: "2026-09-07")],
                diaries: [],
                routines: []
            ).isEmpty
        )
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
        let hits = BoardSearch.hits(
            query: "日报",
            todos: [],
            diaries: [],
            routines: [routine],
            todayKey: "2026-09-09"
        )
        #expect(hits.map(\.id) == [id])
        #expect(hits.first?.kind == .routine)
        #expect(hits.first?.dayKey == "2026-09-09")
        #expect(
            BoardSearch.hits(
                query: "xyz",
                todos: [],
                diaries: [],
                routines: [routine],
                todayKey: "2026-09-09"
            ).isEmpty
        )
    }

    @Test func routineHitsLandOnNextScheduledDay() {
        let id = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let routine = RoutineSnapshot(
            id: id,
            title: "写日报",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2026-01-01",
            weekdayMask: WeekdayMask.workdays
        )
        let hits = BoardSearch.hits(
            query: "日报",
            todos: [],
            diaries: [],
            routines: [routine],
            todayKey: "2026-09-05"
        )
        #expect(hits.first?.dayKey == "2026-09-07")
    }

    @Test func disabledRoutinesDoNotAppear() {
        let routine = RoutineSnapshot(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "写日报",
            sortOrder: 0,
            isEnabled: false,
            createdDayKey: "2026-01-01"
        )
        #expect(
            BoardSearch.hits(
                query: "日报",
                todos: [],
                diaries: [],
                routines: [routine],
                todayKey: "2026-09-09"
            ).isEmpty
        )
    }

    @Test func captureAndSearchSharePriorityTokens() {
        let samples: [(String, Bool, Bool)] = [
            ("!p1", true, true),
            ("!P2", true, false),
            ("!重要紧急", true, true),
            ("!紧急不重要", false, true),
            ("!不重要不紧急", false, false)
        ]
        for (token, important, urgent) in samples {
            let parsed = NaturalLanguageParser.parse("任务 \(token)")
            let query = BoardSearch.parseQuery(token)
            #expect(parsed.hasPriorityToken && parsed.isImportant == important && parsed.isUrgent == urgent)
            #expect(query.hasPriority)
            #expect(query.priority == BoardSearchPriority(isImportant: important, isUrgent: urgent))
        }
        #expect(BoardSearch.parseQuery("!nope").hasPriority == false)
    }

    @Test func filterDateReminderAndTagsIntersectWithTheQuery() {
        let tagID = UUID()
        let today = "2026-09-13"
        let due = TodoSnapshot(
            id: UUID(), title: "会议", isDone: false, dayKey: today,
            remindMinutes: 900, tagIDs: tagID.uuidString, sourceBundleID: "mail.app"
        )
        let later = TodoSnapshot(
            id: UUID(), title: "会议", isDone: false, dayKey: "2026-09-20",
            remindMinutes: 900, tagIDs: tagID.uuidString, sourceBundleID: "mail.app"
        )
        let untagged = TodoSnapshot(
            id: UUID(), title: "会议", isDone: false, dayKey: today, remindMinutes: 900, sourceBundleID: "mail.app"
        )
        let scope = BoardSearchScope(filter: BoardFilter(tagID: tagID, bundleID: "mail.app", reminderScope: .set, dateScope: .today))
        let hits = BoardSearch.hits(
            query: "会议", todos: [due, later, untagged], diaries: [], routines: [],
            todayKey: today, tagMap: [tagID: "工作"], scope: scope
        )
        #expect(hits.map { $0.id } == [due.id])
        let diary = DiarySnapshot(id: UUID(), text: "会议", dayKey: today, createdAt: .now, tagIDs: tagID.uuidString)
        #expect(BoardSearch.filteredDiaries([diary], filter: scope.filter).isEmpty)
        #expect(BoardSearch.hits(
            query: "会议", todos: [], diaries: [diary], routines: [], todayKey: today, scope: scope
        ).isEmpty)
    }

    @Test func noTagFilterKeepsUntaggedTodosSubtasksAndDiaries() {
        let tagID = UUID()
        let today = "2026-09-13"
        let plain = TodoSnapshot(id: UUID(), title: "会议", isDone: false, dayKey: today)
        let tagged = TodoSnapshot(
            id: UUID(), title: "会议", isDone: false, dayKey: today, tagIDs: tagID.uuidString
        )
        let parentID = UUID()
        let openChild = UUID()
        let taggedChild = UUID()
        let parent = TodoSnapshot(
            id: parentID, title: "父任务", isDone: false, dayKey: today, tagIDs: tagID.uuidString,
            subtasks: [
                SubtaskSnapshot(id: openChild, todoId: parentID, title: "会议子项", isDone: false),
                SubtaskSnapshot(id: taggedChild, todoId: parentID, title: "会议已标", isDone: false, tagIDs: tagID.uuidString)
            ]
        )
        let bareDiary = DiarySnapshot(id: UUID(), text: "会议", dayKey: today, createdAt: .now)
        let taggedDiary = DiarySnapshot(
            id: UUID(), text: "会议", dayKey: today, createdAt: .now, tagIDs: tagID.uuidString
        )
        let hits = BoardSearch.hits(
            query: "会议",
            todos: [plain, tagged, parent],
            diaries: [bareDiary, taggedDiary],
            routines: [],
            todayKey: today,
            scope: BoardSearchScope(filter: BoardFilter(tagID: BoardFilter.noneID))
        )
        #expect(Set(hits.map(\.id)) == Set([plain.id, openChild, bareDiary.id]))
        #expect(hits.first { $0.id == openChild }?.parentID == parentID)
    }

    @Test func disabledDeletedAndUnscheduledRoutinesStayOutOfDatedSearch() {
        let today = "2026-09-13"
        let live = RoutineSnapshot(
            id: UUID(), title: "日报", sortOrder: 0, isEnabled: true, createdDayKey: today, weekdayMask: WeekdayMask.all
        )
        let stopped = RoutineSnapshot(
            id: UUID(), title: "日报", sortOrder: 1, isEnabled: false, createdDayKey: today, weekdayMask: WeekdayMask.all
        )
        var removed = live
        removed.id = UUID()
        removed.deletedAt = .now
        let scope = BoardSearchScope(filter: BoardFilter(dateScope: .today))
        let hits = BoardSearch.hits(
            query: "日报", todos: [], diaries: [], routines: [live, stopped, removed], todayKey: today, scope: scope
        )
        #expect(hits.map(\.id) == [live.id])
        #expect(hits.first?.dayKey == today)
        #expect(BoardSearch.hits(
            query: "日报", todos: [], diaries: [], routines: [live], todayKey: today,
            scope: BoardSearchScope(filter: BoardFilter(dateScope: .overdue))
        ).isEmpty)
    }

    @Test func hitKindUsesOneTitleKey() {
        #expect(BoardSearchHit.Kind.todo.titleKey == "search.kind.todo")
        #expect(BoardSearchHit.Kind.routine.titleKey == "search.kind.routine")
        #expect(BoardSearchHit.Kind.diary.titleKey == "search.kind.diary")
        #expect(BoardSearchHit.Kind.subtask.titleKey == "search.kind.subtask")
    }
}

struct OverdueBoardSearchTests {
    @Test func overdueSearchUsesTheSameOpenCheckDayAsPending() {
        let today = "2026-09-13"
        let routine = RoutineSnapshot(
            id: UUID(), title: "日报", sortOrder: 0, isEnabled: true,
            createdDayKey: "2026-09-01", weekdayMask: WeekdayMask.all
        )
        let closedYesterday = CheckSnapshot(
            routineId: routine.id, dayKey: "2026-09-12", isDone: true
        )
        let scope = BoardSearchScope(filter: BoardFilter(dateScope: .overdue))
        let openDay = AgendaProjection.overdueRoutines(
            routines: [routine], checks: [], todayKey: today
        ).first?.displayDayKey
        let hits = BoardSearch.hits(
            query: "日报", todos: [], diaries: [], routines: [routine], checks: [],
            todayKey: today, scope: scope
        )
        #expect(hits.map(\.id) == [routine.id])
        #expect(hits.first?.dayKey == openDay)
        #expect(hits.first?.dayKey == "2026-09-12")
        let afterClose = BoardSearch.hits(
            query: "日报", todos: [], diaries: [], routines: [routine], checks: [closedYesterday],
            todayKey: today, scope: scope
        )
        #expect(afterClose.first?.dayKey == "2026-09-11")
        var stopped = routine
        stopped.isEnabled = false
        #expect(BoardSearch.hits(
            query: "日报", todos: [], diaries: [], routines: [stopped], checks: [],
            todayKey: today, scope: scope
        ).isEmpty)
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
        #expect(L10n.string("header.diary.count \(3)", locale: zh) == "今日已记录 3 条手记")
        #expect(L10n.string("header.diary.count \(3)", locale: en) == "3 notes today")
        #expect(L10n.format("diary.count_format", locale: zh, 5) == "共 5 条")
        #expect(L10n.format("diary.count_format", locale: en, 5) == "5 notes")
    }
}
