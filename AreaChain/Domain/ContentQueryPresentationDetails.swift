import Foundation

/// 文字仍由 SortFields 唯一提取；这里仅处理各类已公开元数据及所属关系。
enum ContentQueryPresentationDetails {
    static func apply(_ match: ContentQueryBatchMatch, to row: inout ContentQueryPresentationRow) {
        switch match {
        case .todo(let value): row.metadata = [.day(field: .scheduledDay, key: value.dayKey), .completion(value.isDone)]
        case .subtask(let value):
            row.relations = [.init(role: .parentTask, object: value.parent, title: value.parentTitle)]
            row.metadata = [.day(field: .parentScheduledDay, key: value.parentScheduledDay), .completion(value.isDone)]
        case .routine(let value): row.metadata = [.enabled(value.isEnabled)]
        case .diary(let value):
            diary(value.presentation, day: value.dayKey, pinned: value.isPinned, row: &row)
            row.metadata.append(.tags(value.tags))
        case .image(let value):
            row.relations = [.init(role: .imageOwner,
                object: ContentQueryPresentationEvidenceRules.ownerReference(value.owner), title: nil)]
        case .tag(let value): row.metadata = [.tagColor(value.tag.resolvedColorToken), .tagUsage(value.usageState, value.usage)]
        case .clipboard(let value): row.metadata = [.pinned(value.isPinned)]
        case .routineOccurrence(let value):
            row.relations = [.init(role: .routine, object: value.routine, title: value.routineTitle)]
            row.metadata = [.occurrenceStatus(value.status)]
            if let day = value.id.dayKey { row.metadata.append(.day(field: .occurrenceDay, key: day)) }
        case .trash(let value): trash(value.object, row: &row)
        }
    }

    private static func diary(_ presentation: DiaryQueryPresentation, day: String, pinned: Bool,
                              row: inout ContentQueryPresentationRow) {
        row.metadata += [.day(field: .diaryDay, key: day), .pinned(pinned)]
        if case .hiddenTitle(let title) = presentation {
            row.primary = .init(text: title, field: nil, mapping: nil, highlights: [], omittedPublicContent: false)
        }
    }

    private static func trash(_ value: TrashTombstone, row: inout ContentQueryPresentationRow) {
        row.metadata = [.deleted(value.deletedAt, value.relation)]
        switch value.fields {
        case .todo(let item): row.metadata += [.day(field: .scheduledDay, key: item.dayKey), .completion(item.isDone)]
        case .subtask(let item): row.metadata += [.completion(item.isDone)]
        case .routine(let item): row.metadata += [.enabled(item.isEnabled)]
        case .diary(let item):
            diary(item.presentation, day: item.dayKey, pinned: item.isPinned, row: &row)
            row.metadata.append(.tags(item.tags))
        case .tag(let item): row.metadata.append(.tagColor(item.resolvedColorToken))
        case .image: break
        }
        if let parent = ContentQueryPresentationEvidenceRules.parentReference(.trash(.init(object: value, evidence: []))) {
            row.relations = [.init(role: value.id.type == .subtask ? .parentTask : .imageOwner, object: parent, title: nil)]
        }
    }
}
