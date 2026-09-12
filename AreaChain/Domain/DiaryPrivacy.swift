import Foundation

enum DiaryPrivacy {
    enum ContentMode { case masked, editing, text }

    static func contentMode(isSensitive: Bool, isMasked: Bool, isEditing: Bool) -> ContentMode {
        if !canReveal(isSensitive: isSensitive, isMasked: isMasked) { return .masked }
        return isEditing ? .editing : .text
    }
    static func isSensitive(_ entry: DiarySnapshot, tags: [TagItem]) -> Bool {
        hasPrivateMarker(entry.text) || tags.contains {
            DiaryMemoTags.isPasswordName($0.name) && TagIDList.contains(entry.tagIDs, $0.id)
        }
    }

    static func isSensitive(_ entry: DiarySnapshot, tagNames: [UUID: String]) -> Bool {
        hasPrivateMarker(entry.text) || tagNames.contains {
            DiaryMemoTags.isPasswordName($0.value) && TagIDList.contains(entry.tagIDs, $0.key)
        }
    }

    static func displayText(_ entry: DiarySnapshot, tags: [TagItem], locale: Locale) -> String {
        isSensitive(entry, tags: tags) ? L10n.string("diary.private.title", locale: locale) : entry.text
    }

    static func canReveal(isSensitive: Bool, isMasked: Bool) -> Bool {
        !isSensitive || !isMasked
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
        guard attachment.deletedAt == nil, let owner = attachment.ownerKey,
              ownerIsLive(owner, todos: todos, routines: routines, diaries: diaries) else { return false }
        if owner.kind == .diary, let entry = diaries.first(where: { $0.id == owner.id }) {
            return !DiaryPrivacy.isSensitive(entry.snapshot, tags: tags)
        }
        return true
    }

    static func ownerIsLive(
        _ owner: AttachmentOwnerKey, todos: [TodoItem], routines: [DailyRoutine], diaries: [DiaryEntry]
    ) -> Bool {
        switch owner.kind {
        case .todo:
            let matches = todos.filter { $0.id == owner.id }
            return matches.count == 1 && matches[0].deletedAt == nil
        case .routine:
            let matches = routines.filter { $0.id == owner.id }
            return matches.count == 1 && matches[0].deletedAt == nil
        case .diary:
            let matches = diaries.filter { $0.id == owner.id }
            return matches.count == 1 && matches[0].deletedAt == nil
        }
    }
}
