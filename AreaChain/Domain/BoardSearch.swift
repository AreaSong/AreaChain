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

enum BoardSearch {
    static func hits(
        query: String,
        todos: [TodoSnapshot],
        diaries: [DiarySnapshot],
        routines: [RoutineSnapshot],
        todayKey: String = DayKey.today()
    ) -> [BoardSearchHit] {
        let needle = normalized(query)
        guard !needle.isEmpty else { return [] }
        let found = todoHits(needle, todos) + diaryHits(needle, diaries) + routineHits(needle, routines, todayKey: todayKey)
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

    private static func todoHits(_ needle: String, _ todos: [TodoSnapshot]) -> [BoardSearchHit] {
        todos.compactMap { item in
            guard item.deletedAt == nil, matches(item.title, needle: needle) else { return nil }
            return BoardSearchHit(
                id: item.id,
                kind: .todo,
                title: item.title,
                dayKey: item.dayKey,
                createdAt: item.createdAt
            )
        }
    }

    private static func diaryHits(_ needle: String, _ diaries: [DiarySnapshot]) -> [BoardSearchHit] {
        diaries.compactMap { item in
            guard item.deletedAt == nil, matches(item.text, needle: needle) else { return nil }
            return BoardSearchHit(
                id: item.id,
                kind: .diary,
                title: item.text,
                dayKey: item.dayKey,
                createdAt: item.createdAt
            )
        }
    }

    private static func routineHits(_ needle: String, _ routines: [RoutineSnapshot], todayKey: String) -> [BoardSearchHit] {
        routines.compactMap { item in
            guard item.deletedAt == nil, item.isEnabled, matches(item.title, needle: needle) else { return nil }
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
