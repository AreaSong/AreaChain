import CryptoKit
import Foundation
import Testing
import Security
@testable import AreaChain

actor FakeSystemVaultKeys: SystemVaultKeyStorage {
    var items: [UUID: Data] = [:]
    var readError: PrivacyError?
    var removeError: PrivacyError?
    var pendingRead: CheckedContinuation<Data, Error>?
    var suspendsReads = false
    var pendingRemoval: CheckedContinuation<Void, Never>?
    var suspendsRemovals = false

    func create(_ data: Data, id: UUID) async throws { items[id] = data }
    func read(id: UUID, reason: String) async throws -> Data {
        if let readError { throw readError }
        guard let data = items[id] else { throw PrivacyError.systemUnavailable }
        if suspendsReads {
            return try await withCheckedThrowingContinuation { pendingRead = $0 }
        }
        return data
    }
    func remove(id: UUID) async throws {
        if suspendsRemovals { await withCheckedContinuation { pendingRemoval = $0 } }
        if let removeError { throw removeError }
        items[id] = nil
    }
    nonisolated func cancel() {}
    func setReadError(_ error: PrivacyError?) { readError = error }
    func setRemoveError(_ error: PrivacyError?) { removeError = error }
    func suspend() { suspendsReads = true }
    func suspendRemovals() { suspendsRemovals = true }
    func finishRemoval() {
        suspendsRemovals = false
        pendingRemoval?.resume()
        pendingRemoval = nil
    }
    func finishRead() {
        pendingRead?.resume(returning: items.values.first!)
        pendingRead = nil
    }
}

@Suite(.serialized) @MainActor
struct PrivacyVaultTests {
    private let password = "synthetic-master-password"

    @Test func readOnlySystemKeychainCapabilityProbeNeverPromptsOrWrites() {
        let status = SystemVaultKeyStore(service: "com.areachain.privacy-qa.probe").availabilityStatus()
        print("AREACHAIN_KEYCHAIN_READONLY_PROBE_STATUS=\(status)")
        #if compiler(>=6.2)
        Attachment.record("OSStatus=\(status)\nRead-only random-item query; no user interaction or keychain writes.",
                          named: "keychain-capability.txt")
        #endif
        #expect([errSecItemNotFound, errSecMissingEntitlement, errSecNotAvailable,
                 errSecInteractionNotAllowed, errSecSuccess].contains(status))
    }

    @Test func bothRoutesUnlockTheSameKeyAndNeverStorePassword() async throws {
        let store = MemoryVaultConfigurationStore()
        let system = FakeSystemVaultKeys()
        let vault = PrivacyVault(store: store, systemKeys: system)
        try await vault.create(password: password, systemUnlock: true)
        let config = try #require(vault.configuration)
        let first = try vault.keys.dataKey(vaultID: config.vaultID)
        #expect(!String(decoding: try JSONEncoder().encode(config), as: UTF8.self).contains(password))
        vault.lock()
        #expect(throws: PrivacyError.locked) { try vault.keys.dataKey(vaultID: config.vaultID) }
        try await vault.unlockWithPassword(password)
        #expect(try vault.keys.dataKey(vaultID: config.vaultID) == first)
        vault.lock()
        try await vault.unlockWithSystem(reason: "Synthetic test")
        #expect(try vault.keys.dataKey(vaultID: config.vaultID) == first)
    }

    @Test func lockingDuringConfigurationCommitPreservesTheCommittedSystemKey() async throws {
        let store = MemoryVaultConfigurationStore()
        let system = FakeSystemVaultKeys()
        let vault = PrivacyVault(store: store, systemKeys: system)
        var lockedAfterCommit = false
        let observer = NotificationCenter.default.addObserver(forName: .privacyDidChange, object: vault, queue: .main) { _ in
            MainActor.assumeIsolated {
                guard vault.isConfigured, !lockedAfterCommit else { return }
                lockedAfterCommit = true
                vault.lock()
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        await #expect(throws: PrivacyError.staleOperation) { try await vault.create(password: nil, systemUnlock: true) }
        #expect(lockedAfterCommit && !vault.isUnlocked)
        let id = try #require(store.value?.systemKeyID)
        #expect(await system.items[id] != nil)
        let reopened = PrivacyVault(store: store, systemKeys: system)
        try await reopened.unlockWithSystem(reason: "Synthetic committed-key recovery")
        #expect(reopened.isUnlocked)
    }

    @Test func passwordOnlyNeverTouchesSystemStoreAndCannotRemoveLastMethod() async throws {
        let system = FakeSystemVaultKeys()
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: system)
        try await vault.create(password: password, systemUnlock: false)
        #expect(await system.items.isEmpty)
        await #expect(throws: PrivacyError.lastMethod) { try await vault.removePassword(reason: "Synthetic test") }
        await #expect(throws: PrivacyError.systemUnavailable) { try await vault.unlockWithSystem(reason: "Synthetic test") }
        #expect(vault.hasMasterPassword)
    }

    @Test func systemOnlyVerifiesRouteBeforeRemovingPassword() async throws {
        let system = FakeSystemVaultKeys()
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: system)
        try await vault.create(password: password, systemUnlock: true)
        await system.setReadError(.cancelled)
        await #expect(throws: PrivacyError.cancelled) { try await vault.removePassword(reason: "Synthetic test") }
        #expect(vault.hasMasterPassword)
        await system.setReadError(nil)
        try await vault.removePassword(reason: "Synthetic test")
        #expect(!vault.hasMasterPassword && vault.hasSystemUnlock)
        await #expect(throws: PrivacyError.lastMethod) { try await vault.disableSystemUnlock(masterPassword: password) }
    }

    @Test func disablingSystemDeletesItsCredentialAndPreservesPasswordRecovery() async throws {
        let system = FakeSystemVaultKeys()
        let store = MemoryVaultConfigurationStore()
        let vault = PrivacyVault(store: store, systemKeys: system)
        try await vault.create(password: password, systemUnlock: true)
        try await vault.disableSystemUnlock(masterPassword: password)
        #expect(await system.items.isEmpty)
        #expect(store.value?.systemKeyID == nil)
        let reopened = PrivacyVault(store: store, systemKeys: system)
        try await reopened.unlockWithPassword(password)
        #expect(reopened.isUnlocked)
    }

    @Test func failedCredentialRemovalRestoresConfiguration() async throws {
        let system = FakeSystemVaultKeys()
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: system)
        try await vault.create(password: password, systemUnlock: true)
        await system.setRemoveError(.systemUnavailable)
        await #expect(throws: PrivacyError.systemUnavailable) { try await vault.disableSystemUnlock(masterPassword: password) }
        #expect(vault.hasSystemUnlock && vault.hasMasterPassword)
    }

    @Test func failedSystemSetupKeepsOrphanedKeyTrackedAcrossRestart() async throws {
        let store = MemoryVaultConfigurationStore()
        let system = FakeSystemVaultKeys()
        let vault = PrivacyVault(store: store, systemKeys: system)
        await system.setReadError(.cancelled)
        await system.setRemoveError(.systemUnavailable)
        await #expect(throws: PrivacyError.systemCleanupPending) { try await vault.create(password: nil, systemUnlock: true) }
        #expect(store.value == nil && store.pendingSystemKeyIDs.count == 1)
        #expect(Set(await system.items.keys) == store.pendingSystemKeyIDs)
        let reopened = PrivacyVault(store: store, systemKeys: system)
        #expect(reopened.hasPendingSystemKeyCleanup)
        await system.setRemoveError(nil)
        await system.setReadError(nil)
        try await reopened.retrySystemKeyCleanup()
        #expect(store.pendingSystemKeyIDs.isEmpty && !reopened.hasPendingSystemKeyCleanup)
        #expect(await system.items.isEmpty)
        try await reopened.create(password: nil, systemUnlock: true)
        #expect(reopened.isUnlocked)
    }

    @Test func cleanupCannotDeleteACommittedKeyOrProceedWithUnreadableConfiguration() async throws {
        let store = MemoryVaultConfigurationStore()
        let system = FakeSystemVaultKeys()
        let vault = PrivacyVault(store: store, systemKeys: system)
        try await vault.create(password: password, systemUnlock: true)
        let id = try #require(store.value?.systemKeyID)
        store.pendingSystemKeyIDs = [id]
        store.loadError = PrivacyError.storageFailure
        await #expect(throws: PrivacyError.storageFailure) { try await vault.retrySystemKeyCleanup() }
        #expect(await system.items[id] != nil)
        #expect(store.pendingSystemKeyIDs == [id])
        store.loadError = nil
        try await vault.retrySystemKeyCleanup()
        #expect(store.pendingSystemKeyIDs.isEmpty)
        #expect(await system.items[id] != nil)
        vault.lock()
        try await vault.unlockWithSystem(reason: "Synthetic active-key preservation")
    }

    @Test func failedJournalWritePreventsCreatingAnySystemCredential() async throws {
        let store = MemoryVaultConfigurationStore()
        store.pendingSaveError = PrivacyError.storageFailure
        let system = FakeSystemVaultKeys()
        let vault = PrivacyVault(store: store, systemKeys: system)
        await #expect(throws: PrivacyError.systemCleanupPending) { try await vault.create(password: nil, systemUnlock: true) }
        #expect(await system.items.isEmpty)
        #expect(!vault.isConfigured)
    }

    @Test func lockingWhileStartupCleanupWaitsCannotFinishCreatingAnUnlockedVault() async throws {
        let store = MemoryVaultConfigurationStore()
        let system = FakeSystemVaultKeys()
        let orphan = UUID()
        store.pendingSystemKeyIDs = [orphan]
        try await system.create(Data(repeating: 7, count: 32), id: orphan)
        await system.suspendRemovals()
        let vault = PrivacyVault(store: store, systemKeys: system)
        let operation = Task { try await vault.create(password: password, systemUnlock: false) }
        for _ in 0..<200 where await system.pendingRemoval == nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect(await system.pendingRemoval != nil)
        vault.lock()
        await system.finishRemoval()
        await #expect(throws: PrivacyError.staleOperation) { try await operation.value }
        #expect(!vault.isUnlocked && !vault.isConfigured && store.value == nil)
        #expect(store.pendingSystemKeyIDs.isEmpty)
    }

    @Test func deletingKeyThenFailingJournalCleanupNeverRestoresItsEnabledConfiguration() async throws {
        let store = MemoryVaultConfigurationStore()
        let system = FakeSystemVaultKeys()
        let vault = PrivacyVault(store: store, systemKeys: system)
        try await vault.create(password: password, systemUnlock: true)
        let id = try #require(store.value?.systemKeyID)
        await system.suspendRemovals()
        let operation = Task { try await vault.disableSystemUnlock(masterPassword: password) }
        for _ in 0..<200 where await system.pendingRemoval == nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect(await system.pendingRemoval != nil)
        store.pendingSaveError = PrivacyError.storageFailure
        await system.finishRemoval()
        await #expect(throws: PrivacyError.systemCleanupPending) { try await operation.value }
        #expect(store.value?.systemKeyID == nil && !vault.hasSystemUnlock)
        #expect(await system.items[id] == nil)
        #expect(store.pendingSystemKeyIDs == [id])
        store.pendingSaveError = nil
        try await vault.retrySystemKeyCleanup()
        #expect(store.pendingSystemKeyIDs.isEmpty)
        vault.lock()
        try await vault.unlockWithPassword(password)
    }

    @Test func failedRevocationAndFailedRollbackRemainRecoverableAfterRestart() async throws {
        let store = MemoryVaultConfigurationStore()
        let system = FakeSystemVaultKeys()
        let vault = PrivacyVault(store: store, systemKeys: system)
        try await vault.create(password: password, systemUnlock: true)
        let id = try #require(store.value?.systemKeyID)
        await system.suspendRemovals()
        let operation = Task { try await vault.disableSystemUnlock(masterPassword: password) }
        for _ in 0..<200 where await system.pendingRemoval == nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect(await system.pendingRemoval != nil)
        #expect(store.value?.systemKeyID == nil && store.pendingSystemKeyIDs == [id])
        store.saveError = PrivacyError.storageFailure
        await system.setRemoveError(.systemUnavailable)
        await system.finishRemoval()
        await #expect(throws: PrivacyError.storageFailure) { try await operation.value }
        #expect(await system.items[id] != nil)
        store.saveError = nil
        let reopened = PrivacyVault(store: store, systemKeys: system)
        try await reopened.unlockWithPassword(password)
        #expect(reopened.hasPendingSystemKeyCleanup)
        await system.setRemoveError(nil)
        try await reopened.retrySystemKeyCleanup()
        #expect(await system.items[id] == nil)
        #expect(!reopened.hasPendingSystemKeyCleanup && reopened.isUnlocked)
    }

    @Test func changingPasswordFailureKeepsOriginalRoute() async throws {
        let store = MemoryVaultConfigurationStore()
        let vault = PrivacyVault(store: store, systemKeys: FakeSystemVaultKeys())
        try await vault.create(password: password, systemUnlock: false)
        let before = store.value
        store.saveError = PrivacyError.storageFailure
        await #expect(throws: PrivacyError.storageFailure) { try await vault.changePassword(to: "replacement-test-password") }
        #expect(store.value == before)
        store.saveError = nil
        vault.lock()
        try await vault.unlockWithPassword(password)
        #expect(vault.isUnlocked)
    }

    @Test func idleAndLateAuthenticationCannotReopenALockedVault() async throws {
        var time = Date(timeIntervalSince1970: 0)
        let system = FakeSystemVaultKeys()
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: system, now: { time })
        try await vault.create(password: nil, systemUnlock: true)
        time += 301
        vault.checkIdle()
        #expect(!vault.isUnlocked)
        await system.suspend()
        let task = Task { try await vault.unlockWithSystem(reason: "Synthetic test") }
        for _ in 0..<100 where await system.pendingRead == nil { await Task.yield() }
        #expect(await system.pendingRead != nil)
        vault.lock()
        await system.finishRead()
        await #expect(throws: PrivacyError.staleOperation) { try await task.value }
        #expect(!vault.isUnlocked)
    }

    @Test func unavailableOrCorruptConfigurationNeverReinitializes() async throws {
        let malformed = PrivacyConfiguration(vaultID: UUID(), passwordSlot: nil, systemKeyID: nil, verification: Data())
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(malformed), systemKeys: FakeSystemVaultKeys())
        #expect(vault.state == .unavailable)
        await #expect(throws: PrivacyError.corruptData) { try await vault.create(password: password, systemUnlock: false) }
    }

    @Test func authenticatedEncryptionRejectsTamperingAndWrongRecord() throws {
        let key = SymmetricKey(size: .bits256)
        let text = Data("synthetic-sensitive-value".utf8)
        let first = try VaultCrypto.seal(text, key: key, context: "diary:one")
        let second = try VaultCrypto.seal(text, key: key, context: "diary:one")
        #expect(first != second)
        #expect(try VaultCrypto.open(first, key: key, context: "diary:one") == text)
        #expect(throws: PrivacyError.corruptData) { try VaultCrypto.open(first, key: key, context: "diary:two") }
        var damaged = first
        damaged[damaged.count - 1] ^= 1
        #expect(throws: PrivacyError.corruptData) { try VaultCrypto.open(damaged, key: key, context: "diary:one") }
    }
}
