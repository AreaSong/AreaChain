import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct TaskChainCommandTests {
    @Test(arguments: [false, true]) func realOutputFreshBaselineAndConfirmation(noChange: Bool) throws {
        let fixture = try TaskChainCommandFixture()
        try fixture.queue(noChange ? "第一步" : "第二步 #新增 !p3 @09:30")
        #expect(throws: (any Error).self) { try fixture.adapter.create.prepare(plan: fixture.handoff.state().plan.stamp,
                                                                           expecting: fixture.handoff.owned().lease) }
        let created = try fixture.create()
        let originalOutput = try fixture.run.outputs
        #expect(created.state == .saved && created.savedID != nil)
        #expect(try fixture.run.units[1].state == .ready)
        let preview = try fixture.prepareTitle()
        #expect(preview.impact.target.id == created.savedID)
        #expect(preview.impact.originalValues[.title] == .text("第一步"))
        #expect(preview.binding.chain?.output.object.id == created.savedID)
        #expect(try fixture.io.creation.capture.readTodos().first?.title == "第一步")
        #expect(try fixture.io.creation.capture.context.fetchCount(FetchDescriptor<TagItem>()) == 0)
        #expect(throws: (any Error).self) { try fixture.handoff.transfer() }
        let accepted = try fixture.accept(preview)
        let facts = try fixture.submit(accepted)
        #expect(facts.state == (noChange ? .noChange : .saved))
        let rows = try fixture.io.creation.capture.readTodos()
        #expect(rows.count == 1 && rows[0].id == created.savedID && rows[0].title == (noChange ? "第一步" : "第二步"))
        #expect(rows[0].dayKey == "2026-10-05" && rows[0].notes.isEmpty)
        #expect(fixture.io.creation.capture.trace.filter { $0 == "save" }.count == 1)
        #expect(fixture.io.creation.capture.trace.filter { $0 == "saveTitle" }.count == (noChange ? 0 : 1))
        #expect(try fixture.run.outputs == originalOutput && fixture.run.units.allSatisfy { $0.state == .succeeded })
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(throws: (any Error).self) { try fixture.create() }
    }

    @Test(arguments: [0, 1, 2]) func producerFailureAndUnknownBlockConsumer(kind: Int) throws {
        let fixture = try TaskChainCommandFixture()
        try fixture.queue()
        if kind == 0 { fixture.io.creation.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected } }
        if kind == 1 { fixture.io.creation.saveMode = .throwAfter }
        if kind == 2 { fixture.io.createEnvironment.beforePublication = { throw TaskCreateCommandIO.Failure.injected } }
        _ = try? fixture.create()
        #expect(throws: (any Error).self) { try fixture.prepareTitle() }
        #expect(try fixture.run.units[1].state == .blocked && fixture.run.units[1].attempt == 0)
        #expect(fixture.io.creation.capture.trace.filter { $0 == "saveTitle" }.isEmpty)
        #expect(try fixture.io.creation.capture.readTodos().count == (kind == 0 ? 0 : 1))
        #expect(throws: (any Error).self) { try fixture.create() }
    }

    @Test(arguments: [0, 1, 2, 3, 4, 5]) func consumerChangesAndFailureNeverRecreate(kind: Int) throws {
        let fixture = try TaskChainCommandFixture()
        try fixture.queue()
        let created = try fixture.create()
        let preview = try fixture.prepareTitle()
        let accepted = try fixture.accept(preview)
        let todo = try #require(fixture.io.creation.capture.context.fetch(FetchDescriptor<TodoItem>()).first)
        switch kind {
        case 0: todo.title = "外部改名"; try fixture.io.creation.capture.context.save()
        case 1: fixture.io.revision = UUID()
        case 2:
            fixture.io.creation.capture.context.insert(TagItem(name: "目录变化", sortOrder: 0))
            try fixture.io.creation.capture.context.save()
        case 3: fixture.io.titleBeforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        case 4: fixture.io.titleSaveMode = .throwAfter
        default: todo.deletedAt = Date(timeIntervalSince1970: 5); try fixture.io.creation.capture.context.save()
        }
        if kind == 4 { #expect(try fixture.submit(accepted).state == .unknown) }
        else { #expect(throws: (any Error).self) { try fixture.submit(accepted) } }
        #expect(try fixture.run.units[0].taskCreation?.savedID == created.savedID)
        #expect(try fixture.io.creation.capture.context.fetchCount(FetchDescriptor<TodoItem>()) == 1)
        #expect(fixture.io.creation.capture.trace.filter { $0 == "save" }.count == 1)
        #expect(throws: (any Error).self) { try fixture.create() }
    }

    @Test func fabricatedProtocolOutputCannotAuthorizeConsumer() throws {
        let fixture = try TaskChainCommandFixture()
        try fixture.queue()
        _ = try fixture.handoff.seal()
        let attempt = try fixture.handoff.begin()
        try fixture.handoff.result(.committed(outputs: [attempt.unitID: .init(type: .todo, id: UUID())], external: []), attempt: attempt)
        #expect(throws: (any Error).self) { try fixture.prepareTitle() }
        #expect(try fixture.io.creation.capture.readTodos().isEmpty)
    }
}
