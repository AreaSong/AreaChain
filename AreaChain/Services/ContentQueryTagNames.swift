import Foundation

enum ContentQueryTagNameIssue: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case fetchFailed, ambiguousID(UUID), missingID(UUID), privateNameUnavailable(UUID)
    var description: String { "ContentQueryTagNameIssue(redacted)" }
    var debugDescription: String { description }
}

/// 任务与习惯只共享关联名字读取；局部映射不声明全局私密资料或标签内容来源完整。
@MainActor
struct ContentQueryTagNames {
    let values: [UUID: String]?
    let coverage: ContentQuerySourceCoverage
    let issues: [ContentQueryTagNameIssue]

    static func associatedIDs(in batch: ContentQueryBatch) -> Set<UUID> {
        Set((batch.snapshots.todos.values ?? []).flatMap { TagIDList.parse($0.tagIDs) }
            + (batch.snapshots.subtasks.values ?? []).flatMap { TagIDList.parse($0.tagIDs) }
            + (batch.snapshots.routines.values ?? []).flatMap { TagIDList.parse($0.tagIDs) }
            + (batch.snapshots.diaries.values ?? []).flatMap { TagIDList.parse($0.tagIDs) })
    }

    static func read(_ ids: Set<UUID>, fetch: (Set<UUID>) throws -> [TagItem]) -> Self {
        guard !ids.isEmpty else { return .init(values: [:], coverage: .complete, issues: []) }
        do {
            return project(ids, rows: try fetch(ids))
        } catch {
            return .init(values: nil, coverage: .failed, issues: [.fetchFailed])
        }
    }

    /// 同批全目录已读取时复用实体资料，但仍只投影关联 ID，并保留原保护/歧义规则。
    static func project(_ ids: Set<UUID>, rows: [TagItem]) -> Self {
        let grouped = Dictionary(grouping: rows, by: \.id)
        var names: [UUID: String] = [:]
        var issues: [ContentQueryTagNameIssue] = []
        for id in ids.sorted(by: { $0.uuidString < $1.uuidString }) {
            let rows = grouped[id] ?? []
            if rows.isEmpty { issues.append(.missingID(id)) }
            else if rows.count != 1 { issues.append(.ambiguousID(id)) }
            else if let row = rows.first {
                if row.isPrivateDiary { issues.append(.privateNameUnavailable(id)) }
                else { names[id] = row.name }
            }
        }
        // 提供者尚无逐 ID 未知映射；缺资料不能被解释为没有标签。
        return .init(values: issues.isEmpty ? names : nil, coverage: issues.isEmpty ? .complete : .partial, issues: issues)
    }
}

extension TaskContentQueryReadIssue {
    init(_ issue: ContentQueryTagNameIssue) {
        switch issue {
        case .fetchFailed: self = .tagFetchFailed
        case .ambiguousID(let id): self = .ambiguousTagID(id)
        case .missingID(let id): self = .missingTagID(id)
        case .privateNameUnavailable(let id): self = .privateTagNameUnavailable(id)
        }
    }
}
