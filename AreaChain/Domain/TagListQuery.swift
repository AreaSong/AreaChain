import Foundation

/// 标签页列表的唯一取法（从 TagManagementPage 抽出，原页面转调）：全部／常用／最近／未使用视图沿 TagUsage，
/// 已删除视图按删除时间倒序，页内搜索按名字包含匹配。tag.search／tag.view／tag.deleted 用同一份。
enum TagListQuery {
    static func usage(todos: [TodoItem], routines: [DailyRoutine], diaries: [DiaryEntry]) -> [UUID: TagUsageRecord] {
        TagUsage.records(TagUsage.subjects(todos: todos, routines: routines, diaries: diaries))
    }

    static func deleted(_ tags: [TagItem]) -> [TagItem] {
        tags.filter { $0.deletedAt != nil }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    /// `tags` 须按 sortOrder 排序（同标签页的 @Query）。
    static func displayed(_ tags: [TagItem], filter: TagListFilter, showsDeleted: Bool, query: String,
                          usage: [UUID: TagUsageRecord]) -> [TagItem] {
        let base = showsDeleted ? deleted(tags) : TagUsage.filtered(tags, filter: filter, usage: usage)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return base }
        return base.filter { $0.name.localizedStandardContains(needle) }
    }
}
