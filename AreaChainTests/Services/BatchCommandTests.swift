import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct BatchCommandTests {
    @Test(arguments: [1, 3, 12]) func datesUseRealBaselinesAndOneSave(count: Int) throws {
        let f = try BatchCommandFixture(count: count)
        let originals = f.todos.map(\.snapshot)
        let other = f.other.snapshot
        let routine = f.routine.snapshot
        try f.queue()
        let accepted = try f.accept()
        #expect(f.count("save") == 0 && f.count("ui") == 0 && !f.context.hasChanges)
        #expect(accepted.preview.impacts.map(\.original) == originals.map { .day($0.dayKey) })
        #expect(accepted.preview.changedCount == count - 1)
        if count > 1 { #expect(accepted.preview.baseline.original(.day, targets: accepted.preview.targets) == .mixed) }
        let facts = try f.submit(accepted)
        #expect(facts.state == (count == 1 ? .noChange : .saved))
        #expect(f.count("save") == (count == 1 ? 0 : 1) && f.count("ui") == (count == 1 ? 0 : 1))
        for (todo, old) in zip(f.todos, originals) {
            #expect(todo.dayKey == "2026-10-09")
            #expect(todo.title == old.title && todo.tagIDs == old.tagIDs && todo.isDone == old.isDone)
            #expect(todo.createdAt == old.createdAt && todo.remindMinutes == old.remindMinutes && todo.notes == old.notes)
            #expect(todo.dueMinutes == 600 && todo.sortOrder == old.sortOrder && todo.calendarEventID == "qa.calendar")
        }
        #expect(f.other.snapshot == other && f.routine.snapshot == routine)
        #expect(f.refreshTargets == Array(f.taskTargets.dropFirst()))
        #expect(try f.handoff.state().execution?.units.count == 1)
        #expect(try f.handoff.state().execution?.units.first?.batch == facts)
    }

    @Test(arguments: [CommandFieldOperation.add, .remove]) func mixedTagsPreserveTypedIdentityAndTagEntities(operation: CommandFieldOperation) throws {
        let f = try BatchCommandFixture()
        let originalTasks = f.todos.map(\.snapshot)
        let originalRoutine = f.routine.snapshot
        let other = f.other.snapshot
        let tagRows = f.tags.map(TaskCreateTagCatalogReader.record)
        let targets = [f.taskTargets[0], .init(type: .routine, id: f.routine.id)]
        try f.queue("batch.tags", argument: f.tagArgument(operation), targets: targets)
        let accepted = try f.accept()
        #expect(accepted.preview.targets.objects.count == 2)
        #expect(accepted.preview.changedCount == 1)
        let facts = try f.submit(accepted)
        #expect(facts.state == .saved && f.count("save") == 1 && f.count("ui") == 1 && f.count("fact") == 1)
        #expect(f.todos[0].tagIDs == (operation == .add ? f.tags[0].id.uuidString : ""))
        #expect(TagIDList.parse(f.routine.tagIDs) == (operation == .add ? [f.tags[2].id, f.tags[0].id] : [f.tags[2].id]))
        #expect(f.tags.map(TaskCreateTagCatalogReader.record) == tagRows)
        #expect(f.other.snapshot == other && f.todos.dropFirst().map(\.snapshot) == Array(originalTasks.dropFirst()))
        #expect(f.routine.title == originalRoutine.title && f.routine.isEnabled == originalRoutine.isEnabled)
        #expect(f.routine.pausedOnDayKey == originalRoutine.pausedOnDayKey && f.routine.remindMinutes == originalRoutine.remindMinutes)
        #expect(f.routine.checks.count == 1 && f.routine.checks[0].isSkipped)
        #expect(facts.impacts == accepted.preview.impacts)
    }

    @Test(arguments: [CommandFieldOperation.add, .remove]) func allNoChangeTagsNeverSave(operation: CommandFieldOperation) throws {
        let f = try BatchCommandFixture()
        let targets = operation == .add ? [f.taskTargets[0]] : Array(f.taskTargets.dropFirst())
        try f.queue("batch.tags", argument: f.tagArgument(operation), targets: targets)
        let accepted = try f.accept()
        #expect(accepted.preview.changedCount == 0)
        #expect(try f.submit(accepted).state == .noChange)
        #expect(f.count("save") == 0 && f.count("ui") == 0 && f.refreshTargets.isEmpty && f.count("fact") == 0)
    }

    @Test(arguments: [0, 1, 2]) func failureAtAnyMemberRollsBackEveryTarget(index: Int) throws {
        let f = try BatchCommandFixture()
        let tasks = f.todos.map(\.snapshot)
        let routine = f.routine.snapshot
        let other = f.other.snapshot
        try f.queue("batch.tags", argument: f.tagArgument(.add, index: 1), targets: [f.taskTargets[0], .init(type: .routine, id: f.routine.id), f.taskTargets[1]])
        let accepted = try f.accept()
        var applied = 0
        f.afterApply = { _ in
            defer { applied += 1 }
            if applied == index { throw TaskCreateCommandIO.Failure.injected }
        }
        let facts = try f.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.save == .notCalled && facts.rollback == .returned)
        #expect(f.todos.map(\.snapshot) == tasks && f.routine.snapshot == routine && f.other.snapshot == other)
        #expect(f.count("save") == 0 && f.count("ui") == 0 && f.refreshTargets.isEmpty && f.count("fact") == 0)
        let fresh = ModelContext(f.io.container)
        #expect(try fresh.fetch(FetchDescriptor<DailyRoutine>()).first?.tagIDs == routine.tagIDs)
        let freshTodos = try fresh.fetch(FetchDescriptor<TodoItem>())
        for old in tasks { #expect(freshTodos.first { $0.id == old.id }?.tagIDs == old.tagIDs) }
    }

    @Test(arguments: [false, true]) func unknownRetainsWholeWriteSetAndCannotReplay(after: Bool) throws {
        let f = try BatchCommandFixture()
        try f.queue("batch.tags", argument: f.tagArgument(.add, index: 1), targets: f.mixedTargets)
        let accepted = try f.accept()
        f.saveMode = after ? .throwAfter : .throwBefore
        let request = try f.request()
        let facts = try f.adapter.execute(request)
        #expect(facts.state == .unknown && facts.save == .called && facts.rollback == .returned)
        #expect(facts.targets == accepted.preview.targets && facts.impacts == accepted.preview.impacts)
        #expect(f.count("save") == 1 && f.count("ui") == 0 && facts.external.isEmpty)
        let another = BatchCommandAdapter(coordinator: f.handoff.coordinator, environment: f.environment)
        #expect(throws: (any Error).self) { try another.execute(request) }
        #expect(throws: (any Error).self) { try f.submit(accepted) }
        #expect(f.count("save") == 1)
        let fresh = ModelContext(f.io.container)
        let rows = try fresh.fetch(FetchDescriptor<TodoItem>())
        for target in f.taskTargets { #expect(TagIDList.parse(rows.first { $0.id == target.id }!.tagIDs).contains(f.tags[1].id) == after) }
        #expect(try f.handoff.state().execution?.units.first?.batch?.impacts == accepted.preview.impacts)
    }

    @Test(arguments: [0, 1, 2]) func savedFactsAndExternalFailuresNeverReplay(kind: Int) throws {
        let f = try BatchCommandFixture()
        try f.queue()
        let accepted = try f.accept()
        if kind == 0 { f.environment.beforePublication = { throw TaskCreateCommandIO.Failure.injected } }
        if kind == 1 { f.afterRegistration = { throw TaskCreateCommandIO.Failure.injected } }
        if kind == 2 { f.externalResult = .failed }
        let facts = try f.submit(accepted)
        #expect(facts.state == .saved && facts.save == .returned)
        #expect(facts.publicationFailed == (kind == 0) && facts.registrationFailed == (kind == 1))
        if kind == 2 { #expect(facts.external.allSatisfy { $0.notification == .failed && $0.calendar == .failed }) }
        #expect(throws: (any Error).self) { try f.submit(accepted) }
        #expect(f.count("save") == 1)
    }
}
