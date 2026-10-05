import Foundation

enum FileLocalSettingCommandIssue: Error, Equatable {
    case unsupportedBackend, backendNotReady, needsExplicitGroup, unsupportedScope
    case duplicateFields([LocalPreferenceField]), conflict([LocalPreferenceField])
    case missingBaseline, untrustedBaseline, stale, busy, notRetryable
}

struct FileLocalSettingCommandRequest: Equatable {
    let lease: CommandHostLease
    let identity: CommandPreferenceGroupIdentity
    let attempt: CommandAttemptStamp
}

/// 成员是否改变只作说明，本地提交结论始终只有 localReceipt 一份。
struct FileLocalSettingCommandReport: Equatable {
    let identity: CommandPreferenceGroupIdentity
    let localReceipt: CommandExecutionReceipt
    var verificationReceipt: CommandExecutionReceipt?
    var presentationReceipt: CommandExecutionReceipt?
    let changedFields: Set<LocalPreferenceField>
    var recovery: LocalPreferenceFileRecovery?

    var latestAttempt: CommandAttemptStamp { presentationReceipt?.attempt ?? localReceipt.attempt }
}

struct FileLocalSettingConflictConfirmation: Equatable {
    let id: UUID
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let members: [CommandPlanItemStamp]
    let affectedFields: Set<LocalPreferenceField>
    let differences: [FileLocalSettingConflictDifference]
}

struct FileLocalSettingConflictDifference: Equatable {
    let command: CommandID
    let baseline: CommandValue
    let current: CommandValue
}

enum FileLocalSettingCommandMapping {
    static let commands: [CommandID] = ["setting.language", "setting.appearance", "setting.truncation", "setting.captureSource"]
        .map { .init(rawValue: $0) }

    static func values(_ items: [CommandPlanItem]) throws -> [LocalPreferenceValue] {
        guard (1...4).contains(items.count) else { throw FileLocalSettingCommandIssue.unsupportedScope }
        let values = try items.map { item in
            guard item.links.dependencies.isEmpty else { throw FileLocalSettingCommandIssue.unsupportedScope }
            return try LocalSettingCommandMapping.value(for: item.draft)
        }
        let duplicates = LocalPreferenceField.allCases.filter { field in values.filter { $0.field == field }.count > 1 }
        guard duplicates.isEmpty else { throw FileLocalSettingCommandIssue.duplicateFields(duplicates) }
        if items.count > 1, items.contains(where: { $0.atomicGroup == nil }) {
            throw FileLocalSettingCommandIssue.needsExplicitGroup
        }
        guard CommandPlanValidation.isPreferenceUnit(items) else { throw FileLocalSettingCommandIssue.unsupportedScope }
        return values
    }

    static func identity(_ record: LocalPreferenceRecord) throws -> CommandPreferenceRecordIdentity {
        let evidence = try LocalPreferenceRecordEvidence(record)
        return identity(evidence)
    }

    static func identity(_ evidence: LocalPreferenceRecordEvidence) -> CommandPreferenceRecordIdentity {
        .init(storeID: evidence.identity.storeID, epoch: evidence.identity.epoch,
              revision: evidence.revision, commitID: evidence.commitID, digest: evidence.digest)
    }

    static func conflicts(_ baseline: LocalPreferenceRecord, current: LocalPreferenceRecord,
                          fields: [LocalPreferenceField]) -> [LocalPreferenceField] {
        guard LocalPreferencePublishedState.committed(baseline).acceptsReload(current) else { return fields }
        return fields.filter {
            baseline.fieldRevisions[$0] != current.fieldRevisions[$0]
                || baseline.values.value(for: $0) != current.values.value(for: $0)
        }
    }

    static func diagnostics(_ fields: [LocalPreferenceField], items: [CommandPlanItem]) -> [CommandFieldConflict] {
        items.compactMap { item in
            guard let field = LocalSettingCommandMapping.field(for: item.draft.commandID), fields.contains(field) else { return nil }
            return .init(item: item.stamp,
                         field: .init(subject: .ambient, parameter: field == .stampCaptureApp ? .enabled : .value),
                         reason: .valueChanged)
        }
    }

    static func facts(_ result: LocalPreferenceFileCommit, baseline: LocalPreferenceRecord,
                      items: [CommandPlanItem]) throws -> CommandPreferenceGroupCommit {
        switch result {
        case .noChange: .noChange
        case .notCommitted: .notCommitted
        case .committed(let record): try .committed(identity(record), cleanupPending: false)
        case .committedCleanupPending(let record): try .committed(identity(record), cleanupPending: true)
        case .unknown(let pending, _): .unknown(identity(pending.target))
        case .recoveryRequired: .recoveryRequired
        case .conflict(let current): .conflict(diagnostics(conflicts(baseline, current: current,
            fields: items.compactMap { LocalSettingCommandMapping.field(for: $0.draft.commandID) }), items: items))
        }
    }

    static func presentation(_ report: LocalPreferencePresentation?) -> CommandPreferenceGroupPresentation {
        guard let report else { return .init(appearance: .pending, event: .pending, supersededCommands: []) }
        return .init(appearance: report.appearance, event: report.event,
                     supersededCommands: Set(commands.filter {
                         LocalSettingCommandMapping.field(for: $0).map(report.supersededFields.contains) == true
                     }))
    }
}
