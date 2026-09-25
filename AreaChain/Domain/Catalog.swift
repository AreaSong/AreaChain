import Foundation

enum TagListFilter: String, CaseIterable, Equatable, Sendable {
    case all
    case frequent
    case recent
    case unused
}

struct TagUsageRecord: Equatable, Sendable {
    var tagID: UUID
    var activeCount: Int
    var latestCreatedAt: Date?
}

struct TagUsageSubject: Equatable, Sendable {
    var tagIDs: String
    var createdAt: Date
    var isDeleted: Bool
}

enum TagUsage {
    /// 活跃使用数只计未删除的事项、重复事项、子任务和手记，不计入打卡记录。
    static func records(_ subjects: [TagUsageSubject]) -> [UUID: TagUsageRecord] {
        var map: [UUID: TagUsageRecord] = [:]
        for subject in subjects where !subject.isDeleted {
            for id in TagIDList.parse(subject.tagIDs) {
                var record = map[id] ?? TagUsageRecord(tagID: id, activeCount: 0, latestCreatedAt: nil)
                record.activeCount += 1
                if record.latestCreatedAt == nil || subject.createdAt > record.latestCreatedAt! {
                    record.latestCreatedAt = subject.createdAt
                }
                map[id] = record
            }
        }
        return map
    }

    static func subjects(
        todos: [TodoItem], routines: [DailyRoutine], diaries: [DiaryEntry]
    ) -> [TagUsageSubject] {
        let todoSubjects = todos.map {
            TagUsageSubject(tagIDs: $0.tagIDs, createdAt: $0.createdAt, isDeleted: $0.deletedAt != nil)
        }
        let routineSubjects = routines.map {
            TagUsageSubject(tagIDs: $0.tagIDs, createdAt: $0.createdAt, isDeleted: $0.deletedAt != nil)
        }
        let subtaskSubjects = todos.flatMap(\.subtasks).map {
            TagUsageSubject(tagIDs: $0.tagIDs, createdAt: $0.createdAt, isDeleted: $0.deletedAt != nil)
        }
        let diarySubjects = diaries.map {
            TagUsageSubject(tagIDs: $0.tagIDs, createdAt: $0.createdAt, isDeleted: $0.deletedAt != nil)
        }
        return todoSubjects + routineSubjects + subtaskSubjects + diarySubjects
    }

    static func filtered(_ tags: [TagItem], filter: TagListFilter, usage: [UUID: TagUsageRecord]) -> [TagItem] {
        let live = Catalog.liveTags(tags)
        switch filter {
        case .all:
            return live
        case .frequent:
            return live.sorted { lhs, rhs in
                let left = usage[lhs.id]?.activeCount ?? 0
                let right = usage[rhs.id]?.activeCount ?? 0
                if left != right { return left > right }
                return lhs.sortOrder < rhs.sortOrder
            }
        case .recent:
            return live
                .filter { usage[$0.id]?.latestCreatedAt != nil }
                .sorted { lhs, rhs in
                    let left = usage[lhs.id]?.latestCreatedAt ?? .distantPast
                    let right = usage[rhs.id]?.latestCreatedAt ?? .distantPast
                    if left != right { return left > right }
                    return lhs.sortOrder < rhs.sortOrder
                }
        case .unused:
            return live.filter { (usage[$0.id]?.activeCount ?? 0) == 0 }
        }
    }
}

enum TagMergeError: Error, Equatable {
    case presetProtected
    case missingTarget
    case emptySources
}

enum Catalog {
    static func liveTags(_ items: [TagItem]) -> [TagItem] {
        items.filter { $0.deletedAt == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 待办侧使用的标签，不含手记三分类。
    static func liveTaskTags(_ items: [TagItem]) -> [TagItem] {
        liveTags(items).filter { !DiaryMemoTags.isPresetName($0.name) }
    }

    /// 抽屉选择器：预设分类仅在该项已打上时出现，方便去掉。
    static func taskPickerTags(_ items: [TagItem], attachedIDs: String) -> [TagItem] {
        liveTags(items).filter { tag in
            if DiaryMemoTags.isPresetName(tag.name) {
                return TagIDList.contains(attachedIDs, tag.id)
            }
            return true
        }
    }

    static func liveAttachments(for ownerID: UUID, in items: [AttachmentItem], ownerKind: AttachmentOwner? = nil) -> [AttachmentItem] {
        items
            .filter {
                $0.deletedAt == nil && $0.ownerID == ownerID
                    && (ownerKind == nil || $0.ownerKind == ownerKind?.rawValue)
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    static func nextSortOrder(_ orders: [Int]) -> Int {
        (orders.max() ?? -1) + 1
    }

    static func matches(tagIDs: String, tag: TagItem?) -> Bool {
        guard let tag, tag.deletedAt == nil else { return false }
        return TagIDList.contains(tagIDs, tag.id)
    }

    static func matchingTodos(_ items: [TodoItem], tag: TagItem?) -> [TodoItem] {
        items.filter { $0.deletedAt == nil && matches(tagIDs: $0.tagIDs, tag: tag) }
    }

    static func matchingRoutines(_ items: [DailyRoutine], tag: TagItem?) -> [DailyRoutine] {
        items.filter { $0.deletedAt == nil && matches(tagIDs: $0.tagIDs, tag: tag) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    static func matchingSubtasks(_ todos: [TodoItem], tag: TagItem?) -> [SubtaskItem] {
        guard let tag, tag.deletedAt == nil else { return [] }
        return todos.filter { $0.deletedAt == nil }.flatMap(\.subtasks)
            .filter { $0.deletedAt == nil && TagIDList.contains($0.tagIDs, tag.id) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    static func openCount(
        todos: [TodoItem],
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        tag: TagItem?,
        dayKey: String
    ) -> Int {
        let openTodos = matchingTodos(todos, tag: tag).filter { !$0.isDone }.count
        let snaps = checks.compactMap(\.snapshot)
        let openRoutines = matchingRoutines(routines, tag: tag)
            .filter {
                DayBoardLogic.isRoutineDue($0.snapshot, on: dayKey)
                    && !DayBoardLogic.isRoutineDone($0.snapshot, checks: snaps, on: dayKey)
            }
            .count
        let openSubtasks = matchingSubtasks(todos, tag: tag).filter { !$0.isDone }.count
        return openTodos + openRoutines + openSubtasks
    }

    static func writeSortOrder<Item>(
        _ items: [Item], orderedIDs: [UUID], id: (Item) -> UUID, assign: (Item, Int) -> Void
    ) {
        for (index, orderedID) in orderedIDs.enumerated() {
            if let item = items.first(where: { id($0) == orderedID }) {
                assign(item, index)
            }
        }
    }

    static func reindexRoutines(_ items: [DailyRoutine], from source: IndexSet, to destination: Int) {
        var ordered = items
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in ordered.enumerated() {
            item.sortOrder = index
        }
    }

    static func mergeTags(
        sources: [UUID],
        into targetID: UUID,
        tags: [TagItem],
        todos: [TodoItem],
        routines: [DailyRoutine],
        diaries: [DiaryEntry],
        subtasks: [SubtaskItem]
    ) throws {
        let sourceSet = Set(sources).subtracting([targetID])
        guard !sourceSet.isEmpty else { throw TagMergeError.emptySources }
        guard let target = tags.first(where: { $0.id == targetID && $0.deletedAt == nil }) else {
            throw TagMergeError.missingTarget
        }
        if target.isDiaryPreset { throw TagMergeError.presetProtected }
        let sourceTags = tags.filter { sourceSet.contains($0.id) }
        guard sourceTags.count == sourceSet.count else { throw TagMergeError.missingTarget }
        if sourceTags.contains(where: \.isDiaryPreset) { throw TagMergeError.presetProtected }

        func rewrite(_ raw: String) -> String {
            let ids = TagIDList.parse(raw)
            guard ids.contains(where: { sourceSet.contains($0) }) else { return TagIDList.normalized(raw) }
            let kept = ids.filter { !sourceSet.contains($0) }
            return TagIDList.encode(TagIDList.normalized(kept + [targetID]))
        }
        for todo in todos { todo.tagIDs = rewrite(todo.tagIDs) }
        for routine in routines { routine.tagIDs = rewrite(routine.tagIDs) }
        for diary in diaries { diary.tagIDs = rewrite(diary.tagIDs) }
        for subtask in subtasks { subtask.tagIDs = rewrite(subtask.tagIDs) }
        let stamp = SoftDelete.stamp()
        for tag in sourceTags where tag.deletedAt == nil {
            tag.deletedAt = stamp
        }
    }

    static func unlinkTag(
        _ id: UUID,
        todos: [TodoItem],
        routines: [DailyRoutine],
        diaries: [DiaryEntry],
        subtasks: [SubtaskItem] = []
    ) {
        for todo in todos where TagIDList.contains(todo.tagIDs, id) {
            todo.tagIDs = TagIDList.toggling(todo.tagIDs, id)
        }
        for routine in routines where TagIDList.contains(routine.tagIDs, id) {
            routine.tagIDs = TagIDList.toggling(routine.tagIDs, id)
        }
        for diary in diaries where TagIDList.contains(diary.tagIDs, id) {
            diary.tagIDs = TagIDList.toggling(diary.tagIDs, id)
        }
        for subtask in (subtasks.isEmpty ? todos.flatMap(\.subtasks) : subtasks) where TagIDList.contains(subtask.tagIDs, id) {
            subtask.tagIDs = TagIDList.toggling(subtask.tagIDs, id)
        }
    }
}

struct AttachmentRef: Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var filename: String
    var storageID: UUID? = nil
    var privacyVaultID: UUID? = nil
    var ownerID: UUID? = nil
    var ownerKind: String? = nil
}

struct AttachmentCluster: Equatable, Identifiable {
    var id: String { "\(kind.rawValue)-\(ownerID.uuidString)" }
    var kind: AttachmentOwner
    var ownerID: UUID
    var items: [AttachmentRef]
}

enum AttachmentClusters {
    static func grouped(_ items: [AttachmentItem], liveOwnerIDs: Set<UUID>? = nil) -> [AttachmentCluster] {
        let live = items.filter { item in
            guard item.deletedAt == nil else { return false }
            if let liveOwnerIDs {
                return liveOwnerIDs.contains(item.ownerID)
            }
            return true
        }.sorted { $0.createdAt > $1.createdAt }
        var order: [(AttachmentOwner, UUID)] = []
        var buckets: [String: [AttachmentRef]] = [:]
        for item in live {
            guard let kind = AttachmentOwner(rawValue: item.ownerKind) else { continue }
            let key = "\(kind.rawValue)|\(item.ownerID.uuidString)"
            if buckets[key] == nil {
                order.append((kind, item.ownerID))
            }
            buckets[key, default: []].append(item.reference)
        }
        let kindRank: [AttachmentOwner: Int] = [.todo: 0, .diary: 1, .routine: 2]
        return order
            .sorted { lhs, rhs in
                let left = kindRank[lhs.0] ?? 9
                let right = kindRank[rhs.0] ?? 9
                if left != right { return left < right }
                return lhs.1.uuidString < rhs.1.uuidString
            }
            .map { kind, ownerID in
                AttachmentCluster(kind: kind, ownerID: ownerID, items: buckets["\(kind.rawValue)|\(ownerID.uuidString)"] ?? [])
            }
    }
}
