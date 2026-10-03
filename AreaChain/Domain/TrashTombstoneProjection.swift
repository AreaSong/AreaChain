import Foundation

/// 保护判定沿 DiaryQueryPrivacy，不把墓碑当作绕过隐私的新入口。
struct TrashTombstoneProjection: CustomStringConvertible, CustomDebugStringConvertible {
    let index: TrashTombstoneIndex
    let publicDiaries: Set<UUID>
    let publicImageOwners: Set<UUID>
    let incompleteDiaries: Set<UUID>
    let hiddenImageOwners: Set<AttachmentOwnerKey>
    let hiddenImageIDs: Set<UUID>

    init(_ index: TrashTombstoneIndex) {
        self.index = index
        var publicIDs: Set<UUID> = []
        var incomplete: Set<UUID> = []
        var imageOwners: Set<UUID> = []
        for diary in index.input.diaries ?? [] {
            let key = AttachmentOwnerKey(kind: .diary, id: diary.id)
            let privacy = DiaryQueryPrivacy(diary: diary, metadata: index.input.privacy)
            let complete = index.input.coverage.diaryPrivacy.state(for: key) == .completeIncludingDeleted
            let protection = index.input.diaryProtection?.protection(for: diary, metadata: index.input.privacy)
            if !complete || !privacy.diagnostics.isEmpty { incomplete.insert(diary.id) }
            if complete && privacy.canPublishBody && (protection == nil || protection == .unprotected),
               index.identityIssue(.init(type: .diary, id: diary.id)) == nil {
                publicIDs.insert(diary.id)
            }
            if complete, index.identityIssue(.init(type: .diary, id: diary.id)) == nil {
                if let facts = index.input.diaryProtection {
                    if facts.protection(for: diary, metadata: index.input.privacy) == .unprotected {
                        imageOwners.insert(diary.id)
                    }
                } else if publicIDs.contains(diary.id) { imageOwners.insert(diary.id) }
            }
        }
        publicDiaries = publicIDs
        publicImageOwners = imageOwners
        incompleteDiaries = incomplete
        let images = index.input.images ?? []
        let hidden = images.filter { image in
            guard let key = image.ownerKey else { return true }
            return image.protection != .unprotected || (key.kind == .diary && !imageOwners.contains(key.id))
        }
        let hiddenIDs = Set(hidden.map(\.id))
        hiddenImageIDs = hiddenIDs
        // 隐藏/公开碰撞不可通过另一拥有者发布同一图片身份；混合关联不输出局部数量。
        hiddenImageOwners = Set(images.filter { hiddenIDs.contains($0.id) }.compactMap(\.ownerKey))
    }

    func hides(_ value: TrashInputValue) -> Bool {
        guard case .image(let image) = value else { return false }
        guard let key = image.ownerKey else { return true }
        return hiddenImageIDs.contains(image.id) || hiddenImageOwners.contains(key)
    }

    func fields(_ value: TrashInputValue) -> TrashObjectFields {
        switch value {
        case .todo(var todo):
            // 子项只以独立身份存一份，避免原始快照绕过成员隔离或重复计数。
            todo.subtasks = []
            return .todo(todo)
        case .subtask(let child): return .subtask(child)
        case .routine(let routine): return .routine(routine)
        case .tag(let tag): return .tag(tag)
        case .image(let image): return .image(image)
        case .diary(let diary):
            let presentation: DiaryQueryPresentation = publicDiaries.contains(diary.id)
                ? .publicText(text: diary.text, bodyEvidence: [])
                : .hiddenTitle(L10n.string("diary.private.title", locale: index.input.locale))
            return .diary(.init(dayKey: diary.dayKey, createdAt: diary.createdAt, isPinned: diary.isPinned,
                tags: TagIDList.normalized(TagIDList.parse(diary.tagIDs)).map {
                    .init(id: $0, name: index.input.privacy.tagNames?[$0])
                }, presentation: presentation, hasValidTagIDs: DiaryQueryMetadata.hasValidTagIDs(diary.tagIDs)))
        }
    }

    func parentAttributes(for value: TrashInputValue, relation: TrashDeletionRelation) -> ImageOwnerProjection? {
        switch relation {
        case .root, .unresolved: return nil
        case .cascaded, .independent: break
        }
        guard let parent = value.parent, let row = index.rows[parent]?.first else { return nil }
        switch row {
        case .todo(let todo): return ImageOwnerInput.todo(todo).projection
        case .routine(let routine): return ImageOwnerInput.routine(routine).projection
        case .diary(let diary):
            guard publicImageOwners.contains(diary.id) else { return nil }
            return ImageOwnerInput.diary(diary).projection
        default: return nil
        }
    }

    static func restoration(for type: CommandObjectType, relation: TrashDeletionRelation) -> TrashRestoreConditions {
        var independent: TrashIndependentRestore = type == .subtask ? .notProvided : .existingEntry
        var cascade: CommandObjectReference?
        if case .cascaded(let parent) = relation { cascade = parent }
        if type == .image {
            switch relation {
            case .cascaded(let parent), .independent(let parent, .timestampsDiffer):
                independent = .requiresLiveOwner(parent)
            case .independent(_, .parentIsLive): independent = .existingEntry
            case .root, .unresolved: independent = .undetermined
            }
        }
        return .init(independent: independent, mayRestoreWithParent: cascade,
                     requiresProtectionCheck: type == .diary || type == .image)
    }

    var description: String { "TrashTombstoneProjection(redacted)" }
    var debugDescription: String { description }
}
