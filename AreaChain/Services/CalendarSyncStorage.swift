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

    private static func apply(_ updates: [CalendarLocalUpdate], context: ModelContext) throws -> Bool {
        let tasks = try context.fetch(FetchDescriptor<TodoItem>())
        guard Set(tasks.map(\.id)).count == tasks.count, !context.hasChanges else { throw CalendarSyncError.invalidData }
        let byID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        var changed = false
        do {
            for update in updates {
                guard let todo = byID[update.id] else { throw CalendarSyncError.conflict }
                if let incoming = update.content, incoming != content(todo) {
                    guard todo.deletedAt == nil, !todo.isDone,
                          !incoming.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          DayKey.date(from: incoming.dayKey) != nil else { throw CalendarSyncError.conflict }
                    todo.title = incoming.title
                    todo.dayKey = incoming.dayKey
                    todo.remindMinutes = incoming.remindMinutes
                    changed = true
                }
                if todo.calendarEventID != update.eventID {
                    todo.calendarEventID = update.eventID
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
