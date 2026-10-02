import Foundation
import Testing
@testable import AreaChain

struct DiaryQueryIntegrationTests {
    @Test func explicitDiaryCompositionIsValidWithoutAllowingOtherScopes() {
        let dates = QuerySessionFixture.page().dates
        #expect(ContentQueryConditionValidation.invalid(.page(.contentTypes([.diary])), dates: dates) == nil)
        #expect(ContentQueryConditionValidation.invalid(.page(.contentTypes([.todo, .diary])), dates: dates) == nil)
        #expect(ContentQueryConditionValidation.invalid(.page(.contentTypes([.image, .diary])), dates: dates) == nil)
        #expect(ContentQueryConditionValidation.invalid(.page(.contentTypes([.tag, .diary])), dates: dates) == nil)
        for types: Set<CommandObjectType> in [[], [.clipboardEntry], [.routineOccurrence], [.diary, .clipboardEntry]] {
            #expect(ContentQueryConditionValidation.invalid(.page(.contentTypes(types)), dates: dates) == .invalidCondition)
        }
    }

    @Test func parserSessionTypeAnalysisAndProviderPreserveConditionIdentity() {
        let source = "/diaries (正文 | 茶) -咖啡 date:today"
        let session = TodoQueryFixture.session(source)
        let before = session
        let response = DiaryQueryFixture.read(session, [DiaryQueryFixture.diary()])
        #expect(session == before && session.isStructurallyValid)
        #expect(response.requestID == TodoQueryFixture.requestID)
        #expect(response.typeAnalysis == session.typeAnalysis)
        #expect(response.typeAnalysis.possibleTypes == [.diary])
        #expect(response.matches.count == 1)
        #expect(response.matches[0].metadataEvidence.allSatisfy { item in session.conditions.contains { $0.id == item.conditionID } })
        if case .publicText(_, let evidence) = response.matches[0].presentation {
            #expect(evidence.allSatisfy { item in session.conditions.contains { $0.id == item.conditionID } })
        } else { Issue.record("公开结果应包含正文依据") }
    }

    @Test func pageTagUserTakeoverAndFrozenHandoffAllParticipate() {
        var work = DiaryQueryFixture.diary(1)
        work.tagIDs = TodoQueryFixture.work.uuidString
        var study = DiaryQueryFixture.diary(2)
        study.tagIDs = TodoQueryFixture.study.uuidString
        let page = ContentQueryPage.diaries(tagID: TodoQueryFixture.work)
        let automatic = TodoQueryFixture.session("正文", page: page)
        #expect(DiaryQueryFixture.read(automatic, [work, study]).matches.map(\.id.id) == [work.id])
        let takeover = ContentQueryReducer.reduce(automatic, .setInput("正文 #学习笔记")).state
        #expect(DiaryQueryFixture.read(takeover, [work, study]).matches.map(\.id.id) == [study.id])
        let target = ContentQuerySession(page: QuerySessionFixture.page(.diaries(tagID: TodoQueryFixture.study), visit: "target"))
        let frozen = automatic.handedOff(to: target)
        let response = DiaryQueryFixture.read(frozen, [work, study])
        #expect(response.matches.map(\.id.id) == [work.id])
        #expect(response.matches[0].metadataEvidence.contains { item in
            frozen.conditions.contains { $0.id == item.conditionID && $0.origin.isHandoffPage }
        })
        let mixed = TodoQueryFixture.session("正文", page: .tagContents(tagID: TodoQueryFixture.work, types: [.todo, .diary]))
        let subset = DiaryQueryFixture.read(mixed, [work, study])
        #expect(subset.coverage.requestedTypes == [.todo, .diary] && subset.coverage.isPartialTypeCoverage)
        #expect(subset.matches.map(\.id.id) == [work.id])
    }

    @Test func legacyCommonSubsetAgreesAndUnreadableDifferenceIsExplicit() {
        var plain = DiaryQueryFixture.diary(1, text: "共同关键词")
        plain.tagIDs = TodoQueryFixture.work.uuidString
        var privateReadable = DiaryQueryFixture.diary(2, text: "共同关键词 #password")
        privateReadable.tagIDs = TodoQueryFixture.work.uuidString
        let unreadable = DiaryQueryFixture.unreadable(3)
        let rows = [plain, privateReadable, unreadable]
        for source in ["共同关键词", "合成工作", "共同关键词 合成工作", "#合成工作", "不存在"] {
            let query = BoardSearch.parseQuery(source)
            let old = rows.filter { BoardSearch.matchesDiary($0, query: query, tagMap: DiaryQueryFixture.names) }
            let new = DiaryQueryFixture.read("/diaries " + source, rows)
            #expect(Set(new.matches.map(\.id.id)) == Set(old.map(\.id)))
            let hits = BoardSearch.hits(query: source, todos: [], diaries: rows, routines: [], tagMap: DiaryQueryFixture.names,
                privacy: .init(placeholder: L10n.string("diary.private.title", locale: DiaryQueryFixture.locale)))
            for match in new.matches {
                let title: String
                switch match.presentation {
                case .publicText(let text, _): title = text
                case .hiddenTitle(let value): title = value
                }
                #expect(hits.first { $0.id == match.id.id }?.title == title)
            }
        }
        let unknown = DiaryQueryFixture.read("/diaries 不存在", [unreadable])
        #expect(unknown.undeterminedObjects.count == 1 && !unknown.isCompleteForCoveredTypes)
        #expect(!BoardSearch.matchesDiary(unreadable, query: BoardSearch.parseQuery("不存在"), tagMap: DiaryQueryFixture.names))
    }
}
