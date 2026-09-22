import Foundation

struct BoardSearchHit: Equatable, Identifiable {
    enum Kind: String, Equatable {
        case todo
        case diary
        case routine
        case subtask

        var titleKey: String {
            switch self {
            case .todo: "search.kind.todo"
            case .routine: "search.kind.routine"
            case .diary: "search.kind.diary"
            case .subtask: "search.kind.subtask"
            }
        }
    }

    var id: UUID
    var kind: Kind
    var title: String
    var dayKey: String
    var createdAt: Date
    var parentID: UUID? = nil
}

struct BoardSearchScope {
    var filter = BoardFilter()
    var projectIDs: Set<UUID>? = nil
}

struct BoardSearchPriority: Equatable {
    var isImportant: Bool
    var isUrgent: Bool
}

struct BoardSearchPrivacy {
    var sensitiveDiaryIDs: Set<UUID> = []
    /// 名字表里看不出 `isPrivateDiary`，搜索遮罩必须带上这组标识。
    var privateTagIDs: Set<UUID> = []
    var placeholder: String = "••••••••"

    static func protected(diaries: [DiaryEntry], tags: [TagItem], locale: Locale) -> BoardSearchPrivacy {
        BoardSearchPrivacy(
            sensitiveDiaryIDs: Set(diaries.filter { DiaryPrivacy.isSensitive($0.snapshot, tags: tags) }.map(\.id)),
            privateTagIDs: Set(tags.filter(\.isPrivateDiary).map(\.id)),
            placeholder: L10n.string("diary.private.title", locale: locale)
        )
    }
}

struct BoardSearchQuery: Equatable {
    var raw: String
    var textKeywords: [String] = []
    var tagNames: [String] = []
    var priority: BoardSearchPriority? = nil
    var hasPriority: Bool = false
    var remindMinutes: Int? = nil

    var isEmpty: Bool {
        textKeywords.isEmpty && tagNames.isEmpty && !hasPriority && remindMinutes == nil
    }
}

enum BoardSearch {
    private static let wordExpression = try! NSRegularExpression(pattern: #"\S+"#)

    static func parseQuery(_ raw: String) -> BoardSearchQuery {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return BoardSearchQuery(raw: raw) }

        let remaining = TagSyntax.removingTags(from: trimmed)
        let source = remaining as NSString
        let tokens = wordExpression.matches(in: remaining, range: NSRange(location: 0, length: source.length))
        let protected = TagSyntax.protectedRanges(in: remaining)
        var keywords: [String] = []
        let tags = TagSyntax.names(in: trimmed)
        var prioritySlot: BoardSearchPriority? = nil
        var hasPriority = false
        var remindMinutes: Int?

        for match in tokens {
            let token = source.substring(with: match.range)
            if protected.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) {
                keywords.append(token)
            } else if token.hasPrefix("!"), let p = parsePriorityToken(token) {
                prioritySlot = p
                hasPriority = true
            } else if let minutes = NaturalLanguageParser.timeMinutes(token) {
                remindMinutes = minutes
            } else {
                keywords.append(token)
            }
        }

        return BoardSearchQuery(
            raw: raw,
            textKeywords: keywords,
            tagNames: tags,
            priority: prioritySlot,
            hasPriority: hasPriority,
            remindMinutes: remindMinutes
        )
    }

    private static func parsePriorityToken(_ token: String) -> BoardSearchPriority? {
        guard let flags = PriorityToken.flags(in: token) else { return nil }
        return BoardSearchPriority(isImportant: flags.isImportant, isUrgent: flags.isUrgent)
    }

    static func hits(
        query: String,
        todos: [TodoSnapshot],
        diaries: [DiarySnapshot],
        routines: [RoutineSnapshot],
        todayKey: String = DayKey.today(),
        tagMap: [UUID: String] = [:],
        privacy: BoardSearchPrivacy = BoardSearchPrivacy(),
        scope: BoardSearchScope = BoardSearchScope()
    ) -> [BoardSearchHit] {
        let parsed = parseQuery(query)
        guard !parsed.isEmpty else { return [] }

        let filteredTodos = todos.filter { Classification.matches($0.classifyBits, filter: scope.filter, projectIDs: scope.projectIDs) }
        let filteredRoutines = routines.filter { Classification.matches($0.classifyBits, filter: scope.filter, projectIDs: scope.projectIDs) }
        let found = todoHits(parsed, filteredTodos, tagMap: tagMap)
            + diaryHits(parsed, filteredDiaries(diaries, filter: scope.filter), tagMap: tagMap, privacy: privacy)
            + routineHits(parsed, filteredRoutines, todayKey: todayKey, tagMap: tagMap)
            + subtaskHits(parsed, todos, tagMap: tagMap, scope: scope)

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

    private static func matchTags(tagNames: [String], attachedIDs: String, tagMap: [UUID: String]) -> Bool {
        guard !tagNames.isEmpty else { return true }
        let attached = Set(TagIDList.parse(attachedIDs).compactMap { tagMap[$0] }.map(TagSyntax.normalizedName))
        return tagNames.allSatisfy { attached.contains(TagSyntax.normalizedName($0)) }
    }

    static func matchesDiary(_ item: DiarySnapshot, query: BoardSearchQuery, tagMap: [UUID: String]) -> Bool {
        guard item.deletedAt == nil, !query.hasPriority, query.remindMinutes == nil else { return false }
        let names = TagIDList.parse(item.tagIDs).compactMap { tagMap[$0] }
        guard query.textKeywords.allSatisfy({ keyword in
            (item.isContentAvailable && matches(item.text, needle: keyword)) || names.contains { matches($0, needle: keyword) }
        }) else { return false }
        return matchTags(tagNames: query.tagNames, attachedIDs: item.tagIDs, tagMap: tagMap)
    }

    private static func matchesRecord(
        title: String,
        notes: String,
        tagIDs: String,
        bits: ClassifyBits,
        remindMinutes: Int?,
        query: BoardSearchQuery,
        tagMap: [UUID: String]
    ) -> Bool {
        if !query.textKeywords.isEmpty {
            let matchesAll = query.textKeywords.allSatisfy { keyword in
                matches(title, needle: keyword) || matches(notes, needle: keyword)
            }
            guard matchesAll else { return false }
        }
        guard matchesAttributes(query, bits: bits, remindMinutes: remindMinutes) else { return false }
        return matchTags(tagNames: query.tagNames, attachedIDs: tagIDs, tagMap: tagMap)
    }

    private static func matchesAttributes(_ query: BoardSearchQuery, bits: ClassifyBits, remindMinutes: Int?) -> Bool {
        if let priority = query.priority {
            guard bits.isImportant == priority.isImportant, bits.isUrgent == priority.isUrgent else { return false }
        }
        if let minutes = query.remindMinutes, remindMinutes != minutes { return false }
        return true
    }

    private static func todoHits(_ query: BoardSearchQuery, _ todos: [TodoSnapshot], tagMap: [UUID: String]) -> [BoardSearchHit] {
        todos.compactMap { item in
            guard item.deletedAt == nil else { return nil }

            guard matchesRecord(
                title: item.title, notes: item.notes, tagIDs: item.tagIDs,
                bits: item.classifyBits, remindMinutes: item.remindMinutes,
                query: query, tagMap: tagMap
            ) else { return nil }

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
        return diaries.compactMap { item in
            guard matchesDiary(item, query: query, tagMap: tagMap) else { return nil }

            return BoardSearchHit(
                id: item.id,
                kind: .diary,
                title: privacy.sensitiveDiaryIDs.contains(item.id)
                    || DiaryPrivacy.isSensitive(item, tagNames: tagMap, privateTagIDs: privacy.privateTagIDs)
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
        return routines.compactMap { item in
            guard item.deletedAt == nil, item.isEnabled else { return nil }

            guard matchesRecord(
                title: item.title, notes: item.notes, tagIDs: item.tagIDs,
                bits: item.classifyBits, remindMinutes: item.remindMinutes,
                query: query, tagMap: tagMap
            ) else { return nil }

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

    private static func subtaskHits(
        _ query: BoardSearchQuery, _ todos: [TodoSnapshot], tagMap: [UUID: String], scope: BoardSearchScope
    ) -> [BoardSearchHit] {
        guard !query.hasPriority, query.remindMinutes == nil, !scope.filter.isHighPriorityOnly else { return [] }
        var parentFilter = scope.filter
        parentFilter.tagID = nil
        return todos.flatMap { todo -> [BoardSearchHit] in
            guard todo.deletedAt == nil,
                  Classification.matches(todo.classifyBits, filter: parentFilter, projectIDs: scope.projectIDs) else { return [] }
            return todo.subtasks.compactMap { subtask in
                guard subtask.deletedAt == nil else { return nil }
                if let id = scope.filter.tagID, !TagIDList.contains(subtask.tagIDs, id) { return nil }
                guard query.textKeywords.allSatisfy({ matches(subtask.title, needle: $0) }),
                      matchTags(tagNames: query.tagNames, attachedIDs: subtask.tagIDs, tagMap: tagMap) else { return nil }
                return BoardSearchHit(
                    id: subtask.id, kind: .subtask, title: "\(todo.title) › \(subtask.title)",
                    dayKey: todo.dayKey, createdAt: subtask.createdAt, parentID: todo.id
                )
            }
        }
    }
}
