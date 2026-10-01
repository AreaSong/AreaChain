import Foundation
import Testing
@testable import AreaChain

enum PlanFixture {
    static func host() -> CommandHostSession { .init(page: QuerySessionFixture.page()) }

    static func argument(_ id: CommandParameterID, _ value: CommandValue) -> CommandArgument {
        .init(parameter: id, operation: .assign, value: value)
    }

    static func setting(_ value: String = "chinese", command: String = "setting.language") -> CommandDraft {
        .init(id: UUID(), hostID: "workspace", commandID: .init(rawValue: command),
              baseline: .init([.init(subject: .ambient, parameter: .value): .uniform(.choice("system"))]),
              arguments: [argument(.value, .choice(value))])
    }

    static func todo() -> CommandDraft {
        .init(id: UUID(), hostID: "workspace", commandID: .init(rawValue: "todo.create"),
              arguments: [argument(.title, .shortText("Synthetic task")), argument(.day, .day("2026-10-01"))])
    }

    static func child() -> CommandDraft {
        .init(id: UUID(), hostID: "workspace", commandID: .init(rawValue: "subtask.create"),
              arguments: [argument(.title, .shortText("Synthetic child"))])
    }

    @discardableResult static func queue(_ draft: CommandDraft, in host: inout CommandHostSession) throws -> UUID {
        #expect(host.operationEvent(.start(expectedRevision: host.operations.revision, draft)).isEmpty)
        let stamp = try #require(host.operations.active?.stamp)
        let id = UUID()
        try host.enqueue(stamp, itemID: id, expecting: host.plan.stamp)
        return id
    }

    static func item(_ id: UUID, in host: CommandHostSession) throws -> CommandPlanItem {
        try #require(host.plan.items.first { $0.id == id })
    }

    static func link(_ id: UUID, to predecessors: Set<UUID>, in host: inout CommandHostSession) throws {
        try host.planEvent(.link(try item(id, in: host).stamp, .init(predecessors: predecessors)), expecting: host.plan.stamp)
    }

    static func reference(_ child: UUID, parent: UUID, parameter: CommandParameterID = .parent,
                          in host: inout CommandHostSession) throws {
        let reference = CommandCreationReference(producer: try item(parent, in: host).stamp, outputType: .todo)
        try host.planEvent(.link(try item(child, in: host).stamp, .init(results: [parameter: reference])), expecting: host.plan.stamp)
    }

    static func edit(_ id: UUID, argument: CommandArgument, in host: inout CommandHostSession) throws {
        try host.planEvent(.beginEditing(try item(id, in: host).stamp), expecting: host.plan.stamp)
        try host.planEvent(.edit(try item(id, in: host).stamp, argument), expecting: host.plan.stamp)
        try host.planEvent(.endEditing(try item(id, in: host).stamp, .finish), expecting: host.plan.stamp)
    }

    static func seal(_ host: inout CommandHostSession) throws {
        try host.sealPlanForProtocol(host.plan.stamp, runID: UUID())
    }

    static func begin(_ host: inout CommandHostSession) throws -> CommandAttemptStamp {
        try host.beginNextProtocolStep(expecting: #require(host.execution?.stamp))
    }

    static func result(_ result: CommandExecutionResult, attempt: CommandAttemptStamp,
                       in host: inout CommandHostSession) throws {
        try host.receiveProtocolResult(.init(attempt: attempt, result: result))
    }
}
