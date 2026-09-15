import AppKit
import CryptoKit
import Foundation
import Observation

extension Notification.Name {
    static let privacyWillLock = Notification.Name("areachain.privacy.willLock")
    static let privacyDidChange = Notification.Name("areachain.privacy.didChange")
    static let privacyMask = Notification.Name("areachain.privacy.mask")
}

@Observable @MainActor
final class PrivacyVault {
    enum State { case unconfigured, locked, unlocked, unavailable }
    static let shared: PrivacyVault = {
        let testing = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let store: any VaultConfigurationStorage = testing
            ? MemoryVaultConfigurationStore() : FileVaultConfigurationStore()
        return PrivacyVault(store: store, systemKeys: SystemVaultKeyStore(), keys: .shared)
    }()

    private(set) var state: State = .unconfigured
    private(set) var configuration: PrivacyConfiguration?
    private(set) var issue: PrivacyError?
    private(set) var isAuthenticating = false
    private(set) var isChangingMethods = false
    private(set) var revision: UInt64 = 0
    private(set) var pendingSystemKeyIDs: Set<UUID> = []
    private(set) var systemKeyJournalUnavailable = false
    let keys: VaultKeyAccess
    let store: any VaultConfigurationStorage
    let systemKeys: any SystemVaultKeyStorage
    var generation: UInt64 = 0
    var authenticatedAt: Date?
    var lastActivity: Date?
    var passwordFailures = 0
    var retryAfter: Date?
    let now: () -> Date
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var timer: Timer?

    var isConfigured: Bool { configuration != nil }
    var isUnlocked: Bool { state == .unlocked }
    var hasSystemUnlock: Bool { configuration?.systemKeyID != nil }
    var hasMasterPassword: Bool { configuration?.passwordSlot != nil }
    var idleSeconds: Int { configuration?.idleSeconds ?? 300 }
    var hasPendingSystemKeyCleanup: Bool {
        systemKeyJournalUnavailable || pendingSystemKeyIDs.contains { $0 != configuration?.systemKeyID }
    }

    init(store: any VaultConfigurationStorage, systemKeys: any SystemVaultKeyStorage,
         keys: VaultKeyAccess = VaultKeyAccess(),
         now: @escaping () -> Date = { Date(timeIntervalSince1970: ProcessInfo.processInfo.systemUptime) }) {
        self.store = store
        self.systemKeys = systemKeys
        self.keys = keys
        self.now = now
        do {
            configuration = try store.load()
            try configuration?.validate()
            state = configuration == nil ? .unconfigured : .locked
        } catch {
            issue = error as? PrivacyError ?? .storageFailure
            state = .unavailable
        }
        if state != .unavailable {
            do { try reloadPendingSystemKeyIDs() }
            catch { issue = .systemCleanupPending }
        }
    }

    func unlockWithPassword(_ password: String) async throws {
        guard let config = configuration, let slot = config.passwordSlot else { throw PrivacyError.notConfigured }
        if let retryAfter, now() < retryAfter { throw PrivacyError.busy }
        let token = try beginAuthentication()
        defer { endAuthentication(token) }
        do {
            let data = try await Task.detached(priority: .userInitiated) {
                let key = try VaultCrypto.unwrap(slot, password: password, vaultID: config.vaultID)
                try VaultCrypto.verify(key, configuration: config)
                return key
            }.value
            try finishAuthentication(data, configuration: config, token: token)
            passwordFailures = 0
            retryAfter = nil
        } catch {
            if generation == token, error as? PrivacyError == .wrongPassword {
                passwordFailures += 1
                retryAfter = now().addingTimeInterval(min(30, pow(2, Double(max(0, passwordFailures - 2)))))
            }
            throw error
        }
    }

    func unlockWithSystem(reason: String) async throws {
        guard let config = configuration, let id = config.systemKeyID else { throw PrivacyError.systemUnavailable }
        let token = try beginAuthentication()
        defer { endAuthentication(token) }
        let data = try await systemKeys.read(id: id, reason: reason)
        try VaultCrypto.verify(data, configuration: config)
        try finishAuthentication(data, configuration: config, token: token)
    }

    func lock() {
        NotificationCenter.default.post(name: .privacyWillLock, object: self)
        generation &+= 1
        systemKeys.cancel()
        keys.clear()
        authenticatedAt = nil
        lastActivity = nil
        isAuthenticating = false
        if state != .unavailable { state = configuration == nil ? .unconfigured : .locked }
        changed()
    }

    func touch() {
        if isUnlocked { lastActivity = now() }
    }

    func checkIdle() {
        guard isUnlocked, let lastActivity, now().timeIntervalSince(lastActivity) >= Double(idleSeconds) else { return }
        lock()
    }

    func requireFreshAuthentication() throws -> PrivacyConfiguration {
        guard isUnlocked, let config = configuration, let authenticatedAt,
              now().timeIntervalSince(authenticatedAt) < 60 else { throw PrivacyError.locked }
        return config
    }

    func startLifecycle() {
        guard observers.isEmpty,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        observe(NSWorkspace.shared.notificationCenter, name: NSWorkspace.willSleepNotification, lock: true)
        observe(NSWorkspace.shared.notificationCenter, name: NSWorkspace.sessionDidResignActiveNotification, lock: true)
        observe(DistributedNotificationCenter.default(), name: .init("com.apple.screenIsLocked"), lock: true)
        observe(.default, name: NSApplication.willTerminateNotification, lock: true)
        observe(.default, name: NSApplication.didResignActiveNotification, lock: false)
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIdle() }
        }
        // 菜单跟踪或原生面板运行期间，闲置锁定也不能被默认运行循环模式推迟。
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func beginAuthentication() throws -> UInt64 {
        guard state != .unavailable else { throw issue ?? .storageFailure }
        guard !isAuthenticating else { throw PrivacyError.busy }
        generation &+= 1
        isAuthenticating = true
        return generation
    }

    func beginMethodChange() throws {
        guard !isChangingMethods else { throw PrivacyError.busy }
        isChangingMethods = true
    }

    func endMethodChange() { isChangingMethods = false }

    func endAuthentication(_ token: UInt64) {
        if generation == token { isAuthenticating = false }
    }

    func finishAuthentication(_ data: Data, configuration: PrivacyConfiguration, token: UInt64) throws {
        guard generation == token, self.configuration == configuration, !Task.isCancelled else { throw PrivacyError.staleOperation }
        keys.install(data, vaultID: configuration.vaultID)
        authenticatedAt = now()
        lastActivity = now()
        state = .unlocked
        issue = nil
        changed()
    }

    func persist(_ config: PrivacyConfiguration) throws {
        do {
            try store.save(config)
            configuration = config
            changed()
        } catch {
            throw PrivacyError.storageFailure
        }
    }

    func changed() {
        revision &+= 1
        NotificationCenter.default.post(name: .privacyDidChange, object: self)
    }

    func reloadPendingSystemKeyIDs() throws {
        do {
            pendingSystemKeyIDs = try store.loadPendingSystemKeyIDs()
            systemKeyJournalUnavailable = false
        } catch {
            systemKeyJournalUnavailable = true
            throw PrivacyError.systemCleanupPending
        }
    }

    func persistPendingSystemKeyIDs(_ ids: Set<UUID>) throws {
        do {
            try store.savePendingSystemKeyIDs(ids)
            pendingSystemKeyIDs = ids
            changed()
        } catch { throw PrivacyError.systemCleanupPending }
    }

    private func observe(_ center: NotificationCenter, name: Notification.Name, lock: Bool) {
        observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if lock { self.lock() }
                else { NotificationCenter.default.post(name: .privacyMask, object: self) }
            }
        })
    }
}
