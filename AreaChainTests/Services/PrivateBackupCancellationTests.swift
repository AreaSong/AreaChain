import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct PrivateBackupCancellationTests {
    private let backupPassword = "independent-backup-passphrase"

    @Test func cancelledBackupWriteStopsAfterPasswordWrap() async throws {
        let f = try await PrivacyFixture.make()
        defer {
            VaultCrypto.testingAfterKeyDerivation = nil
            VaultCrypto.testingDuringKeyDerivation = nil
            f.cleanup()
        }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: "口令派生后取消", dayKey: "2026-09-15", tagIDs: [tag.id])
        let originalText = note.text
        let originalProtected = note.hasProtectedContent
        let url = f.root.appending(path: "wrap-cancel.areachainbackup")
        let sentinel = Data("WRAP_CANCEL_SENTINEL".utf8)
        try sentinel.write(to: url)
        let capture = try PrivateBackupCapture.capture(context: f.context, vault: f.vault)
        let password = backupPassword
        let gate = CancelGate()
        VaultCrypto.testingAfterKeyDerivation = { try gate.blockUntilCancelled() }
        let task = Task.detached {
            try PrivateBackupFile.write(capture, password: password, to: url) { _ in Data() }
        }
        try await Task.detached { try gate.waitUntilWorkStarted() }.value
        task.cancel()
        await #expect(throws: PrivacyError.cancelled) { try await task.value }
        #expect(try Data(contentsOf: url) == sentinel)
        #expect(note.text == originalText && note.hasProtectedContent == originalProtected)
    }

    @Test func cancelledBackupWriteStopsDuringPasswordWrap() async throws {
        let f = try await PrivacyFixture.make()
        defer {
            VaultCrypto.testingDuringKeyDerivation = nil
            f.cleanup()
        }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: "口令轮次中取消", dayKey: "2026-09-15", tagIDs: [tag.id])
        let originalText = note.text
        let originalProtected = note.hasProtectedContent
        let url = f.root.appending(path: "wrap-mid-cancel.areachainbackup")
        let sentinel = Data("WRAP_MID_CANCEL_SENTINEL".utf8)
        try sentinel.write(to: url)
        let capture = try PrivateBackupCapture.capture(context: f.context, vault: f.vault)
        let password = backupPassword
        let gate = CancelGate()
        VaultCrypto.testingDuringKeyDerivation = { _ in try gate.blockUntilCancelled() }
        let task = Task.detached {
            try PrivateBackupFile.write(capture, password: password, to: url) { _ in Data() }
        }
        try await Task.detached { try gate.waitUntilWorkStarted() }.value
        task.cancel()
        await #expect(throws: PrivacyError.cancelled) { try await task.value }
        #expect(try Data(contentsOf: url) == sentinel)
        #expect(note.text == originalText && note.hasProtectedContent == originalProtected)
    }

    @Test func cancelledBackupReadStopsAfterPasswordUnwrap() async throws {
        let f = try await PrivacyFixture.make()
        defer {
            VaultCrypto.testingAfterKeyDerivation = nil
            VaultCrypto.testingDuringKeyDerivation = nil
            f.cleanup()
        }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: "回读口令后取消", dayKey: "2026-09-15", tagIDs: [tag.id])
        let imageBytes = Data(repeating: 0x66, count: 16 * 1024)
        let image = try f.image(owner: note, data: imageBytes)
        let url = f.root.appending(path: "unwrap-cancel.areachainbackup")
        _ = try await PrivateBackupService.export(to: url, password: backupPassword, environment: f.environment)
        let original = try Data(contentsOf: url)
        let originalText = note.text
        let originalProtected = note.hasProtectedContent
        let gate = CancelGate()
        let password = backupPassword
        VaultCrypto.testingAfterKeyDerivation = { try gate.blockUntilCancelled() }
        let task = Task.detached {
            _ = try PrivateBackupFile.open(from: url, password: password)
        }
        try await Task.detached { try gate.waitUntilWorkStarted() }.value
        task.cancel()
        await #expect(throws: PrivacyError.cancelled) { try await task.value }
        #expect(try Data(contentsOf: url) == original)
        #expect(note.text == originalText && note.hasProtectedContent == originalProtected)
        #expect(try f.files.read(reference: image.reference, root: f.root) == imageBytes)
    }

    @Test func restoreUnwrapsBackupPasswordOnce() async throws {
        let source = try await PrivacyFixture.make()
        let destination = try await PrivacyFixture.make()
        defer { source.cleanup(); destination.cleanup() }
        let tag = try source.tag()
        let note = try source.repository.addDiary(text: "单次派生", dayKey: "2026-09-15", tagIDs: [tag.id])
        _ = try source.image(owner: note, data: Data("once".utf8))
        let url = source.root.appending(path: "once.areachainbackup")
        _ = try await PrivateBackupService.export(to: url, password: backupPassword, environment: source.environment)
        VaultCrypto.testingPasswordUnwraps = 0
        try await PrivateBackupService.restore(from: url, password: backupPassword, environment: destination.environment)
        #expect(VaultCrypto.testingPasswordUnwraps == 1)
        #expect(try destination.repository.fetchDiary(id: note.id)?.hasProtectedContent == true)
    }
}
