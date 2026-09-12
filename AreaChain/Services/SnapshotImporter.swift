import Foundation
import SwiftData

enum SnapshotImporter {
    static func validate(_ snapshot: ExportSnapshot, context: ModelContext) throws {
        try SnapshotImportState(context: context).validate(snapshot)
    }

    static func apply(
        _ snapshot: ExportSnapshot,
        context: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        let existing = try SnapshotImportState(context: context)
        try existing.validate(snapshot)
        // 先落盘调用前已有的编辑；失败回滚只能撤销导入，不能丢掉用户此前的修改。
        if context.hasChanges { try context.save() }
        do {
            upsert(routines: snapshot.routines, existing: existing.routines, context: context)
            upsert(todos: snapshot.todos, existing: existing.todos, context: context)
            upsert(diaries: snapshot.diaries, existing: existing.diaries, context: context)
            upsert(projects: snapshot.projects, existing: existing.projects, context: context)
            upsert(tags: snapshot.tags, existing: existing.tags, context: context)
            upsert(attachments: snapshot.attachments, existing: existing.attachments, context: context)
            upsert(
                checks: snapshot.checks,
                existing: existing.checks,
                routines: try context.fetch(FetchDescriptor<DailyRoutine>()),
                context: context
            )
            try save(context)
        } catch {
            throw ModelRollback.failure(error, in: context)
        }
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
                found.setWeekdayMask(item.weekdayMask)
                if let createdAt = item.createdAt {
                    found.createdAt = createdAt
                }
                found.remindMinutes = RemindMinutes.clamped(item.remindMinutes)
                found.deletedAt = item.deletedAt
                found.notes = item.notes
                found.pausedOnDayKey = item.pausedOnDayKey
                applyClassify(item, to: found)
            } else {
                context.insert(
                    DailyRoutine(
                        id: item.id,
                        title: item.title,
                        sortOrder: item.sortOrder,
                        isEnabled: item.isEnabled,
                        createdDayKey: item.createdDayKey,
                        weekdaysOnly: item.weekdaysOnly,
                        weekdayMask: item.weekdayMask,
                        createdAt: item.createdAt ?? .now,
                        remindMinutes: item.remindMinutes,
                        deletedAt: item.deletedAt,
                        projectID: item.projectID,
                        tagIDs: item.tagIDs,
                        isImportant: item.isImportant,
                        isUrgent: item.isUrgent,
                        sourceBundleID: item.sourceBundleID,
                        notes: item.notes,
                        pausedOnDayKey: item.pausedOnDayKey
                    )
                )
            }
        }
    }

    private static func applyClassify(_ item: ExportedRoutine, to found: DailyRoutine) {
        found.projectID = item.projectID
        found.tagIDs = item.tagIDs
        found.isImportant = item.isImportant
        found.isUrgent = item.isUrgent
        found.sourceBundleID = item.sourceBundleID
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
                found.deletedAt = item.deletedAt
                found.projectID = item.projectID
                found.tagIDs = item.tagIDs
                found.isImportant = item.isImportant
                found.isUrgent = item.isUrgent
                found.sourceBundleID = item.sourceBundleID
                found.calendarEventID = item.calendarEventID
                found.notes = item.notes
                upsertSubtasks(item.subtasks, for: found, context: context)
            } else {
                let newTodo = TodoItem(
                    id: item.id,
                    title: item.title,
                    isDone: item.isDone,
                    dayKey: item.dayKey,
                    createdAt: item.createdAt,
                    remindMinutes: item.remindMinutes,
                    deletedAt: item.deletedAt,
                    projectID: item.projectID,
                    tagIDs: item.tagIDs,
                    isImportant: item.isImportant,
                    isUrgent: item.isUrgent,
                    sourceBundleID: item.sourceBundleID,
                    calendarEventID: item.calendarEventID,
                    notes: item.notes
                )
                context.insert(newTodo)
                upsertSubtasks(item.subtasks, for: newTodo, context: context)
            }
        }
    }

    private static func upsertSubtasks(_ subtasks: [ExportedSubtask], for todo: TodoItem, context: ModelContext) {
        let map = Dictionary(uniqueKeysWithValues: todo.subtasks.map { ($0.id, $0) })
        for item in subtasks {
            if let found = map[item.id] {
                found.title = item.title
                found.isDone = item.isDone
                found.sortOrder = item.sortOrder
                found.deletedAt = item.deletedAt
                if let createdAt = item.createdAt {
                    found.createdAt = createdAt
                }
            } else {
                let sub = SubtaskItem(
                    id: item.id,
                    title: item.title,
                    isDone: item.isDone,
                    sortOrder: item.sortOrder,
                    createdAt: item.createdAt ?? .now,
                    deletedAt: item.deletedAt,
                    todo: todo
                )
                context.insert(sub)
                todo.subtasks.append(sub)
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
                found.deletedAt = item.deletedAt
                found.tagIDs = item.tagIDs
                found.isPinned = item.isPinned
            } else {
                context.insert(
                    DiaryEntry(
                        id: item.id,
                        text: item.text,
                        dayKey: item.dayKey,
                        createdAt: item.createdAt,
                        deletedAt: item.deletedAt,
                        tagIDs: item.tagIDs,
                        isPinned: item.isPinned
                    )
                )
            }
        }
    }

    private static func upsert(projects: [ExportedProject], existing: [ProjectItem], context: ModelContext) {
        let map = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for item in projects {
            if let found = map[item.id] {
                found.name = item.name
                found.sortOrder = item.sortOrder
                found.parentID = item.parentID
                found.deletedAt = item.deletedAt
            } else {
                context.insert(
                    ProjectItem(
                        id: item.id,
                        name: item.name,
                        sortOrder: item.sortOrder,
                        parentID: item.parentID,
                        deletedAt: item.deletedAt
                    )
                )
            }
        }
    }

    private static func upsert(tags: [ExportedTag], existing: [TagItem], context: ModelContext) {
        let map = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for item in tags {
            if let found = map[item.id] {
                found.name = item.name
                found.sortOrder = item.sortOrder
                found.deletedAt = item.deletedAt
            } else {
                context.insert(
                    TagItem(id: item.id, name: item.name, sortOrder: item.sortOrder, deletedAt: item.deletedAt)
                )
            }
        }
    }

    private static func upsert(
        attachments: [ExportedAttachment],
        existing: [AttachmentItem],
        context: ModelContext
    ) {
        let map = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for item in attachments {
            if let found = map[item.id] {
                found.ownerKind = item.ownerKind
                found.ownerID = item.ownerID
                found.filename = item.filename
                found.createdAt = item.createdAt
                found.deletedAt = item.deletedAt
            } else {
                context.insert(
                    AttachmentItem(
                        id: item.id,
                        ownerKind: item.ownerKind,
                        ownerID: item.ownerID,
                        filename: item.filename,
                        createdAt: item.createdAt,
                        deletedAt: item.deletedAt
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
