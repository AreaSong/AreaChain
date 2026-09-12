import Foundation
import Testing
@testable import AreaChain

struct SyntaxAutocompleteTests {
    @Test func searchCandidatesNeverOfferCreationOrUnsupportedTime() {
        let tag = SyntaxTrigger(kind: .tag, query: "工", range: NSRange(location: 0, length: 2))
        let candidates = SyntaxAutocompleteEngine.candidates(for: tag, availableTags: ["工作"], context: .search)
        #expect(candidates.map(\.insertText) == ["#工 ", "#工作 "])
        #expect(candidates.allSatisfy { !$0.isCreation && $0.subtitle == "syntax.search.tag" })

        let time = SyntaxTrigger(kind: .time, query: "", range: NSRange(location: 0, length: 1))
        #expect(SyntaxAutocompleteEngine.candidates(for: time, context: .search).isEmpty)
        #expect(!SyntaxAutocompleteEngine.candidates(for: time).isEmpty)

        let priority = SyntaxTrigger(kind: .priority, query: "", range: NSRange(location: 0, length: 1))
        #expect(SyntaxAutocompleteEngine.candidates(for: priority, context: .search).map(\.insertText)
            == ["!p1 ", "!p2 ", "!p3 ", "!p4 "])
    }

    @Test func detectTriggerBasicSymbols() {
        // Tag trigger
        let triggerTag = SyntaxAutocompleteEngine.detectTrigger(in: "准备报告 #", cursorLocation: 6)
        #expect(triggerTag != nil)
        #expect(triggerTag?.kind == .tag)
        #expect(triggerTag?.query == "")
        #expect(triggerTag?.range.location == 5)
        #expect(triggerTag?.range.length == 1)

        // Tag with query
        let triggerTagWithQuery = SyntaxAutocompleteEngine.detectTrigger(in: "准备报告 #工作", cursorLocation: 8)
        #expect(triggerTagWithQuery != nil)
        #expect(triggerTagWithQuery?.kind == .tag)
        #expect(triggerTagWithQuery?.query == "工作")

        // Priority trigger
        let triggerPriority = SyntaxAutocompleteEngine.detectTrigger(in: "开会 !p1", cursorLocation: 6)
        #expect(triggerPriority != nil)
        #expect(triggerPriority?.kind == .priority)
        #expect(triggerPriority?.query == "p1")

        // Time trigger
        let triggerTime = SyntaxAutocompleteEngine.detectTrigger(in: "@15:00", cursorLocation: 6)
        #expect(triggerTime != nil)
        #expect(triggerTime?.kind == .time)
        #expect(triggerTime?.query == "15:00")
    }

    @Test func detectTriggerBoundaries() {
        // Not a trigger when preceded by letter/number without whitespace
        let insideWord = SyntaxAutocompleteEngine.detectTrigger(in: "test#tag", cursorLocation: 8)
        #expect(insideWord == nil)

        // Empty string
        #expect(SyntaxAutocompleteEngine.detectTrigger(in: "", cursorLocation: 0) == nil)

        // Cursor at 0
        #expect(SyntaxAutocompleteEngine.detectTrigger(in: "#tag", cursorLocation: 0) == nil)

        // Plain text
        #expect(SyntaxAutocompleteEngine.detectTrigger(in: "plain text", cursorLocation: 10) == nil)
    }

    @Test func tagCandidatesCreationAndFiltering() {
        let tags = ["工作", "生活", "学习"]

        // Empty query: returns all existing tags
        let triggerEmpty = SyntaxTrigger(kind: .tag, query: "", range: NSRange(location: 0, length: 1))
        let candidatesEmpty = SyntaxAutocompleteEngine.candidates(for: triggerEmpty, availableTags: tags)
        #expect(candidatesEmpty.count == 3)
        #expect(candidatesEmpty.map(\.title) == ["#工作", "#生活", "#学习"])

        // Query matching existing: does not create new tag candidate
        let triggerMatch = SyntaxTrigger(kind: .tag, query: "工", range: NSRange(location: 0, length: 2))
        let candidatesMatch = SyntaxAutocompleteEngine.candidates(for: triggerMatch, availableTags: tags)
        #expect(candidatesMatch.contains { $0.title == "#工作" })
        #expect(candidatesMatch.first?.isCreation == true) // "工" != "工作", so creation offered first

        // Exact match: no creation candidate
        let triggerExact = SyntaxTrigger(kind: .tag, query: "工作", range: NSRange(location: 0, length: 3))
        let candidatesExact = SyntaxAutocompleteEngine.candidates(for: triggerExact, availableTags: tags)
        #expect(candidatesExact.allSatisfy { !$0.isCreation })
        #expect(candidatesExact.first?.title == "#工作")
    }

    @Test func priorityCandidatesFourLevels() {
        let trigger = SyntaxTrigger(kind: .priority, query: "", range: NSRange(location: 0, length: 1))
        let candidates = SyntaxAutocompleteEngine.candidates(for: trigger)
        #expect(candidates.count == 4)
        #expect(candidates.map(\.title) == ["!p1", "!p2", "!p3", "!p4"])
        #expect(candidates[0].subtitle == "重要且紧急")
        #expect(candidates[1].subtitle == "重要不紧急")
        #expect(candidates[2].subtitle == "紧急不重要")
        #expect(candidates[3].subtitle == "不重要不紧急")
    }

    @Test func applyCandidateReplacement() {
        let text = "写材料 #工"
        let candidate = SyntaxCandidate(
            id: "tag_工作",
            title: "#工作",
            insertText: "#工作 ",
            kind: .tag
        )
        let (newText, newCursor) = SyntaxAutocompleteEngine.applyCandidate(
            candidate,
            to: text,
            range: NSRange(location: 4, length: 2)
        )
        #expect(newText == "写材料 #工作 ")
        #expect(newCursor == 8)
    }

    @Test func compoundSearchQueryParsing() {
        let q1 = BoardSearch.parseQuery("周报 #工作 !p1")
        #expect(q1.textKeywords == ["周报"])
        #expect(q1.tagNames == ["工作"])
        #expect(q1.hasPriority == true)
        #expect(q1.priority?.isImportant == true)
        #expect(q1.priority?.isUrgent == true)

        let q2 = BoardSearch.parseQuery("!p2 学习计划")
        #expect(q2.textKeywords == ["学习计划"])
        #expect(q2.hasPriority == true)
        #expect(q2.priority?.isImportant == true)
        #expect(q2.priority?.isUrgent == false)
    }

    @Test func compoundSearchHitsFiltering() {
        let tagWorkID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let tagLifeID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let tagMap: [UUID: String] = [
            tagWorkID: "工作",
            tagLifeID: "生活"
        ]

        let t1 = TodoSnapshot(
            id: UUID(),
            title: "撰写季度总结",
            isDone: false,
            dayKey: "2026-09-10",
            tagIDs: tagWorkID.uuidString,
            isImportant: true,
            isUrgent: true
        )
        let t2 = TodoSnapshot(
            id: UUID(),
            title: "撰写生活随笔",
            isDone: false,
            dayKey: "2026-09-10",
            tagIDs: tagLifeID.uuidString,
            isImportant: true,
            isUrgent: false
        )
        let t3 = TodoSnapshot(
            id: UUID(),
            title: "总结报告",
            isDone: false,
            dayKey: "2026-09-10",
            tagIDs: tagWorkID.uuidString,
            isImportant: false,
            isUrgent: false
        )

        let todos = [t1, t2, t3]

        // 1. Text only
        let textHits = BoardSearch.hits(query: "总结", todos: todos, diaries: [], routines: [], tagMap: tagMap)
        #expect(textHits.map(\.id) == [t1.id, t3.id])

        // 2. Text + Tag
        let tagHits = BoardSearch.hits(query: "总结 #工作", todos: todos, diaries: [], routines: [], tagMap: tagMap)
        #expect(tagHits.map(\.id) == [t1.id, t3.id])

        // 3. Text + Tag + Priority
        let compoundHits = BoardSearch.hits(query: "总结 #工作 !p1", todos: todos, diaries: [], routines: [], tagMap: tagMap)
        #expect(compoundHits.map(\.id) == [t1.id])
    }
}
