import Foundation

enum UnifiedSearchTaskTitleCopy {
    static func error(_ error: Error) -> String {
        if let issue = error as? TaskTitleCommandIssue {
            switch issue {
            case .unassembled: return "unified.title.unassembled"
            case .dirtyContext, .nestedTransaction: return "unified.title.dirty"
            case .sourceUnavailable, .sourceChanged: return "unified.title.source"
            case .notesNotSupported: return "unified.title.notes"
            case .catalogChanged: return "unified.title.catalog"
            case .fieldsChanged: return "unified.title.fields"
            case .ineligibleEnvironment: return "unified.title.environment"
            case .stale, .alreadyInvoked: return "unified.title.stale"
            }
        }
        if let issue = error as? CommandTaskTitlePreviewIssue {
            switch issue {
            case .notesNotSupported: return "unified.title.notes"
            case .unsupportedPlan: return "unified.title.single"
            case .protectedContent: return "unified.composition.protectedContent"
            case .invalidArguments, .emptyTitle: return "unified.title.input"
            case .invalidBaseline: return "unified.title.baseline"
            case .missingTarget, .deletedTarget, .duplicateTarget, .invalidTarget: return "unified.title.target"
            case .invalidTagEncoding, .tags: return "unified.title.tags"
            case .storageUnavailable: return "unified.title.storage"
            case .stale: return "unified.title.stale"
            }
        }
        return "unified.title.stale"
    }

    static func result(_ facts: CommandTaskTitleFacts) -> String {
        switch facts.state {
        case .saved: return "unified.title.saved"
        case .noChange: return "unified.title.noChange"
        case .pending: return "unified.title.pendingResult"
        case .notSubmitted: return "unified.title.notSubmitted"
        case .unknown: return "unified.title.unknown"
        }
    }

    static func value(_ value: TaskTitleFieldValue?, locale: Locale) -> String {
        switch value {
        case .text(let text): return text
        case .flag(let flag): return L10n.format(flag ? "unified.operation.on" : "unified.operation.off", locale: locale)
        case .minutes(let minutes): return minutes.map(UnifiedSearchTaskCompositionCopy.time)
            ?? L10n.format("unified.title.noReminder", locale: locale)
        case nil: return L10n.format("unified.setting.unreadValue", locale: locale)
        }
    }
}
