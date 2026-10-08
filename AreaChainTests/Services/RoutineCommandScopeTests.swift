import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct RoutineCommandScopeTests {
    typealias Fixture = RoutineCommandFixture
    @Test(arguments: [0, 1, 2, 3]) func priorityMappings(kind: Int) throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("routine.priority", .init(parameter: .priority, operation: .assign, value: .choice("p\(kind + 1)")))
        _ = try fixture.submit(accepted)
        #expect(fixture.routine.isImportant == (kind < 2) && fixture.routine.isUrgent == (kind == 0 || kind == 2))
    }
    @Test(arguments: [-1, 1440]) func illegalReminderIsNotCancellation(minutes: Int) throws {
        let fixture = try Fixture()
        try fixture.queue("routine.reminder", .init(parameter: .time, operation: .setReminder, value: .time(minutes)))
        #expect(throws: (any Error).self) { try fixture.preview() }
        #expect(fixture.routine.remindMinutes == 420 && fixture.count("save") == 0)
    }
    @Test func unspecifiedReminderAndNestedContextDoNotWrite() throws {
        let fixture = try Fixture()
        try fixture.queue("routine.reminder", .init(parameter: .time, operation: .unspecified, value: nil))
        #expect(throws: (any Error).self) { try fixture.preview() }
        try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.io.boundary) {
            #expect(throws: TaskTitleCommandIssue.nestedTransaction) { try fixture.preview() }
            #expect(fixture.count("save") == 0 && fixture.count("preSave") == 0)
        }
    }
    @Test(arguments: [false, true]) func eachOrdinaryProofIsRequired(input: Bool) throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("routine.title", Fixture.title("New"))
        if input { fixture.inputProtection = .required }
        else { fixture.targetProtection = .required }
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 0)
    }
    @Test func parametersChangedCannotReuseAcceptance() throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("routine.priority", Fixture.argument(3))
        try fixture.base.editArgument(.init(parameter: .priority, operation: .assign, value: .choice("p4")))
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 0)
    }
    @Test func twoOperationsAndUnassembledEnvironmentRemainClosed() throws {
        let fixture = try Fixture()
        let unassembled = RoutineCommandAdapter(coordinator: fixture.handoff.coordinator)
        #expect(!unassembled.supports(.init(rawValue: "routine.title")))
        #expect(!fixture.adapter.supports(.init(rawValue: "routine.enabled")))
        try fixture.queue("routine.priority", Fixture.argument(3))
        try fixture.queue("routine.weekdays", Fixture.argument(1))
        #expect(throws: RoutineCommandIssue.unsupportedPlan) { try fixture.preview() }
        #expect(fixture.count("save") == 0)
    }
    @Test func saveAndPublicationReentryKeepOriginalInvocation() throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("routine.title", Fixture.title("New #New"))
        let request = try fixture.request()
        let second = RoutineCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment)
        fixture.onSave = { #expect(throws: (any Error).self) { try second.execute(request) } }
        fixture.onRefresh = { #expect(throws: (any Error).self) { try second.execute(request) } }
        let facts = try fixture.adapter.execute(request)
        #expect(facts.state == .saved && fixture.count("save") == 1 && fixture.count("ui") == 1)
        #expect(try fixture.tags().count == 3)
        #expect(throws: (any Error).self) { try second.execute(request) }
        #expect(fixture.count("save") == 1)
    }
}
