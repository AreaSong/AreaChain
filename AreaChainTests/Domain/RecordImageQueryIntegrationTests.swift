import Foundation
import Testing
@testable import AreaChain

struct RecordImageQueryIntegrationTests {
    typealias Fixture = RecordImageQueryFixture

    @Test func parserSessionPageAndFrozenContextReachAllThreeProviders() {
        let page = ContentQueryPage.tagContents(tagID: TodoQueryFixture.work, types: [.todo, .routine, .diary])
        let source = TodoQueryFixture.session("SYNTHETIC date:today has:image", page: page)
        let targetPage = ContentQueryPageContext(location: QuerySessionFixture.page().location, page: .overview,
                                                 todayKey: "2027-01-01", calendar: source.queryDates.calendar)
        let frozen = source.handedOff(to: ContentQuerySession(page: targetPage))
        let session = ContentQueryReducer.reduce(frozen, .refreshPage(targetPage)).state
        #expect(session.queryDates.todayKey == QuerySessionFixture.today && session.isStructurallyValid)
        let owners = ImageQueryFixture.owners
        let input = Fixture.input(ImageQueryFixture.images)
        let todo = TodoQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, session: session,
            todos: owners.todos ?? [], tagNames: TodoQueryFixture.names, subtaskData: .includedInSnapshots, imageInput: input))
        let routine = RoutineQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, session: session,
            routines: owners.routines ?? [], tagNames: TodoQueryFixture.names, checks: [], checkCoverage: [],
            scheduleEvidence: [RoutineQueryFixture.evidence("2026-09-01", "2026-10-10", id: Fixture.id)], imageInput: input))
        let diary = DiaryQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, session: session,
            diaries: owners.diaries ?? [], metadata: .init(tagNames: TodoQueryFixture.names, privateTagIDs: []),
            locale: DiaryQueryFixture.locale, imageInput: input))
        #expect(todo.matches.map(\.id.id) == [Fixture.id])
        #expect(routine.matches.map(\.id.id) == [Fixture.id])
        #expect(diary.matches.map(\.id.id) == [Fixture.id])
        let bodyEvidence: [ContentQueryMatchEvidence]
        if case .publicText(_, let evidence) = diary.matches.first?.presentation { bodyEvidence = evidence }
        else { bodyEvidence = [] }
        let evidence = [todo.matches.flatMap(\.evidence), routine.matches.flatMap(\.evidence),
                        diary.matches.flatMap(\.metadataEvidence) + bodyEvidence]
        for values in evidence {
            #expect(Set(values.map(\.conditionID)) == Set(session.conditions.map(\.id)))
            #expect(values.contains { value in session.conditions.contains { $0.id == value.conditionID && $0.origin.isHandoffPage } })
            #expect(values.contains { $0.field == .imageAssociation })
        }
        #expect(todo.typeAnalysis == session.typeAnalysis && routine.typeAnalysis == session.typeAnalysis
                && diary.typeAnalysis == session.typeAnalysis)
    }

    @Test func noImageQueryDoesNotReadUnrelatedInputsOrAlterOldResponses() {
        let session = TodoQueryFixture.session("SYNTHETIC")
        let bad = Fixture.input([Fixture.image(.todo), Fixture.image(.todo)], coverage: .init())
        var todo = TodoQueryRequest(requestID: TodoQueryFixture.requestID, session: session,
            todos: [ImageAssociationFixture.todo()], tagNames: nil, subtaskData: .unavailable)
        var routine = RoutineQueryRequest(requestID: TodoQueryFixture.requestID, session: session,
            routines: [ImageAssociationFixture.routine()], tagNames: nil, checks: [], checkCoverage: [], scheduleEvidence: [])
        var diary = DiaryQueryFixture.request(session, [ImageAssociationFixture.diary()])
        let oldTodo = TodoQueryProvider.read(todo)
        let oldRoutine = RoutineQueryProvider.read(routine)
        let oldDiary = DiaryQueryProvider.read(diary)
        todo.imageInput = bad
        routine.imageInput = bad
        diary.imageInput = bad
        #expect(TodoQueryProvider.read(todo) == oldTodo && oldTodo.matches.count == 1)
        #expect(RoutineQueryProvider.read(routine) == oldRoutine && oldRoutine.matches.count == 1)
        #expect(DiaryQueryProvider.read(diary) == oldDiary && oldDiary.matches.count == 1)
    }

    @Test func unsupportedTypesAndNegationStayUnsupported() {
        var todo = ImageAssociationFixture.todo()
        todo.subtasks = [TodoQueryFixture.subtask(1, parent: todo)]
        let session = TodoQueryFixture.session("has:image")
        let subtask = SubtaskQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, session: session,
            todos: [todo], tagNames: nil, subtaskData: .includedInSnapshots))
        #expect(subtask.state == .inapplicableConditions && subtask.matches.isEmpty)
        let image = ImageQueryFixture.read("/images has:image")
        #expect(image.matches.isEmpty && image.state == .inapplicableConditions)
        #expect(ContentQueryApplicability.binding(.image, to: .routineOccurrence) == .notApplicable)
        #expect(ContentQueryApplicability.binding(.image, to: .clipboardEntry) == .clipboardImage)
        for source in ["-has:image", "-(has:image | has:image)"] {
            #expect(!TodoQueryFixture.session(source).isStructurallyValid)
        }
    }

    @Test func replacedOwnerSnapshotCannotUseOldImageResponse() {
        let association = ImageQueryFixture.association()
        let old = ImageAssociationReader.read(association)
        #expect(old.association(for: .init(kind: .todo, id: Fixture.id)).presence == .present)
        let input = Fixture.input(association.images, coverage: association.coverage)
        // 只能传原始图片资料；新请求没有旧 response / owners / privacy 的注入口。
        let result = Fixture.todo(values: [ImageAssociationFixture.todo(Fixture.otherID)], input: input)
        #expect(result.matches.isEmpty && result.isCompleteForCoveredTypes)
        var coverage = association.coverage
        coverage.owners.objects[.init(kind: .todo, id: Fixture.otherID)] = .notProvided
        let uncovered = Fixture.todo(values: [ImageAssociationFixture.todo(Fixture.otherID)],
                                     input: Fixture.input(association.images, coverage: coverage))
        #expect(uncovered.undeterminedObjects.map(\.id) == [Fixture.otherID])
    }

    @Test func todoUnknownCompletenessSeparatesTypeCoverageAndBadRows() {
        var bad = ImageAssociationFixture.todo(Fixture.otherID)
        bad.dayKey = "invalid"
        let response = Fixture.todo(values: [ImageAssociationFixture.todo(), bad], input: Fixture.input([Fixture.image(.todo)]))
        #expect(response.matches.map(\.id.id) == [Fixture.id] && response.undeterminedObjects.map(\.id) == [Fixture.otherID])
        #expect(response.coverage.coveredTypes == [.todo] && !response.isCompleteForCoveredTypes)
        #expect(response.diagnostics.contains { $0.issue == .invalidScheduledDay && $0.affectsDetermination })
    }
}
