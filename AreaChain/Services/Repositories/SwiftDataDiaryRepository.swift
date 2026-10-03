import Foundation
import SwiftData

/// 灵感手记 SwiftData 具体仓储实现
@MainActor
final class SwiftDataDiaryRepository: DiaryRepositoryProtocol {
    private let context: ModelContext
    private let retainedContainer: ModelContainer?
    private let vault: PrivacyVault
    private let attachmentStore: AttachmentStore
    private let attachmentRoot: URL?

    init(context: ModelContext, container: ModelContainer? = nil, vault: PrivacyVault? = nil,
         attachmentStore: AttachmentStore = .shared, attachmentRoot: URL? = nil) {
        self.context = context
        self.retainedContainer = container
        self.vault = vault ?? .shared
        self.attachmentStore = attachmentStore
        self.attachmentRoot = attachmentRoot
    }

    convenience init(container: ModelContainer) {
        self.init(context: container.mainContext, container: container)
    }

    private func saveAndNotify() throws {
        try ModelChanges.commit(context)
    }

    // MARK: - 查询与搜索 (Query & Search)

    func fetchDiaries(for dayKey: String?, includeDeleted: Bool) throws -> [DiaryEntry] {
        try fetchDiaries(matching: diaryPredicate(dayKey: dayKey, includeDeleted: includeDeleted))
    }

    func fetchDiary(id: UUID) throws -> DiaryEntry? {
        // 含已软删除行：restore / purge / 按 id 变更都依赖这条路径找到回收站里的手记。
        var descriptor = FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func searchDiaries(query: String, tagID: UUID?, includeDeleted: Bool) throws -> [DiaryEntry] {
        let parsed = BoardSearch.parseQuery(query)
        let entries: [DiaryEntry]
        if let tagID {
            let needle = tagID.uuidString
            entries = try fetchDiaries(
                matching: diaryPredicate(dayKey: nil, includeDeleted: includeDeleted, tagNeedle: needle)
            ).filter { TagIDList.contains($0.tagIDs, tagID) }
        } else {
            entries = try fetchDiaries(matching: diaryPredicate(dayKey: nil, includeDeleted: includeDeleted))
        }
        let tagMap = Dictionary(uniqueKeysWithValues: try liveTags().map { ($0.id, $0.name) })

        return entries.filter { entry in
            var snapshot = DiaryContent.snapshot(entry, vault: vault)
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
            let automatic = DiaryMemoTags.autoTagNames(in: trimmed).filter { !DiaryPresetRetention.isDismissed($0) }
            let names = TagSyntax.names(in: trimmed) + automatic
            let ids = try InputTagResolver.merging(names, into: TagIDList.encode(Array(tagIDs)), in: context)
            let entry = DiaryEntry(text: "", dayKey: dayKey, tagIDs: ids)
            try DiaryContent.write(
                trimmed, to: entry,
                protect: DiaryContent.requiresProtection(tagIDs: ids, tags: try protectionTags()),
                vault: vault
            )
            context.insert(entry)
            return entry
        }
    }

    func moveDiary(id: UUID, to dayKey: String) throws {
        guard let entry = try fetchDiary(id: id) else {
            throw RepositoryError.notFound("DiaryEntry(id: \(id))")
        }
        guard DayKey.date(from: dayKey) != nil else {
            throw RepositoryError.invalidArgument("手记日期无效")
        }
        entry.dayKey = dayKey
        try saveAndNotify()
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
            try writeContent(text, to: entry)
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
        guard entry.deletedAt == nil, try liveTagExists(tagID) else {
            throw PrivacyError.staleOperation
        }
        try ModelChanges.transaction(in: context) {
            let text = try DiaryContent.read(entry, vault: vault)
            entry.tagIDs = TagIDList.toggling(entry.tagIDs, tagID)
            try writeContent(text, to: entry)
        }
    }

    func setTags(id: UUID, tagIDs: Set<UUID>) throws {
        guard let entry = try fetchDiary(id: id) else {
            throw RepositoryError.notFound("DiaryEntry(id: \(id))")
        }
        guard entry.deletedAt == nil else { throw PrivacyError.staleOperation }
        try ModelChanges.transaction(in: context) {
            let text = try DiaryContent.read(entry, vault: vault)
            entry.tagIDs = TagIDList.encode(Array(tagIDs))
            try writeContent(text, to: entry)
        }
    }

    // MARK: - 删除与恢复 (Delete & Restore)

    func deleteDiary(id: UUID, soft: Bool) throws {
        guard let entry = try fetchDiary(id: id) else {
            throw RepositoryError.notFound("DiaryEntry(id: \(id))")
        }
        let attachments = try ownedAttachments(entry.id)
        if soft {
            let now = SoftDelete.stamp()
            entry.deletedAt = now
            SoftDelete.stampAttachments(ownerID: entry.id, at: now, attachments: attachments, ownerKind: .diary)
        } else {
            let stamp = entry.deletedAt ?? SoftDelete.stamp()
            SoftDelete.stampAttachments(
                ownerID: entry.id, at: stamp, attachments: attachments, ownerKind: .diary
            )
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
            attachments: try ownedAttachments(entry.id),
            ownerKind: .diary
        )
        try saveAndNotify()
    }

    func purgeDiary(id: UUID) throws {
        guard let entry = try fetchDiary(id: id) else {
            throw RepositoryError.notFound("DiaryEntry(id: \(id))")
        }
        let ids = Set(try ownedAttachments(entry.id).map(\.id))
        try deleteDiary(id: id, soft: false)
        if !ids.isEmpty { try AttachmentCleanup.purge(ids: ids, context: context) }
    }

    // MARK: - 内部辅助 (Internal Helpers)

    private func writeContent(_ text: String, to entry: DiaryEntry) throws {
        let tags = try protectionTags()
        let protect = entry.hasProtectedContent || DiaryContent.requiresProtection(tagIDs: entry.tagIDs, tags: tags)
        if protect && !entry.hasProtectedContent {
            try PrivacyStoreMaintenance.mark(context)
            let batch = PrivacyAttachmentBatch(store: attachmentStore, root: attachmentRoot)
            let items = try ownedAttachments(entry.id)
            try batch.prepare(items, vault: vault)
            ModelChanges.afterTransaction(in: context, commit: { [context, attachmentStore, attachmentRoot] in
                try PrivacyAttachmentBatch.cleanup(items, context: context, store: attachmentStore, root: attachmentRoot)
                PrivacyStoreMaintenance.request(context)
            }, rollback: { batch.rollback() })
            batch.apply()
        }
        try DiaryContent.write(text, to: entry, protect: protect, vault: vault)
    }

    private func fetchDiaries(matching predicate: Predicate<DiaryEntry>?) throws -> [DiaryEntry] {
        try Self.fetchDiaries(in: context, matching: predicate)
    }

    /// 完整只读枚举不需要仓储实例，避免元数据适配触发默认 vault / 附件依赖初始化。
    static func fetchAllDiaries(in context: ModelContext) throws -> [DiaryEntry] {
        try fetchDiaries(in: context, matching: nil)
    }

    private static func fetchDiaries(in context: ModelContext, matching predicate: Predicate<DiaryEntry>?) throws -> [DiaryEntry] {
        // SwiftData 的 SortDescriptor 没有 @Model + Bool 的可用重载；置顶仍按原比较器在过滤后集合上完成。
        try context.fetch(
            FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        ).sorted { a, b in
            if a.isPinned != b.isPinned {
                return a.isPinned && !b.isPinned
            }
            return a.createdAt > b.createdAt
        }
    }

    private func diaryPredicate(dayKey: String?, includeDeleted: Bool, tagNeedle: String? = nil) -> Predicate<DiaryEntry>? {
        switch (dayKey, includeDeleted, tagNeedle) {
        case (nil, true, nil):
            return nil
        case (nil, false, nil):
            return #Predicate { $0.deletedAt == nil }
        case (let key?, true, nil):
            return #Predicate { $0.dayKey == key }
        case (let key?, false, nil):
            return #Predicate { $0.dayKey == key && $0.deletedAt == nil }
        case (nil, true, let needle?):
            return #Predicate { $0.tagIDs.contains(needle) }
        case (nil, false, let needle?):
            return #Predicate { $0.deletedAt == nil && $0.tagIDs.contains(needle) }
        case (let key?, true, let needle?):
            return #Predicate { $0.dayKey == key && $0.tagIDs.contains(needle) }
        case (let key?, false, let needle?):
            return #Predicate { $0.dayKey == key && $0.deletedAt == nil && $0.tagIDs.contains(needle) }
        }
    }

    private func liveTags() throws -> [TagItem] {
        try context.fetch(FetchDescriptor<TagItem>(predicate: #Predicate { $0.deletedAt == nil }))
    }

    /// `requiresProtection` 只看 `isPrivateDiary`；含已软删除行，避免漏判仍挂在手记上的私密标签。
    private func protectionTags() throws -> [TagItem] {
        try context.fetch(FetchDescriptor<TagItem>(predicate: #Predicate { $0.isPrivateDiary == true }))
    }

    private func liveTagExists(_ tagID: UUID) throws -> Bool {
        var descriptor = FetchDescriptor<TagItem>(predicate: #Predicate { $0.id == tagID && $0.deletedAt == nil })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first != nil
    }

    private func ownedAttachments(_ ownerID: UUID) throws -> [AttachmentItem] {
        let kind = AttachmentOwner.diary.rawValue
        return try context.fetch(
            FetchDescriptor<AttachmentItem>(predicate: #Predicate { $0.ownerID == ownerID && $0.ownerKind == kind })
        )
    }
}
