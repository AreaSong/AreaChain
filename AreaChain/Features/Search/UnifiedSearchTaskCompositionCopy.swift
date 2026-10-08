import Foundation

enum UnifiedSearchTaskCompositionCopy {
    static func error(_ error: Error) -> String {
        if let issue = error as? CommandTaskCreatePreviewIssue {
            switch issue {
            case .notesNotSupported: return "unified.composition.notes"
            case .invalidArguments: return "unified.composition.arguments"
            case .invalidCatalog: return "unified.composition.catalog"
            case .sourceConflict(let id): return id == .priority ? "unified.composition.priorityConflict" : "unified.composition.timeConflict"
            case .emptyEffectiveContent: return "unified.composition.empty"
            case .unsupportedPlan: return "unified.task.ownership"
            case .protectedContent: return "unified.composition.protectedContent"
            case .stale: return "unified.composition.stale"
            }
        }
        if let issue = error as? TaskCreateCommandIssue {
            if issue == .stale || issue == .alreadyInvoked { return "unified.composition.stale" }
            if issue == .protectedContent { return "unified.composition.protectedContent" }
            if issue == .invalidInput { return "unified.composition.arguments" }
            return UnifiedSearchTaskCreateCopy.issue(issue)
        }
        return "unified.composition.stale"
    }

    static func problem(_ kind: CommandTaskTagProblem.Kind) -> String {
        switch kind {
        case .protectedTag: return "unified.composition.protectedTag"
        case .ambiguousName, .duplicateID: return "unified.composition.ambiguousTag"
        case .missingID: return "unified.composition.missingTag"
        case .incompleteCatalog, .incompleteRecord: return "unified.composition.catalog"
        }
    }

    static func name(_ target: CommandTaskTagTarget) -> String {
        switch target {
        case .existing(let row): return row.name ?? ""
        case .newName(let name, _): return name
        }
    }

    static func effect(_ effect: CommandTaskTagAssociation.Effect) -> String {
        switch effect {
        case .associateLive: return "unified.composition.associate"
        case .restoreAndAssociate: return "unified.composition.restore"
        case .createAndAssociate: return "unified.composition.new"
        }
    }

    static func priority(_ flags: PriorityFlags) -> String {
        if flags.isImportant { return flags.isUrgent ? "P1" : "P2" }
        return flags.isUrgent ? "P3" : "P4"
    }

    static func time(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }

    static func field<Value>(_ resolution: CommandTaskFieldResolution<Value>, locale: Locale,
                             format: (Value) -> String,
                             unspecifiedKey: String = "unified.operation.mode.unspecified") -> String {
        let syntax = resolution.syntax.map(format) ?? L10n.format(unspecifiedKey, locale: locale)
        let explicit: String
        switch resolution.explicit {
        case .unspecified: explicit = L10n.format(unspecifiedKey, locale: locale)
        case .clear: explicit = L10n.format("unified.operation.mode.clear", locale: locale)
        case .set(let value): explicit = format(value)
        }
        return L10n.format("unified.composition.fieldSources", locale: locale, syntax, explicit)
    }
}
