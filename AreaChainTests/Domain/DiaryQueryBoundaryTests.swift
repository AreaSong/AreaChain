import Foundation
import Testing
@testable import AreaChain

struct DiaryQueryBoundaryTests {
    @Test func malformedAssociationsCannotBecomePublicOrProveNoTags() {
        var diary = DiaryQueryFixture.diary(text: DiaryQueryFixture.secret)
        diary.tagIDs = "invalid-id"
        let noTags = TodoQueryFixture.add(.page(.noTags), to: TodoQueryFixture.session("/diaries"))
        let unknown = DiaryQueryFixture.read(noTags, [diary])
        #expect(unknown.undeterminedObjects.count == 1)
        #expect(unknown.diagnostics.contains { $0.issue == .invalidTagIDs })
        #expect(DiaryQueryFixture.read("/diaries -#合成工作", [diary]).undeterminedObjects.count == 1)
        let byDate = DiaryQueryFixture.read("/diaries date:today", [diary])
        #expect(byDate.matches.count == 1 && byDate.isCompleteForCoveredTypes)
        let leaked = DiaryQueryFixture.containsSecret(byDate)
        #expect(!leaked)
    }

    @Test func duplicateLiveAndDeletedIdentitiesAreAllQuarantined() {
        let first = DiaryQueryFixture.diary(1)
        var deleted = first
        deleted.deletedAt = TodoQueryFixture.created
        let valid = DiaryQueryFixture.diary(2)
        let result = DiaryQueryFixture.read("/diaries", [first, valid, deleted])
        #expect(result.matches.map(\.id) == [.init(type: .diary, id: valid.id)])
        #expect(result.undeterminedObjects == [.init(type: .diary, id: first.id)])
        #expect(result.diagnostics.contains { $0.issue == .duplicateDiaryID && $0.inputIndices == [0, 2] })
        #expect(DiaryQueryFixture.read("/diaries", [deleted]).matches.isEmpty)
        #expect(DiaryQueryFixture.read("/diaries", [deleted]).isCompleteForCoveredTypes)
        #expect(DiaryQueryFixture.read("/diaries", [first, first]).matches.isEmpty)
        #expect(DiaryQueryFixture.read("/diaries", [deleted, deleted]).diagnostics.contains { $0.issue == .duplicateDiaryID })
    }

    @Test func badDatesAndTimestampsDoNotContaminateOtherObjects() {
        var badDay = DiaryQueryFixture.diary(1)
        badDay.dayKey = "2026-02-30"
        var badTime = DiaryQueryFixture.diary(2)
        badTime.createdAt = Date(timeIntervalSince1970: .infinity)
        let valid = DiaryQueryFixture.diary(3)
        let result = DiaryQueryFixture.read("/diaries", [badDay, badTime, valid])
        #expect(result.matches.map(\.id.id) == [valid.id])
        #expect(result.undeterminedObjects.count == 2)
        #expect(result.diagnostics.contains { $0.issue == .invalidDiaryDay })
        #expect(result.diagnostics.contains { $0.issue == .invalidCreatedAt })
    }

    @Test func inapplicableFieldsAndOldTaskPagePredicatesStayExplicit() {
        let diary = DiaryQueryFixture.diary()
        for query in ["!p1", "@15:30", "status:done", "status:open", "status:skipped", "on:today", "(status:open | status:done)"] {
            let response = DiaryQueryFixture.read("/diaries " + query, [diary])
            #expect(response.state == .inapplicableConditions)
            #expect(response.typeAnalysis.assessment(for: .diary)?.reasons.contains { $0.issue == .fieldNotApplicable } == true)
        }
        let predicates: [ContentQueryPagePredicate] = [
            .todoStatus(.done), .routineStatus(.enabled), .taskPriority(.init(scope: .p1)),
            .reminderPresence(.set), .sourceApplication("synthetic.app"), .itemKind(.oneOff),
            .boardDate(.today, .init(evaluation: .items, todayKey: QuerySessionFixture.today, calendar: QuerySessionFixture.page().calendar))
        ]
        for predicate in predicates {
            let session = TodoQueryFixture.add(.page(predicate), to: TodoQueryFixture.session("/diaries"))
            #expect(DiaryQueryFixture.read(session, [diary]).state == .inapplicableConditions)
        }
    }

    @Test func imageCapabilityIsSeparateFromObjectUncertaintyAndSeverity() {
        let diary = DiaryQueryFixture.diary()
        let unknown = DiaryQueryFixture.read("/diaries has:image", [diary])
        #expect(unknown.state == .evaluated && unknown.undeterminedObjects.count == 1)
        #expect(unknown.diagnostics.contains { $0.issue == .imageAssociationUnavailable && $0.affectsDetermination })
        let ruledOut = DiaryQueryFixture.read("/diaries has:image date:2026-09-01", [diary])
        #expect(ruledOut.matches.isEmpty && ruledOut.isCompleteForCoveredTypes)
        #expect(ruledOut.diagnostics.contains { $0.issue == .imageAssociationUnavailable && $0.severity == .error && !$0.affectsDetermination })
        let empty = DiaryQueryFixture.read("/diaries has:image", [])
        #expect(empty.diagnostics.contains { $0.issue == .imageAssociationUnavailable })
    }

    @Test func invalidStructureConditionIdentityAndContradictionAreNotZeroResults() {
        let rows = [DiaryQueryFixture.diary()]
        #expect(DiaryQueryFixture.read("/diaries (词 |", rows).state == .invalidQuery)
        #expect(DiaryQueryFixture.read("/diaries date:today date:2026-09-01", rows).state == .unsatisfiable)
        var duplicate = TodoQueryFixture.session("/diaries 词")
        duplicate.conditions.append(duplicate.conditions[0])
        #expect(DiaryQueryFixture.read(duplicate, rows).state == .invalidQuery)
    }
}
