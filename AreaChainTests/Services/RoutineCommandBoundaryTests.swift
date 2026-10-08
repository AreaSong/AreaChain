import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct RoutineCommandBoundaryTests {
    typealias Fixture = RoutineCommandFixture

    @Test(arguments: [0, -1, 128, 255]) func invalidWeekdaysRemainInvalid(mask: Int) throws {
        let fixture = try Fixture()
        try fixture.queue("routine.weekdays", .init(parameter: .weekdays, operation: .assign, value: .weekdays(mask)))
        #expect(throws: (any Error).self) { try fixture.preview() }
        #expect(try fixture.handoff.state().plan.items.first?.draft.arguments[0].value == .weekdays(mask))
        #expect(fixture.base.io.trace.isEmpty)
    }

    @Test(arguments: ["one\ntwo", "one\rtwo", "title // notes", "title\n", "#密码", "#日记", ""])
    func rejectedTitleKeepsRawInput(raw: String) throws {
        let fixture = try Fixture()
        try fixture.queue("routine.title", Fixture.title(raw))
        #expect(throws: (any Error).self) { try fixture.preview() }
        #expect(try fixture.handoff.state().plan.items.first?.draft.arguments[0].value == .shortText(raw))
        #expect(fixture.base.io.trace.isEmpty)
    }

    @Test(arguments: [CommandObjectType.todo, .subtask, .routineOccurrence]) func sameUUIDCannotSubstitute(type: CommandObjectType) throws {
        let fixture = try Fixture()
        try fixture.queue("routine.title", Fixture.title("New"), target: .init(type: type, id: fixture.routine.id,
            dayKey: type == .routineOccurrence ? "2026-10-08" : nil))
        #expect(throws: (any Error).self) { try fixture.preview() }
        #expect(fixture.count("save") == 0)
    }

    @Test(arguments: Array(0...8)) func staleIdentitySourceAndCatalogReject(kind: Int) throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("routine.title", Fixture.title("New #New"))
        switch kind {
        case 0: fixture.routine.deletedAt = .now
        case 1: fixture.context.insert(DailyRoutine(id: fixture.routine.id, title: "duplicate", sortOrder: 0))
        case 2: fixture.context.insert(DailyRoutine(id: fixture.routine.id, title: "tombstone", sortOrder: 0, deletedAt: .now))
        case 3: fixture.targetRevision = UUID()
        case 4: fixture.inputRevision = UUID()
        case 5: fixture.notes = .unknown
        case 6: fixture.base.live.name = "Changed"
        case 7: fixture.routine.title = "External"
        default: fixture.base.live.name = "密码"
        }
        try fixture.context.save()
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test(arguments: [CommandFieldOperation.remove, .clear], [0, 1, 2]) func removalCannotBypassD3(mode: CommandFieldOperation, kind: Int) throws {
        let fixture = try Fixture()
        if kind == 0 { fixture.routine.tagIDs = UUID().uuidString }
        if kind == 1 { fixture.base.live.name = "密码" }
        if kind == 2 { fixture.context.insert(TagItem(id: fixture.base.live.id, name: "Duplicate", sortOrder: 5)) }
        try fixture.context.save()
        try fixture.queue("routine.tags", .init(parameter: .tags, operation: mode,
            value: mode == .clear ? nil : .tags([fixture.base.live.id])))
        #expect(throws: (any Error).self) { try fixture.preview() }
        #expect(fixture.count("save") == 0)
    }

    @Test func dirtyContextDoesNotSaveOrRollbackUnrelatedDraft() throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("routine.priority", Fixture.argument(3))
        fixture.base.todo.title = "唯一未保存输入"
        #expect(throws: TaskTitleCommandIssue.dirtyContext) { try fixture.submit(accepted) }
        #expect(fixture.base.todo.title == "唯一未保存输入" && fixture.context.hasChanges)
        #expect(fixture.count("save") == 0 && fixture.count("preSave") == 0)
    }

    @Test(arguments: [0, 1, 2, 3, 4]) func failureFactsAndStableIdentity(kind: Int) throws {
        let fixture = try Fixture()
        let before = fixture.routine.snapshot
        let checks = try fixture.checks()
        let accepted = try fixture.accept("routine.title", Fixture.argument(0))
        switch kind {
        case 0: fixture.saveMode = .throwBefore
        case 1: fixture.saveMode = .throwAfter
        case 2: fixture.environment.beforePublication = { throw TaskCreateCommandIO.Failure.injected }
        case 3: fixture.afterRegistration = { throw TaskCreateCommandIO.Failure.injected }
        default: fixture.notificationResult = .failed; fixture.calendarResult = .failed
        }
        let facts = try fixture.submit(accepted)
        #expect(facts.state == (kind < 2 ? .unknown : .saved))
        #expect(kind != 2 || facts.publicationFailed)
        #expect(kind != 3 || facts.registrationFailed)
        if kind == 0 {
            #expect(try fixture.stored().snapshot == before && fixture.tags().count == 2)
            #expect(fixture.base.deleted.deletedAt != nil && facts.rollback == .returned)
        } else {
            #expect(try fixture.stored().title == "新习惯" && fixture.tags().count == 3)
            #expect(try fixture.tags().contains { accepted.tagCreationIDs.values.contains($0.id) })
        }
        #expect(try fixture.checks() == checks)
        let another = RoutineCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment)
        #expect(throws: (any Error).self) { try another.submit(accepted: accepted, expecting: fixture.handoff.owned().lease) }
        #expect(fixture.count("save") == 1)
        if kind < 2 {
            let run = try #require(fixture.handoff.state().execution)
            let operation = try #require(run.operation(accepted.preview.item.id))
            #expect(try fixture.adapter.verifyUnknown(operation, expecting: fixture.handoff.owned().lease) == .singleLive)
            #expect(try fixture.unit().routine?.state == .unknown)
        }
    }

    @Test func reentryAndLateMutationFailBeforeWrite() throws {
        let fixture = try Fixture()
        try fixture.queue("routine.title", Fixture.title("New"))
        fixture.sourceRead = {
            #expect(throws: CommandExecutionError.busy) { try fixture.preview() }
        }
        let accepted = try fixture.adapter.accept(fixture.preview(), expecting: fixture.handoff.owned().lease)
        fixture.sourceRead = nil
        var calls = 0
        fixture.beforeTransaction = {
            calls += 1
            if calls == 2 { fixture.routine.title = "Late"; try fixture.context.save() }
        }
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.conflict && fixture.count("save") == 0)
        #expect(fixture.routine.title == "Late")
    }

    @Test func wrongRepositoryAndNestedContextAreRejected() throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("routine.weekdays", Fixture.argument(1))
        let foreign = ModelContext(fixture.context.container)
        foreign.autosaveEnabled = false
        fixture.repository = { _ in SwiftDataRoutineRepository(context: foreign) }
        #expect(throws: RoutineCommandIssue.invalidRepository) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 0)
    }
}
