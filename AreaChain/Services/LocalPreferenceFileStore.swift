import Foundation

/// 仅显式临时目录的同步后端。目录锁串行提交，内存锁保护失去磁盘证据后的未知标记。
final class LocalPreferenceFileStore: @unchecked Sendable {
    let identity: LocalPreferenceStoreIdentity
    private let io: LocalPreferenceFileIO
    private let fault: LocalPreferenceFileFault?
    let metrics: LocalPreferenceFileMetrics
    private let memoryLock = NSLock()
    private var unresolvedEvidence: LocalPreferencePendingWrite?
    private var unresolved: LocalPreferencePendingWrite? {
        get {
            memoryLock.lock()
            defer { memoryLock.unlock() }
            return unresolvedEvidence
        }
        set {
            memoryLock.lock()
            defer { memoryLock.unlock() }
            unresolvedEvidence = newValue
        }
    }

    init(temporaryRoot: URL, identity: LocalPreferenceStoreIdentity, fault: LocalPreferenceFileFault? = nil,
         metrics: LocalPreferenceFileMetrics = LocalPreferenceFileMetrics()) throws {
        self.identity = identity
        self.io = try LocalPreferenceFileIO(temporaryRoot: temporaryRoot)
        self.fault = fault
        self.metrics = metrics
    }

    func read() -> LocalPreferenceFileRead {
        metrics.increment(\.reads)
        do {
            let names = try io.names()
            if names.isEmpty { return unresolved == nil ? .absent : .unavailable(.inconsistentEvidence) }
            let lock = try LocalPreferenceFileLock.acquire(io, creating: false)
            return withExtendedLifetime(lock) { readLocked() }
        } catch { return .unavailable(issue(error)) }
    }

    /// 合成新存储显式建点，不是“缺文件就导入旧设置”；任何其他文件都阻断新建。
    func initializeNew(values: LocalPreferenceValues) -> LocalPreferenceFileCommit {
        let target = LocalPreferenceRecord.initial(identity: identity, values: values)
        do {
            try target.validate()
            let lock = try LocalPreferenceFileLock.acquire(io, creating: true)
            return withExtendedLifetime(lock) {
                do {
                    guard unresolved == nil, try Set(io.names()).isSubset(of: ["writer.lock"]) else {
                        return .recoveryRequired(readLocked())
                    }
                    return perform(base: nil, target: target, fields: LocalPreferenceField.allCases, lock: lock)
                } catch { return .notCommitted(issue(error)) }
            }
        } catch { return .notCommitted(issue(error)) }
    }

    /// 重开只核验 current/证据；有新来源时绝不调用旧源，最多清理已确认的 pending。
    func reopen(from source: LocalPreferenceLegacySource) -> LocalPreferenceMigrationResult {
        let state = read()
        switch state {
        case .absent:
            do { return .notMigrated(readOnly: try source.capture().values) }
            catch { return migrationFailure(error) }
        case .record(let record): return .ready(record, cleanupPending: false)
        case .pending: return migrationRecovery(verifyPendingCommit())
        case .unavailable: return .recoveryRequired(.backend(.blocked(state)))
        }
    }

    /// 显式初次迁移。锁不保护旧 UserDefaults；受控来源之外必须先停止旧版/其他写入者。
    func migrate(from source: LocalPreferenceLegacySource) -> LocalPreferenceMigrationResult {
        do {
            let lock = try LocalPreferenceFileLock.acquire(io, creating: true)
            return withExtendedLifetime(lock) {
                do {
                    let state = readLocked()
                    guard state == .absent, unresolved == nil,
                          try Set(io.names()).isSubset(of: ["writer.lock"]) else {
                        return migrationRecovery(verifyLocked())
                    }
                    let snapshot = try source.capture()
                    let target = LocalPreferenceRecord.initial(identity: identity, values: snapshot.values, migrationID: UUID())
                    let evidence = try LocalPreferenceMigrationEvidence(snapshot: snapshot, target: target)
                    try prepareMigration(evidence)
                    // 第二次四键采集也含存在性和来源；变化后保留已写证据，绝不更新它再重试。
                    guard try source.capture() == snapshot else { return .conflict(.sourceChanged) }
                    let result = perform(base: nil, target: target, fields: LocalPreferenceField.allCases, lock: lock)
                    return migrationCommit(result)
                } catch { return migrationFailure(error) }
            }
        } catch { return migrationFailure(error) }
    }

    private func prepareMigration(_ evidence: LocalPreferenceMigrationEvidence) throws {
        if fault == .migrationWrite { throw LocalPreferenceFileIssue.migrationWriteFailed }
        try io.create("migration.plist", data: evidence.encoded(), partial: fault == .migrationPartialWrite)
        if fault == .migrationReadback { throw LocalPreferenceFileIssue.readbackFailed }
        guard try readMigration() == evidence else { throw LocalPreferenceFileIssue.inconsistentEvidence }
        if fault == .migrationPrepared { throw LocalPreferenceFileIssue.incompleteMigration }
    }

    private func migrationFailure(_ error: Error) -> LocalPreferenceMigrationResult {
        if let problem = error as? LocalPreferenceMigrationIssue {
            if case .untrustedSource = problem { return .conflict(problem) }
            return .failed(problem)
        }
        return .failed(.file(issue(error)))
    }

    private func migrationCommit(_ result: LocalPreferenceFileCommit) -> LocalPreferenceMigrationResult {
        switch result {
        case .committed(let record), .noChange(let record): return .ready(record, cleanupPending: false)
        case .committedCleanupPending(let record): return .ready(record, cleanupPending: true)
        case .unknown(let pending, let issue): return .recoveryRequired(.unverifiedCommit(pending, issue))
        case .notCommitted(let issue): return .failed(.file(issue))
        case .recoveryRequired(let state): return .recoveryRequired(.backend(.blocked(state)))
        case .conflict: return .conflict(.sourceChanged)
        }
    }

    private func migrationRecovery(_ recovery: LocalPreferenceFileRecovery) -> LocalPreferenceMigrationResult {
        switch recovery {
        case .confirmed(let record), .nothingToVerify(.record(let record)): return .ready(record, cleanupPending: false)
        case .confirmedCleanupPending(let record): return .ready(record, cleanupPending: true)
        default: return .recoveryRequired(.backend(recovery))
        }
    }

    func commit(basedOn baseline: LocalPreferenceRecord, changes: [LocalPreferenceValue]) -> LocalPreferenceFileCommit {
        metrics.increment(\.commits)
        do {
            // 数组先校验重复，不用字典吞掉重复；全部纯输入检查发生在任何文件 IO 前。
            guard (1...4).contains(changes.count), Set(changes.map(\.field)).count == changes.count else {
                return .notCommitted(.invalidRequest)
            }
            try baseline.validate()
            guard baseline.identity == identity else { return .notCommitted(.sourceMismatch) }
            let lock = try LocalPreferenceFileLock.acquire(io, creating: false)
            return withExtendedLifetime(lock) { commitLocked(baseline: baseline, changes: changes, lock: lock) }
        } catch { return .notCommitted(issue(error)) }
    }

    private func commitLocked(baseline: LocalPreferenceRecord, changes: [LocalPreferenceValue],
                              lock: LocalPreferenceFileLock) -> LocalPreferenceFileCommit {
        let state = readLocked()
        guard case .record(let current) = state else { return .recoveryRequired(state) }
        guard accepts(baseline: baseline, current: current, changes: changes) else { return .conflict(current: current) }
        if changes.allSatisfy({ current.values.value(for: $0.field) == $0 }) { return .noChange(current) }
        do {
            let target = try current.changing(changes)
            return perform(base: current, target: target, fields: changes.map(\.field), lock: lock)
        } catch { return .notCommitted(issue(error)) }
    }

    private func accepts(baseline: LocalPreferenceRecord, current: LocalPreferenceRecord,
                         changes: [LocalPreferenceValue]) -> Bool {
        guard baseline.identity == current.identity, baseline.migrationID == current.migrationID,
              baseline.recordRevision <= current.recordRevision else { return false }
        if baseline.recordRevision == current.recordRevision { return baseline == current }
        guard LocalPreferenceField.allCases.allSatisfy({ baseline.fieldRevisions[$0] <= current.fieldRevisions[$0] }) else {
            return false
        }
        return changes.allSatisfy {
            baseline.fieldRevisions[$0.field] == current.fieldRevisions[$0.field]
                && baseline.values.value(for: $0.field) == current.values.value(for: $0.field)
        }
    }

    private func readLocked() -> LocalPreferenceFileRead {
        do {
            let names = try io.names()
            let migration = try readMigration()
            let current = try readCurrent()
            let pending = try readPending()
            if let unresolved, pending != unresolved { return .unavailable(.inconsistentEvidence) }
            let candidates = names.filter { $0.hasPrefix("candidate-") && $0.hasSuffix(".json") }
            let recognized = Set(["writer.lock", "current.json", "migration.plist", "pending-write.json"] + candidates)
            guard Set(names).isSubset(of: recognized), candidates.allSatisfy({ $0 == pending?.candidateName }) else {
                return .unavailable(.orphanedPreparation)
            }
            if let pending {
                if let migration, pending.base == nil, pending.target != migration.payload.target {
                    return .unavailable(.inconsistentEvidence)
                }
                if let current { try validateRelationship(pending, current: current) }
                return .pending(pending, current: current)
            }
            if current == nil, migration != nil { return .unavailable(.incompleteMigration) }
            return current.map(LocalPreferenceFileRead.record) ?? .absent
        } catch { return .unavailable(issue(error)) }
    }

    private func readCurrent() throws -> LocalPreferenceRecord? {
        if fault == .readCurrent { throw LocalPreferenceFileIssue.readFailed }
        guard let data = try io.read("current.json") else { return nil }
        let record = try LocalPreferenceRecordCodec.decode(LocalPreferenceRecord.self, from: data)
        try record.validate()
        guard record.identity == identity else { throw LocalPreferenceFileIssue.sourceMismatch }
        try validateMigration(record)
        return record
    }

    private func readMigration() throws -> LocalPreferenceMigrationEvidence? {
        guard let data = try io.read("migration.plist") else { return nil }
        let evidence = try LocalPreferenceMigrationEvidence.decode(data)
        try evidence.validate(identity: identity)
        return evidence
    }

    private func validateMigration(_ record: LocalPreferenceRecord) throws {
        if let migration = try readMigration() {
            try migration.validate(record: record)
        } else if record.migrationID != nil {
            throw LocalPreferenceFileIssue.inconsistentEvidence
        }
    }

    private func readPending() throws -> LocalPreferencePendingWrite? {
        guard let data = try io.read("pending-write.json") else { return nil }
        let pending = try LocalPreferenceRecordCodec.decode(LocalPreferencePendingWrite.self, from: data)
        try pending.validate(identity: identity)
        return pending
    }

    private func validateRelationship(_ pending: LocalPreferencePendingWrite, current: LocalPreferenceRecord) throws {
        if current.commitID == pending.target.commitID {
            guard try pending.target.matches(current), current.parentCommitID == pending.base?.commitID else {
                throw LocalPreferenceFileIssue.inconsistentEvidence
            }
        }
        if current.commitID == pending.base?.commitID, try pending.base?.matches(current) != true {
            throw LocalPreferenceFileIssue.inconsistentEvidence
        }
    }

    private func perform(base: LocalPreferenceRecord?, target: LocalPreferenceRecord,
                         fields: [LocalPreferenceField], lock: LocalPreferenceFileLock) -> LocalPreferenceFileCommit {
        let pending: LocalPreferencePendingWrite
        do {
            if fault == .encoding { throw LocalPreferenceFileIssue.encodingFailed }
            pending = try LocalPreferencePendingWrite(schemaVersion: 1, base: base.map(LocalPreferenceRecordEvidence.init),
                                                      target: LocalPreferenceRecordEvidence(target), fields: fields.map(\.storageName))
            let bytes = try LocalPreferenceRecordCodec.encode(target)
            let evidenceBytes = try LocalPreferenceRecordCodec.encode(pending)
            try prepare(bytes: bytes, evidenceBytes: evidenceBytes, pending: pending)
            try qualify(base: base, target: target, pending: pending, lock: lock)
        } catch { return .notCommitted(issue(error)) }

        // 从此处起，抛错也不能断言未提交。证据在任何权威替换之前已经落下并读回。
        unresolved = pending
        do {
            if fault == .replaceBefore { throw LocalPreferenceFileIssue.replacementFailed }
            metrics.increment(\.replacements)
            try io.replace(candidate: pending.candidateName)
            if fault == .replaceAfter { throw LocalPreferenceFileIssue.replacementFailed }
            if fault == .readback { throw LocalPreferenceFileIssue.readbackFailed }
            guard try readCurrent() == target, try readPending() == pending else { throw LocalPreferenceFileIssue.readbackFailed }
        } catch { return .unknown(pending, issue(error)) }
        unresolved = nil
        do {
            try cleanup(pending)
            return .committed(target)
        } catch { return .committedCleanupPending(target) }
    }

    private func prepare(bytes: Data, evidenceBytes: Data, pending: LocalPreferencePendingWrite) throws {
        if fault == .temporaryWrite { throw LocalPreferenceFileIssue.temporaryWriteFailed }
        try io.create(pending.candidateName, data: bytes, partial: fault == .temporaryPartialWrite)
        guard try io.read(pending.candidateName) == bytes else { throw LocalPreferenceFileIssue.temporaryWriteFailed }
        if fault == .pendingWrite { throw LocalPreferenceFileIssue.pendingWriteFailed }
        do { try io.create("pending-write.json", data: evidenceBytes, partial: fault == .pendingPartialWrite) }
        catch { throw LocalPreferenceFileIssue.pendingWriteFailed }
        if fault == .pendingRead { throw LocalPreferenceFileIssue.readFailed }
        guard try readPending() == pending else { throw LocalPreferenceFileIssue.inconsistentEvidence }
    }

    private func qualify(base: LocalPreferenceRecord?, target: LocalPreferenceRecord,
                         pending: LocalPreferencePendingWrite, lock: LocalPreferenceFileLock) throws {
        if fault == .qualification { throw LocalPreferenceFileIssue.qualificationChanged }
        try lock.validate()
        try validateMigration(target)
        guard try readCurrent() == base, try readPending() == pending,
              let data = try io.read(pending.candidateName),
              try LocalPreferenceRecordCodec.decode(LocalPreferenceRecord.self, from: data) == target else {
            throw LocalPreferenceFileIssue.qualificationChanged
        }
    }

    private func cleanup(_ pending: LocalPreferencePendingWrite) throws {
        if fault == .cleanupBefore { throw LocalPreferenceFileIssue.cleanupFailed }
        // 只删身份和内容已确认属于本 pending 的候选；pending 最后删除。
        if let data = try io.read(pending.candidateName) {
            let candidate = try LocalPreferenceRecordCodec.decode(LocalPreferenceRecord.self, from: data)
            try candidate.validate()
            guard try pending.target.matches(candidate) else { throw LocalPreferenceFileIssue.inconsistentEvidence }
            try io.remove(pending.candidateName)
        }
        guard try readPending() == pending else { throw LocalPreferenceFileIssue.inconsistentEvidence }
        try io.remove("pending-write.json")
        if fault == .cleanupAfter { throw LocalPreferenceFileIssue.cleanupFailed }
    }

    /// 显式核验只读取 current，最多清理辅助证据；不重新提交、不恢复命令或 lease。
    func verifyPendingCommit() -> LocalPreferenceFileRecovery {
        do {
            let lock = try LocalPreferenceFileLock.acquire(io, creating: false)
            return withExtendedLifetime(lock) { verifyLocked() }
        } catch { return .blocked(.unavailable(issue(error))) }
    }

    private func verifyLocked() -> LocalPreferenceFileRecovery {
        let state = readLocked()
        guard case .pending(let pending, let current) = state else {
            if case .unavailable = state { return .blocked(state) }
            return .nothingToVerify(state)
        }
        guard let current else { return .historicalUnknown(pending, current: nil) }
        do {
            if try pending.target.matches(current) {
                unresolved = nil
                do {
                    try cleanup(pending)
                    return .confirmed(current)
                } catch { return .confirmedCleanupPending(current) }
            }
            if try pending.base?.matches(current) == true { return .historicalUnknown(pending, current: current) }
            // 同 commitID 却不同内容不是“后来一份”；保留证据不清理。
            if current.commitID == pending.target.commitID || current.commitID == pending.base?.commitID {
                return .blocked(.unavailable(.inconsistentEvidence))
            }
            return .superseded(pending, current: current)
        } catch { return .blocked(.unavailable(issue(error))) }
    }

    private func issue(_ error: Error) -> LocalPreferenceFileIssue {
        (error as? LocalPreferenceFileIssue) ?? .readFailed
    }
}
