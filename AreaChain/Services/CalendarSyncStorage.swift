import Foundation
import SwiftData

enum CalendarSyncStorage {
    static let ledgerFilename = "areachain-calendar-sync.json"

    static func ledger(at root: URL = .applicationSupportDirectory) -> CalendarLedgerAccess {
        let url = root.appending(path: ledgerFilename)
        return CalendarLedgerAccess(load: {
            do {
                return try JSONDecoder().decode(CalendarSyncLedger.self, from: Data(contentsOf: url))
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
                return CalendarSyncLedger()
            }
        }, save: { ledger in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(ledger)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        })
    }

    @MainActor
    static func local(context: ModelContext, didSave: @escaping () -> Void = {}) -> CalendarLocalAccess {
        CalendarLocalAccess(load: {
            guard !context.hasChanges else { throw CalendarSyncError.invalidData }
            return try context.fetch(FetchDescriptor<TodoItem>()).map { todo in
                CalendarLocalItem(
                    id: todo.id,
                    state: CalendarLocalState(content: content(todo), isPublished: todo.deletedAt == nil && !todo.isDone),
                    eventID: todo.calendarEventID
                )
            }
        }, apply: { updates in
            try apply(updates, context: context)
        }, didSave: didSave)
    }

    private static func content(_ todo: TodoItem) -> CalendarContent {
        CalendarContent(title: todo.title, dayKey: todo.dayKey, remindMinutes: todo.remindMinutes)
    }

    private static func applyUpdate(
        _ update: CalendarLocalUpdate,
        todo: TodoItem
    ) throws -> Bool {
        if let incoming = update.content, incoming != content(todo) {
            guard todo.deletedAt == nil, !todo.isDone else { throw CalendarSyncError.conflict }
            try TodoCalendarFieldUpdate.apply(
                todo, title: incoming.title, dayKey: incoming.dayKey,
                remindMinutes: incoming.remindMinutes, eventID: update.eventID
            )
            return true
        }
        if todo.calendarEventID != update.eventID {
            try TodoCalendarFieldUpdate.apply(
                todo, title: todo.title, dayKey: todo.dayKey,
                remindMinutes: todo.remindMinutes, eventID: update.eventID
            )
            return true
        }
        return false
    }

    private static func apply(_ updates: [CalendarLocalUpdate], context: ModelContext) throws -> Bool {
        let tasks = try context.fetch(FetchDescriptor<TodoItem>())
        guard Set(tasks.map(\.id)).count == tasks.count, !context.hasChanges else { throw CalendarSyncError.invalidData }
        let byID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        var changed = false
        do {
            for update in updates {
                guard let todo = byID[update.id] else { throw CalendarSyncError.conflict }
                if try applyUpdate(update, todo: todo) {
                    changed = true
                }
            }
            if changed { try context.save() }
            return changed
        } catch {
            throw ModelRollback.failure(error, in: context)
        }
    }
}
