import Foundation
import Testing
@testable import AreaChain

struct DiaryQueryProviderTests {
    @Test func publicCrossFieldAndOrPhrasesAndExclusion() {
        var diary = DiaryQueryFixture.diary(text: "咖啡 研究方案")
        diary.tagIDs = TodoQueryFixture.work.uuidString
        let cases: [(String, Bool)] = [
            ("咖啡 合成工作", true), ("(咖啡 | 茶)", true), ("(茶 | 果汁)", false),
            ("\"研究方案\" 合成工作", true), ("\"方案 合成\"", false),
            ("咖啡 -茶", true), ("咖啡 -合成工作", false), ("-咖啡", false),
            ("-\"研究方案\"", false), ("(茶 | 合成工作) -果汁", true)
        ]
        for (query, expected) in cases {
            let result = DiaryQueryFixture.read("/diaries " + query, [diary])
            #expect(result.state == .evaluated)
            #expect(!result.matches.isEmpty == expected)
            #expect(result.isCompleteForCoveredTypes)
        }
    }

    @Test func evidenceUsesOriginalUnicodeTextAndOriginalTagNames() throws {
        let original = "👩🏽‍💻 Cafe\u{301} 计划"
        var diary = DiaryQueryFixture.diary(text: original)
        diary.tagIDs = TodoQueryFixture.work.uuidString
        let result = DiaryQueryFixture.read("/diaries cafe 合成", [diary])
        let match = try #require(result.matches.first)
        guard case .publicText(let text, let evidence) = match.presentation else { Issue.record("应有公开正文"); return }
        #expect(text == original)
        let body = try #require(evidence.first)
        #expect(body.field == .diaryBody && body.alternativeIndex == 0)
        #expect((text as NSString).substring(with: try #require(body.range)) == "Cafe\u{301}")
        let tag = try #require(match.metadataEvidence.first { $0.field == .tags })
        let name = try #require(match.tags.first { $0.id == tag.relatedObject?.id }?.name)
        #expect((name as NSString).substring(with: try #require(tag.range)) == "合成")
        #expect(!match.metadataEvidence.contains { $0.field == .diaryBody })
    }

    @Test func datesUseOwnDayAndRealCreatedAtAndKeepInputOrder() throws {
        var first = DiaryQueryFixture.diary(3)
        first.isPinned = false
        var second = DiaryQueryFixture.diary(1)
        second.isPinned = true
        second.dayKey = "2026-09-30"
        let createdDay = DayKey.from(first.createdAt, calendar: QuerySessionFixture.page().calendar)
        let query = "/diaries (date:today | date:2026-09-30) created:" + createdDay
        let result = DiaryQueryFixture.read(query, [first, second])
        #expect(result.matches.map(\.id.id) == [first.id, second.id])
        #expect(result.matches.map(\.isPinned) == [false, true])
        #expect(result.matches.allSatisfy { $0.createdAt == first.createdAt })
        #expect(DiaryQueryFixture.read(query + " date:today", [first, second]).matches.map(\.id.id) == [first.id])
        #expect(result.matches.allSatisfy { $0.metadataEvidence.contains { $0.field == .diaryDay } })
        #expect(result.matches.allSatisfy { $0.metadataEvidence.contains { $0.field == .createdAt } })
    }

    @Test func stableTagsNoTagsAndNamedTagsReadOnlyOwnAssociation() {
        var tagged = DiaryQueryFixture.unreadable()
        tagged.tagIDs = TagIDList.encode([TodoQueryFixture.work, TodoQueryFixture.study])
        let empty = DiaryQueryFixture.diary(2)
        #expect(DiaryQueryFixture.read("/diaries #合成工作 #学习笔记", [tagged, empty]).matches.map(\.id.id) == [tagged.id])
        #expect(DiaryQueryFixture.read("/diaries -#合成工作", [tagged, empty]).matches.map(\.id.id) == [empty.id])
        let stable = TodoQueryFixture.add(.page(.tagID(TodoQueryFixture.work, matching: .taskOrSubtask)),
                                           to: TodoQueryFixture.session("/diaries"))
        let missing = DiaryQueryMetadata(tagNames: nil, privateTagIDs: nil)
        let result = DiaryQueryFixture.read(stable, [tagged, empty], metadata: missing)
        #expect(result.matches.map(\.id.id) == [tagged.id])
        #expect(result.isCompleteForCoveredTypes)
        let noTags = TodoQueryFixture.add(.page(.noTags), to: TodoQueryFixture.session("/diaries"))
        #expect(DiaryQueryFixture.read(noTags, [tagged, empty], metadata: missing).matches.map(\.id.id) == [empty.id])
    }

    @Test func liveScopeCoverageAndEmptySnapshotDistinguishTypes() {
        let diary = DiaryQueryFixture.diary()
        let global = DiaryQueryFixture.read("公开", [diary])
        #expect(global.coverage.providerTypes == [.diary] && global.coverage.coveredTypes == [.diary])
        #expect(global.coverage.isPartialTypeCoverage && global.isCompleteForCoveredTypes)
        for query in ["/tasks", "/subtasks", "/routines", "/trash", "/clipboard", "/tags", "/images"] {
            let result = DiaryQueryFixture.read(query, [diary])
            #expect(result.state == .notApplicable && result.matches.isEmpty)
            #expect(result.coverage.coveredTypes.isEmpty)
        }
        let empty = DiaryQueryFixture.read("/diaries", [])
        #expect(empty.matches.isEmpty && empty.isCompleteForCoveredTypes)
        #expect(!empty.coverage.isPartialTypeCoverage)
    }
}
