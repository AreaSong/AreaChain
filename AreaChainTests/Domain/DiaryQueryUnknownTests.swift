import Foundation
import Testing
@testable import AreaChain

struct DiaryQueryUnknownTests {
    @Test func unreadablePositiveNegativeAndCombinationsUseThreeValues() {
        let diary = DiaryQueryFixture.unreadable()
        let cases: [(String, DiaryQueryTruth)] = [
            ("正文词", .unknown), ("-正文词", .unknown), ("合成工作", .matches), ("-合成工作", .doesNotMatch),
            ("合成工作 正文词", .unknown), ("正文词 -合成工作", .doesNotMatch),
            ("(正文词 | 合成工作)", .matches), ("(-正文词 | 合成工作)", .matches),
            ("(-合成工作 | 正文词)", .unknown), ("(-合成工作 | -工作)", .doesNotMatch),
            ("(-合成工作 | -正文词)", .unknown), ("正文词 date:2026-09-01", .doesNotMatch)
        ]
        for (source, truth) in cases {
            let result = DiaryQueryFixture.read("/diaries " + source, [diary])
            #expect(result.state == .evaluated)
            #expect(!result.matches.isEmpty == (truth == .matches))
            #expect(!result.undeterminedObjects.isEmpty == (truth == .unknown))
            #expect(result.isCompleteForCoveredTypes == (truth != .unknown))
            // 即使 AND/OR 已可决定结果，仍保留正文不可读的诊断。
            #expect(result.diagnostics.contains { $0.issue == .bodyUnavailable })
        }
    }

    @Test func readableAbsenceIsDifferentFromUnavailableBody() {
        let readable = DiaryQueryFixture.diary(text: "")
        var unreadable = readable
        unreadable.isContentAvailable = false
        #expect(DiaryQueryFixture.read("/diaries 任意", [readable]).isCompleteForCoveredTypes)
        #expect(DiaryQueryFixture.read("/diaries -任意", [readable]).matches.count == 1)
        #expect(!DiaryQueryFixture.read("/diaries 任意", [unreadable]).isCompleteForCoveredTypes)
        #expect(!DiaryQueryFixture.read("/diaries -任意", [unreadable]).isCompleteForCoveredTypes)
    }

    @Test func placeholderNeverSearchesAndMetadataNeedsNoReadableBody() {
        let diary = DiaryQueryFixture.unreadable()
        let placeholder = DiaryQueryFixture.read("/diaries 占位文本", [diary])
        #expect(placeholder.matches.isEmpty && placeholder.undeterminedObjects.count == 1)
        for source in ["/diaries date:today", "/diaries #合成工作", "/diaries -#学习笔记"] {
            let result = DiaryQueryFixture.read(source, [diary])
            #expect(result.matches.count == 1 && result.isCompleteForCoveredTypes)
            #expect(!result.diagnostics.contains { $0.issue == .bodyUnavailable })
        }
    }

    @Test func missingNamesDoNotEraseAssociationsAndKnownFieldsCanDecide() {
        var diary = DiaryQueryFixture.diary(text: "正文词")
        diary.tagIDs = TagIDList.encode([TodoQueryFixture.work, TodoQueryFixture.study])
        let partial = DiaryQueryMetadata(tagNames: [TodoQueryFixture.work: "合成工作"], privateTagIDs: [])
        for source in ["合成工作", "#合成工作", "正文词"] {
            let result = DiaryQueryFixture.read("/diaries " + source, [diary], metadata: partial)
            #expect(result.matches.count == 1 && result.isCompleteForCoveredTypes)
            #expect(result.diagnostics.contains { $0.issue == .missingAssociatedTagName(TodoQueryFixture.study) })
        }
        for source in ["学习笔记", "#学习笔记", "-学习笔记", "-#学习笔记"] {
            let result = DiaryQueryFixture.read("/diaries " + source, [diary], metadata: partial)
            #expect(result.matches.isEmpty && result.undeterminedObjects.count == 1)
        }
        #expect(DiaryQueryFixture.read("/diaries -合成工作", [diary], metadata: partial).isCompleteForCoveredTypes)
        let missing = DiaryQueryMetadata(tagNames: nil, privateTagIDs: [])
        let result = DiaryQueryFixture.read("/diaries #合成工作", [diary], metadata: missing)
        #expect(result.diagnostics.contains { $0.issue == .missingTagNames })
        #expect(result.undeterminedObjects.count == 1)
        // 真正无关联不依赖名字表即可证明结构化排除标签。
        #expect(DiaryQueryFixture.read("/diaries -#合成工作", [DiaryQueryFixture.diary()], metadata: missing).matches.count == 1)
    }

    @Test func unknownObjectsDoNotHideOtherDefiniteResults() {
        let uncertain = DiaryQueryFixture.unreadable(1)
        let known = DiaryQueryFixture.diary(2, text: "正文词")
        let result = DiaryQueryFixture.read("/diaries 正文词", [uncertain, known])
        #expect(result.matches.map(\.id.id) == [known.id])
        #expect(result.undeterminedObjects == [.init(type: .diary, id: uncertain.id)])
        #expect(!result.isCompleteForCoveredTypes)
    }
}
