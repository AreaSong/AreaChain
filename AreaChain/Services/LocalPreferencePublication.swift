import Foundation

/// 四值只保留在这一份不可变发布值中；文件模式的值和修订均从同一个 record 派生。
enum LocalPreferencePublishedState: Equatable {
    case legacy(LocalPreferenceValues)
    case readOnly(LocalPreferenceValues)
    case committed(LocalPreferenceRecord)

    var values: LocalPreferenceValues {
        switch self {
        case .legacy(let values), .readOnly(let values): values
        case .committed(let record): record.values
        }
    }

    var record: LocalPreferenceRecord? {
        if case .committed(let record) = self { return record }
        return nil
    }

    /// 磁盘核验不等于可连续发布；已见过的同源修订不能在运行内倒退。
    func acceptsReload(_ next: LocalPreferenceRecord) -> Bool {
        guard let previous = record else { return true }
        guard previous.identity == next.identity, previous.migrationID == next.migrationID else { return false }
        if next.recordRevision == previous.recordRevision { return next == previous }
        return next.recordRevision > previous.recordRevision && LocalPreferenceField.allCases.allSatisfy {
            next.fieldRevisions[$0] > previous.fieldRevisions[$0]
                || (next.fieldRevisions[$0] == previous.fieldRevisions[$0]
                    && next.values.value(for: $0) == previous.values.value(for: $0))
        }
    }
}

enum LocalPreferenceBackendState: Equatable {
    case legacy, ready
    case readOnly(LocalPreferenceMigrationResult)
    case verificationRequired(LocalPreferenceFileRead)
    case cleanupPending(LocalPreferenceFileRead)
    case unknown(LocalPreferencePendingWrite, LocalPreferenceFileIssue)

    var canWrite: Bool { self == .legacy || self == .ready }

    var blockedRead: LocalPreferenceFileRead {
        switch self {
        case .verificationRequired(let state), .cleanupPending(let state): state
        case .unknown(let pending, _): .pending(pending, current: nil)
        default: .unavailable(.qualificationChanged)
        }
    }
}

/// 只接已存在的后端，重用 read/verify；不采集旧键、不迁移、不建立或重写 current。
struct LocalPreferenceLoad {
    let published: LocalPreferencePublishedState
    let backend: LocalPreferenceBackendState

    static func initial(_ startup: LocalPreferenceMigrationResult, store: LocalPreferenceFileStore) -> Self {
        switch startup {
        case .ready(let record, let cleanupPending):
            do {
                try record.validate()
                guard record.identity == store.identity else { return rejected(.unavailable(.sourceMismatch)) }
            } catch {
                return rejected(.unavailable((error as? LocalPreferenceFileIssue) ?? .corrupt))
            }
            let state = store.read()
            if case .record(let current) = state, current == record {
                return Self(published: .committed(current), backend: .ready)
            }
            // 带完整载荷的 pending 仍须由原恢复入口确认，调用方的 ready 不是写许可。
            if cleanupPending, case .pending(_, let current) = state, current == record {
                switch store.verifyPendingCommit() {
                case .confirmed(let verified), .confirmedCleanupPending(let verified):
                    guard verified == record else { return rejected(state) }
                    return Self.verified(verified, store: store)
                default: break
                }
            }
            return rejected(state)
        case .notMigrated(let values):
            return Self(published: .readOnly(values), backend: .readOnly(startup))
        default:
            return Self(published: .readOnly(.legacyDefaults), backend: .readOnly(startup))
        }
    }

    static func verified(_ record: LocalPreferenceRecord, store: LocalPreferenceFileStore) -> Self {
        let state = store.read()
        switch state {
        case .record(let current) where current == record:
            return Self(published: .committed(record), backend: .ready)
        case .pending(let pending, let current) where current == record:
            guard (try? pending.target.matches(record)) == true else { return rejected(state) }
            return Self(published: .committed(record), backend: .cleanupPending(state))
        default: return rejected(state)
        }
    }

    private static func rejected(_ state: LocalPreferenceFileRead) -> Self {
        Self(published: .readOnly(.legacyDefaults), backend: .verificationRequired(state))
    }
}

/// 组事件只有身份、变化字段及必要修订；不携带四值、设置字典或业务内容。
struct LocalPreferenceGroupChange: Equatable, Sendable {
    let source: LocalPreferenceSource
    let identity: LocalPreferenceStoreIdentity
    let recordRevision: UInt64
    let commitID: UUID
    let fields: Set<LocalPreferenceField>
    let fieldRevisions: [LocalPreferenceField: UInt64]

    init(source: LocalPreferenceSource, record: LocalPreferenceRecord, fields: Set<LocalPreferenceField>) {
        self.source = source
        identity = record.identity
        recordRevision = record.recordRevision
        commitID = record.commitID
        self.fields = fields
        fieldRevisions = Dictionary(uniqueKeysWithValues: fields.map { ($0, record.fieldRevisions[$0]) })
    }

    func currentFields(in record: LocalPreferenceRecord?) -> Set<LocalPreferenceField> {
        guard let record, record.identity == identity, record.recordRevision >= recordRevision,
              record.recordRevision != recordRevision || record.commitID == commitID else { return [] }
        return Set(fields.filter { fieldRevisions[$0] == record.fieldRevisions[$0] })
    }

    static func changedFields(from previous: LocalPreferenceRecord?, to next: LocalPreferenceRecord) -> Set<LocalPreferenceField> {
        guard let previous, previous.identity == next.identity else { return Set(LocalPreferenceField.allCases) }
        return Set(LocalPreferenceField.allCases.filter {
            previous.fieldRevisions[$0] != next.fieldRevisions[$0] || previous.values.value(for: $0) != next.values.value(for: $0)
        })
    }
}
