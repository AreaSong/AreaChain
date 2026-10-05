import Foundation

/// 封闭诊断不保存系统错误、路径或原始文件内容。
enum LocalPreferenceFileIssue: Error, Equatable, Sendable {
    case invalidRoot, readFailed, corrupt, unsupportedSchema, sourceMismatch, inconsistentEvidence
    case incompleteMigration, migrationWriteFailed, orphanedPreparation, invalidRequest, revisionExhausted
    case lockBusy, reentrant, lockFailed, encodingFailed, temporaryWriteFailed, pendingWriteFailed
    case qualificationChanged, replacementFailed, readbackFailed, cleanupFailed
}

enum LocalPreferenceFileRead: Equatable, Sendable {
    case absent
    case record(LocalPreferenceRecord)
    case pending(LocalPreferencePendingWrite, current: LocalPreferenceRecord?)
    case unavailable(LocalPreferenceFileIssue)
}

enum LocalPreferenceFileCommit: Equatable, Sendable {
    case noChange(LocalPreferenceRecord)
    case notCommitted(LocalPreferenceFileIssue)
    case committed(LocalPreferenceRecord)
    case committedCleanupPending(LocalPreferenceRecord)
    case unknown(LocalPreferencePendingWrite, LocalPreferenceFileIssue)
    case conflict(current: LocalPreferenceRecord)
    case recoveryRequired(LocalPreferenceFileRead)
}

enum LocalPreferenceFileRecovery: Equatable, Sendable {
    case nothingToVerify(LocalPreferenceFileRead)
    case confirmed(LocalPreferenceRecord)
    case confirmedCleanupPending(LocalPreferenceRecord)
    case historicalUnknown(LocalPreferencePendingWrite, current: LocalPreferenceRecord?)
    case superseded(LocalPreferencePendingWrite, current: LocalPreferenceRecord)
    case blocked(LocalPreferenceFileRead)
}

/// 只注入确定故障，不接任意回调；最终比较与替换之间没有应用闭包。
enum LocalPreferenceFileFault: Sendable {
    case encoding, temporaryWrite, temporaryPartialWrite, pendingWrite, pendingPartialWrite, pendingRead
    case qualification, replaceBefore, replaceAfter, readback, cleanupBefore, cleanupAfter
    case readCurrent
    case migrationWrite, migrationPartialWrite, migrationReadback, migrationPrepared
}

/// 只计实际入口/替换调用，无回调、无载荷；隔离测试以此核对共同提交次数。
final class LocalPreferenceFileMetrics: @unchecked Sendable {
    struct Counts: Equatable { var reads = 0; var commits = 0; var replacements = 0 }
    private let lock = NSLock()
    private var counts = Counts()

    func snapshot() -> Counts {
        lock.lock()
        defer { lock.unlock() }
        return counts
    }

    func increment(_ key: WritableKeyPath<Counts, Int>) {
        lock.lock()
        defer { lock.unlock() }
        counts[keyPath: key] += 1
    }
}
