import Foundation
import Testing
@testable import AreaChain

@MainActor struct CommandHandoffTests {
    @Test func emptyReceiverTakesAllOwnersWithoutExecuting() throws {
        let fixture = try HandoffFixture()
        try fixture.send(.query(.setInput("Synthetic query #sample")))
        try fixture.queue(HandoffFixture.setting())
        try fixture.start(HandoffFixture.setting(value: "english"))
        try fixture.start(HandoffFixture.setting(value: "system"))
        let decision = try #require(fixture.state().operations.pending)
        try fixture.send(.operation(.resolve(decision, .retain)))
        let before = try fixture.owned()
        let target = try fixture.owned(HandoffFixture.target)
        let ticket = try fixture.transfer()
        let received = try fixture.owned(HandoffFixture.target)
        let source = try fixture.owned()
        #expect(received.session.operations.active?.id == before.session.operations.active?.id)
        #expect(received.session.operations.active?.arguments == before.session.operations.active?.arguments)
        #expect(received.session.operations.active?.baseline == before.session.operations.active?.baseline)
        #expect(received.session.operations.active?.modification == before.session.operations.active?.modification)
        #expect(received.session.operations.retained.map(\.id) == before.session.operations.retained.map(\.id))
        #expect(received.session.operations.retained.map(\.arguments) == before.session.operations.retained.map(\.arguments))
        #expect(received.session.plan.id == before.session.plan.id)
        #expect(received.session.plan.items.map(\.id) == before.session.plan.items.map(\.id))
        #expect(received.session.query.input == before.session.query.input)
        #expect(received.session.query.scope == before.session.query.scope)
        #expect(received.session.execution == nil && source.session.execution == nil)
        #expect(!received.session.plan.check().isExecutable)
        #expect(received.session.plan.items.allSatisfy { $0.draft.check().execution == .unwired })
        #expect(source.session.operations.active == nil && source.session.operations.retained.isEmpty)
        #expect(source.session.plan.items.isEmpty && !source.session.query.showsResults)
        #expect(source.session.query.binding == .page(visitID: source.session.query.page.location.visitID))
        #expect(source.lease.ownership.generation == before.lease.ownership.generation + 1)
        #expect(received.lease.ownership.generation == target.lease.ownership.generation + 1)
        #expect(fixture.coordinator.status(ticket.id) == .completed)
        #expect(throws: CommandHandoffError.stale) { try fixture.coordinator.validate(target.lease) }
    }

    @Test(arguments: ["active", "retained", "plan", "unchanged", "emptyDraft"])
    func occupiedTargetRejectsWithoutChangingEitherHost(kind: String) throws {
        let fixture = try HandoffFixture()
        try fixture.start(HandoffFixture.setting())
        let target = HandoffFixture.target
        let draft = kind == "emptyDraft"
            ? CommandDraft(id: UUID(), hostID: target, commandID: .init(rawValue: "setting.language"))
            : HandoffFixture.setting(target, value: kind == "unchanged" ? "system" : "chinese")
        if kind == "plan" { try fixture.queue(draft) } else { try fixture.start(draft) }
        if kind == "retained" {
            try fixture.start(HandoffFixture.setting(target))
            try fixture.send(.operation(.resolve(#require(fixture.state(target).operations.pending), .retain)), host: target)
            let current = try fixture.state(target)
            try fixture.send(.enqueue(#require(current.operations.active?.stamp), itemID: UUID(), plan: current.plan.stamp), host: target)
            let run = try fixture.seal(host: target)
            try fixture.result(.committed(outputs: [:], external: []), attempt: fixture.begin(host: target), host: target)
            try fixture.send(.releaseExecution(run), host: target)
            #expect(try fixture.state(target).operations.active == nil)
        }
        let sourceBefore = try fixture.owned(), targetBefore = try fixture.owned(target)
        #expect(throws: CommandHandoffError.targetOccupied) { try fixture.prepare() }
        #expect(try fixture.owned() == sourceBefore)
        #expect(try fixture.owned(target) == targetBefore)
    }

    @Test func queryReplacementRequiresRevisionBoundAcceptance() throws {
        let fixture = try HandoffFixture()
        try fixture.send(.query(.setInput("Synthetic target")), host: HandoffFixture.target)
        let ticket = try fixture.prepare()
        #expect(ticket.requirements.replacesQuery)
        #expect(throws: CommandHandoffError.queryReplacementRequired) {
            try fixture.coordinator.confirm(ticket, readiness: .init())
        }
        #expect(throws: CommandHandoffError.receiverUnconfirmed) { try fixture.coordinator.commit(ticket) }
        try fixture.coordinator.confirm(ticket, readiness: .init(acceptsQueryReplacement: true))
        try fixture.send(.query(.setInput("Synthetic newer target")), host: HandoffFixture.target)
        let current = try fixture.owned(HandoffFixture.target)
        #expect(throws: CommandHandoffError.stale) {
            try fixture.coordinator.confirm(ticket, readiness: .init(acceptsQueryReplacement: true))
        }
        #expect(throws: CommandHandoffError.stale) { try fixture.coordinator.commit(ticket) }
        #expect(try fixture.owned(HandoffFixture.target) == current)
        try fixture.coordinator.cancel(ticket)
        let fresh = try fixture.prepare()
        try fixture.coordinator.confirm(fresh, readiness: .init(acceptsQueryReplacement: true))
        try fixture.coordinator.commit(fresh)
    }

    @Test(arguments: [HandoffFixture.source, HandoffFixture.target])
    func normalEditingInvalidatesPreparedTicket(host: String) throws {
        let fixture = try HandoffFixture()
        try fixture.start(HandoffFixture.setting())
        let ticket = try fixture.prepare()
        try fixture.coordinator.confirm(ticket, readiness: .init())
        try fixture.send(.query(.setInput("Synthetic edit")), host: host)
        let source = try fixture.owned(), target = try fixture.owned(HandoffFixture.target)
        #expect(throws: CommandHandoffError.stale) { try fixture.coordinator.commit(ticket) }
        #expect(try fixture.owned() == source)
        #expect(try fixture.owned(HandoffFixture.target) == target)
    }

    @Test(arguments: [CommandHandoffFailure.receiverUnavailable, .windowPreparationFailed, .resourceUnavailable, .commitFailed])
    func syntheticPreparationAndCommitFailuresKeepSource(reason: CommandHandoffFailure) throws {
        let fixture = try HandoffFixture()
        try fixture.start(HandoffFixture.setting())
        let source = try fixture.owned(), target = try fixture.owned(HandoffFixture.target)
        let ticket = try fixture.prepare()
        if reason == .commitFailed { try fixture.coordinator.confirm(ticket, readiness: .init()) }
        try fixture.coordinator.fail(ticket, reason: reason)
        #expect(fixture.coordinator.status(ticket.id) == .failed(reason))
        #expect(try fixture.owned() == source && fixture.owned(HandoffFixture.target) == target)
        #expect(throws: CommandHandoffError.stale) { try fixture.coordinator.commit(ticket) }
    }

    @Test func cancellationAndDuplicatesNeverReactivateTickets() throws {
        let fixture = try HandoffFixture()
        try fixture.start(HandoffFixture.setting())
        let before = try fixture.owned()
        let cancelled = try fixture.prepare()
        try fixture.coordinator.cancel(cancelled)
        #expect(try fixture.owned() == before)
        #expect(throws: CommandHandoffError.stale) { try fixture.coordinator.commit(cancelled) }
        #expect(throws: CommandHandoffError.stale) { try fixture.coordinator.confirm(cancelled, readiness: .init()) }
        #expect(throws: CommandHandoffError.duplicate) {
            try fixture.coordinator.prepare(id: cancelled.id, source: fixture.owned().lease, target: fixture.owned(HandoffFixture.target).lease)
        }
        let ticket = try fixture.prepare()
        try fixture.coordinator.confirm(ticket, readiness: .init())
        try fixture.coordinator.confirm(ticket, readiness: .init())
        try fixture.coordinator.commit(ticket)
        let after = try fixture.owned(HandoffFixture.target)
        #expect(throws: CommandHandoffError.stale) { try fixture.coordinator.commit(ticket) }
        #expect(throws: CommandHandoffError.stale) { try fixture.coordinator.cancel(ticket) }
        #expect(try fixture.owned(HandoffFixture.target) == after)
    }

    @Test func sameHostStaleAndConcurrentTransfersReject() throws {
        let fixture = try HandoffFixture()
        let source = try fixture.owned(), target = try fixture.owned(HandoffFixture.target)
        #expect(throws: CommandHandoffError.sameHost) {
            try fixture.coordinator.prepare(id: UUID(), source: source.lease, target: source.lease)
        }
        let ticket = try fixture.prepare()
        #expect(throws: CommandHandoffError.transferInProgress) { try fixture.prepare() }
        try fixture.coordinator.cancel(ticket)
        try fixture.send(.query(.setInput("")))
        #expect(throws: CommandHandoffError.stale) {
            try fixture.coordinator.prepare(id: UUID(), source: source.lease, target: target.lease)
        }
        let other = try HandoffFixture()
        #expect(throws: CommandHandoffError.stale) { try other.coordinator.validate(target.lease) }
    }

    @Test(arguments: [HandoffFixture.source, HandoffFixture.target])
    func pendingDraftDecisionBlocksBothEnds(host: String) throws {
        let fixture = try HandoffFixture()
        try fixture.start(HandoffFixture.setting(host))
        try fixture.start(HandoffFixture.setting(host))
        let before = try fixture.owned(host)
        #expect(before.session.operations.pending != nil)
        #expect(throws: CommandHandoffError.ineligible) { try fixture.prepare() }
        #expect(try fixture.owned(host) == before)
    }

    @Test(arguments: ["draft", "plan"])
    func parameterEditsInvalidateTicketWithoutFreezingContent(owner: String) throws {
        let fixture = try HandoffFixture()
        if owner == "plan" { try fixture.queue(HandoffFixture.setting()) } else { try fixture.start(HandoffFixture.setting()) }
        let ticket = try fixture.prepare()
        try fixture.coordinator.confirm(ticket, readiness: .init())
        let before = try fixture.state()
        let argument = PlanFixture.argument(.value, .choice("english"))
        if owner == "plan" {
            try fixture.plan(.beginEditing(before.plan.items[0].stamp))
            try fixture.plan(.edit(before.plan.items[0].stamp, argument))
        } else {
            try fixture.send(.operation(.edit(#require(before.operations.active?.stamp), argument)))
        }
        let current = try fixture.owned()
        #expect(throws: CommandHandoffError.stale) { try fixture.coordinator.commit(ticket) }
        try fixture.coordinator.cancel(ticket)
        #expect(try fixture.owned() == current)
        let arguments = owner == "plan" ? current.session.plan.items[0].draft.arguments : current.session.operations.active?.arguments
        #expect(arguments == [argument])
    }
}
