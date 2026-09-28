import Foundation
@testable import AreaChain

/// 冻结 PHASE-3D 之前的逐条打卡查找与按习惯重建逾期索引，只给等价测试对照，不是产品入口。
enum CatalogSearchOracle {
    static func matchingListedRoutines(
        _ items: [DailyRoutine],
        checks: [RoutineCheck],
        tag: TagItem?,
        dayKey: String,
        open: Bool
    ) -> [DailyRoutine] {
        let snaps = checks.compactMap(\.snapshot)
        return Catalog.matchingRoutines(items, tag: tag).filter {
            let done = DayBoardLogic.isRoutineDone($0.snapshot, checks: snaps, on: dayKey)
            return open ? !done : done
        }
    }

    static func matchingOpenRoutines(
        _ items: [DailyRoutine],
        checks: [RoutineCheck],
        tag: TagItem?,
        dayKey: String
    ) -> [DailyRoutine] {
        matchingListedRoutines(items, checks: checks, tag: tag, dayKey: dayKey, open: true).filter {
            DayBoardLogic.isRoutineDue($0.snapshot, on: dayKey)
        }
    }

    static func openCount(
        todos: [TodoItem],
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        tag: TagItem?,
        dayKey: String
    ) -> Int {
        let openTodos = Catalog.matchingTodos(todos, tag: tag).filter { !$0.isDone }.count
        let openRoutines = matchingListedRoutines(
            routines, checks: checks, tag: tag, dayKey: dayKey, open: true
        ).count
        let openSubtasks = Catalog.matchingSubtasks(todos, tag: tag).filter { !$0.isDone }.count
        return openTodos + openRoutines + openSubtasks
    }

    static func hits(
        query: String,
        todos: [TodoSnapshot],
        diaries: [DiarySnapshot],
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot] = [],
        todayKey: String = DayKey.today(),
        tagMap: [UUID: String] = [:],
        privacy: BoardSearchPrivacy = BoardSearchPrivacy(),
        scope: BoardSearchScope = BoardSearchScope(),
        calendar: Calendar = .current
    ) -> [BoardSearchHit] {
        let parsed = BoardSearch.parseQuery(query)
        guard !parsed.isEmpty else { return [] }

        let routineDays = routineDisplayDays(
            routines, checks: checks, todayKey: todayKey, filter: scope.filter, calendar: calendar
        )
        let filteredTodos = todos.filter { matchesTodoScope($0, todayKey: todayKey, filter: scope.filter) }
        let filteredRoutines = routines.filter { routineDays[$0.id] != nil }
        let found = todoHits(parsed, filteredTodos, tagMap: tagMap)
            + diaryHits(parsed, BoardSearch.filteredDiaries(diaries, filter: scope.filter), tagMap: tagMap, privacy: privacy)
            + routineHits(parsed, filteredRoutines, dayKeys: routineDays, tagMap: tagMap)
            + subtaskHits(parsed, todos, todayKey: todayKey, tagMap: tagMap, scope: scope)

        return found.sorted {
            if $0.dayKey != $1.dayKey { return $0.dayKey > $1.dayKey }
            return $0.createdAt > $1.createdAt
        }
    }

    private static func routineDisplayDays(
        _ routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todayKey: String,
        filter: BoardFilter,
        calendar: Calendar
    ) -> [UUID: String] {
        var days: [UUID: String] = [:]
        for routine in routines {
            guard let day = routineDisplayDay(
                routine, checks: checks, todayKey: todayKey, filter: filter, calendar: calendar
            ) else { continue }
            days[routine.id] = day
        }
        return days
    }

    private static func routineDisplayDay(
        _ item: RoutineSnapshot,
        checks: [CheckSnapshot],
        todayKey: String,
        filter: BoardFilter,
        calendar: Calendar
    ) -> String? {
        guard item.deletedAt == nil, item.isEnabled else { return nil }
        guard Classification.matches(item.classifyBits, filter: filter),
              Classification.matchesReminder(item.remindMinutes, scope: filter.reminderScope) else { return nil }
        if filter.dateScope == .overdue {
            return AgendaProjection.overdueRoutines(
                routines: [item], checks: checks, todayKey: todayKey, calendar: calendar
            ).first?.displayDayKey
        }
        let fromKey = item.createdDayKey > todayKey ? item.createdDayKey : todayKey
        let scheduled = WeekdayMask.nextScheduledDayKey(
            mask: item.weekdayMask, from: fromKey, calendar: calendar
        )
        guard filter.dateScope == .all || Classification.matchesDate(
            dayKey: scheduled, isDone: false, todayKey: todayKey, scope: filter.dateScope
        ) else { return nil }
        return scheduled
    }

    private static func matchesTodoScope(_ item: TodoSnapshot, todayKey: String, filter: BoardFilter) -> Bool {
        Classification.matchesListedTodo(
            item.classifyBits, dayKey: item.dayKey, isDone: item.isDone, todayKey: todayKey, filter: filter
        ) && Classification.matchesReminder(item.remindMinutes, scope: filter.reminderScope)
    }

    private static func matchesOwnTags(_ tagIDs: String, filter: BoardFilter) -> Bool {
        Classification.matches(ClassifyBits(tagIDs: tagIDs), filter: BoardFilter(tagID: filter.tagID))
    }

    private static func matchTags(tagNames: [String], attachedIDs: String, tagMap: [UUID: String]) -> Bool {
        guard !tagNames.isEmpty else { return true }
        let attached = Set(TagIDList.parse(attachedIDs).compactMap { tagMap[$0] }.map(TagSyntax.normalizedName))
        return tagNames.allSatisfy { attached.contains(TagSyntax.normalizedName($0)) }
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
                BoardSearch.matches(title, needle: keyword) || BoardSearch.matches(notes, needle: keyword)
            }
            guard matchesAll else { return false }
        }
        if let priority = query.priority {
            guard bits.isImportant == priority.isImportant, bits.isUrgent == priority.isUrgent else { return false }
        }
        if let minutes = query.remindMinutes, remindMinutes != minutes { return false }
        return matchTags(tagNames: query.tagNames, attachedIDs: tagIDs, tagMap: tagMap)
    }

    private static func todoHits(
        _ query: BoardSearchQuery, _ todos: [TodoSnapshot], tagMap: [UUID: String]
    ) -> [BoardSearchHit] {
        todos.compactMap { item in
            guard item.deletedAt == nil else { return nil }
            guard matchesRecord(
                title: item.title, notes: item.notes, tagIDs: item.tagIDs,
                bits: item.classifyBits, remindMinutes: item.remindMinutes,
                query: query, tagMap: tagMap
            ) else { return nil }
            return BoardSearchHit(
                id: item.id, kind: .todo, title: item.title, dayKey: item.dayKey, createdAt: item.createdAt
            )
        }
    }

    private static func diaryHits(
        _ query: BoardSearchQuery,
        _ diaries: [DiarySnapshot],
        tagMap: [UUID: String],
        privacy: BoardSearchPrivacy
    ) -> [BoardSearchHit] {
        diaries.compactMap { item in
            guard BoardSearch.matchesDiary(item, query: query, tagMap: tagMap) else { return nil }
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
        dayKeys: [UUID: String],
        tagMap: [UUID: String]
    ) -> [BoardSearchHit] {
        routines.compactMap { item in
            guard let dayKey = dayKeys[item.id] else { return nil }
            guard matchesRecord(
                title: item.title, notes: item.notes, tagIDs: item.tagIDs,
                bits: item.classifyBits, remindMinutes: item.remindMinutes,
                query: query, tagMap: tagMap
            ) else { return nil }
            return BoardSearchHit(
                id: item.id, kind: .routine, title: item.title, dayKey: dayKey, createdAt: item.createdAt
            )
        }
    }

    private static func subtaskHits(
        _ query: BoardSearchQuery,
        _ todos: [TodoSnapshot],
        todayKey: String,
        tagMap: [UUID: String],
        scope: BoardSearchScope
    ) -> [BoardSearchHit] {
        guard !query.hasPriority, query.remindMinutes == nil, !scope.filter.isHighPriorityOnly else { return [] }
        var parentFilter = scope.filter
        parentFilter.tagID = nil
        return todos.flatMap { todo -> [BoardSearchHit] in
            guard todo.deletedAt == nil,
                  matchesTodoScope(todo, todayKey: todayKey, filter: parentFilter) else { return [] }
            return todo.subtasks.compactMap { subtask in
                guard subtask.deletedAt == nil, matchesOwnTags(subtask.tagIDs, filter: scope.filter) else { return nil }
                guard query.textKeywords.allSatisfy({ BoardSearch.matches(subtask.title, needle: $0) }),
                      matchTags(tagNames: query.tagNames, attachedIDs: subtask.tagIDs, tagMap: tagMap) else { return nil }
                return BoardSearchHit(
                    id: subtask.id, kind: .subtask, title: "\(todo.title) › \(subtask.title)",
                    dayKey: todo.dayKey, createdAt: subtask.createdAt, parentID: todo.id
                )
            }
        }
    }
}
