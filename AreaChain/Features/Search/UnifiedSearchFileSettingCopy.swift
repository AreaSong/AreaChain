import Foundation

enum UnifiedSearchFileSettingCopy {
    static func issue(_ error: Error) -> String {
        if let legacy = error as? LocalSettingCommandIssue { return UnifiedSearchSettingCopy.issue(legacy) }
        guard let issue = error as? FileLocalSettingCommandIssue else {
            return error is CommandPlanError ? "unified.group.scope" : "unified.setting.stale"
        }
        switch issue {
        case .unsupportedBackend: return "unified.setting.unavailable"
        case .backendNotReady: return "unified.group.backendNotReady"
        case .needsExplicitGroup: return "unified.group.needsPreparation"
        case .unsupportedScope: return "unified.group.scope"
        case .duplicateFields: return "unified.group.duplicates"
        case .conflict: return "unified.group.conflict"
        case .missingBaseline, .untrustedBaseline: return "unified.group.needsPreparation"
        case .stale: return "unified.setting.stale"
        case .busy: return "unified.setting.finishEditing"
        case .notRetryable: return "unified.setting.noRetry"
        }
    }

    static func commit(_ report: FileLocalSettingCommandReport) -> CommandPreferenceGroupCommit? {
        if case .preferenceGroupCommit(let facts) = (report.verificationReceipt ?? report.localReceipt).result { return facts }
        return nil
    }

    static func presentation(_ report: FileLocalSettingCommandReport) -> CommandPreferenceGroupPresentation? {
        if case .preferenceGroupPresentation(let facts) = report.presentationReceipt?.result { return facts }
        return nil
    }

    static func result(_ report: FileLocalSettingCommandReport) -> String {
        switch commit(report) {
        case .noChange: return "unified.group.noChange"
        case .committed:
            if presentation(report)?.superseded == true { return "unified.group.superseded" }
            if presentation(report)?.incomplete == true { return "unified.group.presentationFailed" }
            return "unified.group.saved"
        case .unknown: return "unified.group.unknown"
        case .conflict: return "unified.group.conflict"
        case .recoveryRequired: return "unified.group.recoveryRequired"
        case .notCommitted: return "unified.group.notCommitted"
        case nil: return "unified.setting.runHeld"
        }
    }

    static func canReturn(_ report: FileLocalSettingCommandReport) -> Bool {
        switch commit(report) {
        case .notCommitted, .conflict, .recoveryRequired: true
        default: false
        }
    }
}
