import Foundation
import Testing
@testable import AreaChain

struct ContentQueryTypeAnalysisTests {
    @Test func overdueParentCanReturnCompletedChildThroughOriginalParser() throws {
        for (lane, day) in [(PendingLane.overdue, "2026-09-30"), (.upcoming, "2026-10-02")] {
            var parent = SubtaskQueryFixture.parent(1, day: day)
            parent.subtasks[0].isDone = true
            let session = TodoQueryFixture.session("/tasks status:done", page: .pending(lane: lane, filter: .init()))
            let before = session
            let result = SubtaskQueryFixture.read(session, [parent])
            #expect(result.queryIsValid && result.state == .evaluated)
            #expect(result.matches.map(\.id.id) == [parent.subtasks[0].id])
            #expect(session == before && session.isReady && session.isStructurallyValid)
            #expect(result.typeAnalysis.requestedTypes == [.todo, .subtask, .routine])
            #expect(result.typeAnalysis.possibleTypes == [.subtask, .routine])
            let todo = TodoQueryFixture.read(session, [parent])
            #expect(todo.queryIsValid && todo.state == .unsatisfiable && todo.matches.isEmpty)
            #expect(todo.typeAnalysis.assessment(for: .todo)?.reasons.contains { $0.binding == .ownCompletion } == true)
            #expect(result.typeAnalysis.assessment(for: .routine)?.requiresInput == true)
            let match = try #require(result.matches.first)
            #expect(match.evidence.contains { $0.field == .completion && $0.relatedObject == nil })
            #expect(match.evidence.contains { $0.field == .parentScheduledDay && $0.relatedObject == match.parent })
            #expect(match.evidence.contains { $0.field == .parentCompletion && $0.relatedObject == match.parent })
            #expect(result.coverage.isPartialTypeCoverage && result.isCompleteForCoveredTypes)
            #expect(todo.coverage.isPartialTypeCoverage && !todo.isCompleteForCoveredTypes)
        }
    }

    @Test func parentAndOwnCompletionAreIndependentButSameObjectConflicts() {
        var parent = SubtaskQueryFixture.parent(1)
        parent.isDone = true
        parent.subtasks[0].isDone = false
        let query = TodoQueryFixture.session("status:open", page: .items(.init(todoStatus: .done, todayKey: QuerySessionFixture.today)))
        #expect(SubtaskQueryFixture.read(query, [parent]).matches.map(\.id.id) == [parent.subtasks[0].id])
        #expect(TodoQueryFixture.read(query, [parent]).state == .unsatisfiable)
        let ownConflict = TodoQueryFixture.session("/subtasks status:open status:done")
        #expect(ownConflict.isStructurallyValid && !ownConflict.isReady)
        #expect(ownConflict.typeAnalysis.possibleTypes.isEmpty)
        #expect(SubtaskQueryFixture.read(ownConflict, [parent]).state == .unsatisfiable)
        let parentConflict = TodoQueryFixture.add(.page(.todoStatus(.done)), to:
            TodoQueryFixture.session("status:done", page: .pending(lane: .overdue, filter: .init())))
        #expect(parentConflict.typeAnalysis.assessment(for: .subtask)?.reasons.contains {
            $0.issue == .contradiction && $0.binding == .parentCompletion
        } == true)
    }

    @Test func allTypesExcludedAndMissingDayAreNotConfusedWithStructure() {
        let all = TodoQueryFixture.session("/tasks !p1 !p2")
        #expect(all.isStructurallyValid && !all.isReady)
        #expect(all.typeAnalysis.requestedTypes == [.todo, .subtask, .routine])
        #expect(all.typeAnalysis.possibleTypes.isEmpty)
        #expect(all.typeAnalysis.assessment(for: .subtask)?.reasons.allSatisfy { $0.issue == .fieldNotApplicable } == true)
        #expect(all.typeAnalysis.assessment(for: .routine)?.reasons.contains { $0.issue == .contradiction } == true)
        let routine = TodoQueryFixture.session("/routines status:done date:today")
        #expect(routine.typeAnalysis.possibleTypes == [.routine])
        #expect(routine.typeAnalysis.assessment(for: .routine)?.requiresInput == true)
        let selected = ContentQueryTypeValidation.analyze(routine.conditions, requestedTypes: [.routine], occurrenceDay: "2026-10-01")
        #expect(selected.assessment(for: .routine)?.reasons.isEmpty == true)
        let noDay = TodoQueryFixture.session("/tasks status:open status:done")
        #expect(noDay.typeAnalysis.possibleTypes.isEmpty)
        #expect(noDay.typeAnalysis.assessment(for: .routine)?.requiresInput == true)
        #expect(noDay.typeAnalysis.assessment(for: .routine)?.reasons.contains { $0.issue == .contradiction } == true)
    }

    @Test func structureErrorsRemainGlobalAndOriginalInputIsUnchanged() {
        for source in ["/tasks status:done \"未闭合", "/tasks date:2026-02-30", "/tasks unknown:value"] {
            let query = TodoQueryFixture.session(source)
            let before = query.conditions
            #expect(!query.isStructurallyValid)
            let todo = TodoQueryFixture.read(query, [])
            let child = SubtaskQueryFixture.read(query, [])
            #expect(todo.state == .invalidQuery && child.state == .invalidQuery)
            #expect(todo.textDiagnostics == query.textDiagnostics && child.conditionDiagnostics == query.conditionDiagnostics)
            #expect(query.conditions == before)
        }
        var duplicate = TodoQueryFixture.session("/tasks 汇报")
        duplicate.conditions.append(duplicate.conditions[0])
        #expect(!duplicate.isStructurallyValid)
        #expect(duplicate.conditionDiagnostics.contains { $0.issue == .ambiguousConditionIDs })
    }

    @Test func capabilityAndRecordFailuresDoNotBecomeSemanticExclusion() {
        let parent = SubtaskQueryFixture.parent(1)
        let query = TodoQueryFixture.session("/tasks #工作")
        let missing = SubtaskQueryFixture.read(query, [parent], names: nil, subtasks: .unavailable)
        #expect(missing.state == .blocked && !missing.isCompleteForCoveredTypes)
        #expect(missing.typeAnalysis.possibleTypes == missing.typeAnalysis.requestedTypes)
        #expect(Set(missing.diagnostics.map { String(describing: $0.issue) }) == ["missingSubtasks", "missingTagNames"])
        let image = TodoQueryFixture.read("/tasks has:image", [parent])
        #expect(image.state == .evaluated && image.diagnostics.first?.issue == .imageAssociationUnavailable)
        #expect(image.undeterminedObjects.map(\.id) == [parent.id] && !image.isCompleteForCoveredTypes)
        #expect(image.typeAnalysis.assessment(for: .subtask)?.readRestriction == .inapplicableConditions)
        let duplicate = SubtaskQueryFixture.read(TodoQueryFixture.session("/tasks"), [parent, parent])
        #expect(duplicate.state == .evaluated && !duplicate.isCompleteForCoveredTypes)
        #expect(duplicate.diagnostics.contains { $0.issue == .duplicateTodoID })
        #expect(duplicate.typeAnalysis.possibleTypes == [.todo, .subtask, .routine])
    }

    @Test func dateBindingsAndUnknownAssociationsAreConservative() {
        let rule = ContentQueryPageDateRule(evaluation: .listedDay, todayKey: QuerySessionFixture.today,
                                           calendar: QuerySessionFixture.page().calendar)
        let query = TodoQueryFixture.add(.page(.boardDate(.overdue, rule)), to:
            TodoQueryFixture.session("/tasks date:today created:today"))
        #expect(query.typeAnalysis.assessment(for: .subtask)?.reasons.contains { $0.binding == .parentScheduledDay } == true)
        #expect(query.typeAnalysis.assessment(for: .todo)?.reasons.contains { $0.binding == .scheduledDay } == true)
        #expect(query.typeAnalysis.assessment(for: .routine)?.isPossible == true)
        let tag = TodoQueryFixture.add(.page(.tagID(TodoQueryFixture.work, matching: .taskOrSubtask)), to:
            TodoQueryFixture.add(.page(.noTags), to: TodoQueryFixture.session("/tasks")))
        #expect(tag.typeAnalysis.assessment(for: .todo)?.isPossible == true)
        #expect(tag.typeAnalysis.assessment(for: .subtask)?.isPossible == false)
        let unknown = TodoQueryFixture.session("/tasks #不存在的标签")
        #expect(unknown.typeAnalysis.possibleTypes == [.todo, .subtask, .routine])
    }
}
