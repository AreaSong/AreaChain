import CryptoKit
import Foundation
import Testing
@testable import AreaChain

@MainActor struct ProtectedDraftFixture {
    let host: HandoffFixture
    let vault: PrivacyVault
    let service: CommandDraftContentSession
    let key = Data(repeating: 42, count: 32)

    init(configured: Bool = true) throws {
        host = try HandoffFixture()
        let id = UUID()
        let config = PrivacyConfiguration(vaultID: id, systemKeyID: UUID(),
            verification: try VaultCrypto.seal(Data("verify".utf8), key: SymmetricKey(data: key), context: "synthetic"))
        vault = PrivacyVault(store: MemoryVaultConfigurationStore(configured ? config : nil), systemKeys: FakeSystemVaultKeys())
        if configured {
            try vault.finishAuthentication(key, configuration: config, token: vault.generation)
        }
        service = .init(coordinator: host.coordinator, vault: vault)
    }

    func unlock() throws {
        try vault.finishAuthentication(key, configuration: #require(vault.configuration), token: vault.generation)
    }

    func start() throws {
        let actual = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.notes"),
            targets: .init(.single, objects: [.init(type: .todo, id: UUID())]),
            baseline: .init([.init(subject: .ambient, parameter: .notes): .uniform(.longText("synthetic-baseline")),
                             .init(subject: .ambient, parameter: .title): .absent,
                             .init(subject: .ambient, parameter: .tags): .mixed]),
            arguments: [.init(parameter: .notes, operation: .replace, value: .longText("synthetic-body"))])
        try host.start(actual)
    }

    func draft() throws -> CommandDraft { try #require(host.state().operations.active) }
    func protect() throws -> CommandProtectedReference {
        try service.protect(draft().stamp, expecting: host.owned().lease,
            editing: [.init(parameter: "notes", spelling: "合成未完成🙂", selectionLocation: 2, selectionLength: 1)])
    }
    func restore() throws -> CommandDraftContentAccess {
        try service.explicitlyRestore(draft().stamp, expecting: host.owned().lease)
    }
    func contents(_ access: CommandDraftContentAccess) throws -> CommandDraftContents {
        var value: CommandDraftContents?
        try service.withRestoredContents(access) { value = $0 }
        return try #require(value)
    }
}
