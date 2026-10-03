import Foundation
import SwiftData

struct TagUsageContentQueryStatistics {
    let input: TagQueryUsageInput
    let details: TagUsageContentQueryDetails
    fileprivate init(input: TagQueryUsageInput, details: TagUsageContentQueryDetails) {
        self.input = input; self.details = details
    }
}

extension TagUsageContentQueryCapture {
    /// 全来源完整与名称候选分开。任何无法可靠归属的坏行使整批未知，不发布局部正数。
    func statistics(dates: ContentQueryDateContext) -> TagUsageContentQueryStatistics {
        var checked = details
        let catalog = tags.values ?? []
        let tagIDs = Set(catalog.map(\.id))
        if tagIDs.count != catalog.count { checked.issues.insert(.invalidTagIdentity) }
        if catalog.contains(where: { $0.deletedAt.map { !ContentQuerySnapshotValidation.validTimestamp($0, dates: dates) } == true }) {
            checked.issues.insert(.invalidDate(.tag))
        }
        validate((todos.values ?? []).map(TagUsageRowStamp.init), type: .todo, tagIDs: tagIDs, dates: dates, details: &checked)
        validate((subtasks.values ?? []).map(TagUsageRowStamp.init), type: .subtask, tagIDs: tagIDs, dates: dates, details: &checked)
        validate((routines.values ?? []).map(TagUsageRowStamp.init), type: .routine, tagIDs: tagIDs, dates: dates, details: &checked)
        validate((diaries.values ?? []).map(TagUsageRowStamp.init), type: .diary, tagIDs: tagIDs, dates: dates, details: &checked)
        if !validOwnership() { checked.issues.insert(.invalidSubtaskOwnership) }
        let complete = checked.issues.isEmpty && [.todo, .subtask, .routine, .diary, .tag].allSatisfy {
            checked.sources[$0] == .complete
        }
        // subjects 是旧页唯一口径：父项已删不额外排除活子项；重复 tagIDs 不去重。
        let records = complete ? Array(TagUsage.records(TagUsage.subjects(
            todos: todos.values ?? [], routines: routines.values ?? [], diaries: diaries.values ?? [])).values) : []
        return .init(input: .init(records: records, coverage: complete ? .complete : .partial(completeTagIDs: [])), details: checked)
    }

    private func validate(_ rows: [TagUsageRowStamp], type: CommandObjectType, tagIDs: Set<UUID>,
                          dates: ContentQueryDateContext, details: inout TagUsageContentQueryDetails) {
        if Set(rows.map(\.id)).count != rows.count { details.issues.insert(.duplicateIdentity(type)) }
        for row in rows {
            if !ContentQuerySnapshotValidation.validTimestamp(row.subject.createdAt, dates: dates)
                || row.deletedAt.map({ !ContentQuerySnapshotValidation.validTimestamp($0, dates: dates) }) == true {
                details.issues.insert(.invalidDate(type))
            }
            let raw = row.subject.tagIDs
            let parts = raw.isEmpty ? [] : raw.split(separator: ",", omittingEmptySubsequences: false)
            let parsed = TagIDList.parse(raw)
            if parts.count != parsed.count || !Set(parsed).isSubset(of: tagIDs) {
                details.issues.insert(.invalidTagIDs(type))
            }
        }
    }

    private func validOwnership() -> Bool {
        guard let todos = todos.values, let subtasks = subtasks.values else { return false }
        let parents = Dictionary(grouping: todos, by: \.id)
        let children = todos.flatMap(\.subtasks)
        guard children.count == subtasks.count,
              Set(children.map(\.persistentModelID)) == Set(subtasks.map(\.persistentModelID)),
              Set(children.map(\.persistentModelID)).count == children.count else { return false }
        return subtasks.allSatisfy { child in
            guard let parent = child.todo, parent.modelContext === context,
                  let candidates = parents[parent.id], candidates.count == 1,
                  candidates[0].persistentModelID == parent.persistentModelID else { return false }
            return parent.subtasks.filter { $0.persistentModelID == child.persistentModelID }.count == 1
        }
    }
}
