import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct TaskChainCommandBoundaryTests {
    @Test(arguments: [false, true]) func outdatedConsumerVersionsAreRejected(parsing: Bool) throws {
        let fixture = try TaskChainCommandFixture()
        try fixture.queue()
        _ = try fixture.create()
        let original = try fixture.prepareTitle()
        let binding = original.binding
        let preview = CommandTaskTitlePreview(binding: .init(lease: binding.lease, plan: binding.plan, item: binding.item,
            draft: binding.draft, source: binding.source, catalog: binding.catalog,
            parsingVersion: parsing ? 0 : binding.parsingVersion, impactVersion: parsing ? binding.impactVersion : 0,
            chain: binding.chain), impact: original.impact, followUpContext: original.followUpContext,
            arguments: original.arguments, draftBaseline: original.draftBaseline)
        #expect(throws: (any Error).self) { try fixture.accept(preview) }
        #expect(fixture.io.creation.capture.trace.filter { $0 == "saveTitle" }.isEmpty)
    }

    @Test func unknownVerificationCannotUseConsumerIdentity() throws {
        let fixture = try TaskChainCommandFixture()
        try fixture.queue()
        fixture.io.creation.saveMode = .throwAfter
        #expect(try fixture.create().state == .unknown)
        let run = try fixture.run
        let consumer = try #require(run.operation(run.snapshot.items[1].id))
        #expect(throws: (any Error).self) {
            try fixture.adapter.create.verifyUnknown(consumer, expecting: fixture.handoff.owned().lease)
        }
        let producer = try #require(run.operation(run.snapshot.items[0].id))
        #expect(try fixture.adapter.create.verifyUnknown(producer, expecting: fixture.handoff.owned().lease) == .singleLive)
        #expect(try fixture.run.units[0].local == .unknown)
    }

    @Test func lateReceiptsCannotReplaceFixedOutputOrReplayProducer() throws {
        let fixture = try TaskChainCommandFixture()
        try fixture.queue()
        let created = try fixture.create()
        let preview = try fixture.prepareTitle()
        let binding = try #require(preview.binding.chain)
        let outputs = try fixture.run.outputs
        #expect(throws: (any Error).self) {
            try fixture.handoff.result(.committed(outputs: [binding.identity.producer.id: .init(type: .todo, id: UUID())], external: []),
                                       attempt: binding.output.localAttempt)
        }
        #expect(try fixture.run.outputs == outputs)
        let accepted = try fixture.accept(preview)
        _ = try fixture.submit(accepted)
        let after = try fixture.run
        let receipt = try #require(after.units[1].receipt)
        try fixture.handoff.result(receipt.result, attempt: receipt.attempt)
        #expect(try fixture.run.outputs == outputs)
        #expect(try fixture.io.creation.capture.readTodos().first?.id == created.savedID)
        #expect(fixture.io.creation.capture.trace.filter { $0 == "save" }.count == 1)
    }

    @Test(arguments: [false, true]) func secondAdapterAndReentryCannotExecuteTwice(fromSource: Bool) throws {
        let fixture = try TaskChainCommandFixture()
        try fixture.queue()
        _ = try fixture.create()
        let preview = try fixture.prepareTitle()
        let accepted = try fixture.accept(preview)
        let another = TaskChainCommandAdapter(create: fixture.adapter.create, title: .init(coordinator: fixture.handoff.coordinator,
                                                                                         environment: fixture.io.titleEnvironment))
        var blocked = 0
        let reenter = {
            #expect(throws: (any Error).self) { try another.prepareTitle(expecting: fixture.handoff.owned().lease) }
            #expect(throws: (any Error).self) { try another.submitTitle(accepted, expecting: fixture.handoff.owned().lease) }
            blocked += 1
        }
        if fromSource { fixture.io.titleSourceRead = reenter } else { fixture.io.titleBeforeTransaction = reenter }
        #expect(try fixture.submit(accepted).state == .saved)
        #expect(blocked == (fromSource ? 4 : 2))
        #expect(fixture.io.creation.capture.trace.filter { $0 == "saveTitle" }.count == 1)
        #expect(try fixture.io.creation.capture.readTodos().count == 1)
    }

    @Test(arguments: [0, 1, 2]) func otherShapesAndInputsStayClosed(kind: Int) throws {
        let fixture = try TaskChainCommandFixture()
        try fixture.queue(kind == 0 ? "修改 // notes" : "修改")
        if kind == 1 {
            try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.create"),
                                           arguments: TaskCreateCommandFixture.arguments()))
        }
        if kind == 2 {
            let item = try #require(fixture.handoff.state().plan.items.last)
            try fixture.handoff.plan(.link(item.stamp, .init()))
        }
        #expect(throws: (any Error).self) { try fixture.create() }
        #expect(try fixture.io.creation.capture.readTodos().isEmpty)
    }
}
