import Foundation
import SwiftData

enum SnapshotImportError: LocalizedError, Equatable {
    case duplicateID(kind: String, id: UUID)
    case subtaskOwnerConflict(UUID)
    case attachmentOwnerConflict(UUID)
    case missingRoutine(UUID)
    case checkConflict(routineID: UUID, dayKey: String)

    var errorDescription: String? { message(locale: .current) }

    func message(locale: Locale) -> String {
        switch self {
        case let .duplicateID(kind, id):
            return L10n.format("import.error.duplicate", locale: locale, kind, id.uuidString)
        case .subtaskOwnerConflict(let id):
            return L10n.format("import.error.subtask.owner", locale: locale, id.uuidString)
        case .attachmentOwnerConflict(let id):
            return L10n.format("import.error.attachment.owner", locale: locale, id.uuidString)
        case .missingRoutine(let id):
            return L10n.format("import.error.routine.missing", locale: locale, id.uuidString)
        case let .checkConflict(routineID, dayKey):
            return L10n.format("import.error.check.conflict", locale: locale, routineID.uuidString, dayKey)
        }
    }
}

/// 预览和写入共用同一份结构校验，避免预览去重掩盖真正的数据库冲突。
struct SnapshotImportState {
    let routines: [DailyRoutine]
    let checks: [RoutineCheck]
    let todos: [TodoItem]
    let subtasks: [SubtaskItem]
    let diaries: [DiaryEntry]
    let projects: [ProjectItem]
    let tags: [TagItem]
    let attachments: [AttachmentItem]

    init(context: ModelContext) throws {
        routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        checks = try context.fetch(FetchDescriptor<RoutineCheck>())
        todos = try context.fetch(FetchDescriptor<TodoItem>())
        subtasks = try context.fetch(FetchDescriptor<SubtaskItem>())
        diaries = try context.fetch(FetchDescriptor<DiaryEntry>())
        projects = try context.fetch(FetchDescriptor<ProjectItem>())
        tags = try context.fetch(FetchDescriptor<TagItem>())
        attachments = try context.fetch(FetchDescriptor<AttachmentItem>())
    }

    func validate(_ snapshot: ExportSnapshot) throws {
        let groups: [(String, [UUID], [UUID])] = [
            ("DailyRoutine", routines.map(\.id), snapshot.routines.map(\.id)),
            ("RoutineCheck", checks.map(\.id), snapshot.checks.map(\.id)),
            ("TodoItem", todos.map(\.id), snapshot.todos.map(\.id)),
            ("SubtaskItem", subtasks.map(\.id), snapshot.todos.flatMap { $0.subtasks.map(\.id) }),
            ("DiaryEntry", diaries.map(\.id), snapshot.diaries.map(\.id)),
            ("ProjectItem", projects.map(\.id), snapshot.projects.map(\.id)),
            ("TagItem", tags.map(\.id), snapshot.tags.map(\.id)),
            ("AttachmentItem", attachments.map(\.id), snapshot.attachments.map(\.id))
        ]
        for (kind, existing, incoming) in groups {
            try Self.requireUnique(existing, kind: kind)
            try Self.requireUnique(incoming, kind: kind)
        }
        try validateSubtasks(snapshot.todos)
        try validateAttachments(snapshot.attachments)
        try validateChecks(snapshot)
    }

    private static func requireUnique(_ ids: [UUID], kind: String) throws {
        var seen: Set<UUID> = []
        for id in ids where !seen.insert(id).inserted {
            throw SnapshotImportError.duplicateID(kind: kind, id: id)
        }
    }

    private func validateSubtasks(_ incoming: [ExportedTodo]) throws {
        for todo in todos {
            try Self.requireUnique(todo.subtasks.map(\.id), kind: "SubtaskItem")
        }
        let byID = Dictionary(uniqueKeysWithValues: subtasks.map { ($0.id, $0) })
        for todo in incoming {
            for subtask in todo.subtasks {
                if let existing = byID[subtask.id], existing.todo?.id != todo.id {
                    throw SnapshotImportError.subtaskOwnerConflict(subtask.id)
                }
            }
        }
    }

    private struct CheckKey: Hashable {
        let routineID: UUID
        let dayKey: String
    }

    private func validateAttachments(_ incoming: [ExportedAttachment]) throws {
        let byID = Dictionary(uniqueKeysWithValues: attachments.map { ($0.id, $0) })
        for item in incoming {
            if let existing = byID[item.id],
               existing.ownerID != item.ownerID || existing.ownerKind != item.ownerKind {
                throw SnapshotImportError.attachmentOwnerConflict(item.id)
            }
        }
    }

    private func validateChecks(_ snapshot: ExportSnapshot) throws {
        let routineIDs = Set(routines.map(\.id)).union(snapshot.routines.map(\.id))
        var finalKeys: [UUID: CheckKey] = [:]
        for check in checks {
            if let routineID = check.routine?.id {
                finalKeys[check.id] = CheckKey(routineID: routineID, dayKey: check.dayKey)
            }
        }
        // 先按 UUID 应用全部更新，再检查业务键；合法移日或交换日期不应被误拒绝。
        for check in snapshot.checks {
            guard routineIDs.contains(check.routineId) else {
                throw SnapshotImportError.missingRoutine(check.routineId)
            }
            finalKeys[check.id] = CheckKey(routineID: check.routineId, dayKey: check.dayKey)
        }
        var seen: Set<CheckKey> = []
        for key in finalKeys.values where !seen.insert(key).inserted {
            throw SnapshotImportError.checkConflict(routineID: key.routineID, dayKey: key.dayKey)
        }
    }
}
