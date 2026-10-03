import Foundation

/// 仅校验已有依据的语义形状与公开关联，不重新求值查询或读取关联对象。
enum ContentQueryPresentationEvidenceRules {
    static func issue(_ item: ContentQueryMatchEvidence, condition: ContentQueryConditionValue,
                      match: ContentQueryBatchMatch) -> ContentQueryPresentationIssue? {
        if let related = item.relatedObject, related.type != .routineOccurrence && related.dayKey != nil { return .invalidRelation }
        guard fields(for: match.id.type).contains(item.field) else { return .invalidField }
        guard item.range == nil else { return .invalidRange }
        let allowed: [ContentQueryMatchField]
        switch condition {
        case .scope:
            guard item.alternativeIndex == nil else { return .invalidBranch }
            allowed = [.scope]
        case .clause(let terms):
            guard let index = item.alternativeIndex, terms.indices.contains(index) else { return .invalidBranch }
            let term = terms[index]
            guard (term.excluded && item.kind == .absence) || (!term.excluded && item.kind == .positive) else {
                return .invalidBranch
            }
            allowed = fields(term.atom.dimension)
        case .page(let predicate):
            guard item.alternativeIndex == nil else { return .invalidBranch }
            if item.kind == .typeNeutral {
                guard item.field == .objectType else { return .invalidField }
                return relationIssue(item, match: match)
            }
            allowed = fields(predicate)
        }
        guard allowed.contains(item.field) else { return .invalidField }
        return relationIssue(item, match: match)
    }

    private static func fields(for type: CommandObjectType) -> [ContentQueryMatchField] {
        let common: [ContentQueryMatchField] = [.scope, .objectType]
        switch type {
        case .todo: return common + [.tags, .subtaskTags, .priority, .reminder, .completion, .scheduledDay,
                                     .createdAt, .sourceApplication, .legacyPageProjection, .imageAssociation]
        case .subtask: return common + [.tags, .completion, .createdAt, .parentPriority, .parentScheduledDay,
            .parentCompletion, .parentReminder, .parentSourceApplication, .parentItemKind, .legacyPageProjection]
        case .routine: return common + [.tags, .priority, .reminder, .completion, .routineEnabled, .createdAt,
            .sourceApplication, .scheduleExistence, .occurrenceDay, .legacyPageProjection, .imageAssociation]
        case .diary: return common + [.tags, .diaryDay, .createdAt, .imageAssociation]
        case .image: return common + [.createdAt, .ownerTags, .ownerPriority, .ownerReminder, .ownerCompletion,
            .ownerBusinessDay, .ownerOccurrenceDay, .ownerScheduleExistence, .routineEnabled]
        case .clipboardEntry: return common + [.clipboardCapturedDay, .clipboardImage, .sourceApplication]
        case .routineOccurrence: return common + [.completion, .occurrenceDay]
        case .tag: return common
        default: return []
        }
    }

    private static func fields(_ dimension: ContentQueryDimension) -> [ContentQueryMatchField] {
        switch dimension {
        case .text: []
        case .tag: [.tags, .ownerTags]
        case .priority: [.priority, .ownerPriority]
        case .reminder: [.reminder, .ownerReminder]
        case .status: [.completion, .ownerCompletion]
        case .date: [.scheduledDay, .parentScheduledDay, .diaryDay, .scheduleExistence, .occurrenceDay,
                     .ownerBusinessDay, .ownerScheduleExistence, .clipboardCapturedDay]
        case .on: [.occurrenceDay, .ownerOccurrenceDay]
        case .created: [.createdAt]
        case .image: [.imageAssociation, .clipboardImage]
        }
    }

    private static func fields(_ predicate: ContentQueryPagePredicate) -> [ContentQueryMatchField] {
        switch predicate {
        case .tagID: [.tags, .subtaskTags, .ownerTags]
        case .noTags: [.tags, .ownerTags]
        case .sourceApplication: [.sourceApplication, .parentSourceApplication]
        case .taskPriority: [.priority, .parentPriority, .ownerPriority]
        case .reminderPresence: [.reminder, .parentReminder, .ownerReminder]
        case .boardDate: [.scheduledDay, .parentScheduledDay, .legacyPageProjection, .scheduleExistence,
                          .ownerBusinessDay, .ownerScheduleExistence]
        case .itemKind: [.objectType, .parentItemKind]
        case .todoStatus: [.completion, .parentCompletion, .ownerCompletion, .objectType]
        case .routineStatus: [.routineEnabled, .objectType]
        case .contentTypes: [.objectType]
        }
    }

    private static func relationIssue(_ item: ContentQueryMatchEvidence,
                                      match: ContentQueryBatchMatch) -> ContentQueryPresentationIssue? {
        let parent = parentReference(match)
        let ownerFields: [ContentQueryMatchField] = [.ownerTags, .ownerPriority, .ownerReminder, .ownerCompletion,
            .ownerBusinessDay, .ownerOccurrenceDay, .ownerScheduleExistence]
        let parentFields: [ContentQueryMatchField] = [.parentPriority, .parentScheduledDay, .parentCompletion,
            .parentReminder, .parentSourceApplication, .parentItemKind]
        if ownerFields.contains(item.field) || parentFields.contains(item.field) {
            guard let parent, item.ownerObject == parent || item.relatedObject == parent else { return .invalidRelation }
        }
        if let owner = item.ownerObject {
            let isOwnerField = ownerFields.contains(item.field) || parentFields.contains(item.field)
                || (match.id.type == .image && [.objectType, .routineEnabled].contains(item.field))
            guard owner == parent, isOwnerField else { return .invalidRelation }
        }
        guard let related = item.relatedObject else { return nil }
        switch item.field {
        case .tags:
            guard related.type == .tag else { return .invalidRelation }
            if let tags = knownTagIDs(match), !tags.contains(related.id) { return .invalidRelation }
            return nil
        case .ownerTags: return related.type == .tag || related == parent ? nil : .invalidRelation
        case .subtaskTags: return related.type == .subtask && match.id.type == .todo ? nil : .invalidRelation
        case .occurrenceDay, .completion, .scheduleExistence, .ownerOccurrenceDay, .ownerCompletion, .ownerScheduleExistence:
            if ownerFields.contains(item.field), related == parent { return nil }
            let routineID = match.id.type == .image ? parent?.id : match.id.id
            return related.type == .routineOccurrence && related.id == routineID
                && related.dayKey.map(CommandArgumentValidation.isCanonicalDay) == true ? nil : .invalidRelation
        default:
            let allowsParent = parentFields.contains(item.field) || ownerFields.contains(item.field)
                || item.field == .legacyPageProjection || (match.id.type == .image && item.ownerObject != nil)
                || (item.field == .objectType && item.kind == .typeNeutral)
            return allowsParent && related == parent ? nil : .invalidRelation
        }
    }

    private static func knownTagIDs(_ match: ContentQueryBatchMatch) -> [UUID]? {
        switch match {
        case .diary(let value): return value.tags.map(\.id)
        case .trash(let value):
            return TrashQueryFields(value.object.fields).tagIDs.map(TagIDList.parse)
        default: return nil
        }
    }

    static func parentReference(_ match: ContentQueryBatchMatch) -> CommandObjectReference? {
        switch match {
        case .subtask(let value): value.parent
        case .image(let value): ownerReference(value.owner)
        case .routineOccurrence(let value): value.routine
        case .trash(let value):
            switch value.object.relation {
            case .cascaded(let parent), .independent(let parent, _): parent
            case .unresolved(let parent, _): parent
            case .root: nil
            }
        default: nil
        }
    }

    static func ownerReference(_ owner: AttachmentOwnerKey) -> CommandObjectReference {
        let type: CommandObjectType
        switch owner.kind {
        case .todo: type = .todo
        case .routine: type = .routine
        case .diary: type = .diary
        }
        return .init(type: type, id: owner.id)
    }
}
