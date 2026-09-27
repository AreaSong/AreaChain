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

enum AttachmentAccess {
    /// 所属类型是边界的一部分；不能因另一类型恰好使用相同 UUID 就放行图片。
    static func canBrowse(
        _ attachment: AttachmentItem, todos: [TodoItem], routines: [DailyRoutine],
        diaries: [DiaryEntry], tags: [TagItem]
    ) -> Bool {
        guard attachment.deletedAt == nil, attachment.privacyVaultID == nil, let owner = attachment.ownerKey,
              ownerIsLive(owner, todos: todos, routines: routines, diaries: diaries) else { return false }
        if owner.kind == .diary, let entry = diaries.first(where: { $0.id == owner.id }) {
            return !DiaryPrivacy.isSensitive(entry.snapshot, tags: tags)
        }
        return true
    }

    static func isSingleLive(deletedAts: [Date?]) -> Bool {
        deletedAts.count == 1 && deletedAts[0] == nil
    }

    static func ownerIsLive(
        _ owner: AttachmentOwnerKey, todos: [TodoItem], routines: [DailyRoutine], diaries: [DiaryEntry]
    ) -> Bool {
        switch owner.kind {
        case .todo:
            return isSingleLive(deletedAts: todos.filter { $0.id == owner.id }.map(\.deletedAt))
        case .routine:
            return isSingleLive(deletedAts: routines.filter { $0.id == owner.id }.map(\.deletedAt))
        case .diary:
            return isSingleLive(deletedAts: diaries.filter { $0.id == owner.id }.map(\.deletedAt))
        }
    }

    static func ownerIsLive(_ owner: AttachmentOwnerKey, context: ModelContext) throws -> Bool {
        switch owner.kind {
        case .todo:
            return isSingleLive(deletedAts: try fetchTodos(id: owner.id, in: context).map(\.deletedAt))
        case .routine:
            return isSingleLive(deletedAts: try fetchRoutines(id: owner.id, in: context).map(\.deletedAt))
        case .diary:
            return isSingleLive(deletedAts: try fetchDiaries(id: owner.id, in: context).map(\.deletedAt))
        }
    }

    /// 不设 fetchLimit：同一 UUID 出现多行时拥有者必须判为不可用，不能只看第一行。
    static func fetchTodos(id: UUID, in context: ModelContext) throws -> [TodoItem] {
        try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id }))
    }

    static func fetchRoutines(id: UUID, in context: ModelContext) throws -> [DailyRoutine] {
        try context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.id == id }))
    }

    static func fetchDiaries(id: UUID, in context: ModelContext) throws -> [DiaryEntry] {
        try context.fetch(FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.id == id }))
    }
}
