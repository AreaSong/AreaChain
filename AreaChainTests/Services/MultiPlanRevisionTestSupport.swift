import Foundation
import Testing
@testable import AreaChain

@MainActor enum MultiPlanRevisionSupport {
    static func adapter(_ fixture: TaskFieldCommandFixture) -> MultiPlanCommandAdapter {
        fixture.io.notificationResult = .succeeded
        fixture.io.calendarResult = .succeeded
        return .init(coordinator: fixture.handoff.coordinator, adapters: .init(taskField: fixture.adapter),
                     outputCapability: .typedCreation, supportsRevisions: true)
    }

    @discardableResult static func queue(_ fixture: TaskFieldCommandFixture, kind: Int = 0,
                                        argument: CommandArgument? = nil) throws -> CommandPlanItem {
        try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
            commandID: .init(rawValue: TaskFieldCommandFixture.command(kind)),
            targets: .init(.single, objects: [.init(type: .todo, id: fixture.base.todo.id)]),
            arguments: [argument ?? TaskFieldCommandFixture.argument(kind)]))
        return try #require(fixture.handoff.state().plan.items.last)
    }

    static func start(_ adapter: MultiPlanCommandAdapter, _ handoff: HandoffFixture, maximum: Int = .max) throws {
        let host = try handoff.owned()
        let preview = try adapter.prepare(plan: host.session.plan.stamp, expecting: host.lease)
        try adapter.submit(preview, expecting: handoff.owned().lease, maximumUnits: maximum)
    }

    static func returnAll(_ adapter: MultiPlanCommandAdapter, _ handoff: HandoffFixture) throws -> CommandPlanReturnTicket {
        let ticket = try adapter.prepareReturn(expecting: handoff.owned().lease)
        try adapter.returnRemaining(ticket, expecting: handoff.owned().lease)
        return ticket
    }

    static func edit(_ id: UUID, argument: CommandArgument, handoff: HandoffFixture) throws {
        let original = try #require(handoff.state().plan.items.first(where: { $0.id == id }))
        try handoff.plan(.beginEditing(original.stamp))
        try handoff.plan(.edit(original.stamp, argument))
        let edited = try #require(handoff.state().plan.items.first(where: { $0.id == id }))
        try handoff.plan(.endEditing(edited.stamp, .finish))
    }
}
