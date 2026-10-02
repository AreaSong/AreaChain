import Foundation

struct ImageQueryMatching: CustomStringConvertible, CustomDebugStringConvertible {
    typealias Result = ImageQueryEvaluation
    let request: ImageQueryRequest
    let image: ImageBrowseProjection
    let owner: ImageOwnerProjection?
    let temporal: ImageQueryTemporal

    var description: String { "ImageQueryMatching(redacted)" }
    var debugDescription: String { description }

    init(request: ImageQueryRequest, image: ImageBrowseProjection, owner: ImageOwnerProjection?) {
        self.request = request
        self.image = image
        self.owner = owner
        temporal = .init(request: request, owner: owner)
    }

    var businessDay: String? {
        switch owner?.attributes {
        case .todo(let value): value.scheduledDay
        case .diary(let value): value.day
        default: nil
        }
    }

    private var ownerType: CommandObjectType {
        switch image.owner.kind {
        case .todo: .todo
        case .routine: .routine
        case .diary: .diary
        }
    }

    func evaluate(assessment: ContentQueryTypeAssessment?) -> Result {
        var result = Result.combine(request.session.conditions.map(match), any: false)
        // 静态分支沿用既有 OR 不掩盖不适用字段的约定；不能只靠部分合法项使该拥有者入围。
        let ownerAssessment = assessment?.imageOwnerAssessments.first { $0.type == ownerType }
        if ownerAssessment?.isPossible == false {
            result.truth = .doesNotMatch
            result.evidence = []
            result.diagnostics = result.diagnostics.map { value in
                var value = value
                value.affectsDetermination = false
                return value
            }
        }
        return result
    }

    private func match(_ condition: ContentQueryCondition) -> Result {
        switch condition.value {
        case .scope: return .known(true, id: condition.id, field: .scope)
        case .page(let predicate): return page(predicate, id: condition.id)
        case .clause(let terms):
            return Result.combine(terms.enumerated().map { index, term in
                var result = termMatch(term, id: condition.id)
                result.evidence = result.evidence.map { evidence in
                    var evidence = evidence
                    evidence.alternativeIndex = index
                    return evidence
                }
                return result
            }, any: true)
        }
    }

    private func termMatch(_ term: ContentQuerySemanticTerm, id: ContentQueryConditionID) -> Result {
        switch term.atom {
        case .text(let needle, _):
            let evidence = ContentQuerySnapshotMatching.text(needle, excluded: term.excluded,
                                                            fields: [(.filename, image.filename)], id: id)
            return .init(truth: evidence == nil ? .doesNotMatch : .matches, evidence: evidence ?? [])
        case .created(let interval):
            guard ContentQuerySnapshotValidation.validTimestamp(image.createdAt, dates: request.session.queryDates) else {
                return .unknown(.invalidCreatedAt, id: id)
            }
            return .known(ContentQuerySnapshotMatching.contains(interval, day: DayKey.from(
                image.createdAt, calendar: request.session.queryDates.calendar)), id: id, field: .createdAt)
        case .image: return inapplicable(id)
        default: break
        }
        let binding = ContentQueryApplicability.binding(for: term.atom, to: ownerType, occurrenceDay: request.session.occurrenceDay.dayKey)
        guard binding != .notApplicable else { return inapplicable(id) }
        guard let owner else { return .unknown(.missingOwnerAttributes, id: id) }
        return attributed(ownerTerm(term, attributes: owner.attributes, id: id))
    }

    private func ownerTerm(_ term: ContentQuerySemanticTerm, attributes: ImageOwnerAttributes, id: ContentQueryConditionID) -> Result {
        switch term.atom {
        case .tag(let name): return tag(name, excluded: term.excluded, tagIDs: attributes.queryTagIDs, id: id)
        case .priority(let flags):
            guard let bits = attributes.queryPriority else { return inapplicable(id) }
            return .known(bits.isImportant == flags.isImportant && bits.isUrgent == flags.isUrgent, id: id, field: .ownerPriority)
        case .reminder(let minutes): return .known(attributes.queryReminder == minutes, id: id, field: .ownerReminder)
        case .status(let status):
            if case .todo(let value) = attributes {
                return .known(value.isDone == (status == .done), id: id, field: .ownerCompletion)
            }
            return temporal.on(id: id, status: status)
        case .on: return temporal.on(id: id, status: nil)
        case .date(let interval):
            if case .routine = attributes { return temporal.date(interval, id: id) }
            guard let day = businessDay, ContentQuerySnapshotValidation.validDay(day, dates: request.session.queryDates) else {
                return .unknown(.missingOwnerAttributes, id: id)
            }
            return .known(ContentQuerySnapshotMatching.contains(interval, day: day), id: id, field: .ownerBusinessDay)
        case .text, .created, .image: return inapplicable(id)
        }
    }

    private func tag(_ name: String, excluded: Bool, tagIDs: String, id: ContentQueryConditionID) -> Result {
        let ids = TagIDList.normalized(TagIDList.parse(tagIDs))
        guard !ids.isEmpty else { return tagEvidence(name, excluded: excluded, tagIDs: tagIDs, names: [:], id: id) }
        guard let names = request.tagNames else { return .unknown(.missingTagNames, id: id) }
        let known = tagEvidence(name, excluded: excluded, tagIDs: tagIDs, names: names, id: id)
        // 已知名字命中足以决定正向/排除；没有命中且关联名字不全才未知。
        let found = ContentQuerySnapshotMatching.tag(name, excluded: false, tagIDs: tagIDs,
                                                     normalizedNames: names.mapValues(TagSyntax.normalizedName), id: id) != nil
        if !found && ids.contains(where: { names[$0] == nil }) { return .unknown(.missingAssociatedTagNames, id: id) }
        return known
    }

    private func tagEvidence(
        _ name: String, excluded: Bool, tagIDs: String, names: [UUID: String], id: ContentQueryConditionID
    ) -> Result {
        let evidence = ContentQuerySnapshotMatching.tag(name, excluded: excluded, tagIDs: tagIDs,
                                                        normalizedNames: names.mapValues(TagSyntax.normalizedName), id: id)
        return .init(truth: evidence == nil ? .doesNotMatch : .matches, evidence: (evidence ?? []).map {
            .init(conditionID: $0.conditionID, field: .ownerTags, kind: $0.kind, relatedObject: $0.relatedObject)
        })
    }

    private func page(_ predicate: ContentQueryPagePredicate, id: ContentQueryConditionID) -> Result {
        if case .contentTypes(let types) = predicate { return .known(types.contains(.image), id: id, field: .objectType) }
        let binding = ContentQueryApplicability.pageBinding(predicate, to: ownerType)
        guard binding != .notApplicable else { return inapplicable(id) }
        if binding == .typeNeutral { return attributed(neutral(id)) }
        guard let owner else { return .unknown(.missingOwnerAttributes, id: id) }
        return attributed(ownerPage(predicate, attributes: owner.attributes, id: id))
    }

    private func ownerPage(_ predicate: ContentQueryPagePredicate, attributes: ImageOwnerAttributes, id: ContentQueryConditionID) -> Result {
        switch predicate {
        case .tagID(let tagID, _):
            var result = Result.known(TagIDList.contains(attributes.queryTagIDs, tagID), id: id, field: .ownerTags)
            result.evidence = result.evidence.map {
                .init(conditionID: $0.conditionID, field: .ownerTags, relatedObject: .init(type: .tag, id: tagID))
            }
            return result
        case .noTags:
            return .init(truth: TagIDList.parse(attributes.queryTagIDs).isEmpty ? .matches : .doesNotMatch,
                         evidence: TagIDList.parse(attributes.queryTagIDs).isEmpty
                            ? [.init(conditionID: id, field: .ownerTags, kind: .absence)] : [])
        case .taskPriority(let priority):
            guard let bits = attributes.queryPriority else { return inapplicable(id) }
            return .known(Classification.matches(bits, filter: priority.filter), id: id, field: .ownerPriority)
        case .reminderPresence(let scope):
            return .known(Classification.matchesReminder(attributes.queryReminder, scope: scope), id: id, field: .ownerReminder)
        case .sourceApplication: return .unknown(.ownerSourceUnavailable, id: id)
        case .boardDate(let scope, let rule):
            guard case .todo(let value) = attributes,
                  rule.evaluation != .agenda || [.overdue, .upcoming].contains(scope) else {
                return .unknown(.unsupportedOwnerPageDate, id: id)
            }
            // 三种旧任务日期入口最终都用相同的安排日/完成条件，身份与活性已由关联层核实。
            return .known(Classification.matchesDate(dayKey: value.scheduledDay, isDone: value.isDone,
                todayKey: rule.todayKey, scope: scope, calendar: rule.calendar), id: id, field: .ownerBusinessDay)
        case .todoStatus(let status):
            if case .todo(let value) = attributes {
                return .known(value.isDone == (status == .done), id: id, field: .ownerCompletion)
            }
            return neutral(id)
        case .routineStatus(let status):
            if case .routine(let value) = attributes {
                return .known(value.isEnabled == (status == .enabled), id: id, field: .routineEnabled)
            }
            return neutral(id)
        case .itemKind(let kind):
            return .known((ownerType == .routine) == (kind == .recurring), id: id, field: .objectType)
        case .contentTypes: return inapplicable(id)
        }
    }

    private func attributed(_ result: Result) -> Result {
        var result = result
        result.evidence = result.evidence.map {
            var item = $0
            item.ownerObject = .init(type: ownerType, id: image.owner.id)
            if item.relatedObject == nil { item.relatedObject = item.ownerObject }
            return item
        }
        return result
    }

    private func inapplicable(_ id: ContentQueryConditionID) -> Result {
        .init(truth: .doesNotMatch, diagnostics: [.init(issue: .ownerConditionNotApplicable,
                                                      affectsDetermination: false, conditionIDs: [id])])
    }

    private func neutral(_ id: ContentQueryConditionID) -> Result {
        .init(truth: .matches, evidence: [.init(conditionID: id, field: .objectType, kind: .typeNeutral)])
    }
}

private extension ImageOwnerAttributes {
    var queryTagIDs: String {
        switch self {
        case .todo(let value): value.tagIDs
        case .routine(let value): value.tagIDs
        case .diary(let value): value.tagIDs
        }
    }
    var queryPriority: ClassifyBits? {
        switch self {
        case .todo(let value): .init(tagIDs: value.tagIDs, isImportant: value.isImportant, isUrgent: value.isUrgent, sourceBundleID: "")
        case .routine(let value): .init(tagIDs: value.tagIDs, isImportant: value.isImportant, isUrgent: value.isUrgent, sourceBundleID: "")
        case .diary: nil
        }
    }
    var queryReminder: Int? {
        switch self {
        case .todo(let value): value.remindMinutes
        case .routine(let value): value.remindMinutes
        case .diary: nil
        }
    }
}
