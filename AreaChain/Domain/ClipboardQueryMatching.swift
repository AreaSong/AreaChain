import Foundation

enum ClipboardQueryEvaluation {
    case match([ContentQueryMatchEvidence]), noMatch, unknown
}

enum ClipboardQueryMatching {
    static func supports(_ value: ContentQueryConditionValue) -> Bool {
        switch value {
        case .scope, .page(.sourceApplication), .page(.contentTypes): true
        case .clause(let terms): terms.allSatisfy { [.text, .date, .image].contains($0.atom.dimension) }
        default: false
        }
    }

    static func evaluate(
        _ record: ClipboardHistoryRecord, payload: ClipboardQueryPayload, session: ContentQuerySession
    ) -> ClipboardQueryEvaluation {
        var evidence: [ContentQueryMatchEvidence] = []
        var unknown = false
        for condition in session.conditions {
            switch evaluate(condition, record: record, payload: payload, dates: session.queryDates) {
            case .noMatch: return .noMatch
            case .unknown: unknown = true
            case .match(let found): evidence += found
            }
        }
        return unknown ? .unknown : .match(evidence)
    }

    private static func evaluate(
        _ condition: ContentQueryCondition, record: ClipboardHistoryRecord,
        payload: ClipboardQueryPayload, dates: ContentQueryDateContext
    ) -> ClipboardQueryEvaluation {
        switch condition.value {
        case .scope: return .match([.init(conditionID: condition.id, field: .scope)])
        case .page(.contentTypes): return .match([.init(conditionID: condition.id, field: .objectType)])
        case .page(.sourceApplication(let source)):
            return source == record.sourceBundleID
                ? .match([.init(conditionID: condition.id, field: .sourceApplication)]) : .noMatch
        case .clause(let terms):
            var evidence: [ContentQueryMatchEvidence] = []
            var unknown = false
            for (index, term) in terms.enumerated() {
                switch atom(term, record: record, payload: payload, condition: condition, dates: dates) {
                case .unknown: unknown = true
                case .noMatch: break
                case .match(let found): evidence += found.map {
                    var item = $0
                    item.alternativeIndex = index
                    return item
                }
                }
            }
            if !evidence.isEmpty { return .match(evidence) }
            return unknown ? .unknown : .noMatch
        default: return .noMatch
        }
    }

    private static func atom(
        _ term: ContentQuerySemanticTerm, record: ClipboardHistoryRecord, payload: ClipboardQueryPayload,
        condition: ContentQueryCondition, dates: ContentQueryDateContext
    ) -> ClipboardQueryEvaluation {
        switch term.atom {
        case .text(let needle, _):
            return ContentQuerySnapshotMatching.text(needle, excluded: term.excluded,
                fields: [(.clipboardPlainText, record.plainText)], id: condition.id).map(ClipboardQueryEvaluation.match) ?? .noMatch
        case .date(let interval):
            let day = DayKey.from(record.copiedAt, calendar: dates.calendar)
            return ContentQuerySnapshotMatching.contains(interval, day: day)
                ? .match([.init(conditionID: condition.id, field: .clipboardCapturedDay)]) : .noMatch
        case .image:
            switch payload.image {
            case .reference: return .match([.init(conditionID: condition.id, field: .clipboardImage)])
            case .none: return .noMatch
            case .invalidReference: return .unknown
            }
        default: return .noMatch
        }
    }
}
