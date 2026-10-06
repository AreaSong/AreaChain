import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskCreateCommandIdentityTests {
    @Test(arguments: [0, 1, 2])
    func exactIdentityCollisionIncludesTombstonesAndDuplicates(kind: Int) throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue()
        let prepared = try fixture.prepare()
        let old = TodoItem(id: prepared.creationID, title: "existing", dayKey: "2026-10-04")
        if kind == 1 { old.deletedAt = .now }
        fixture.io.capture.context.insert(old)
        if kind == 2 {
            fixture.io.capture.context.insert(TodoItem(id: prepared.creationID, title: "duplicate", dayKey: "2026-10-05"))
        }
        try fixture.io.capture.context.save()
        #expect(throws: TaskCreateCommandIssue.identityCollision) { try fixture.submit() }
        #expect(try fixture.io.capture.readTodos().count == (kind == 2 ? 2 : 1))
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
        let repository = SwiftDataTaskRepository(context: fixture.io.capture.context)
        #expect(try repository.fetchTodos(withID: prepared.creationID).count == (kind == 2 ? 2 : 1))
        #expect(throws: RepositoryError.self) {
            try repository.addTodo(.init(title: "new", dayKey: "2026-10-05", creationID: prepared.creationID))
        }
        #expect(!fixture.io.capture.context.hasChanges)
    }

    @Test func twoAdaptersAndReentryHaveOneBusinessInvocation() throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue()
        let prepared = try fixture.prepare()
        let other = TaskCreateCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment)
        #expect(try other.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease) == prepared)
        let request = try fixture.request()
        var reentries = 0
        fixture.io.beforeTransaction = {
            reentries += 1
            #expect(throws: TaskCreateCommandIssue.alreadyInvoked) { try other.execute(request) }
        }
        let facts = try fixture.adapter.execute(request)
        #expect(facts.savedID == prepared.creationID && reentries == 1)
        #expect(throws: (any Error).self) { try other.execute(request) }
        #expect(throws: (any Error).self) { try fixture.submit() }
        #expect(try fixture.io.capture.readTodos().count == 1)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
    }

    @Test func preparationReentryAndForeignEnvironmentCannotReserveAnotherIdentity() throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue()
        let other = TaskCreateCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment)
        var reentered = false
        fixture.io.sourceRead = {
            if !reentered {
                reentered = true
                #expect(throws: CommandExecutionError.busy) {
                    try other.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
                }
            }
        }
        let prepared = try fixture.prepare()
        #expect(reentered)
        fixture.io.sourceRead = nil
        let foreign = try fixture.io.environment()
        let impostor = TaskCreateCommandAdapter(coordinator: fixture.handoff.coordinator, environment: foreign)
        #expect(throws: TaskCreateCommandIssue.stale) {
            try impostor.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        }
        #expect(try fixture.prepare().creationID == prepared.creationID)
        #expect(fixture.io.capture.trace.isEmpty)
    }

    @Test func explicitRepositoryIdentityAndLegacyRandomDefaultsRemainCompatible() throws {
        let fixture = try TaskCaptureFixture()
        let fixed = UUID()
        let result = TaskMutationService.createCaptured(.init(text: "fixed", dayKey: "2026-10-05", creationID: fixed),
                                                        in: fixture.context, dependencies: fixture.dependencies)
        #expect(result.savedID == fixed)
        #expect(fixture.create("legacy").saved)
        #expect(fixture.create("legacy").saved)
        let rows = try fixture.readTodos()
        #expect(rows.count == 3 && Set(rows.map(\.id)).count == 3 && rows.contains { $0.id == fixed })
        #expect(fixture.trace.filter { $0 == "save" }.count == 3)
    }
}
