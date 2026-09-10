import Foundation
import SwiftData

/// 分类目录（项目树与标签体系）SwiftData 具体仓储实现
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
        try context.save()
        BoardEvents.changed()
    }

    // MARK: - 项目操作 (Projects)

    func fetchProjects(includeDeleted: Bool) throws -> [ProjectItem] {
        let items = try context.fetch(FetchDescriptor<ProjectItem>())
        let sorted = items.sorted { $0.sortOrder < $1.sortOrder }
        if includeDeleted {
            return sorted
        }
        return sorted.filter { $0.deletedAt == nil }
    }

    func fetchProject(id: UUID) throws -> ProjectItem? {
        let items = try context.fetch(FetchDescriptor<ProjectItem>())
        return items.first { $0.id == id }
    }

    @discardableResult
    func createProject(name: String, parentID: UUID?, sortOrder: Int?) throws -> ProjectItem {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidArgument("项目名称不能为空")
        }
        let order: Int
        if let sortOrder {
            order = sortOrder
        } else {
            let live = try fetchProjects(includeDeleted: false)
            order = (live.map(\.sortOrder).max() ?? -1) + 1
        }
        let project = ProjectItem(name: trimmed, sortOrder: order, parentID: parentID)
        context.insert(project)
        try saveAndNotify()
        return project
    }

    func updateProject(id: UUID, name: String?, parentID: UUID??, sortOrder: Int?) throws {
        guard let project = try fetchProject(id: id) else {
            throw RepositoryError.notFound("ProjectItem(id: \(id))")
        }
        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw RepositoryError.invalidArgument("项目名称不能为空")
            }
            project.name = trimmed
        }
        if let parentID {
            project.parentID = parentID
        }
        if let sortOrder {
            project.sortOrder = sortOrder
        }
        try saveAndNotify()
    }

    func deleteProject(id: UUID, soft: Bool) throws {
        guard let project = try fetchProject(id: id) else {
            throw RepositoryError.notFound("ProjectItem(id: \(id))")
        }
        if soft {
            project.deletedAt = SoftDelete.stamp()
        } else {
            try unlinkProject(id: id)
            context.delete(project)
        }
        try saveAndNotify()
    }

    func restoreProject(id: UUID) throws {
        guard let project = try fetchProject(id: id) else {
            throw RepositoryError.notFound("ProjectItem(id: \(id))")
        }
        project.deletedAt = nil
        try saveAndNotify()
    }

    func purgeProject(id: UUID) throws {
        try deleteProject(id: id, soft: false)
    }

    func unlinkProject(id: UUID) throws {
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        let projects = try fetchProjects(includeDeleted: true)
        Catalog.unlinkProject(id, todos: todos, routines: routines, projects: projects)
        try saveAndNotify()
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
        let order: Int
        if let sortOrder {
            order = sortOrder
        } else {
            let live = try fetchTags(includeDeleted: false)
            order = (live.map(\.sortOrder).max() ?? -1) + 1
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
        let allTags = try fetchTags(includeDeleted: true)
        if let live = allTags.first(where: { $0.name == trimmed && $0.deletedAt == nil }) {
            return live
        }
        if let deleted = allTags.first(where: { $0.name == trimmed }) {
            deleted.deletedAt = nil
            try saveAndNotify()
            return deleted
        }
        let order = (allTags.map(\.sortOrder).max() ?? -1) + 1
        let created = TagItem(name: trimmed, sortOrder: order)
        context.insert(created)
        try saveAndNotify()
        return created
    }

    func resolveTaskTag(name: String) throws -> TagItem? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !DiaryMemoTags.isPresetName(trimmed) else {
            return nil
        }
        return try resolveOrCreateTag(name: trimmed)
    }

    func ensurePresetTags() throws {
        for preset in DiaryMemoTags.presets {
            _ = try resolveOrCreateTag(name: preset)
        }
    }

    func updateTag(id: UUID, name: String?, sortOrder: Int?) throws {
        guard let tag = try fetchTag(id: id) else {
            throw RepositoryError.notFound("TagItem(id: \(id))")
        }
        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw RepositoryError.invalidArgument("标签名称不能为空")
            }
            tag.name = trimmed
        }
        if let sortOrder {
            tag.sortOrder = sortOrder
        }
        try saveAndNotify()
    }

    func deleteTag(id: UUID, soft: Bool) throws {
        guard let tag = try fetchTag(id: id) else {
            throw RepositoryError.notFound("TagItem(id: \(id))")
        }
        if soft {
            tag.deletedAt = SoftDelete.stamp()
        } else {
            try unlinkTag(id: id)
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
        Catalog.unlinkTag(id, todos: todos, routines: routines, diaries: diaries)
        try saveAndNotify()
    }

    // MARK: - 聚合指标 (Metrics)

    func openCount(projectID: UUID?, tagID: UUID?, dayKey: String) throws -> Int {
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        let checks = try context.fetch(FetchDescriptor<RoutineCheck>())
        let projects = try fetchProjects(includeDeleted: false)
        let project = projectID != nil ? try fetchProject(id: projectID!) : nil
        let tag = tagID != nil ? try fetchTag(id: tagID!) : nil
        return Catalog.openCount(
            todos: todos,
            routines: routines,
            checks: checks,
            project: project,
            tag: tag,
            projects: projects,
            dayKey: dayKey
        )
    }
}
