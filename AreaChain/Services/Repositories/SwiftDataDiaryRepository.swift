import Foundation
import SwiftData

/// 灵感手记 SwiftData 具体仓储实现
@MainActor
final class SwiftDataDiaryRepository: DiaryRepositoryProtocol {
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

    // MARK: - 查询与搜索 (Query & Search)

    func fetchDiaries(for dayKey: String?, includeDeleted: Bool) throws -> [DiaryEntry] {
        let descriptor = FetchDescriptor<DiaryEntry>()
        let items = try context.fetch(descriptor)
        return items
            .filter { item in
                if !includeDeleted && item.deletedAt != nil { return false }
                if let dayKey, item.dayKey != dayKey { return false }
                return true
            }
            .sorted { a, b in
                if a.isPinned != b.isPinned {
                    return a.isPinned && !b.isPinned
                }
                return a.createdAt > b.createdAt
            }
    }

    func fetchDiary(id: UUID) throws -> DiaryEntry? {
        let items = try context.fetch(FetchDescriptor<DiaryEntry>())
        return items.first { $0.id == id }
    }

    func searchDiaries(query: String, tagID: UUID?, includeDeleted: Bool) throws -> [DiaryEntry] {
        let entries = try fetchDiaries(for: nil, includeDeleted: includeDeleted)
        let parsed = BoardSearch.parseQuery(query)
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        let activeTags = tags.filter { $0.deletedAt == nil }
        let tagMap = Dictionary(uniqueKeysWithValues: activeTags.map { ($0.id, $0.name) })

        return entries.filter { entry in
            if let tagID, !TagIDList.contains(entry.tagIDs, tagID) {
                return false
            }
            var snapshot = entry.snapshot
            if includeDeleted { snapshot.deletedAt = nil }
            return BoardSearch.matchesDiary(snapshot, query: parsed, tagMap: tagMap)
        }
    }

    // MARK: - 创建与编辑 (Create & Edit)

    @discardableResult
    func addDiary(text: String, dayKey: String, tagIDs: Set<UUID>) throws -> DiaryEntry {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidArgument("手记内容不能为空")
        }
        return try ModelChanges.transaction(in: context) {
            let names = TagSyntax.names(in: trimmed) + DiaryMemoTags.autoTagNames(in: trimmed)
            let ids = try InputTagResolver.merging(names, into: TagIDList.encode(Array(tagIDs)), in: context)
            let entry = DiaryEntry(text: trimmed, dayKey: dayKey, tagIDs: ids)
            context.insert(entry)
            return entry
        }
    }

    func editDiary(id: UUID, text: String) throws {
        guard let entry = try fetchDiary(id: id) else {
            throw RepositoryError.notFound("DiaryEntry(id: \(id))")
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RepositoryError.invalidArgument("手记内容不能为空")
        }
        try ModelChanges.transaction(in: context) {
            entry.tagIDs = try InputTagResolver.merging(TagSyntax.names(in: text), into: entry.tagIDs, in: context)
            entry.text = text
        }
    }

    // MARK: - 置顶与标签操作 (Pin & Tags)

    func togglePin(id: UUID) throws {
        guard let entry = try fetchDiary(id: id) else {
            throw RepositoryError.notFound("DiaryEntry(id: \(id))")
        }
        entry.isPinned.toggle()
        try saveAndNotify()
    }

    func setPinned(id: UUID, isPinned: Bool) throws {
        guard let entry = try fetchDiary(id: id) else {
            throw RepositoryError.notFound("DiaryEntry(id: \(id))")
        }
        entry.isPinned = isPinned
        try saveAndNotify()
    }

    func toggleTag(id: UUID, tagID: UUID) throws {
        guard let entry = try fetchDiary(id: id) else {
            throw RepositoryError.notFound("DiaryEntry(id: \(id))")
        }
        entry.tagIDs = TagIDList.toggling(entry.tagIDs, tagID)
        try saveAndNotify()
    }

    func setTags(id: UUID, tagIDs: Set<UUID>) throws {
        guard let entry = try fetchDiary(id: id) else {
            throw RepositoryError.notFound("DiaryEntry(id: \(id))")
        }
        entry.tagIDs = TagIDList.encode(Array(tagIDs))
        try saveAndNotify()
    }

    // MARK: - 删除与恢复 (Delete & Restore)

    func deleteDiary(id: UUID, soft: Bool) throws {
        guard let entry = try fetchDiary(id: id) else {
            throw RepositoryError.notFound("DiaryEntry(id: \(id))")
        }
        if soft {
            let now = SoftDelete.stamp()
            entry.deletedAt = now
            SoftDelete.stampAttachments(ownerID: entry.id, at: now, attachments: try fetchOwnedAttachments(), ownerKind: .diary)
        } else {
            try purgeAttachments(ownerID: entry.id)
            context.delete(entry)
        }
        try saveAndNotify()
    }

    func restoreDiary(id: UUID) throws {
        guard let entry = try fetchDiary(id: id) else {
            throw RepositoryError.notFound("DiaryEntry(id: \(id))")
        }
        let stamp = entry.deletedAt
        entry.deletedAt = nil
        SoftDelete.restoreCascadedAttachments(
            ownerID: entry.id,
            parentDeletedAt: stamp,
            attachments: try fetchOwnedAttachments(),
            ownerKind: .diary
        )
        try saveAndNotify()
    }

    func purgeDiary(id: UUID) throws {
        try deleteDiary(id: id, soft: false)
    }

    // MARK: - 内部辅助 (Internal Helpers)

    private func fetchOwnedAttachments() throws -> [AttachmentItem] {
        try context.fetch(FetchDescriptor<AttachmentItem>())
    }

    private func purgeAttachments(ownerID: UUID) throws {
        let attachments = try fetchOwnedAttachments()
        for item in attachments where item.ownerID == ownerID && item.ownerKind == AttachmentOwner.diary.rawValue {
            context.delete(item)
        }
    }
}
