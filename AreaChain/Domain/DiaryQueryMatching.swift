import Foundation

struct DiaryQueryMatching {
    typealias Result = DiaryQueryEvaluation
    /// 一次请求共用名字规范化和日期窗口，避免每个对象/关键词重扫整份标签表。
    struct Context {
        let session: ContentQuerySession
        let metadata: DiaryQueryMetadata
        let normalizedTagNames: [UUID: String]
        let dateWindow: ContentQueryDateWindow.Resolution
        let images: ContentQueryImageRead

        init(session: ContentQuerySession, metadata: DiaryQueryMetadata, images: ContentQueryImageRead) {
            self.session = session
            self.metadata = metadata
            self.images = images
            normalizedTagNames = (metadata.tagNames ?? [:]).mapValues(TagSyntax.normalizedName)
            dateWindow = ContentQueryDateWindow.resolve(session.conditions, dates: session.queryDates)
        }
    }

    let context: Context
    let diary: DiarySnapshot
    private var session: ContentQuerySession { context.session }
    private var metadata: DiaryQueryMetadata { context.metadata }

    func evaluate() -> Result {
        Result.combine(session.conditions.map(match), any: false)
    }

    private func match(_ condition: ContentQueryCondition) -> Result {
        switch condition.value {
        case .scope: return .known(true, id: condition.id, field: .scope)
        case .page(let predicate): return page(predicate, id: condition.id)
        case .clause(let terms):
            let values = terms.enumerated().map { index, term in
                var result = termMatch(term, id: condition.id)
                result.evidence = result.evidence.map { item in
                    var item = item
                    item.alternativeIndex = index
                    return item
                }
                return result
            }
            return Result.combine(values, any: true)
        }
    }

    private func termMatch(_ term: ContentQuerySemanticTerm, id: ContentQueryConditionID) -> Result {
        switch term.atom {
        case .text(let needle, _): return text(needle, excluded: term.excluded, id: id)
        case .tag(let name): return tag(name, excluded: term.excluded, id: id)
        case .date(let interval):
            // 沿同一 DateWindow 的并/交契约核对最终归属日，分支仍给自己的条件依据。
            guard case .window(let window) = context.dateWindow else {
                return .unknown(.invalidQuery, id: id)
            }
            return .known(window.contains(diary.dayKey) && ContentQuerySnapshotMatching.contains(interval, day: diary.dayKey),
                          id: id, field: .diaryDay)
        case .created(let interval):
            return .known(ContentQuerySnapshotMatching.contains(interval, day: DayKey.from(
                diary.createdAt, calendar: session.queryDates.calendar)), id: id, field: .createdAt)
        case .image: return context.images.evaluate(owner: .init(kind: .diary, id: diary.id), conditionID: id).diary
        case .priority, .reminder, .status, .on: return .unknown(.inapplicableCondition, id: id)
        }
    }

    private var associatedIDs: [UUID] { TagIDList.normalized(TagIDList.parse(diary.tagIDs)) }

    private func missingNames(id: ContentQueryConditionID) -> [DiaryQueryDiagnostic] {
        var issues: [DiaryQueryDiagnostic] = DiaryQueryMetadata.hasValidTagIDs(diary.tagIDs)
            ? [] : [.init(issue: .invalidTagIDs, conditionIDs: [id])]
        // 无关联可以直接证明无标签；未提供全表也不能伪造成丢失了某个实际关联。
        guard !associatedIDs.isEmpty else { return issues }
        guard let names = metadata.tagNames else { return issues + [.init(issue: .missingTagNames, conditionIDs: [id])] }
        issues += associatedIDs.filter { names[$0] == nil }.map {
            .init(issue: .missingAssociatedTagName($0), conditionIDs: [id])
        }
        return issues
    }

    private func text(_ needle: String, excluded: Bool, id: ContentQueryConditionID) -> Result {
        var diagnostics = missingNames(id: id)
        var found: [ContentQueryMatchEvidence] = []
        var fields: [(ContentQueryMatchField, String)] = []
        if diary.isContentAvailable { fields.append((.diaryBody, diary.text)) }
        else { diagnostics.append(.init(issue: .bodyUnavailable, severity: .warning, conditionIDs: [id])) }
        found += ContentQuerySnapshotMatching.text(needle, excluded: false, fields: fields, id: id) ?? []
        for tagID in associatedIDs {
            guard let name = metadata.tagNames?[tagID] else { continue }
            let evidence = ContentQuerySnapshotMatching.text(needle, excluded: false, fields: [(.tags, name)], id: id) ?? []
            found += evidence.map { item in
                var item = item
                item.relatedObject = .init(type: .tag, id: tagID)
                return item
            }
        }
        return presence(found, excluded: excluded, diagnostics: diagnostics, id: id, fields: [.diaryBody, .tags])
    }

    private func tag(_ name: String, excluded: Bool, id: ContentQueryConditionID) -> Result {
        let found = ContentQuerySnapshotMatching.tag(name, excluded: false, tagIDs: diary.tagIDs,
            normalizedNames: context.normalizedTagNames, id: id) ?? []
        return presence(found, excluded: excluded, diagnostics: missingNames(id: id), id: id, fields: [.tags])
    }

    /// 任何已知包含都足以决定正向/排除；只有全字段可读才能由没有命中推出不存在。
    private func presence(
        _ found: [ContentQueryMatchEvidence], excluded: Bool, diagnostics: [DiaryQueryDiagnostic],
        id: ContentQueryConditionID, fields: [ContentQueryMatchField]
    ) -> Result {
        let truth: DiaryQueryTruth
        if !found.isEmpty { truth = excluded ? .doesNotMatch : .matches }
        else if !diagnostics.isEmpty { truth = .unknown }
        else { truth = excluded ? .matches : .doesNotMatch }
        let evidence: [ContentQueryMatchEvidence] = truth != .matches ? []
            : (excluded ? fields.map { .init(conditionID: id, field: $0, kind: .absence) } : found)
        return .init(truth: truth, evidence: evidence, diagnostics: diagnostics.map { diagnostic in
            var diagnostic = diagnostic
            diagnostic.affectsDetermination = truth == .unknown
            return diagnostic
        })
    }

    private func page(_ predicate: ContentQueryPagePredicate, id: ContentQueryConditionID) -> Result {
        switch predicate {
        case .tagID(let tagID, _):
            let matches = TagIDList.contains(diary.tagIDs, tagID)
            if !matches && !DiaryQueryMetadata.hasValidTagIDs(diary.tagIDs) { return .unknown(.invalidTagIDs, id: id) }
            return .init(truth: matches ? .matches : .doesNotMatch, evidence: matches
                         ? [.init(conditionID: id, field: .tags, relatedObject: .init(type: .tag, id: tagID))] : [])
        case .noTags:
            let matches = TagIDList.parse(diary.tagIDs).isEmpty
            if matches && !DiaryQueryMetadata.hasValidTagIDs(diary.tagIDs) { return .unknown(.invalidTagIDs, id: id) }
            return .init(truth: matches ? .matches : .doesNotMatch,
                         evidence: matches ? [.init(conditionID: id, field: .tags, kind: .absence)] : [])
        case .contentTypes(let types): return .known(types.contains(.diary), id: id, field: .objectType)
        default: return .unknown(.inapplicableCondition, id: id)
        }
    }
}
