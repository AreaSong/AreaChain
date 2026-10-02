import Foundation

/// 目录过滤只依赖这些值；名称、保护和关联正文都不是排序输入。
struct TagListFacts {
    let id: UUID
    let sortOrder: Int
    let isDeleted: Bool
}

extension TagUsage {
    /// 调用方须先确认 usage 的完整性；旧目录传入完整统计，新查询在边界处理未知。
    static func filteredValues<Value>(
        _ tags: [Value], filter: TagListFilter, usage: [UUID: TagUsageRecord], facts: (Value) -> TagListFacts
    ) -> [Value] {
        let live = tags.map { (value: $0, facts: facts($0)) }.filter { !$0.facts.isDeleted }
            .sorted { $0.facts.sortOrder < $1.facts.sortOrder }
        switch filter {
        case .all: return live.map(\.value)
        case .frequent:
            return live.sorted { lhs, rhs in
                let left = usage[lhs.facts.id]?.activeCount ?? 0
                let right = usage[rhs.facts.id]?.activeCount ?? 0
                if left != right { return left > right }
                return lhs.facts.sortOrder < rhs.facts.sortOrder
            }.map(\.value)
        case .recent:
            return live.filter { usage[$0.facts.id]?.latestCreatedAt != nil }.sorted { lhs, rhs in
                let left = usage[lhs.facts.id]?.latestCreatedAt ?? .distantPast
                let right = usage[rhs.facts.id]?.latestCreatedAt ?? .distantPast
                if left != right { return left > right }
                return lhs.facts.sortOrder < rhs.facts.sortOrder
            }.map(\.value)
        case .unused: return live.filter { (usage[$0.facts.id]?.activeCount ?? 0) == 0 }.map(\.value)
        }
    }
}
