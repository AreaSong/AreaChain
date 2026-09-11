import Foundation
import Testing
@testable import AreaChain

struct ClassificationTests {
    @Test func tagListParsesAndToggles() {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let other = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        #expect(TagIDList.parse("") == [])
        #expect(TagIDList.parse(id.uuidString) == [id])
        let both = TagIDList.toggling(id.uuidString, other)
        #expect(TagIDList.parse(both).contains(id))
        #expect(TagIDList.parse(both).contains(other))
        #expect(TagIDList.parse(TagIDList.toggling(both, id)) == [other])
    }

    @Test func priorityRankIsQuadrantOrder() {
        #expect(Classification.priorityRank(important: true, urgent: true) == 0)
        #expect(Classification.priorityRank(important: true, urgent: false) == 1)
        #expect(Classification.priorityRank(important: false, urgent: true) == 2)
        #expect(Classification.priorityRank(important: false, urgent: false) == 3)
    }

    @Test func boardOrderPutsQuadrantThenTimeThenCreated() {
        let early = Date(timeIntervalSince1970: 1)
        let late = Date(timeIntervalSince1970: 9)
        let both = BoardSortKey(isImportant: true, isUrgent: true, remindMinutes: 600, createdAt: late)
        let important = BoardSortKey(isImportant: true, isUrgent: false, remindMinutes: 60, createdAt: early)
        let urgent = BoardSortKey(isImportant: false, isUrgent: true, remindMinutes: nil, createdAt: early)
        let restTimed = BoardSortKey(isImportant: false, isUrgent: false, remindMinutes: 120, createdAt: late)
        let restLater = BoardSortKey(isImportant: false, isUrgent: false, remindMinutes: nil, createdAt: late)
        let restEarlier = BoardSortKey(isImportant: false, isUrgent: false, remindMinutes: nil, createdAt: early)
        #expect(Classification.precedes(both, important))
        #expect(Classification.precedes(important, urgent))
        #expect(Classification.precedes(urgent, restTimed))
        #expect(Classification.precedes(restTimed, restEarlier))
        #expect(Classification.precedes(restEarlier, restLater))
    }

    @Test func filterMatchesProjectTagAndBundle() {
        let project = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let tag = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let bits = ClassifyBits(
            projectID: project,
            tagIDs: tag.uuidString,
            sourceBundleID: "com.apple.Safari"
        )
        #expect(Classification.matches(bits, filter: BoardFilter()))
        #expect(Classification.matches(bits, filter: BoardFilter(projectID: project)))
        #expect(!Classification.matches(bits, filter: BoardFilter(projectID: UUID())))
        #expect(Classification.matches(bits, filter: BoardFilter(tagID: tag)))
        #expect(!Classification.matches(bits, filter: BoardFilter(tagID: UUID())))
        #expect(Classification.matches(bits, filter: BoardFilter(bundleID: "com.apple.Safari")))
        #expect(!Classification.matches(bits, filter: BoardFilter(bundleID: "com.apple.mail")))
        let child = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        #expect(Classification.matches(bits, filter: BoardFilter(projectID: child), projectIDs: [project, child]))
        #expect(!Classification.matches(bits, filter: BoardFilter(projectID: child), projectIDs: [child]))
    }

    @Test func filterMatchesHighPriorityOnly() {
        let normal = ClassifyBits(isImportant: false, isUrgent: false)
        let important = ClassifyBits(isImportant: true, isUrgent: false)
        let urgent = ClassifyBits(isImportant: false, isUrgent: true)
        let both = ClassifyBits(isImportant: true, isUrgent: true)

        let filter = BoardFilter().withHighPriority(true)
        #expect(filter.isActive)
        #expect(!Classification.matches(normal, filter: filter))
        #expect(Classification.matches(important, filter: filter))
        #expect(Classification.matches(urgent, filter: filter))
        #expect(Classification.matches(both, filter: filter))

        let inactiveFilter = filter.withHighPriority(false)
        #expect(!inactiveFilter.isActive)
        #expect(Classification.matches(normal, filter: inactiveFilter))
    }

    @Test func quadrantSlotMapsTwoSwitches() throws {
        #expect(QuadrantSlot.of(important: true, urgent: true) == .importantUrgent)
        #expect(QuadrantSlot.of(important: true, urgent: false) == .important)
        #expect(QuadrantSlot.of(important: false, urgent: true) == .urgent)
        #expect(QuadrantSlot.of(important: false, urgent: false) == .rest)
        #expect(QuadrantSlot.important.isImportant && !QuadrantSlot.important.isUrgent)
        #expect(CalendarEventPolicy.shouldPublish(isDone: false, deletedAt: nil))
        #expect(!CalendarEventPolicy.shouldPublish(isDone: true, deletedAt: nil))
        #expect(!CalendarEventPolicy.shouldPublish(isDone: false, deletedAt: Date(timeIntervalSince1970: 1)))
        #expect(
            CalendarEventPolicy.shouldUnlinkMissingRemote(
                deletedAt: nil,
                calendarEventID: "ek-1",
                seenRemote: false
            )
        )
        #expect(
            !CalendarEventPolicy.shouldUnlinkMissingRemote(
                deletedAt: nil,
                calendarEventID: "ek-1",
                seenRemote: true
            )
        )
        #expect(
            !CalendarEventPolicy.shouldUnlinkMissingRemote(
                deletedAt: Date(),
                calendarEventID: "ek-1",
                seenRemote: false
            )
        )
        #expect(CalendarEventPolicy.remoteRemindMinutes(isAllDay: true, startDate: Date(timeIntervalSince1970: 8 * 3600)) == nil)
        let start = try #require(DayKey.date(dayKey: "2026-09-09", minutes: 15 * 60 + 30))
        #expect(CalendarEventPolicy.remoteRemindMinutes(isAllDay: false, startDate: start) == 15 * 60 + 30)
        let allDayStart = Date(timeIntervalSince1970: 0)
        #expect(CalendarEventPolicy.remoteDayKey(isAllDay: true, startDate: allDayStart) == "1970-01-01")
        let end = CalendarEventPolicy.allDayEnd(from: allDayStart, calendar: utc)
        #expect(DayKey.from(end, calendar: utc) == "1970-01-02")
        var pacific = Calendar(identifier: .gregorian)
        pacific.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let bounds = try #require(CalendarEventPolicy.allDayBounds(dayKey: "2026-09-09", calendar: pacific))
        #expect(CalendarEventPolicy.remoteDayKey(isAllDay: true, startDate: bounds.start) == "2026-09-09")
        #expect(DayKey.from(bounds.end, calendar: CalendarEventPolicy.gmtGregorian) == "2026-09-10")
        let far = CalendarEventPolicy.eventQueryBounds(
            now: Date(timeIntervalSince1970: 1_788_800_000),
            dayKeys: ["2030-01-01"],
            calendar: utc
        )
        #expect(far.end > DayKey.date(from: "2030-01-01", calendar: utc)!)
        #expect(
            !CalendarEventPolicy.shouldUnlinkMissingRemote(
                deletedAt: nil,
                calendarEventID: "ek-far",
                seenRemote: false,
                dayKey: "2030-01-01",
                windowStart: Date(timeIntervalSince1970: 0),
                windowEnd: Date(timeIntervalSince1970: 10)
            )
        )
        #expect(
            CalendarEventPolicy.shouldRemoveOrphanEvent(
                notes: nil,
                eventIdentifier: "old",
                liveTokens: [],
                knownEventIDs: [],
                unpublishedEventIDs: []
            )
        )
        let token = TodoDragToken.encode(UUID())
        #expect(
            !CalendarEventPolicy.shouldRemoveOrphanEvent(
                notes: token,
                eventIdentifier: "live",
                liveTokens: [token],
                knownEventIDs: ["live"],
                unpublishedEventIDs: []
            )
        )
    }

    @Test func clipboardPrefersTextAndSkipsEmpty() {
        #expect(ClipboardPayload.make(text: " 修角标 ", hasImage: true, imageTitle: "图片")?.title == "修角标")
        #expect(ClipboardPayload.make(text: " 修角标 ", hasImage: true, imageTitle: "图片")?.attachImage == false)
        #expect(ClipboardPayload.make(text: "  ", hasImage: true, imageTitle: "图片") == .init(title: "图片", attachImage: true))
        #expect(ClipboardPayload.make(text: nil, hasImage: false, imageTitle: "图片") == nil)
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
