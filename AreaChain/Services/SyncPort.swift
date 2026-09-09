import Foundation

enum SyncPort {
    static func makeSnapshot(
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        todos: [TodoItem],
        diaries: [DiaryEntry],
        projects: [ProjectItem] = [],
        tags: [TagItem] = [],
        attachments: [AttachmentItem] = [],
        exportedAt: Date = .now
    ) -> ExportSnapshot {
        ExportSnapshot(
            exportedAt: exportedAt,
            routines: routines.map(exportedRoutine),
            checks: checks.compactMap(exportedCheck),
            todos: todos.map(exportedTodo),
            diaries: diaries.map {
                ExportedDiary(
                    id: $0.id,
                    text: $0.text,
                    dayKey: $0.dayKey,
                    createdAt: $0.createdAt,
                    deletedAt: $0.deletedAt,
                    tagIDs: $0.tagIDs,
                    isPinned: $0.isPinned
                )
            },
            projects: projects.map {
                ExportedProject(
                    id: $0.id,
                    name: $0.name,
                    sortOrder: $0.sortOrder,
                    parentID: $0.parentID,
                    deletedAt: $0.deletedAt
                )
            },
            tags: tags.map {
                ExportedTag(id: $0.id, name: $0.name, sortOrder: $0.sortOrder, deletedAt: $0.deletedAt)
            },
            attachments: attachments.map {
                ExportedAttachment(
                    id: $0.id,
                    ownerKind: $0.ownerKind,
                    ownerID: $0.ownerID,
                    filename: $0.filename,
                    createdAt: $0.createdAt,
                    deletedAt: $0.deletedAt
                )
            }
        )
    }

    static func encode(_ snapshot: ExportSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = ExportDates.encodeStrategy()
        return try encoder.encode(snapshot)
    }

    static func decode(_ data: Data) throws -> ExportSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ExportDates.decodeStrategy()
        return try decoder.decode(ExportSnapshot.self, from: data)
    }

    private static func exportedRoutine(_ item: DailyRoutine) -> ExportedRoutine {
        let mask = item.resolvedWeekdayMask
        return ExportedRoutine(
            id: item.id,
            title: item.title,
            sortOrder: item.sortOrder,
            isEnabled: item.isEnabled,
            createdDayKey: item.createdDayKey,
            weekdaysOnly: WeekdayMask.isWorkdays(mask),
            weekdayMask: mask,
            createdAt: item.createdAt,
            remindMinutes: item.remindMinutes,
            deletedAt: item.deletedAt,
            projectID: item.projectID,
            tagIDs: item.tagIDs,
            isImportant: item.isImportant,
            isUrgent: item.isUrgent,
            sourceBundleID: item.sourceBundleID,
            notes: item.notes
        )
    }

    private static func exportedCheck(_ check: RoutineCheck) -> ExportedCheck? {
        guard let routineId = check.routine?.id else { return nil }
        return ExportedCheck(
            id: check.id,
            routineId: routineId,
            dayKey: check.dayKey,
            isDone: check.isDone,
            isSkipped: check.isSkipped
        )
    }

    private static func exportedTodo(_ item: TodoItem) -> ExportedTodo {
        ExportedTodo(
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
            notes: item.notes,
            subtasks: item.subtasks.map {
                ExportedSubtask(
                    id: $0.id,
                    title: $0.title,
                    isDone: $0.isDone,
                    sortOrder: $0.sortOrder,
                    createdAt: $0.createdAt,
                    deletedAt: $0.deletedAt
                )
            }
        )
    }
}
