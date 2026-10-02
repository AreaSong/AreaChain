import Foundation
import SwiftData

enum DiaryPrivacy {
    enum ContentMode { case masked, editing, text }

    static func contentMode(isSensitive: Bool, isMasked: Bool, isEditing: Bool) -> ContentMode {
        if !canReveal(isSensitive: isSensitive, isMasked: isMasked) { return .masked }
        return isEditing ? .editing : .text
    }
    static func isSensitive(_ entry: DiarySnapshot, tags: [TagItem]) -> Bool {
        entry.isPrivate || hasPrivateMarker(entry.text) || tags.contains {
            ($0.isPrivateDiary || DiaryMemoTags.isPasswordName($0.name)) && TagIDList.contains(entry.tagIDs, $0.id)
        }
    }

    static func isSensitive(
        _ entry: DiarySnapshot, tagNames: [UUID: String], privateTagIDs: Set<UUID> = []
    ) -> Bool {
        entry.isPrivate || hasPrivateMarker(entry.text) || tagNames.contains {
            TagIDList.contains(entry.tagIDs, $0.key)
                && (privateTagIDs.contains($0.key) || DiaryMemoTags.isPasswordName($0.value))
        }
    }

    static func displayText(_ entry: DiarySnapshot, tags: [TagItem], locale: Locale) -> String {
        isSensitive(entry, tags: tags) ? L10n.string("diary.private.title", locale: locale) : entry.text
    }

    static func canReveal(isSensitive: Bool, isMasked: Bool) -> Bool {
        !isSensitive || !isMasked
    }

    static func requiresProtection(tagIDs: String, tags: [TagItem]) -> Bool {
        requiresProtection(text: "", tagIDs: Set(TagIDList.parse(tagIDs)), tags: tags)
    }

    static func requiresProtection(text: String, tagIDs: Set<UUID>, tags: [TagItem]) -> Bool {
        let names = Set((TagSyntax.names(in: text) + DiaryMemoTags.autoTagNames(in: text)).map(TagSyntax.normalizedName))
        return tags.contains { tag in
            tag.isPrivateDiary && (tagIDs.contains(tag.id) || names.contains(TagSyntax.normalizedName(tag.name)))
        }
    }

    /// 私密标记的唯一赋值。加密和解除保护决定何时为真，不各自写字段。
    static func assign(_ entry: DiaryEntry, isPrivate: Bool) {
        entry.isPrivate = isPrivate
    }

    static func toggle(_ entry: DiaryEntry) {
        assign(entry, isPrivate: !entry.isPrivate)
    }

    private static func hasPrivateMarker(_ text: String) -> Bool {
        text.contains("#密码") || text.localizedCaseInsensitiveContains("#password")
    }
}

/// 已物化列表上的拥有者存活集。重复 UUID 不能放进 live 集合，否则会比 `isSingleLive` 更宽松。
struct AttachmentOwnerIndex {
    let liveTodos: [UUID: TodoItem]
    let liveRoutines: [UUID: DailyRoutine]
    let liveDiaries: [UUID: DiaryEntry]
    /// 恰好一行的手记，含已软删除；回收站附件标题要用，不能只用 live 集。
    let uniqueDiaries: [UUID: DiaryEntry]

    var liveTodoIDs: Set<UUID> { Set(liveTodos.keys) }
    var liveRoutineIDs: Set<UUID> { Set(liveRoutines.keys) }
    var liveDiaryIDs: Set<UUID> { Set(liveDiaries.keys) }

    func ownerIsLive(_ owner: AttachmentOwnerKey) -> Bool {
        switch owner.kind {
        case .todo: liveTodos[owner.id] != nil
        case .routine: liveRoutines[owner.id] != nil
        case .diary: liveDiaries[owner.id] != nil
        }
    }

    static var empty: AttachmentOwnerIndex {
        AttachmentOwnerIndex(liveTodos: [:], liveRoutines: [:], liveDiaries: [:], uniqueDiaries: [:])
    }
}

enum AttachmentAccess {
    /// 所属类型是边界的一部分；不能因另一类型恰好使用相同 UUID 就放行图片。
    static func canBrowse(
        _ attachment: AttachmentItem, todos: [TodoItem], routines: [DailyRoutine],
        diaries: [DiaryEntry], tags: [TagItem]
    ) -> Bool {
        canBrowse(
            attachment,
            owners: ownerIndex(todos: todos, routines: routines, diaries: diaries),
            tags: tags
        )
    }

    static func canBrowse(
        _ attachment: AttachmentItem, owners: AttachmentOwnerIndex, tags: [TagItem]
    ) -> Bool {
        let owner = attachment.ownerKey
        let sensitive = owner.flatMap { key in
            key.kind == .diary ? owners.liveDiaries[key.id] : nil
        }.map { DiaryPrivacy.isSensitive($0.snapshot, tags: tags) } ?? false
        return canBrowse(AttachmentBrowseFacts(
            attachmentIsLive: attachment.deletedAt == nil, hasPrivacyVault: attachment.privacyVaultID != nil,
            owner: owner, ownerIsSingleLive: owner.map(owners.ownerIsLive) ?? false,
            diaryIsSensitive: sensitive
        ))
    }

    static func isSingleLive(deletedAts: [Date?]) -> Bool {
        deletedAts.count == 1 && deletedAts[0] == nil
    }

    static func ownerIndex(
        todos: [TodoItem], routines: [DailyRoutine], diaries: [DiaryEntry]
    ) -> AttachmentOwnerIndex {
        let uniqueDiaries = uniqueItems(diaries, id: \.id)
        return AttachmentOwnerIndex(
            liveTodos: liveUniqueItems(todos, id: \.id, deletedAt: \.deletedAt),
            liveRoutines: liveUniqueItems(routines, id: \.id, deletedAt: \.deletedAt),
            liveDiaries: uniqueDiaries.filter { $0.value.deletedAt == nil },
            uniqueDiaries: uniqueDiaries
        )
    }

    /// 只拉 keys 里出现过的 UUID，仍不设 fetchLimit，重复行会全部回来。
    static func ownerIndex(
        context: ModelContext, keys: [AttachmentOwnerKey]
    ) throws -> AttachmentOwnerIndex {
        var todoIDs = Set<UUID>()
        var routineIDs = Set<UUID>()
        var diaryIDs = Set<UUID>()
        for key in keys {
            switch key.kind {
            case .todo: todoIDs.insert(key.id)
            case .routine: routineIDs.insert(key.id)
            case .diary: diaryIDs.insert(key.id)
            }
        }
        return ownerIndex(
            todos: try fetchTodos(ids: todoIDs, in: context),
            routines: try fetchRoutines(ids: routineIDs, in: context),
            diaries: try fetchDiaries(ids: diaryIDs, in: context)
        )
    }

    static func ownerIsLive(
        _ owner: AttachmentOwnerKey, todos: [TodoItem], routines: [DailyRoutine], diaries: [DiaryEntry]
    ) -> Bool {
        ownerIndex(todos: todos, routines: routines, diaries: diaries).ownerIsLive(owner)
    }

    static func ownerIsLive(_ owner: AttachmentOwnerKey, context: ModelContext) throws -> Bool {
        try ownerIndex(context: context, keys: [owner]).ownerIsLive(owner)
    }

    /// 不设 fetchLimit：同一 UUID 出现多行时拥有者必须判为不可用，不能只看第一行。
    static func todosDescriptor(ids: Set<UUID>) -> FetchDescriptor<TodoItem>? {
        guard !ids.isEmpty else { return nil }
        let wanted = Array(ids)
        return FetchDescriptor(predicate: #Predicate { wanted.contains($0.id) })
    }

    static func routinesDescriptor(ids: Set<UUID>) -> FetchDescriptor<DailyRoutine>? {
        guard !ids.isEmpty else { return nil }
        let wanted = Array(ids)
        return FetchDescriptor(predicate: #Predicate { wanted.contains($0.id) })
    }

    static func diariesDescriptor(ids: Set<UUID>) -> FetchDescriptor<DiaryEntry>? {
        guard !ids.isEmpty else { return nil }
        let wanted = Array(ids)
        return FetchDescriptor(predicate: #Predicate { wanted.contains($0.id) })
    }

    static func fetchTodos(id: UUID, in context: ModelContext) throws -> [TodoItem] {
        try fetchTodos(ids: [id], in: context)
    }

    static func fetchTodos(ids: Set<UUID>, in context: ModelContext) throws -> [TodoItem] {
        guard let descriptor = todosDescriptor(ids: ids) else { return [] }
        return try context.fetch(descriptor)
    }

    static func fetchRoutines(id: UUID, in context: ModelContext) throws -> [DailyRoutine] {
        try fetchRoutines(ids: [id], in: context)
    }

    static func fetchRoutines(ids: Set<UUID>, in context: ModelContext) throws -> [DailyRoutine] {
        guard let descriptor = routinesDescriptor(ids: ids) else { return [] }
        return try context.fetch(descriptor)
    }

    static func fetchDiaries(id: UUID, in context: ModelContext) throws -> [DiaryEntry] {
        try fetchDiaries(ids: [id], in: context)
    }

    static func fetchDiaries(ids: Set<UUID>, in context: ModelContext) throws -> [DiaryEntry] {
        guard let descriptor = diariesDescriptor(ids: ids) else { return [] }
        return try context.fetch(descriptor)
    }

    private static func liveUniqueItems<T>(
        _ items: [T], id: KeyPath<T, UUID>, deletedAt: KeyPath<T, Date?>
    ) -> [UUID: T] {
        var grouped: [UUID: [T]] = [:]
        grouped.reserveCapacity(items.count)
        for item in items {
            grouped[item[keyPath: id], default: []].append(item)
        }
        var live: [UUID: T] = [:]
        for (key, rows) in grouped {
            guard isSingleLive(deletedAts: rows.map { $0[keyPath: deletedAt] }) else { continue }
            live[key] = rows[0]
        }
        return live
    }

    private static func uniqueItems<T>(_ items: [T], id: KeyPath<T, UUID>) -> [UUID: T] {
        var grouped: [UUID: [T]] = [:]
        grouped.reserveCapacity(items.count)
        for item in items {
            grouped[item[keyPath: id], default: []].append(item)
        }
        var unique: [UUID: T] = [:]
        for (key, rows) in grouped where rows.count == 1 {
            unique[key] = rows[0]
        }
        return unique
    }
}
