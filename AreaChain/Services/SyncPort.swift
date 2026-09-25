import Foundation

enum SyncPort {
    static func makeSnapshot(
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        todos: [TodoItem],
        diaries: [DiaryEntry],
        tags: [TagItem] = [],
        attachments: [AttachmentItem] = [],
        exportedAt: Date = .now
    ) -> ExportSnapshot {
        let privateIDs = Set(diaries.filter { DiaryPrivacy.isSensitive($0.snapshot, tags: tags) }.map(\.id))
        return ExportSnapshot(
            exportedAt: exportedAt,
            routines: routines.map(exportedRoutine),
            checks: checks.compactMap(exportedCheck),
            todos: todos.map(exportedTodo),
            diaries: diaries.filter { !privateIDs.contains($0.id) }.map(exportedDiary),
            tags: tags.map(exportedTag),
            attachments: attachments.filter {
                $0.privacyVaultID == nil && !($0.ownerKind == AttachmentOwner.diary.rawValue && privateIDs.contains($0.ownerID))
            }.map(exportedAttachment)
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
            tagIDs: item.tagIDs,
            isImportant: item.isImportant,
            isUrgent: item.isUrgent,
            sourceBundleID: item.sourceBundleID,
            notes: item.notes,
            pausedOnDayKey: item.pausedOnDayKey
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
                    deletedAt: $0.deletedAt,
                    tagIDs: $0.tagIDs
                )
            }
        )
    }

    private static func exportedDiary(_ item: DiaryEntry) -> ExportedDiary {
        ExportedDiary(
            id: item.id,
            text: item.text,
            dayKey: item.dayKey,
            createdAt: item.createdAt,
            deletedAt: item.deletedAt,
            tagIDs: item.tagIDs,
            isPinned: item.isPinned
        )
    }

    private static func exportedTag(_ item: TagItem) -> ExportedTag {
        ExportedTag(
            id: item.id, name: item.name, sortOrder: item.sortOrder,
            deletedAt: item.deletedAt, colorToken: item.colorToken
        )
    }

    private static func exportedAttachment(_ item: AttachmentItem) -> ExportedAttachment {
        ExportedAttachment(
            id: item.id,
            ownerKind: item.ownerKind,
            ownerID: item.ownerID,
            filename: item.filename,
            createdAt: item.createdAt,
            deletedAt: item.deletedAt
        )
    }
}

