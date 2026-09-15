import CryptoKit
import Foundation
import LocalAuthentication
import Security
import XCTest
@testable import AreaChain

/// 真实钥匙串验收须显式授权；普通单测永远不会创建系统凭据。
@MainActor
final class SystemVaultIntegrationTests: XCTestCase {
    func testAuthorizedPhase() async throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["AREACHAIN_SYSTEM_KEYCHAIN_QA"] == "authorized",
                          "真实钥匙串验收默认关闭，须单独授权并指定 QA 阶段。")
        guard Bundle.main.bundleIdentifier == "com.areachain.privacy-qa",
              let runID = UUID(uuidString: environment["AREACHAIN_SYSTEM_KEYCHAIN_RUN_ID"] ?? ""),
              let phase = KeychainQAProbe.Phase(rawValue: environment["AREACHAIN_SYSTEM_KEYCHAIN_PHASE"] ?? "") else {
            throw KeychainQAProbe.Failure.invalidAuthorization
        }
        let probe = KeychainQAProbe(runID: runID)
        let status = KeychainQAStatus()
        let keys = SystemVaultKeyStore(service: probe.service, onFailure: { status.record($0) })
        defer {
            let details = "phase=\(phase.rawValue)\nrun=\(runID)\nservice=\(probe.service)\n"
                + "state=\(probe.stateURL.path)\nbundleVersion=\(probe.bundleVersion)\nOSStatus=\(status.values)\n"
            print("AREACHAIN_SYSTEM_KEYCHAIN_QA\n" + details)
            let attachment = XCTAttachment(string: details)
            attachment.name = "system-keychain-\(phase.rawValue).txt"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        switch phase {
        case .create:
            try await probe.create(using: keys)
        case .read, .rebuildRead:
            try await probe.verify(using: keys, afterRebuild: phase == .rebuildRead)
        case .cleanup:
            try await probe.cleanup(using: keys)
        }
    }
}

private struct KeychainQAProbe {
    enum Phase: String { case create, read, rebuildRead = "rebuild-read", cleanup }
    enum Failure: Error { case invalidAuthorization, existingRun, invalidState, unchangedBuild, cleanupUnconfirmed }
    struct State: Codable {
        let runID: UUID
        let expectedDigest: Data
        let creationVersion: String
    }

    let runID: UUID
    var service: String { "com.areachain.privacy-qa.system-validation." + runID.uuidString }
    var bundleVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown" }
    var stateURL: URL {
        URL.applicationSupportDirectory.appending(path: "areachain-keychain-validation", directoryHint: .isDirectory)
            .appending(path: runID.uuidString + ".json")
    }

    func create(using keys: SystemVaultKeyStore) async throws {
        guard !FileManager.default.fileExists(atPath: stateURL.path) else { throw Failure.existingRun }
        let key = try VaultCrypto.randomBytes(count: 32)
        let state = State(runID: runID, expectedDigest: Data(SHA256.hash(data: key)), creationVersion: bundleVersion)
        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        // 先记录唯一测试标识和摘要；中断后仍能找到待清理条目，不保存明文测试密钥。
        try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateURL.path)
        do {
            try await keys.create(key, id: runID)
        } catch {
            do { try await cleanup(using: keys) }
            catch { print("AREACHAIN_SYSTEM_KEYCHAIN_QA_CLEANUP_PENDING=\(stateURL.path)") }
            throw error
        }
    }

    func verify(using keys: SystemVaultKeyStore, afterRebuild: Bool) async throws {
        let bytes = try Data(contentsOf: stateURL)
        guard bytes.count < 4_096 else { throw Failure.invalidState }
        let state = try JSONDecoder().decode(State.self, from: bytes)
        guard state.runID == runID, state.expectedDigest.count == 32 else { throw Failure.invalidState }
        if afterRebuild, state.creationVersion == bundleVersion { throw Failure.unchangedBuild }
        let timeout = Task {
            do { try await Task.sleep(for: .seconds(120)); keys.cancel() }
            catch { /* 正常结束会取消计时，不取消后续认证。 */ }
        }
        defer { timeout.cancel() }
        let reason = "AreaChain 隔离验收：读取随机测试密钥，不访问真实手记。请在系统窗口中验证身份。"
        let key = try await keys.read(id: runID, reason: reason)
        XCTAssertEqual(Data(SHA256.hash(data: key)), state.expectedDigest)
    }

    func cleanup(using keys: SystemVaultKeyStore) async throws {
        try await keys.remove(id: runID)
        guard presenceStatus() == errSecItemNotFound else { throw Failure.cleanupUnconfirmed }
        if FileManager.default.fileExists(atPath: stateURL.path) { try FileManager.default.removeItem(at: stateURL) }
    }

    private func presenceStatus() -> OSStatus {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: runID.uuidString,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: false,
            kSecUseAuthenticationContext as String: context,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil)
    }
}

private final class KeychainQAStatus: @unchecked Sendable {
    private let mutex = NSLock()
    private var recorded: [OSStatus] = []
    var values: [OSStatus] {
        mutex.lock()
        defer { mutex.unlock() }
        return recorded
    }
    func record(_ value: OSStatus) {
        mutex.lock()
        recorded.append(value)
        mutex.unlock()
    }
}
