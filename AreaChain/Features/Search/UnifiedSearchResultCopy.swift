import Foundation

/// 只把既有完整性结论译成用户可理解的原因；不推断隐藏数量或重新判定命中。
struct UnifiedSearchResultCopy {
    let reasons: [String]
    let emptyKey: String

    init(_ status: ContentQueryPaginationStatus) {
        let complete = status.completeness
        var keys: Set<String> = []
        if complete.queryState != .content { keys.insert("unified.results.incompleteInput") }
        if complete.possibleTypes.isEmpty { keys.insert("unified.results.notApplicable") }
        for provider in complete.providers {
            for limitation in provider.limitations { keys.insert(Self.reason(limitation)) }
            for hint in provider.hints {
                if hint == .nonPublicCoverage { keys.insert("unified.results.protected") }
            }
        }
        let priority = ["unified.results.incompleteInput", "unified.results.notApplicable", "unified.results.readFailed",
                        "unified.results.protected", "unified.results.unread", "unified.results.unknown"]
        reasons = priority.filter { keys.contains($0) }
        emptyKey = status.canDeclareCompleteNoMatch ? "unified.results.empty" : (reasons.first ?? "unified.results.unknown")
    }

    private static func reason(_ limitation: ContentQueryBatchLimitation) -> String {
        switch limitation {
        case .source(_, .failed), .checkSource(.readFailed): "unified.results.readFailed"
        case .source, .enumerationRemainder: "unified.results.unread"
        case .nonPublicCoverage: "unified.results.protected"
        case .restriction(let value): value.requiresInput ? "unified.results.incompleteInput" : "unified.results.notApplicable"
        case .providerState(.invalidQuery), .providerState(.requiresInput): "unified.results.incompleteInput"
        case .providerState(.notApplicable): "unified.results.notApplicable"
        default: "unified.results.unknown"
        }
    }

    static func typeKey(_ type: CommandObjectType) -> String { "unified.results.type." + type.rawValue }

    static func metadata(_ values: [ContentQueryPresentationMetadata], locale: Locale) -> String {
        values.compactMap { value -> String? in
            switch value {
            case .day(_, let day): day.isEmpty ? nil : DayKey.displayName(day, locale: locale)
            case .completion(let done): L10n.format(done ? "unified.results.done" : "unified.results.open", locale: locale)
            case .enabled(let enabled): L10n.format(enabled ? "unified.results.enabled" : "unified.results.disabled", locale: locale)
            case .pinned(let pinned): pinned ? L10n.format("unified.results.pinned", locale: locale) : nil
            case .occurrenceStatus(let status): L10n.format("unified.results." + status.rawValue, locale: locale)
            case .tags(let tags): tags.compactMap(\.name).map { "#" + $0 }.joined(separator: " ")
            case .deleted(let date, let relation): deleted(date, relation: relation, locale: locale)
            case .tagColor: nil
            case .tagUsage(_, let summary): summary.map { L10n.format("unified.results.usage", locale: locale, $0.activeCount) }
            }
        }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private static func deleted(_ date: Date, relation: TrashDeletionRelation, locale: Locale) -> String {
        var parts = [L10n.format("unified.results.deletedMatch", locale: locale),
                     date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))]
        let key: String?
        switch relation {
        case .root: key = nil
        case .cascaded: key = "unified.results.cascaded"
        case .independent: key = "unified.results.independent"
        case .unresolved: key = "unified.results.relationUnknown"
        }
        if let key { parts.append(L10n.format(key, locale: locale)) }
        return parts.joined(separator: " · ")
    }

    static func relation(_ value: ContentQueryPresentationRelation, locale: Locale) -> String {
        let key: String
        switch value.role {
        case .parentTask: key = "unified.results.parent"
        case .imageOwner: key = "unified.results.owner"
        case .routine: key = "unified.results.routine"
        }
        return L10n.format(key, locale: locale, value.title ?? L10n.format(typeKey(value.object.type), locale: locale))
    }
}
