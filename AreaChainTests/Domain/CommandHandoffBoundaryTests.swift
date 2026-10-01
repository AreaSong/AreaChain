import Foundation
import Testing
@testable import AreaChain

@MainActor struct CommandHandoffBoundaryTests {
    @Test(arguments: ["ready", "running", "waiting", "failed", "conflict", "unknown", "partial", "externalFailed", "externalUnknown", "notExecuted", "succeeded"],
          [HandoffFixture.source, HandoffFixture.target])
    func everyRetainedRunBlocksRegardlessOfBusy(state: String, host: String) throws {
        let fixture = try HandoffFixture()
        try fixture.queue(HandoffFixture.setting(host))
        if state == "partial" { try fixture.queue(HandoffFixture.setting(host, value: "english")) }
        let first = try fixture.state(host).plan.items[0]
        let run = try fixture.seal(host: host)
        if state != "ready" {
            let attempt = try fixture.begin(host: host)
            try advance(state, attempt: attempt, item: first, fixture: fixture, host: host)
        }
        let before = try fixture.owned(host)
        let other = try fixture.owned(host == HandoffFixture.source ? HandoffFixture.target : HandoffFixture.source)
        if !["running", "waiting"].contains(state) { #expect(!before.session.isBusy) }
        #expect(throws: CommandHandoffError.ineligible) { try fixture.prepare() }
        #expect(try fixture.owned(host) == before)
        #expect(try fixture.owned(other.session.hostID) == other)
        if state == "succeeded" {
            #expect(!before.session.requiresUnsavedContentHandling)
            try fixture.send(.releaseExecution(run), host: host)
            try fixture.transfer()
        } else {
            #expect(throws: CommandExecutionError.busy) { try fixture.send(.releaseExecution(run), host: host) }
        }
    }

    private func advance(_ state: String, attempt: CommandAttemptStamp, item: CommandPlanItem,
                         fixture: HandoffFixture, host: String) throws {
        switch state {
        case "running": break
        case "waiting": try fixture.result(.waitingAuthorization, attempt: attempt, host: host)
        case "failed": try fixture.result(.failedWithoutCommit, attempt: attempt, host: host)
        case "unknown": try fixture.result(.commitUnknown, attempt: attempt, host: host)
        case "notExecuted": try fixture.result(.notExecuted, attempt: attempt, host: host)
        case "conflict":
            try fixture.result(.conflict([.init(item: item.stamp, field: .init(subject: .ambient, parameter: .value),
                                                reason: .valueChanged)]), attempt: attempt, host: host)
        case "partial":
            try fixture.result(.committed(outputs: [:], external: []), attempt: attempt, host: host)
            try fixture.result(.failedWithoutCommit, attempt: fixture.begin(host: host), host: host)
        case "externalFailed", "externalUnknown":
            try fixture.result(.committed(outputs: [:], external: [.notification]), attempt: attempt, host: host)
            try fixture.result(.external([.notification: state == "externalFailed" ? .failed : .unknown]),
                               attempt: fixture.begin(host: host), host: host)
        default: try fixture.result(.committed(outputs: [:], external: []), attempt: attempt, host: host)
        }
    }

    @Test(arguments: ["active", "retained", "plan", "baseline"])
    func nativeHandlesRequireExactReceiverConfirmation(owner: String) throws {
        let fixture = try HandoffFixture()
        let handle = UUID()
        let argument = PlanFixture.argument(.file, .nativeSelection(handle))
        let baseline = CommandDraftBaseline([.init(subject: .ambient, parameter: .file): .uniform(.nativeSelection(handle))])
        let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source,
                                 commandID: .init(rawValue: owner == "plan" ? "setting.language" : "image.pick"),
                                 baseline: owner == "baseline" ? baseline : .init(),
                                 arguments: owner == "baseline" ? [] : [argument])
        if owner == "plan" { try fixture.queue(draft) } else { try fixture.start(draft) }
        if owner == "retained" {
            try fixture.start(HandoffFixture.setting())
            try fixture.send(.operation(.resolve(#require(fixture.state().operations.pending), .retain)))
        }
        let before = try fixture.owned()
        let ticket = try fixture.prepare()
        #expect(ticket.requirements.nativeSelections == [handle])
        #expect(throws: CommandHandoffError.resourcesUnconfirmed) { try fixture.coordinator.confirm(ticket, readiness: .init()) }
        #expect(throws: CommandHandoffError.resourcesUnconfirmed) {
            try fixture.coordinator.confirm(ticket, readiness: .init(confirmedNativeSelections: [UUID()]))
        }
        #expect(throws: CommandHandoffError.receiverUnconfirmed) { try fixture.coordinator.commit(ticket) }
        #expect(try fixture.owned() == before)
        try fixture.coordinator.confirm(ticket, readiness: .init(confirmedNativeSelections: [handle]))
        try fixture.coordinator.commit(ticket)
        #expect(try fixture.state(HandoffFixture.target).handoffNativeSelections == [handle])
        #expect(try fixture.state(HandoffFixture.target).execution == nil)
    }

    @Test func staleCreationReferenceIsNotSilentlyRepairedByTransfer() throws {
        let fixture = try HandoffFixture()
        try fixture.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.create")))
        let parent = try fixture.state().plan.items[0]
        try fixture.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "subtask.create")))
        let child = try fixture.state().plan.items[1]
        try fixture.plan(.link(child.stamp, .init(results: [.parent: .init(producer: parent.stamp, outputType: .todo)])))
        try fixture.plan(.beginEditing(parent.stamp))
        try fixture.plan(.edit(parent.stamp, PlanFixture.argument(.title, .shortText("Synthetic revision"))))
        let before = try fixture.owned()
        #expect(throws: CommandHandoffError.invalidPlan) { try fixture.prepare() }
        #expect(try fixture.owned() == before)
    }

    @Test func descriptionsHideSyntheticContent() throws {
        let fixture = try HandoffFixture()
        let marker = "SyntheticContentMustRemainRedacted"
        try fixture.send(.query(.setInput(marker)))
        let event = CommandHostEvent.operation(.start(expectedRevision: 0, .init(
            id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "diary.create"),
            baseline: .init([.init(subject: .ambient, parameter: .body): .uniform(.longText(marker))]),
            arguments: [PlanFixture.argument(.body, .longText(marker))])))
        let effect = try fixture.send(event)
        let snapshot = try fixture.owned()
        let ticket = try fixture.prepare()
        let descriptions = [String(describing: fixture.coordinator), String(reflecting: snapshot),
                            String(reflecting: snapshot.session), String(reflecting: snapshot.session.query),
                            String(reflecting: event), String(reflecting: effect), String(reflecting: ticket),
                            String(reflecting: ticket.requirements)]
        #expect(descriptions.allSatisfy { !$0.contains(marker) })
    }
}
