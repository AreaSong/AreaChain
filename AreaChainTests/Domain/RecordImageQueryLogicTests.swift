import Foundation
import Testing
@testable import AreaChain

struct RecordImageQueryLogicTests {
    typealias Fixture = RecordImageQueryFixture

    @Test func andFailureDoesNotHideImageIdentityErrors() {
        let images = [Fixture.image(.todo), Fixture.image(.routine), Fixture.image(.diary)]
        let input = Fixture.input(images + images)
        let todo = Fixture.todo("不存在 has:image", input: input)
        let routine = Fixture.routine("/routines 不存在 has:image", input: input)
        let diary = Fixture.diary("/diaries 不存在 has:image", input: input)
        #expect(todo.matches.isEmpty && todo.undeterminedObjects.isEmpty && todo.isCompleteForCoveredTypes)
        #expect(routine.matches.isEmpty && routine.undeterminedObjects.isEmpty && routine.isCompleteForCoveredTypes)
        #expect(diary.matches.isEmpty && diary.undeterminedObjects.isEmpty && diary.isCompleteForCoveredTypes)
        #expect(todo.diagnostics.contains { $0.issue == .imageAssociation(.association(.duplicateImageID))
            && $0.severity == .error && !$0.affectsDetermination })
        #expect(routine.diagnostics.contains { $0.issue == .imageAssociation(.association(.duplicateImageID))
            && $0.severity == .error && !$0.affectsDetermination })
        #expect(diary.diagnostics.contains { $0.issue == .imageAssociation(.association(.duplicateImageID))
            && $0.severity == .error && !$0.affectsDetermination })
    }

    @Test func imageAlternativesKeepOrTruthAndAllDiagnostics() {
        // 现有文法只允许同维度 OR；两个 has:image 分支共享事实，仍保留各自 alternativeIndex。
        let source = "(has:image | has:image)"
        let present = Fixture.todo(source, input: Fixture.input([Fixture.image(.todo)]))
        #expect(present.matches.count == 1)
        #expect(present.matches[0].evidence.filter { $0.field == .imageAssociation }.map(\.alternativeIndex) == [0, 1])
        let unknown = Fixture.todo(source)
        #expect(unknown.undeterminedObjects.map(\.id) == [Fixture.id] && !unknown.isCompleteForCoveredTypes)
        let id = ContentQueryConditionID(rawValue: 1)
        let owner = AttachmentOwnerKey(kind: .todo, id: Fixture.id)
        let reading = ContentQueryImageRead(conditions: TodoQueryFixture.session("has:image").conditions,
                                            input: nil, owners: .init(todos: [ImageAssociationFixture.todo()]))
        let evaluation = reading.evaluate(owner: owner, conditionID: id)
        #expect(evaluation.reasons.first?.owner == owner && evaluation.reasons.first?.conditionID == id)
        let any = TodoQueryEvaluation.combine([.known([.init(conditionID: id, field: .title)]), evaluation.todo], any: true)
        #expect(any.truth == .matches && any.diagnostics.allSatisfy { !$0.affectsDetermination })
        let routine = RoutineQueryEvaluationResult.combine([.known(true, id: id, field: .title), evaluation.routine], any: true)
        let diary = DiaryQueryEvaluation.combine([.known(true, id: id, field: .diaryBody), evaluation.diary], any: true)
        #expect(routine.truth == .matches && routine.diagnostics.allSatisfy { !$0.affectsDetermination })
        #expect(diary.truth == .matches && diary.diagnostics.allSatisfy { !$0.affectsDetermination })
    }

    @Test func independentValidWitnessSurvivesAnotherBadImage() {
        let image = Fixture.image(.todo)
        let duplicate = Fixture.image(.todo)
        let response = Fixture.todo(input: Fixture.input([duplicate, image, duplicate]))
        #expect(response.matches.map(\.id.id) == [Fixture.id] && response.isCompleteForCoveredTypes)
        #expect(response.diagnostics.contains { $0.issue == .imageAssociation(.association(.duplicateImageID))
            && !$0.affectsDetermination })
    }

    @Test func todoCombinesTextTagsDateStatusAndImage() {
        var todo = ImageAssociationFixture.todo()
        todo.title = "合成任务"
        todo.tagIDs = TodoQueryFixture.work.uuidString
        let input = Fixture.input([Fixture.image(.todo)])
        let response = Fixture.todo("合成 #工作 date:today status:open has:image", values: [todo], input: input)
        #expect(response.matches.map(\.id.id) == [todo.id])
        for field: ContentQueryMatchField in [.title, .tags, .scheduledDay, .completion, .imageAssociation] {
            #expect(response.matches[0].evidence.contains { $0.field == field })
        }
        todo.isDone = true
        #expect(Fixture.todo("status:open has:image", values: [todo]).isCompleteForCoveredTypes)
    }

    @Test func routineImageOnlyNeedsNoHistoryButStatusStillDoes() {
        let routine = RoutineQueryFixture.routine()
        let input = Fixture.input([Fixture.image(.routine, id: routine.id)])
        let only = Fixture.routine(values: [routine], input: input)
        #expect(only.matches.map(\.id.id) == [routine.id] && only.isCompleteForCoveredTypes)
        #expect(only.matches[0].occurrence == nil && only.matches[0].dateExistence == nil)
        let missing = Fixture.routine("/routines on:today status:open has:image", values: [routine], input: input)
        #expect(missing.matches.isEmpty && missing.undeterminedObjects.map(\.id) == [routine.id])
        let session = TodoQueryFixture.session("/routines 合成 date:today on:today status:open has:image")
        let request = RoutineQueryRequest(requestID: TodoQueryFixture.requestID, session: session,
            routines: [routine], tagNames: nil, checks: [], checkCoverage: [RoutineProviderFixture.complete],
            scheduleEvidence: [RoutineProviderFixture.schedule], imageInput: input)
        let complete = RoutineQueryProvider.read(request)
        #expect(complete.matches.map(\.id.id) == [routine.id] && complete.isCompleteForCoveredTypes)
        #expect(complete.matches[0].occurrence?.state == .open && complete.matches[0].dateExistence?.truth == .matches)
        #expect(complete.matches[0].id.type == .routine && complete.matches[0].id.dayKey == nil)
    }

    @Test func duplicateOwnersAndChangedSnapshotNeverReuseOldTruth() {
        let todo = ImageAssociationFixture.todo()
        let input = Fixture.input([Fixture.image(.todo), Fixture.image(.routine), Fixture.image(.diary)])
        #expect(Fixture.todo(input: input).matches.count == 1)
        var deleted = todo
        deleted.deletedAt = ImageAssociationFixture.date
        let duplicate = Fixture.todo(values: [todo, deleted], input: input)
        #expect(duplicate.matches.isEmpty && duplicate.undeterminedObjects.map(\.id) == [todo.id])
        #expect(duplicate.diagnostics.contains { $0.issue == .duplicateTodoID })
        #expect(Fixture.todo(values: [deleted], input: input).matches.isEmpty)
        let changed = Fixture.todo(values: [ImageAssociationFixture.todo(Fixture.otherID)], input: input)
        #expect(changed.matches.isEmpty && changed.undeterminedObjects.isEmpty && changed.isCompleteForCoveredTypes)
        let routine = ImageAssociationFixture.routine()
        let diary = ImageAssociationFixture.diary()
        #expect(Fixture.routine(values: [routine, routine], input: input).undeterminedObjects.map(\.id) == [routine.id])
        #expect(Fixture.diary(values: [diary, diary], input: input).undeterminedObjects.map(\.id) == [diary.id])
    }

    @Test func todoAuxiliaryErrorsRemainVisibleAfterImageCanRuleOutObject() {
        var todo = ImageAssociationFixture.todo()
        todo.tagIDs = TodoQueryFixture.work.uuidString
        let session = TodoQueryFixture.session("#工作 has:image")
        let request = TodoQueryRequest(requestID: TodoQueryFixture.requestID, session: session,
            todos: [todo], tagNames: nil, subtaskData: .unavailable, imageInput: Fixture.input())
        let absent = TodoQueryProvider.read(request)
        #expect(absent.state == .evaluated && absent.matches.isEmpty && absent.undeterminedObjects.isEmpty)
        #expect(absent.isCompleteForCoveredTypes)
        #expect(absent.diagnostics.contains { $0.issue == .missingTagNames && !$0.affectsDetermination })
        var missing = request
        missing.imageInput = nil
        let unknown = TodoQueryProvider.read(missing)
        #expect(unknown.undeterminedObjects.map(\.id) == [todo.id])
        #expect(unknown.diagnostics.contains { $0.issue == .imageAssociationUnavailable && $0.affectsDetermination })
        #expect(unknown.diagnostics.contains { $0.issue == .missingTagNames && $0.affectsDetermination })
        #expect(TodoQueryFixture.read(TodoQueryFixture.session("#工作"), [todo], names: nil).state == .blocked)
    }

    @Test func todoPartialTagAndSubtaskInputsDoNotBlockOtherImageMatches() {
        var first = ImageAssociationFixture.todo()
        first.tagIDs = TodoQueryFixture.work.uuidString
        var other = ImageAssociationFixture.todo(Fixture.otherID)
        other.tagIDs = TodoQueryFixture.study.uuidString
        let request = TodoQueryRequest(requestID: TodoQueryFixture.requestID, session: TodoQueryFixture.session("#工作 has:image"),
            todos: [first, other], tagNames: [TodoQueryFixture.work: "工作"], subtaskData: .includedInSnapshots,
            imageInput: Fixture.input([Fixture.image(.todo), Fixture.image(.todo, id: other.id)]))
        let result = TodoQueryProvider.read(request)
        #expect(result.matches.map(\.id.id) == [first.id] && result.undeterminedObjects.map(\.id) == [other.id])
        let page = TodoQueryFixture.add(.page(.tagID(TodoQueryFixture.work, matching: .taskOrSubtask)),
                                        to: TodoQueryFixture.session("has:image"))
        let subtask = TodoQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, session: page,
            todos: [first], tagNames: nil, subtaskData: .unavailable, imageInput: Fixture.input()))
        #expect(subtask.matches.isEmpty && subtask.undeterminedObjects.isEmpty && subtask.isCompleteForCoveredTypes)
        #expect(subtask.diagnostics.contains { $0.issue == .missingSubtasks && !$0.affectsDetermination })
    }
}
