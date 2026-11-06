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
}
