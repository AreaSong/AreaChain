import Foundation
import Testing
@testable import AreaChain

struct BoardPageTests {
    @Test func taskAndDiaryKeepSeparateFiltersOfTheSameType() {
        var filters = BoardFilters()
        filters.write(BoardFilter(tagID: UUID(), dateScope: .today), for: .tasks)
        filters.write(BoardFilter(tagID: UUID(), priorityScope: .p1), for: .diary)

        let tasks = filters.selection(for: .tasks)
        let diary = filters.selection(for: .diary)
        #expect(tasks.tagID != nil && tasks.dateScope == .today)
        #expect(diary.tagID != nil && diary.priorityScope == .all)
        #expect(filters.activeCount(for: .tasks) == 2)
        #expect(filters.activeCount(for: .diary) == 1)

        filters.clear(.diary)
        #expect(filters.selection(for: .diary) == BoardFilter())
        #expect(filters.selection(for: .tasks).tagID != nil)
    }

    @Test func priorityAndDateTitlesStayOnTheSharedFilter() {
        let locale = Locale(identifier: "zh-Hans")
        #expect(DateFilterScope.today.title(locale: locale) == L10n.string("filter.date.today", locale: locale))
        #expect(BoardFilter(priorityScope: .p3).priorityTitle(locale: locale) == L10n.string("filter.priority.p3", locale: locale))
        #expect(BoardFilter().priorityTitle(locale: locale).isEmpty)
    }
}
