import Foundation
import Testing
@testable import AreaChain

struct UnifiedSearchTests {
    @Test func protectedSearchSyntaxStaysLiteralAndStillFindsDiaryText() {
        let input = "讨论 \u{0060}代码 !p1 @18:00 片段\u{0060} [说明](#章节)"
        let query = BoardSearch.parseQuery(input)
        #expect(!query.hasPriority && query.remindMinutes == nil && query.tagNames.isEmpty)
        #expect(query.textKeywords == ["讨论", "\u{0060}代码", "!p1", "@18:00", "片段\u{0060}", "[说明](#章节)"])
        let entry = DiarySnapshot(id: UUID(), text: input, dayKey: "2026-09-13", createdAt: .now)
        #expect(BoardSearch.matchesDiary(entry, query: query, tagMap: [:]))
        let compound = BoardSearch.parseQuery(input + " !p2 @09:00 #真实")
        #expect(compound.priority == BoardSearchPriority(isImportant: true, isUrgent: false))
        #expect(compound.remindMinutes == 540 && compound.tagNames == ["真实"])
        #expect(compound.textKeywords == query.textKeywords)
    }

    @Test func subtasksAreIndependentlySearchableAndKeepTheParentRoute() {
        let tagID = UUID()
        let todoID = UUID()
        let child = SubtaskSnapshot(id: UUID(), todoId: todoID, title: "今天很开心", isDone: false, tagIDs: tagID.uuidString)
        let parent = TodoSnapshot(id: todoID, title: "父任务", isDone: false, dayKey: "2026-09-13", subtasks: [child])
        let hits = BoardSearch.hits(query: "#今日", todos: [parent], diaries: [], routines: [], tagMap: [tagID: "今日"])
        #expect(hits.count == 1)
        #expect(hits.first?.id == child.id)
        #expect(hits.first?.kind == .subtask)
        #expect(hits.first?.parentID == todoID)
        #expect(hits.first?.dayKey == parent.dayKey)
        #expect(parent.tagIDs.isEmpty)
    }

    @Test func scopeFiltersChildrenByTheirOwnTags() {
        let tagID = UUID()
        let parentID = UUID()
        let child = SubtaskSnapshot(id: UUID(), todoId: parentID, title: "子任务", isDone: false, tagIDs: tagID.uuidString)
        let parent = TodoSnapshot(id: parentID, title: "父任务", isDone: false, dayKey: "2026-09-13", subtasks: [child])
        let hits = BoardSearch.hits(
            query: "子任务", todos: [parent], diaries: [], routines: [],
            tagMap: [tagID: "今日"], scope: BoardSearchScope(filter: BoardFilter(tagID: tagID))
        )
        #expect(hits.map(\.id) == [child.id])
        var deleted = parent
        deleted.deletedAt = .now
        #expect(BoardSearch.hits(query: "#今日", todos: [deleted], diaries: [], routines: [], tagMap: [tagID: "今日"]).isEmpty)
    }

    @Test func searchUsesRealTagAssociationsRatherThanLiteralFragments() {
        let tagID = UUID()
        let untagged = DiarySnapshot(id: UUID(), text: "#今日 今天很开心", dayKey: "2026-09-13", createdAt: .now)
        var tagged = untagged
        tagged.tagIDs = tagID.uuidString
        let query = BoardSearch.parseQuery("#今日")
        #expect(!BoardSearch.matchesDiary(untagged, query: query, tagMap: [tagID: "今日"]))
        #expect(BoardSearch.matchesDiary(tagged, query: query, tagMap: [tagID: "今日"]))
        #expect(!BoardSearch.matchesDiary(tagged, query: BoardSearch.parseQuery("#今"), tagMap: [tagID: "今日"]))
    }

    @Test func quotedTagsAndCompoundDiarySearchShareTheGlobalRules() {
        let first = UUID()
        let second = UUID()
        let entry = DiarySnapshot(
            id: UUID(), text: "今天很开心", dayKey: "2026-09-13", createdAt: .now,
            tagIDs: TagIDList.encode([first, second])
        )
        let tags = [first: "项目 A", second: "生活"]
        let query = BoardSearch.parseQuery("#\"项目 A\" #生活 开心")
        #expect(query.tagNames == ["项目 A", "生活"])
        #expect(BoardSearch.matchesDiary(entry, query: query, tagMap: tags))
        #expect(BoardSearch.hits(query: query.raw, todos: [], diaries: [entry], routines: [], tagMap: tags).map(\.id) == [entry.id])
        #expect(!BoardSearch.matchesDiary(entry, query: BoardSearch.parseQuery("@15:00"), tagMap: tags))
    }

    @Test func tasksAndHabitsSupportTheSamePriorityAndTimeQuery() {
        let todo = TodoSnapshot(id: UUID(), title: "待办", isDone: false, dayKey: "2026-09-13", remindMinutes: 900, isImportant: true)
        let habit = RoutineSnapshot(
            id: UUID(), title: "习惯", sortOrder: 0, isEnabled: true, createdDayKey: "2026-09-13",
            remindMinutes: 900, isImportant: true
        )
        let hits = BoardSearch.hits(query: "!p2 @15:00", todos: [todo], diaries: [], routines: [habit])
        #expect(Set(hits.map(\.id)) == Set([todo.id, habit.id]))
        #expect(BoardSearch.hits(query: "!p2 @16:00", todos: [todo], diaries: [], routines: [habit]).isEmpty)
        #expect(BoardSearch.parseQuery("@25:00").textKeywords == ["@25:00"])
    }
}
