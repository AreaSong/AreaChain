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
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        let activeTags = tags.filter { $0.deletedAt == nil }

        return entries.filter { entry in
            if let tagID, !TagIDList.contains(entry.tagIDs, tagID) {
                return false
            }
            guard !needle.isEmpty else { return true }
            let matchesText = entry.text.localizedCaseInsensitiveContains(needle)
            let matchesTag = activeTags.contains { tag in
                TagIDList.contains(entry.tagIDs, tag.id) && tag.name.localizedCaseInsensitiveContains(needle)
            }
            return matchesText || matchesTag
        }
    }

    // MARK: - 创建与编辑 (Create & Edit)

    @discardableResult
    func addDiary(text: String, dayKey: String, tagIDs: Set<UUID>) throws -> DiaryEntry {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidArgument("手记内容不能为空")
        }
        var ids = tagIDs
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        var availableTags = tags
        let parsed = NaturalLanguageParser.parse(trimmed)
        if let tagName = parsed.tagName {
            ids.insert(ensureTag(named: tagName, among: &availableTags).id)
        }
        for name in DiaryMemoTags.autoTagNames(in: trimmed) {
            ids.insert(ensureTag(named: name, among: &availableTags).id)
        }
        let entry = DiaryEntry(
            text: trimmed,
            dayKey: dayKey,
            tagIDs: TagIDList.encode(Array(ids))
        )
        context.insert(entry)
        try saveAndNotify()
        return entry
    }

    func editDiary(id: UUID, text: String) throws {
        guard let entry = try fetchDiary(id: id) else {
            throw RepositoryError.notFound("DiaryEntry(id: \(id))")
        }
        entry.text = text
        try saveAndNotify()
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

    private func ensureTag(named name: String, among tags: inout [TagItem]) -> TagItem {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = tags.first(where: { $0.name == trimmed }) {
            if existing.deletedAt != nil { existing.deletedAt = nil }
            return existing
        }
        let created = TagItem(name: trimmed, sortOrder: tags.count)
        context.insert(created)
        tags.append(created)
        return created
    }

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
