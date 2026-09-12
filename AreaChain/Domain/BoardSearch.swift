import Foundation

struct BoardSearchHit: Equatable, Identifiable {
    enum Kind: String, Equatable {
        case todo
        case diary
        case routine
    }

    var id: UUID
    var kind: Kind
    var title: String
    var dayKey: String
    var createdAt: Date
}

struct BoardSearchPriority: Equatable {
    var isImportant: Bool
    var isUrgent: Bool
}

struct BoardSearchPrivacy {
    var sensitiveDiaryIDs: Set<UUID> = []
    var placeholder: String = "••••••••"
}

struct BoardSearchQuery: Equatable {
    var raw: String
    var textKeywords: [String] = []
    var tagNames: [String] = []
    var priority: BoardSearchPriority? = nil
    var hasPriority: Bool = false

    var isEmpty: Bool {
        textKeywords.isEmpty && tagNames.isEmpty && !hasPriority
    }
}

enum BoardSearch {
    static func parseQuery(_ raw: String) -> BoardSearchQuery {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return BoardSearchQuery(raw: raw) }

        let tokens = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var keywords: [String] = []
        var tags: [String] = []
        var prioritySlot: BoardSearchPriority? = nil
        var hasPriority = false

        for token in tokens {
            if token.hasPrefix("#"), token.count > 1 {
                tags.append(String(token.dropFirst()))
            } else if token.hasPrefix("!"), let p = parsePriorityToken(token) {
                prioritySlot = p
                hasPriority = true
            } else {
                keywords.append(token)
            }
        }

        return BoardSearchQuery(
            raw: raw,
            textKeywords: keywords,
            tagNames: tags,
            priority: prioritySlot,
            hasPriority: hasPriority
        )
    }

    private static func parsePriorityToken(_ token: String) -> BoardSearchPriority? {
        let lower = token.lowercased()
        switch lower {
        case "!p1", "!重要紧急", "!紧急重要", "!重要且紧急":
            return BoardSearchPriority(isImportant: true, isUrgent: true)
        case "!p2", "!重要", "!重要不紧急":
            return BoardSearchPriority(isImportant: true, isUrgent: false)
        case "!p3", "!紧急", "!不重要紧急", "!紧急不重要":
            return BoardSearchPriority(isImportant: false, isUrgent: true)
        case "!p4", "!不重要不紧急":
            return BoardSearchPriority(isImportant: false, isUrgent: false)
        default:
            return nil
        }
    }

    static func hits(
        query: String,
        todos: [TodoSnapshot],
        diaries: [DiarySnapshot],
        routines: [RoutineSnapshot],
        todayKey: String = DayKey.today(),
        tagMap: [UUID: String] = [:],
        privacy: BoardSearchPrivacy = BoardSearchPrivacy()
    ) -> [BoardSearchHit] {
        let parsed = parseQuery(query)
        guard !parsed.isEmpty else { return [] }

        let found = todoHits(parsed, todos, tagMap: tagMap)
            + diaryHits(parsed, diaries, tagMap: tagMap, privacy: privacy)
            + routineHits(parsed, routines, todayKey: todayKey, tagMap: tagMap)

        return found.sorted {
            if $0.dayKey != $1.dayKey { return $0.dayKey > $1.dayKey }
            return $0.createdAt > $1.createdAt
        }
    }

    static func grouped(_ hits: [BoardSearchHit]) -> [(dayKey: String, items: [BoardSearchHit])] {
        var order: [String] = []
        var buckets: [String: [BoardSearchHit]] = [:]
        for hit in hits {
            if buckets[hit.dayKey] == nil {
                order.append(hit.dayKey)
            }
            buckets[hit.dayKey, default: []].append(hit)
        }
        return order.map { key in (key, buckets[key] ?? []) }
    }

    static func matches(_ haystack: String, needle: String) -> Bool {
        !needle.isEmpty && haystack.localizedStandardContains(needle)
    }

    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func filteredDiaries(_ entries: [DiarySnapshot], filter: BoardFilter) -> [DiarySnapshot] {
        // 手记没有项目、捕获来源和优先级，不能混进要求这些属性的结果。
        guard filter.projectID == nil, filter.bundleID == nil, !filter.isHighPriorityOnly else { return [] }
        guard let tagID = filter.tagID else { return entries }
        return entries.filter { TagIDList.contains($0.tagIDs, tagID) }
    }

    private static func matchTags(tagNames: [String], attachedIDs: String, text: String, tagMap: [UUID: String]) -> Bool {
        guard !tagNames.isEmpty else { return true }
        for name in tagNames {
            let directInText = text.localizedCaseInsensitiveContains("#\(name)")
            let inAttached = tagMap.contains { id, tagName in
                TagIDList.contains(attachedIDs, id) && tagName.caseInsensitiveCompare(name) == .orderedSame
            }
            if !directInText && !inAttached {
                return false
            }
        }
        return true
    }

    private static func todoHits(_ query: BoardSearchQuery, _ todos: [TodoSnapshot], tagMap: [UUID: String]) -> [BoardSearchHit] {
        todos.compactMap { item in
            guard item.deletedAt == nil else { return nil }

            if !query.textKeywords.isEmpty {
                let matchesAll = query.textKeywords.allSatisfy { kw in
                    matches(item.title, needle: kw) || matches(item.notes, needle: kw)
                }
                guard matchesAll else { return nil }
            }

            if query.hasPriority, let p = query.priority {
                guard item.isImportant == p.isImportant && item.isUrgent == p.isUrgent else { return nil }
            }

            guard matchTags(tagNames: query.tagNames, attachedIDs: item.tagIDs, text: "\(item.title) \(item.notes)", tagMap: tagMap) else {
                return nil
            }

            return BoardSearchHit(
                id: item.id,
                kind: .todo,
                title: item.title,
                dayKey: item.dayKey,
                createdAt: item.createdAt
            )
        }
    }

    private static func diaryHits(
        _ query: BoardSearchQuery, _ diaries: [DiarySnapshot], tagMap: [UUID: String], privacy: BoardSearchPrivacy
    ) -> [BoardSearchHit] {
        guard !query.hasPriority else { return [] }

        return diaries.compactMap { item in
            guard item.deletedAt == nil else { return nil }

            if !query.textKeywords.isEmpty {
                let matchesAll = query.textKeywords.allSatisfy { kw in
                    matches(item.text, needle: kw)
                }
                guard matchesAll else { return nil }
            }

            guard matchTags(tagNames: query.tagNames, attachedIDs: item.tagIDs, text: item.text, tagMap: tagMap) else {
                return nil
            }

            return BoardSearchHit(
                id: item.id,
                kind: .diary,
                title: privacy.sensitiveDiaryIDs.contains(item.id) || DiaryPrivacy.isSensitive(item, tagNames: tagMap)
                    ? privacy.placeholder : item.text,
                dayKey: item.dayKey,
                createdAt: item.createdAt
            )
        }
    }

    private static func routineHits(
        _ query: BoardSearchQuery,
        _ routines: [RoutineSnapshot],
        todayKey: String,
        tagMap: [UUID: String]
    ) -> [BoardSearchHit] {
        guard !query.hasPriority else { return [] }

        return routines.compactMap { item in
            guard item.deletedAt == nil, item.isEnabled else { return nil }

            if !query.textKeywords.isEmpty {
                let matchesAll = query.textKeywords.allSatisfy { kw in
                    matches(item.title, needle: kw) || matches(item.notes, needle: kw)
                }
                guard matchesAll else { return nil }
            }

            guard matchTags(tagNames: query.tagNames, attachedIDs: item.tagIDs, text: "\(item.title) \(item.notes)", tagMap: tagMap) else {
                return nil
            }

            let fromKey = item.createdDayKey > todayKey ? item.createdDayKey : todayKey
            return BoardSearchHit(
                id: item.id,
                kind: .routine,
                title: item.title,
                dayKey: WeekdayMask.nextScheduledDayKey(mask: item.weekdayMask, from: fromKey),
                createdAt: item.createdAt
            )
        }
    }
}
