import Foundation

/// 附件中心聚合投影：按底层物理文件标识与内容指纹去重、分配全局唯一文件名，并支持类型/标签/优先级/提醒/日期筛选与排序。
enum AttachmentLibraryProjection {
    static func build(
        attachments: [AttachmentItem],
        unlinked: [UnlinkedAttachmentEntry],
        owners: AttachmentOwnerIndex,
        tags: [TagItem],
        contentHashes: [UUID: String] = [:],
        locale: Locale = .current
    ) -> [AttachmentLibraryItem] {
        let liveTagMap = Dictionary(
            uniqueKeysWithValues: tags.filter { $0.deletedAt == nil }.map { ($0.id, $0) }
        )
        let grouped = groupStorageBuckets(
            attachments: attachments,
            unlinked: unlinked,
            owners: owners,
            tags: tags,
            contentHashes: contentHashes
        )
        let rawItems = grouped.order.compactMap { storageID in
            makeLibraryItem(
                storageID: storageID,
                allStorageIDs: grouped.mergedStorageIDs[storageID] ?? [storageID],
                items: grouped.buckets[storageID] ?? [],
                unlinkedEntry: grouped.unlinkedByID[storageID],
                owners: owners,
                allTags: tags,
                liveTagMap: liveTagMap,
                locale: locale
            )
        }
        return assignGloballyUniqueFilenames(rawItems)
    }

    static func filterAndSort(
        _ items: [AttachmentLibraryItem],
        filter: AttachmentFilterKind = .all,
        boardFilter: BoardFilter = BoardFilter(),
        todayKey: String = "",
        query: String = "",
        sort: AttachmentSortOrder = .newest
    ) -> [AttachmentLibraryItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = items.filter { item in
            guard matchesFilter(item, filter: filter) else { return false }
            guard matchesBoardFilter(item, filter: boardFilter, todayKey: todayKey) else { return false }
            guard !trimmedQuery.isEmpty else { return true }
            return matchesQuery(item, query: trimmedQuery)
        }
        return sortItems(filtered, by: sort)
    }

    static func tagCounts(for items: [AttachmentLibraryItem]) -> (counts: [UUID: Int], untaggedCount: Int) {
        var counts: [UUID: Int] = [:]
        var untaggedCount = 0
        for item in items {
            let tagIDs = Set(item.references.flatMap { $0.tags.map(\.id) })
            if tagIDs.isEmpty || item.references.contains(where: { $0.tags.isEmpty }) {
                untaggedCount += 1
            }
            for tagID in tagIDs {
                counts[tagID, default: 0] += 1
            }
        }
        return (counts, untaggedCount)
    }

    static func filterCounts(for items: [AttachmentLibraryItem]) -> [AttachmentFilterKind: Int] {
        var counts: [AttachmentFilterKind: Int] = [.all: items.count]
        for kind in [AttachmentFilterKind.todo, .routine, .diary, .unlinked] {
            counts[kind] = items.reduce(into: 0) { acc, item in
                if matchesFilter(item, filter: kind) { acc += 1 }
            }
        }
        return counts
    }

    static func availableFilenames(
        attachments: [AttachmentItem],
        unlinked: [UnlinkedAttachmentEntry],
        owners: AttachmentOwnerIndex,
        tags: [TagItem],
        contentHashes: [UUID: String] = [:]
    ) -> [String] {
        let items = build(
            attachments: attachments,
            unlinked: unlinked,
            owners: owners,
            tags: tags,
            contentHashes: contentHashes
        )
        return TagSyntax.uniqueNames(items.map(\.filename))
    }

    private struct GroupedStorageBuckets {
        var buckets: [UUID: [AttachmentItem]] = [:]
        var mergedStorageIDs: [UUID: [UUID]] = [:]
        var unlinkedByID: [UUID: UnlinkedAttachmentEntry] = [:]
        var order: [UUID] = []
    }

    private static func groupStorageBuckets(
        attachments: [AttachmentItem],
        unlinked: [UnlinkedAttachmentEntry],
        owners: AttachmentOwnerIndex,
        tags: [TagItem],
        contentHashes: [UUID: String]
    ) -> GroupedStorageBuckets {
        var result = GroupedStorageBuckets()
        var hashCanonical: [String: UUID] = [:]
        let browsable = attachments
            .filter { AttachmentAccess.canBrowse($0, owners: owners, tags: tags) }
            .sorted { $0.createdAt < $1.createdAt }
        for item in browsable {
            let rawKey = item.storageID ?? item.id
            let canonicalKey = resolveCanonicalKey(rawKey: rawKey, contentHashes: contentHashes, hashCanonical: &hashCanonical)
            if result.buckets[canonicalKey] == nil { result.order.append(canonicalKey) }
            result.buckets[canonicalKey, default: []].append(item)
            if !(result.mergedStorageIDs[canonicalKey]?.contains(rawKey) ?? false) {
                result.mergedStorageIDs[canonicalKey, default: []].append(rawKey)
            }
        }
        appendUnlinkedBuckets(unlinked: unlinked, contentHashes: contentHashes, hashCanonical: &hashCanonical, into: &result)
        return result
    }

    private static func resolveCanonicalKey(
        rawKey: UUID,
        contentHashes: [UUID: String],
        hashCanonical: inout [String: UUID]
    ) -> UUID {
        guard let hash = contentHashes[rawKey], !hash.isEmpty else { return rawKey }
        if let existing = hashCanonical[hash] {
            return existing
        }
        hashCanonical[hash] = rawKey
        return rawKey
    }

    private static func appendUnlinkedBuckets(
        unlinked: [UnlinkedAttachmentEntry],
        contentHashes: [UUID: String],
        hashCanonical: inout [String: UUID],
        into result: inout GroupedStorageBuckets
    ) {
        for entry in unlinked.sorted(by: { $0.createdAt < $1.createdAt }) {
            if let hash = contentHashes[entry.id], !hash.isEmpty, let existing = hashCanonical[hash] {
                if !(result.mergedStorageIDs[existing]?.contains(entry.id) ?? false) {
                    result.mergedStorageIDs[existing, default: []].append(entry.id)
                }
                if result.unlinkedByID[existing] == nil {
                    result.unlinkedByID[existing] = entry
                }
                continue
            }
            if let hash = contentHashes[entry.id], !hash.isEmpty {
                hashCanonical[hash] = entry.id
            }
            result.unlinkedByID[entry.id] = entry
            if result.buckets[entry.id] == nil {
                result.order.append(entry.id)
                result.mergedStorageIDs[entry.id] = [entry.id]
            }
        }
    }

    private static func assignGloballyUniqueFilenames(_ items: [AttachmentLibraryItem]) -> [AttachmentLibraryItem] {
        var result = items
        let sortedIndices = result.indices.sorted { lhs, rhs in
            if result[lhs].createdAt != result[rhs].createdAt {
                return result[lhs].createdAt < result[rhs].createdAt
            }
            return result[lhs].storageID.uuidString < result[rhs].storageID.uuidString
        }
        var assignedNames: [String] = []
        for idx in sortedIndices {
            let unique = AttachmentSyntax.uniqueFilename(base: result[idx].filename, existing: assignedNames)
            assignedNames.append(unique)
            result[idx].filename = unique
        }
        return result
    }

    private static func makeLibraryItem(
        storageID: UUID,
        allStorageIDs: [UUID],
        items: [AttachmentItem],
        unlinkedEntry: UnlinkedAttachmentEntry?,
        owners: AttachmentOwnerIndex,
        allTags: [TagItem],
        liveTagMap: [UUID: TagItem],
        locale: Locale
    ) -> AttachmentLibraryItem? {
        let sortedItems = items.sorted { $0.createdAt < $1.createdAt }
        guard let primary = sortedItems.first?.reference ?? unlinkedEntry?.reference else { return nil }
        let preferredName = sortedItems.last(where: {
            AttachmentSyntax.normalizedName($0.filename) != AttachmentSyntax.normalizedName("paste.png")
        })?.filename ?? sortedItems.last?.filename ?? unlinkedEntry?.filename ?? primary.filename
        let createdAt = sortedItems.first?.createdAt ?? unlinkedEntry?.createdAt ?? .distantPast
        let refs = buildReferences(for: sortedItems, owners: owners, allTags: allTags, liveTagMap: liveTagMap, locale: locale)
        return AttachmentLibraryItem(
            storageID: storageID,
            allStorageIDs: allStorageIDs,
            primaryReference: primary,
            filename: preferredName,
            createdAt: createdAt,
            attachmentItemIDs: sortedItems.map(\.id),
            isInUnlinkedPool: unlinkedEntry != nil,
            references: refs
        )
    }

    private struct ResolvedOwnerInfo {
        let title: String
        let dayKey: String?
        let tags: [AttachmentReferenceTag]
        var isImportant: Bool = false
        var isUrgent: Bool = false
        var remindMinutes: Int?
        var isDone: Bool = false
        var sourceBundleID: String = ""
    }

    private static func buildReferences(
        for items: [AttachmentItem],
        owners: AttachmentOwnerIndex,
        allTags: [TagItem],
        liveTagMap: [UUID: TagItem],
        locale: Locale
    ) -> [AttachmentReferenceItem] {
        var seen: Set<String> = []
        var result: [AttachmentReferenceItem] = []
        for item in items {
            guard let key = item.ownerKey else { continue }
            let dedupKey = "\(key.kind.rawValue)|\(key.id.uuidString)"
            guard seen.insert(dedupKey).inserted else { continue }
            guard let info = resolveOwnerInfo(
                key: key, fallbackName: item.filename, owners: owners,
                allTags: allTags, liveTagMap: liveTagMap, locale: locale
            ) else {
                continue
            }
            result.append(AttachmentReferenceItem(
                attachmentID: item.id,
                kind: key.kind,
                ownerID: key.id,
                title: info.title,
                dayKey: info.dayKey,
                tags: info.tags,
                isImportant: info.isImportant,
                isUrgent: info.isUrgent,
                remindMinutes: info.remindMinutes,
                isDone: info.isDone,
                sourceBundleID: info.sourceBundleID,
                createdAt: item.createdAt
            ))
        }
        return result
    }

    private static func resolveOwnerInfo(
        key: AttachmentOwnerKey,
        fallbackName: String,
        owners: AttachmentOwnerIndex,
        allTags: [TagItem],
        liveTagMap: [UUID: TagItem],
        locale: Locale
    ) -> ResolvedOwnerInfo? {
        switch key.kind {
        case .todo:
            guard let todo = owners.liveTodos[key.id] else { return nil }
            let title = todo.title.isEmpty ? fallbackName : todo.title
            return ResolvedOwnerInfo(
                title: title,
                dayKey: todo.dayKey,
                tags: resolveTags(rawTagIDs: todo.tagIDs, liveTagMap: liveTagMap),
                isImportant: todo.isImportant,
                isUrgent: todo.isUrgent,
                remindMinutes: todo.remindMinutes,
                isDone: todo.isDone,
                sourceBundleID: todo.sourceBundleID
            )
        case .routine:
            guard let routine = owners.liveRoutines[key.id] else { return nil }
            let title = routine.title.isEmpty ? fallbackName : routine.title
            return ResolvedOwnerInfo(
                title: title,
                dayKey: nil,
                tags: resolveTags(rawTagIDs: routine.tagIDs, liveTagMap: liveTagMap),
                isImportant: routine.isImportant,
                isUrgent: routine.isUrgent,
                remindMinutes: routine.remindMinutes
            )
        case .diary:
            guard let diary = owners.liveDiaries[key.id] else { return nil }
            let title = DiaryPrivacy.displayText(diary.snapshot, tags: allTags, locale: locale)
            let tags = resolveDiaryTags(diary: diary, allTags: allTags, liveTagMap: liveTagMap)
            return ResolvedOwnerInfo(title: title, dayKey: diary.dayKey, tags: tags)
        }
    }

    private static func resolveTags(rawTagIDs: String, liveTagMap: [UUID: TagItem]) -> [AttachmentReferenceTag] {
        TagIDList.parse(rawTagIDs).compactMap { id in
            guard let tag = liveTagMap[id] else { return nil }
            return AttachmentReferenceTag(id: tag.id, name: tag.name, colorToken: tag.resolvedColorToken)
        }
    }

    private static func resolveDiaryTags(
        diary: DiaryEntry,
        allTags: [TagItem],
        liveTagMap: [UUID: TagItem]
    ) -> [AttachmentReferenceTag] {
        var result = resolveTags(rawTagIDs: diary.tagIDs, liveTagMap: liveTagMap)
        var seen = Set(result.map { TagSyntax.normalizedName($0.name) })
        let liveByName = Dictionary(
            allTags.filter { $0.deletedAt == nil }.map { (TagSyntax.normalizedName($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for name in TagSyntax.names(in: diary.text) {
            let key = TagSyntax.normalizedName(name)
            guard seen.insert(key).inserted else { continue }
            if let tag = liveByName[key] {
                result.append(AttachmentReferenceTag(id: tag.id, name: tag.name, colorToken: tag.resolvedColorToken))
            }
        }
        return result
    }

    private static func matchesFilter(_ item: AttachmentLibraryItem, filter: AttachmentFilterKind) -> Bool {
        switch filter {
        case .all: return true
        case .todo: return item.references.contains { $0.kind == .todo }
        case .routine: return item.references.contains { $0.kind == .routine }
        case .diary: return item.references.contains { $0.kind == .diary }
        case .unlinked: return item.isUnlinked
        }
    }

    private static func matchesBoardFilter(
        _ item: AttachmentLibraryItem,
        filter: BoardFilter,
        todayKey: String
    ) -> Bool {
        guard filter.isActive else { return true }
        if item.references.isEmpty {
            let onlyNoTag = filter.isNoTag
                && filter.priorityScope == .all
                && !filter.isHighPriorityOnly
                && filter.reminderScope == .all
                && filter.dateScope == .all
                && filter.bundleID == nil
            return onlyNoTag
        }
        return item.references.contains { matchesReferenceBoardFilter($0, filter: filter, todayKey: todayKey) }
    }

    private static func matchesReferenceBoardFilter(
        _ ref: AttachmentReferenceItem,
        filter: BoardFilter,
        todayKey: String
    ) -> Bool {
        if let tagID = filter.tagID {
            if tagID == BoardFilter.noneID {
                guard ref.tags.isEmpty else { return false }
            } else {
                guard ref.tags.contains(where: { $0.id == tagID }) else { return false }
            }
        }
        if filter.priorityScope != .all || filter.isHighPriorityOnly {
            guard ref.kind == .todo || ref.kind == .routine else { return false }
            let bits = ClassifyBits(
                tagIDs: "",
                isImportant: ref.isImportant,
                isUrgent: ref.isUrgent,
                sourceBundleID: ref.sourceBundleID
            )
            guard Classification.matches(bits, filter: filter.withTag(nil).withBundle(nil)) else { return false }
        }
        if filter.reminderScope != .all {
            guard ref.kind == .todo || ref.kind == .routine else { return false }
            guard Classification.matchesReminder(ref.remindMinutes, scope: filter.reminderScope) else { return false }
        }
        if filter.dateScope != .all {
            guard let dayKey = ref.dayKey, !todayKey.isEmpty else { return false }
            guard Classification.matchesDate(dayKey: dayKey, isDone: ref.isDone, todayKey: todayKey, scope: filter.dateScope) else {
                return false
            }
        }
        if let bundleID = filter.bundleID, ref.sourceBundleID != bundleID { return false }
        return true
    }

    private static func matchesQuery(_ item: AttachmentLibraryItem, query: String) -> Bool {
        if item.filename.localizedCaseInsensitiveContains(query) { return true }
        for ref in item.references {
            if ref.title.localizedCaseInsensitiveContains(query) { return true }
            if ref.tags.contains(where: { $0.name.localizedCaseInsensitiveContains(query) }) { return true }
        }
        return false
    }

    private static func sortItems(_ items: [AttachmentLibraryItem], by order: AttachmentSortOrder) -> [AttachmentLibraryItem] {
        items.sorted { lhs, rhs in
            switch order {
            case .newest:
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            case .oldest:
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            case .name:
                let cmp = lhs.filename.localizedStandardCompare(rhs.filename)
                if cmp != .orderedSame { return cmp == .orderedAscending }
            case .referenceCount:
                if lhs.referenceCount != rhs.referenceCount { return lhs.referenceCount > rhs.referenceCount }
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            }
            return lhs.storageID.uuidString < rhs.storageID.uuidString
        }
    }
}
