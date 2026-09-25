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
        let items = try context.fetch(FetchDescriptor<TagItem>())
        let sorted = items.sorted { $0.sortOrder < $1.sortOrder }
        if includeDeleted {
            return sorted
        }
        return sorted.filter { $0.deletedAt == nil }
    }

    func fetchTag(id: UUID) throws -> TagItem? {
        let items = try context.fetch(FetchDescriptor<TagItem>())
        return items.first { $0.id == id }
    }

    func fetchLiveTaskTags() throws -> [TagItem] {
        let live = try fetchTags(includeDeleted: false)
        return Catalog.liveTaskTags(live)
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
        if try fetchTags(includeDeleted: false).contains(where: { TagSyntax.normalizedName($0.name) == key }) {
            throw RepositoryError.invalidArgument("标签名称已存在")
        }
        let order: Int
        if let sortOrder {
            order = sortOrder
        } else {
            let live = try fetchTags(includeDeleted: false)
            order = Catalog.nextSortOrder(live.map(\.sortOrder))
        }
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
            let todos = try context.fetch(FetchDescriptor<TodoItem>())
            let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
            let diaries = try context.fetch(FetchDescriptor<DiaryEntry>())
            let subtasks = try context.fetch(FetchDescriptor<SubtaskItem>())
            Catalog.unlinkTag(id, todos: todos, routines: routines, diaries: diaries, subtasks: subtasks)
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
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        let diaries = try context.fetch(FetchDescriptor<DiaryEntry>())
        let subtasks = try context.fetch(FetchDescriptor<SubtaskItem>())
        Catalog.unlinkTag(id, todos: todos, routines: routines, diaries: diaries, subtasks: subtasks)
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
        let tags = try fetchTags(includeDeleted: false).filter { ids.contains($0.id) }
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
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        let checks = try context.fetch(FetchDescriptor<RoutineCheck>())
        let tag = tagID != nil ? try fetchTag(id: tagID!) : nil
        return Catalog.openCount(
            todos: todos, routines: routines, checks: checks, tag: tag, dayKey: dayKey
        )
    }
}
