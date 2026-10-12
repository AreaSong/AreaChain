import Foundation

struct AttachmentSyntaxToken: Equatable, Sendable {
    let name: String
    let range: NSRange
}

struct UnlinkedAttachmentEntry: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var filename: String
    var createdAt: Date

    var reference: AttachmentRef {
        AttachmentRef(id: id, filename: filename, storageID: id)
    }
}

struct AttachmentReferenceTag: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let name: String
    let colorToken: TagColorToken
}

struct AttachmentReferenceItem: Identifiable, Equatable, Hashable, Sendable {
    var id: String { "\(kind.rawValue)-\(ownerID.uuidString)" }
    let attachmentID: UUID
    let kind: AttachmentOwner
    let ownerID: UUID
    let title: String
    let dayKey: String?
    let tags: [AttachmentReferenceTag]
    let createdAt: Date
}

struct AttachmentLibraryItem: Identifiable, Equatable, Hashable, Sendable {
    let storageID: UUID
    var allStorageIDs: [UUID]
    let primaryReference: AttachmentRef
    var filename: String
    let createdAt: Date
    let attachmentItemIDs: [UUID]
    let isInUnlinkedPool: Bool
    let references: [AttachmentReferenceItem]

    init(
        storageID: UUID,
        allStorageIDs: [UUID]? = nil,
        primaryReference: AttachmentRef,
        filename: String,
        createdAt: Date,
        attachmentItemIDs: [UUID],
        isInUnlinkedPool: Bool,
        references: [AttachmentReferenceItem]
    ) {
        self.storageID = storageID
        self.allStorageIDs = allStorageIDs ?? [storageID]
        self.primaryReference = primaryReference
        self.filename = filename
        self.createdAt = createdAt
        self.attachmentItemIDs = attachmentItemIDs
        self.isInUnlinkedPool = isInUnlinkedPool
        self.references = references
    }

    var id: UUID { primaryReference.id }
    var isUnlinked: Bool { references.isEmpty }
    var referenceCount: Int { references.count }
}

enum AttachmentFilterKind: String, CaseIterable, Identifiable, Sendable {
    case all
    case todo
    case routine
    case diary
    case unlinked

    var id: String { rawValue }
}

enum AttachmentSortOrder: String, CaseIterable, Identifiable, Sendable {
    case newest
    case oldest
    case name
    case referenceCount

    var id: String { rawValue }
}

/// 附件 `@` 引用语法、防重名默认命名与以附件为主体的聚合筛选排序投影。
enum AttachmentSyntax {
    private static let tokenPattern =
        #"(?<![^\s(\[（【])[@＠]"#
        + ##"(?:"((?:\\.|[^"\\\r\n])+)"|([\p{L}\p{M}\p{N}_\-]+(?:\.[\p{L}\p{M}\p{N}_\-]+)*))"##
        + #"(?=$|[\s,，.。;；:：!！?？)）\]】])"#
    private static let expression = CompiledRegularExpression.make(tokenPattern)
    private static let timePresetWords: Set<String> = [
        "早上", "上午", "中午", "下午", "傍晚", "晚上",
        "morning", "noon", "afternoon", "evening", "night"
    ]

    static func normalizedName(_ name: String) -> String {
        TagSyntax.normalizedName(name)
    }

    static func tokens(in text: String) -> [AttachmentSyntaxToken] {
        let source = text as NSString
        let protected = TagSyntax.protectedRanges(in: text)
        return expression.matches(in: text, range: NSRange(location: 0, length: source.length)).compactMap { match in
            guard !protected.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { return nil }
            let raw = source.substring(with: match.range)
            let name = TagSyntax.decodedName(String(raw.dropFirst())).trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidAttachmentTokenName(name) else { return nil }
            return AttachmentSyntaxToken(name: name, range: match.range)
        }
    }

    static func names(in text: String) -> [String] {
        TagSyntax.uniqueNames(tokens(in: text).map(\.name))
    }

    static func spelling(for filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: #"^[\p{L}\p{M}\p{N}_\-]+(?:\.[\p{L}\p{M}\p{N}_\-]+)*$"#, options: .regularExpression) != nil {
            return "@" + trimmed
        }
        let quoted = (try? JSONEncoder().encode(trimmed)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        return "@" + quoted
    }

    static func uniqueFilename(base: String, existing: [String]) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "paste.png" : trimmed
        let normalizedExisting = Set(existing.map(normalizedName))
        if !normalizedExisting.contains(normalizedName(fallback)) {
            return fallback
        }
        let (stem, ext) = splitExtension(fallback)
        var index = 2
        while true {
            let candidate = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
            if !normalizedExisting.contains(normalizedName(candidate)) {
                return candidate
            }
            index += 1
        }
    }

    static func sanitizedFilename(_ candidate: String, fallback: String) -> String {
        let cleaned = candidate
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return fallback }
        let (_, candidateExt) = splitExtension(cleaned)
        let (_, fallbackExt) = splitExtension(fallback)
        if candidateExt.isEmpty, !fallbackExt.isEmpty {
            return "\(cleaned).\(fallbackExt)"
        }
        return cleaned
    }

    private static func isValidAttachmentTokenName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        if NaturalLanguageParser.timeMinutes("@" + name) != nil { return false }
        let lowered = name.lowercased()
        if timePresetWords.contains(lowered) { return false }
        if name.allSatisfy(\.isNumber) { return false }
        return true
    }

    private static func splitExtension(_ filename: String) -> (stem: String, ext: String) {
        guard let dot = filename.lastIndex(of: "."), dot > filename.startIndex else {
            return (filename, "")
        }
        let stem = String(filename[..<dot])
        let ext = String(filename[filename.index(after: dot)...])
        return (stem, ext)
    }
}

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
            let canonicalKey: UUID
            if let hash = contentHashes[rawKey], !hash.isEmpty {
                if let existing = hashCanonical[hash] {
                    canonicalKey = existing
                } else {
                    canonicalKey = rawKey
                    hashCanonical[hash] = rawKey
                }
            } else {
                canonicalKey = rawKey
            }
            if result.buckets[canonicalKey] == nil { result.order.append(canonicalKey) }
            result.buckets[canonicalKey, default: []].append(item)
            if !(result.mergedStorageIDs[canonicalKey]?.contains(rawKey) ?? false) {
                result.mergedStorageIDs[canonicalKey, default: []].append(rawKey)
            }
        }
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
        return result
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

    static func filterAndSort(
        _ items: [AttachmentLibraryItem],
        filter: AttachmentFilterKind = .all,
        query: String = "",
        sort: AttachmentSortOrder = .newest
    ) -> [AttachmentLibraryItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = items.filter { item in
            guard matchesFilter(item, filter: filter) else { return false }
            guard !trimmedQuery.isEmpty else { return true }
            return matchesQuery(item, query: trimmedQuery)
        }
        return sortItems(filtered, by: sort)
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
    ) -> (title: String, dayKey: String?, tags: [AttachmentReferenceTag])? {
        switch key.kind {
        case .todo:
            guard let todo = owners.liveTodos[key.id] else { return nil }
            let title = todo.title.isEmpty ? fallbackName : todo.title
            return (title, todo.dayKey, resolveTags(rawTagIDs: todo.tagIDs, liveTagMap: liveTagMap))
        case .routine:
            guard let routine = owners.liveRoutines[key.id] else { return nil }
            let title = routine.title.isEmpty ? fallbackName : routine.title
            return (title, nil, resolveTags(rawTagIDs: routine.tagIDs, liveTagMap: liveTagMap))
        case .diary:
            guard let diary = owners.liveDiaries[key.id] else { return nil }
            let title = DiaryPrivacy.displayText(diary.snapshot, tags: allTags, locale: locale)
            let tags = resolveDiaryTags(diary: diary, allTags: allTags, liveTagMap: liveTagMap)
            return (title, diary.dayKey, tags)
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
