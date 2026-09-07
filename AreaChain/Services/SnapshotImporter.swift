import Foundation
import SwiftData

enum SnapshotImporter {
    static func apply(_ snapshot: ExportSnapshot, context: ModelContext) throws {
        let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        let checks = try context.fetch(FetchDescriptor<RoutineCheck>())
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let diaries = try context.fetch(FetchDescriptor<DiaryEntry>())
        upsert(routines: snapshot.routines, existing: routines, context: context)
        upsert(todos: snapshot.todos, existing: todos, context: context)
        upsert(diaries: snapshot.diaries, existing: diaries, context: context)
        upsert(checks: snapshot.checks, existing: checks, routines: try context.fetch(FetchDescriptor<DailyRoutine>()), context: context)
        try context.save()
    }

    private static func upsert(
        routines: [ExportedRoutine],
        existing: [DailyRoutine],
        context: ModelContext
    ) {
        let map = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for item in routines {
            if let found = map[item.id] {
                found.title = item.title
                found.sortOrder = item.sortOrder
                found.isEnabled = item.isEnabled
                found.createdDayKey = item.createdDayKey
                found.weekdaysOnly = item.weekdaysOnly
                if let createdAt = item.createdAt {
                    found.createdAt = createdAt
                }
                found.remindMinutes = RemindMinutes.clamped(item.remindMinutes)
            } else {
                context.insert(
                    DailyRoutine(
                        id: item.id,
                        title: item.title,
                        sortOrder: item.sortOrder,
                        isEnabled: item.isEnabled,
                        createdDayKey: item.createdDayKey,
                        weekdaysOnly: item.weekdaysOnly,
                        createdAt: item.createdAt ?? .now,
                        remindMinutes: item.remindMinutes
                    )
                )
            }
        }
    }

    private static func upsert(todos: [ExportedTodo], existing: [TodoItem], context: ModelContext) {
        let map = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for item in todos {
            if let found = map[item.id] {
                found.title = item.title
                found.isDone = item.isDone
                found.dayKey = item.dayKey
                found.createdAt = item.createdAt
                found.remindMinutes = RemindMinutes.clamped(item.remindMinutes)
            } else {
                context.insert(
                    TodoItem(
                        id: item.id,
                        title: item.title,
                        isDone: item.isDone,
                        dayKey: item.dayKey,
                        createdAt: item.createdAt,
                        remindMinutes: item.remindMinutes
                    )
                )
            }
        }
    }

    private static func upsert(diaries: [ExportedDiary], existing: [DiaryEntry], context: ModelContext) {
        let map = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for item in diaries {
            if let found = map[item.id] {
                found.text = item.text
                found.dayKey = item.dayKey
                found.createdAt = item.createdAt
            } else {
                context.insert(
                    DiaryEntry(
                        id: item.id,
                        text: item.text,
                        dayKey: item.dayKey,
                        createdAt: item.createdAt
                    )
                )
            }
        }
    }

    private static func upsert(
        checks: [ExportedCheck],
        existing: [RoutineCheck],
        routines: [DailyRoutine],
        context: ModelContext
    ) {
        let map = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let routinesByID = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
        for item in checks {
            let routine = routinesByID[item.routineId]
            if let found = map[item.id] {
                found.dayKey = item.dayKey
                found.isDone = item.isDone
                found.isSkipped = item.isSkipped
                found.routine = routine
            } else {
                context.insert(
                    RoutineCheck(
                        id: item.id,
                        dayKey: item.dayKey,
                        isDone: item.isDone,
                        isSkipped: item.isSkipped,
                        routine: routine
                    )
                )
            }
        }
    }
}
