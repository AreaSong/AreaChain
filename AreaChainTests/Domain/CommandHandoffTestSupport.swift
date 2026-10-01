import Foundation
import Testing
@testable import AreaChain

@MainActor struct HandoffFixture {
    let coordinator: CommandHandoffCoordinator
    nonisolated static let source = "menubar"
    nonisolated static let target = "workspace"

    init(sourcePage: ContentQueryPage = .today(.init()), targetPage: ContentQueryPage = .settings) throws {
        coordinator = try .init(pages: [QuerySessionFixture.page(sourcePage, host: Self.source),
                                       QuerySessionFixture.page(targetPage, visit: "target", host: Self.target)])
    }

    func state(_ host: String = source) throws -> CommandHostSession { try coordinator.host(host).session }
    func owned(_ host: String = source) throws -> CommandOwnedHost { try coordinator.host(host) }

    @discardableResult func send(_ event: CommandHostEvent, host: String = source) throws -> CommandHostEffect {
        try coordinator.send(event, expecting: owned(host).lease)
    }

    func prepare() throws -> CommandHandoffTicket {
        try coordinator.prepare(id: UUID(), source: owned().lease, target: owned(Self.target).lease)
    }

    @discardableResult func transfer() throws -> CommandHandoffTicket {
        let ticket = try prepare()
        try coordinator.confirm(ticket, readiness: .init())
        try coordinator.commit(ticket)
        return ticket
    }

    static func setting(_ host: String = source, value: String = "chinese") -> CommandDraft {
        .init(id: UUID(), hostID: host, commandID: .init(rawValue: "setting.language"),
              baseline: .init([.init(subject: .ambient, parameter: .value): .uniform(.choice("system"))]),
              arguments: [PlanFixture.argument(.value, .choice(value))])
    }

    func start(_ draft: CommandDraft) throws {
        try send(.operation(.start(expectedRevision: state(draft.hostID).operations.revision, draft)), host: draft.hostID)
    }

    @discardableResult func queue(_ draft: CommandDraft, itemID: UUID = UUID()) throws -> UUID {
        try start(draft)
        let state = try state(draft.hostID)
        try send(.enqueue(#require(state.operations.active?.stamp), itemID: itemID, plan: state.plan.stamp), host: draft.hostID)
        return itemID
    }

    func plan(_ event: CommandPlanEvent, host: String = source) throws {
        try send(.plan(event, state(host).plan.stamp), host: host)
    }

    func seal(host: String = source, id: UUID = UUID()) throws -> CommandExecutionStamp {
        try send(.sealPlan(state(host).plan.stamp, runID: id), host: host)
        return try #require(state(host).execution?.stamp)
    }

    func begin(host: String = source) throws -> CommandAttemptStamp {
        let result = try send(.beginStep(#require(state(host).execution?.stamp)), host: host)
        guard case .attempt(let attempt) = result else { throw CommandExecutionError.noReadyUnit }
        return attempt
    }

    func result(_ result: CommandExecutionResult, attempt: CommandAttemptStamp, host: String = source) throws {
        try send(.result(.init(attempt: attempt, result: result)), host: host)
    }
}
