import Foundation
import SwiftData

/// 平面标签目录的 SwiftData 仓储实现
@MainActor
final class SwiftDataCatalogRepository: CatalogRepositoryProtocol {
    private let context: ModelContext
    private let retainedContainer: ModelContainer?

    init(context: ModelContext, container: ModelContainer? = nil) {
        self.context = context
        self.retainedContainer = container
    }

    convenience init(container: ModelContainer) {
        self.init(context: container.mainContext, container: container)
    }

    private func saveAndNotify() throws {
        try ModelChanges.commit(context)
    }

    // MARK: - 标签操作 (Tags)

    func fetchTags(includeDeleted: Bool) throws -> [TagItem] {
        try fetchTags(matching: includeDeleted ? nil : #Predicate { $0.deletedAt == nil })
    }

    func fetchTag(id: UUID) throws -> TagItem? {
        // 含已软删除行：restore / purge / 按 id 变更都依赖这条路径找到回收站里的标签。
        var descriptor = FetchDescriptor<TagItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetchLiveTaskTags() throws -> [TagItem] {
        Catalog.liveTaskTags(try fetchTags(includeDeleted: false))
    }

    @discardableResult
    func createTag(name: String, sortOrder: Int?) throws -> TagItem {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidArgument("标签名称不能为空")
        }
        if DiaryMemoTags.isPresetName(trimmed) {
            throw RepositoryError.invalidArgument("手记预置标签不能当作普通标签创建")
        }
        let key = TagSyntax.normalizedName(trimmed)
        let live = try fetchTags(includeDeleted: false)
        if live.contains(where: { TagSyntax.normalizedName($0.name) == key }) {
            throw RepositoryError.invalidArgument("标签名称已存在")
        }
        let order = sortOrder ?? Catalog.nextSortOrder(live.map(\.sortOrder))
        let tag = TagItem(name: trimmed, sortOrder: order)
        context.insert(tag)
        try saveAndNotify()
        return tag
    }

    @discardableResult
    func resolveOrCreateTag(name: String) throws -> TagItem {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidArgument("标签名称不能为空")
        }
        let key = TagSyntax.normalizedName(trimmed)
        if let existing = try fetchTags(includeDeleted: false).first(where: { TagSyntax.normalizedName($0.name) == key }) {
            return existing
        }
        return try ModelChanges.transaction(in: context) {
            let ids = try InputTagResolver.resolve([trimmed], in: context)
            guard let id = ids.first, let tag = try fetchTag(id: id) else {
                throw RepositoryError.invalidArgument("无法创建标签")
            }
            return tag
        }
    }

    func resolveTaskTag(name: String) throws -> TagItem? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !DiaryMemoTags.isPresetName(trimmed) else {
            return nil
        }
        return try resolveOrCreateTag(name: trimmed)
    }

    func ensurePresetTags() throws {
        let liveNames = Set(try fetchTags(includeDeleted: false).map { TagSyntax.normalizedName($0.name) })
        let missing = DiaryMemoTags.presets.filter { !liveNames.contains(TagSyntax.normalizedName($0)) }
        // 页面反复出现时只读；确有缺失或软删除时，合并为一次保存和变更通知。
        guard !missing.isEmpty else { return }
        try ModelChanges.transaction(in: context) {
            _ = try InputTagResolver.resolve(missing, in: context)
        }
    }

    func updateTag(id: UUID, name: String?, sortOrder: Int?, colorToken: String?) throws {
        guard let tag = try fetchTag(id: id) else {
            throw RepositoryError.notFound("TagItem(id: \(id))")
        }
        if let name {
            if tag.isDiaryPreset {
                throw RepositoryError.invalidArgument("手记预置标签不能改名")
            }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw RepositoryError.invalidArgument("标签名称不能为空")
            }
            let key = TagSyntax.normalizedName(trimmed)
            let clash = try fetchTags(includeDeleted: false).contains {
                $0.id != id && TagSyntax.normalizedName($0.name) == key
            }
            if clash { throw RepositoryError.invalidArgument("标签名称已存在") }
            tag.name = trimmed
        }
        if let sortOrder {
            tag.sortOrder = sortOrder
        }
        if let colorToken {
            if tag.isDiaryPreset {
                throw RepositoryError.invalidArgument("手记预置标签不能改色")
            }
            tag.colorToken = TagColorToken.resolved(colorToken).rawValue
        }
        try saveAndNotify()
    }

    func deleteTag(id: UUID, soft: Bool) throws {
        guard let tag = try fetchTag(id: id) else {
            throw RepositoryError.notFound("TagItem(id: \(id))")
        }
        if tag.isDiaryPreset {
            throw RepositoryError.invalidArgument("手记预置标签不能删除")
        }
        if soft {
            tag.deletedAt = SoftDelete.stamp()
        } else {
            let linked = try recordsLinked(to: id)
            Catalog.unlinkTag(id, todos: linked.todos, routines: linked.routines, diaries: linked.diaries, subtasks: linked.subtasks)
            context.delete(tag)
        }
        try saveAndNotify()
    }

    func restoreTag(id: UUID) throws {
        guard let tag = try fetchTag(id: id) else {
            throw RepositoryError.notFound("TagItem(id: \(id))")
        }
        tag.deletedAt = nil
        try saveAndNotify()
    }

    func purgeTag(id: UUID) throws {
        try deleteTag(id: id, soft: false)
    }

    func unlinkTag(id: UUID) throws {
        let linked = try recordsLinked(to: id)
        Catalog.unlinkTag(id, todos: linked.todos, routines: linked.routines, diaries: linked.diaries, subtasks: linked.subtasks)
        try saveAndNotify()
    }

    func reorderTags(orderedIDs: [UUID]) throws {
        let tags = try fetchTags(includeDeleted: false)
        Catalog.writeSortOrder(tags, orderedIDs: orderedIDs, id: \.id) { $0.sortOrder = $1 }
        try saveAndNotify()
    }

    func mergeTags(sourceIDs: [UUID], into targetID: UUID) throws {
        try ModelChanges.transaction(in: context) {
            let tags = try fetchTags(includeDeleted: true)
            // merge 会对传入集合做 TagIDList.normalized，不能先按来源 ID 缩小四表，否则会跳过无关行的编码归一化。
            let todos = try context.fetch(FetchDescriptor<TodoItem>())
            let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
            let diaries = try context.fetch(FetchDescriptor<DiaryEntry>())
            let subtasks = try context.fetch(FetchDescriptor<SubtaskItem>())
            try Catalog.mergeTags(
                sources: sourceIDs, into: targetID, tags: tags,
                todos: todos, routines: routines, diaries: diaries, subtasks: subtasks
            )
        }
    }

    func batchSetColor(ids: Set<UUID>, colorToken: String) throws {
        let token = TagColorToken.resolved(colorToken).rawValue
        let wanted = Array(ids)
        let tags = wanted.isEmpty
            ? []
            : try fetchTags(
                matching: #Predicate { wanted.contains($0.id) && $0.deletedAt == nil },
                sortBy: []
            )
        guard tags.contains(where: { !$0.isDiaryPreset }) else {
            throw RepositoryError.invalidArgument("手记预置标签不能改色")
        }
        for tag in tags where !tag.isDiaryPreset {
            tag.colorToken = token
        }
        try saveAndNotify()
    }

    // MARK: - 聚合指标 (Metrics)

    func openCount(tagID: UUID?, dayKey: String) throws -> Int {
        let tag = tagID != nil ? try fetchTag(id: tagID!) : nil
        guard let tag, tag.deletedAt == nil else {
            return Catalog.openCount(todos: [], routines: [], checks: [], tag: tag, dayKey: dayKey)
        }
        // 子任务可独立挂签：必须带上全部未删除待办，不能只取自己挂了该标签的父项。
        let todos = try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.deletedAt == nil }))
        let routines = try context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.deletedAt == nil }))
        let checks = try context.fetch(FetchDescriptor<RoutineCheck>())
        return Catalog.openCount(
            todos: todos, routines: routines, checks: checks, tag: tag, dayKey: dayKey
        )
    }

    // MARK: - 内部辅助 (Internal Helpers)

    private func fetchTags(
        matching predicate: Predicate<TagItem>?,
        sortBy: [SortDescriptor<TagItem>] = [SortDescriptor(\.sortOrder)]
    ) throws -> [TagItem] {
        try context.fetch(FetchDescriptor(predicate: predicate, sortBy: sortBy))
    }

    private func recordsLinked(to tagID: UUID) throws -> (
        todos: [TodoItem], routines: [DailyRoutine], diaries: [DiaryEntry], subtasks: [SubtaskItem]
    ) {
        let needle = tagID.uuidString
        return (
            try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.tagIDs.contains(needle) }))
                .filter { TagIDList.contains($0.tagIDs, tagID) },
            try context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.tagIDs.contains(needle) }))
                .filter { TagIDList.contains($0.tagIDs, tagID) },
            try context.fetch(FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.tagIDs.contains(needle) }))
                .filter { TagIDList.contains($0.tagIDs, tagID) },
            try context.fetch(FetchDescriptor<SubtaskItem>(predicate: #Predicate { $0.tagIDs.contains(needle) }))
                .filter { TagIDList.contains($0.tagIDs, tagID) }
        )
    }
}
