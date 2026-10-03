import Foundation
import Testing
@testable import AreaChain

struct ContentQueryPresentationTests {
    @Test func nineBranchesUseOnlyPublishedPresentation() throws {
        let ordinary = QueryPresentationFixture.project(QueryBatchFixture.mixed())
        #expect(Set(ordinary.rows.map(\.id.type)) == [.todo, .subtask, .routine, .diary, .image, .tag])
        for row in ordinary.rows {
            #expect(row.primary != nil || row.summary != nil)
            #expect(row.lineLimit == 2 && row.treatsContentAsPlainText)
        }
        let child = try #require(ordinary.rows.first { $0.id.type == .subtask })
        #expect(child.relations.first?.title == QueryBatchFixture.common)
        #expect(child.primary?.field == .title && child.summary == nil)
        let image = try #require(ordinary.rows.first { $0.id.type == .image })
        #expect(image.primary?.text == QueryBatchFixture.common + ".png")
        #expect(image.relations.first?.role == .imageOwner && image.relations.first?.title == nil)
        let clipboard = QueryPresentationFixture.project(QueryBatchFixture.mixed("/clipboard batch-common"))
        #expect(clipboard.rows[0].summary?.field == .clipboardPlainText)
        let occurrence = QueryPresentationFixture.project(QueryBatchFixture.occurrences())
        #expect(occurrence.rows[0].primary == nil && occurrence.rows[0].summary == nil)
        #expect(occurrence.rows[0].relations.first?.role == .routine)
        #expect(occurrence.rows[0].metadata.contains { if case .occurrenceStatus = $0 { return true }; return false })
        let trash = QueryPresentationFixture.project(QueryBatchFixture.trash())
        #expect(trash.rows.count == 3)
        #expect(trash.rows.allSatisfy { $0.metadata.contains { if case .deleted = $0 { return true }; return false } })
    }

    @Test func titleOnlyDoesNotFillNotesAndNotesUseHitNeighborhood() {
        let titleOnly = QueryPresentationFixture.todo("alpha", title: "alpha", notes: "irrelevant notes")
        #expect(titleOnly.summary == nil && !titleOnly.canRequestExpansion)
        let row = QueryPresentationFixture.todo("alpha", title: "Task", notes: String(repeating: "前", count: 100) + "alpha trailing")
        #expect(row.primary?.text == "Task")
        #expect(QueryPresentationFixture.highlighted(row.summary) == ["alpha"])
        #expect(row.summary?.text.hasPrefix("…") == true && row.canRequestExpansion)
        #expect(row.expansion == [.init(object: row.id, field: .notes)])
    }

    @Test func lateDiaryBodyDoesNotBecomeTitle() {
        var batch = QueryBatchFixture.mixed("needle")
        var diary = batch.snapshots.diaries.values![0]
        diary.text = String(repeating: "公开段落 ", count: 100) + "needle 尾段"
        batch.snapshots.diaries = .complete([diary])
        let row = QueryPresentationFixture.project(batch).rows[0]
        #expect(row.primary == nil && row.summary?.text.contains("needle") == true)
        #expect(QueryPresentationFixture.highlighted(row.summary) == ["needle"])
    }

    @Test func noPositiveTextPermitsBodyPrefixButNotTaskNotes() {
        let batch = QueryBatchFixture.mixed("")
        let rows = QueryPresentationFixture.project(batch).rows
        #expect(rows.first { $0.id.type == .diary }?.summary?.text == QueryBatchFixture.common)
        #expect(rows.filter { [.todo, .routine].contains($0.id.type) }.allSatisfy { $0.summary == nil })
        let clipboard = QueryPresentationFixture.project(QueryBatchFixture.mixed("/clipboard -missing"))
        #expect(clipboard.rows[0].summary?.text == QueryBatchFixture.common)
        #expect(clipboard.rows[0].summary?.highlights.isEmpty == true)
    }

    @Test func diaryTagOnlyTextEvidenceNeverPaintsBody() throws {
        var batch = QueryBatchFixture.mixed("needle")
        var diary = batch.snapshots.diaries.values![0]
        diary.text = "公开开头不自动填满摘要"
        diary.tagIDs = QueryBatchFixture.id.uuidString
        batch.snapshots.diaries = .complete([diary])
        batch.facts.metadata = .init(tagNames: [QueryBatchFixture.id: "needle"], privateTagIDs: [])
        let row = try #require(QueryPresentationFixture.project(batch).rows.first)
        #expect(row.summary == nil)
        #expect(row.reasons.contains { $0.field == .tags && $0.relatedObject?.id == QueryBatchFixture.id })
        #expect(row.diagnostics.contains(.init(issue: .metadataOnlySummaryOmitted)))
    }

    @Test func orDuplicateConditionsAndExclusionsDoNotInventCoverage() {
        let row = QueryPresentationFixture.todo("(alpha | absent) beta alpha -excluded", title: "Task", notes: "alpha beta")
        #expect(Set(QueryPresentationFixture.highlighted(row.summary)) == ["alpha", "beta"])
        #expect(row.summary?.highlights.count == 2)
        #expect(row.summary?.highlights.first?.sources.count == 2)
        #expect(!row.reasons.contains { $0.kind == .absence })
    }

    @Test func structuredReasonsRemainShortAndHaveNoBodyRanges() {
        var batch = QueryBatchFixture.mixed("#work")
        var todo = batch.snapshots.todos.values![0]
        todo.tagIDs = QueryBatchFixture.id.uuidString
        batch.snapshots.todos = .complete([todo])
        batch.facts.metadata = .init(tagNames: [QueryBatchFixture.id: "work"], privateTagIDs: [])
        let row = QueryPresentationFixture.project(batch).rows[0]
        #expect(row.reasons.contains { $0.field == .tags && $0.relatedObject?.type == .tag })
        #expect(row.primary?.highlights.isEmpty == true && row.summary == nil)
    }

    @Test func markupURLAndCommandsStayLiteral() {
        var batch = QueryBatchFixture.mixed("/clipboard")
        let text = "**bold** <b>html</b> https://example.test /go/settings"
        batch.snapshots.clipboard = .complete([ClipboardQueryFixture.record(1, text)])
        let result = QueryPresentationFixture.project(batch, budget: .init())
        #expect(result.rows[0].summary?.text == text)
        #expect(result.rows[0].treatsContentAsPlainText)
    }
}
