import Foundation

struct TrashQueryMatching: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "TrashQueryMatching(redacted)" }
    var debugDescription: String { description }
    typealias Result = TrashQueryEvaluation
    let session: ContentQuerySession
    let tagNames: [UUID: String]?
    let tagNamesCoverage: TrashReadCompleteness
    var routineInput: TrashQueryRoutineInput?

    func evaluate(_ object: TrashTombstone) -> Result {
        Result.combine(session.conditions.map { condition in
            switch condition.value {
            case .scope: return known(true, id: condition.id, field: .scope)
            case .page(let predicate): return page(predicate, object: object, id: condition.id)
            case .clause(let terms):
                return Result.combine(terms.enumerated().map { index, term in
                    var result = match(term, object: object, id: condition.id)
                    result.value.evidence = result.value.evidence.map {
                        var evidence = $0
                        evidence.alternativeIndex = index
                        return evidence
                    }
                    return result
                }, any: true)
            }
        }, any: false)
    }

    private func match(_ term: ContentQuerySemanticTerm, object: TrashTombstone, id: ContentQueryConditionID) -> Result {
        let own = TrashQueryFields(object.fields)
        if case .text(let needle, _) = term.atom {
            guard let text = own.text else { return .unknown(.unreadableBody, id: id) }
            return .known(ContentQuerySnapshotMatching.text(needle, excluded: term.excluded, fields: text, id: id))
        }
        if case .created(let interval) = term.atom { return created(interval, fields: own, id: id) }
        var fields = own
        let needsParent = own.type == .image || (own.type == .subtask && term.atom.dimension == .date)
        if needsParent {
            guard let parent = object.parentAttributes else { return .unknown(.missingParentAttributes, id: id) }
            fields = TrashQueryFields(parent.attributes)
        }
        let binding = ContentQueryApplicability.binding(for: term.atom, to: fields.type,
                                                        occurrenceDay: session.occurrenceDay.dayKey)
        guard binding != .notApplicable else { return known(false, id: id, field: .objectType) }
        if fields.type == .routine && [.date, .on, .status].contains(term.atom.dimension) {
            let result = TrashQueryTemporal.evaluate(term.atom, object: object, session: session, input: routineInput, id: id)
            return remap(result, object: object, parent: needsParent)
        }
        let result = scalar(term, fields: fields, id: id)
        return remap(result, object: object, parent: needsParent)
    }

    private func scalar(_ term: ContentQuerySemanticTerm, fields: TrashQueryFields, id: ContentQueryConditionID) -> Result {
        switch term.atom {
        case .tag(let name): return tag(name, excluded: term.excluded, fields: fields, id: id)
        case .priority(let flags):
            return known(fields.important == flags.isImportant && fields.urgent == flags.isUrgent, id: id, field: .priority)
        case .reminder(let minutes): return known(fields.reminder == minutes, id: id, field: .reminder)
        case .status(let status):
            if fields.type == .routine { return .unknown(.routineEvidenceUnavailable, id: id) }
            return known(fields.done == (status == .done), id: id, field: .completion)
        case .date(let interval):
            if fields.type == .routine { return .unknown(.routineEvidenceUnavailable, id: id) }
            guard let day = fields.day, ContentQuerySnapshotValidation.validDay(day, dates: session.queryDates) else {
                return .unknown(.invalidField, id: id)
            }
            return known(ContentQuerySnapshotMatching.contains(interval, day: day), id: id,
                         field: fields.type == .diary ? .diaryDay : .scheduledDay)
        case .on: return .unknown(.routineEvidenceUnavailable, id: id)
        case .image: return .unknown(.imageAssociationUnavailable, id: id)
        case .created: return .unknown(.invalidField, id: id)
        case .text: return .unknown(.unsupportedCondition, id: id)
        }
    }

    private func created(_ interval: ContentQueryDateInterval, fields: TrashQueryFields, id: ContentQueryConditionID) -> Result {
        guard let date = fields.createdAt, ContentQuerySnapshotValidation.validTimestamp(date, dates: session.queryDates) else {
            return .unknown(.invalidField, id: id)
        }
        return known(ContentQuerySnapshotMatching.contains(interval, day: DayKey.from(date, calendar: session.queryDates.calendar)),
                     id: id, field: .createdAt)
    }

    private func tag(_ name: String, excluded: Bool, fields: TrashQueryFields, id: ContentQueryConditionID) -> Result {
        guard let tags = fields.tagIDs, DiaryQueryMetadata.hasValidTagIDs(tags) else { return .unknown(.invalidField, id: id) }
        guard tagNamesCoverage == .completeIncludingDeleted, let names = tagNames,
              TagIDList.parse(tags).allSatisfy({ names[$0] != nil }) else { return .unknown(.missingTagNames, id: id) }
        return .known(ContentQuerySnapshotMatching.tag(name, excluded: excluded, tagIDs: tags,
                                                       normalizedNames: names.mapValues(TagSyntax.normalizedName), id: id))
    }

    private func page(_ predicate: ContentQueryPagePredicate, object: TrashTombstone, id: ContentQueryConditionID) -> Result {
        let own = TrashQueryFields(object.fields)
        let binding = ContentQueryApplicability.pageBinding(predicate, to: own.type)
        if binding == .notApplicable { return known(false, id: id, field: .objectType) }
        if binding == .typeNeutral {
            return .known([.init(conditionID: id, field: .objectType, kind: .typeNeutral)])
        }
        if case .contentTypes(let types) = predicate { return known(types.contains(own.type), id: id, field: .objectType) }
        let parentBindings: Set<ContentQueryFieldBinding> = [.parentPriority, .parentReminder, .parentCompletion,
            .parentSourceApplication, .parentScheduledDay, .requiresImageOwnerType]
        let needsParent = parentBindings.contains(binding)
        var fields = own
        if needsParent {
            guard let projection = object.parentAttributes else { return .unknown(.missingParentAttributes, id: id) }
            fields = TrashQueryFields(projection.attributes)
            if ContentQueryApplicability.pageBinding(predicate, to: fields.type) == .notApplicable {
                return known(false, id: id, field: .objectType)
            }
        }
        return remap(pageScalar(predicate, fields: fields, id: id), object: object, parent: needsParent)
    }

    private func pageScalar(_ predicate: ContentQueryPagePredicate, fields: TrashQueryFields, id: ContentQueryConditionID) -> Result {
        switch predicate {
        case .tagID(let tagID, let matching):
            if fields.type == .todo && matching == .taskOrSubtask { return .unknown(.unsupportedCondition, id: id) }
            guard let tags = fields.tagIDs, DiaryQueryMetadata.hasValidTagIDs(tags) else { return .unknown(.invalidField, id: id) }
            return known(TagIDList.contains(tags, tagID), id: id, field: .tags)
        case .noTags:
            guard let tags = fields.tagIDs, DiaryQueryMetadata.hasValidTagIDs(tags) else { return .unknown(.invalidField, id: id) }
            return known(TagIDList.parse(tags).isEmpty, id: id, field: .tags)
        case .taskPriority(let priority):
            guard let important = fields.important, let urgent = fields.urgent else { return .unknown(.invalidField, id: id) }
            let bits = ClassifyBits(tagIDs: "", isImportant: important, isUrgent: urgent, sourceBundleID: "")
            return known(Classification.matches(bits, filter: priority.filter), id: id, field: .priority)
        case .reminderPresence(let scope):
            return known(Classification.matchesReminder(fields.reminder, scope: scope), id: id, field: .reminder)
        case .sourceApplication(let bundle):
            guard let source = fields.source else { return .unknown(.unsupportedCondition, id: id) }
            return known(source == bundle, id: id, field: .sourceApplication)
        case .routineStatus(let status):
            if fields.type != .routine { return .known([.init(conditionID: id, field: .objectType, kind: .typeNeutral)]) }
            return known(status == .all || fields.enabled == (status == .enabled), id: id, field: .routineEnabled)
        case .todoStatus(let status):
            if fields.type == .routine { return .known([.init(conditionID: id, field: .objectType, kind: .typeNeutral)]) }
            return known(status == .all || fields.done == (status == .done), id: id, field: .completion)
        case .itemKind(let kind):
            return known(kind == .all || (kind == .recurring) == (fields.type == .routine), id: id, field: .objectType)
        case .boardDate: return .unknown(.unsupportedCondition, id: id)
        case .contentTypes: return known(true, id: id, field: .objectType)
        }
    }

    private func remap(_ value: Result, object: TrashTombstone, parent: Bool) -> Result {
        guard parent else { return value }
        var result = value
        result.value.evidence = value.value.evidence.map { item in
            let field: ContentQueryMatchField
            if object.id.type == .subtask {
                switch item.field {
                case .scheduledDay: field = .parentScheduledDay
                case .priority: field = .parentPriority
                case .completion: field = .parentCompletion
                case .reminder: field = .parentReminder
                default: field = item.field
                }
            } else {
                switch item.field {
                case .scheduledDay, .diaryDay: field = .ownerBusinessDay
                case .tags: field = .ownerTags
                case .priority: field = .ownerPriority
                case .reminder: field = .ownerReminder
                case .completion: field = .ownerCompletion
                case .occurrenceDay: field = .ownerOccurrenceDay
                case .scheduleExistence: field = .ownerScheduleExistence
                default: field = item.field
                }
            }
            return .init(conditionID: item.conditionID, field: field, kind: item.kind,
                         range: item.range, relatedObject: item.relatedObject, ownerObject: object.parentAttributes?.relatedObject)
        }
        return result
    }

    private func known(_ matched: Bool, id: ContentQueryConditionID, field: ContentQueryMatchField) -> Result {
        .known(matched ? [.init(conditionID: id, field: field)] : nil)
    }
}
