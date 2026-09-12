import Foundation
@testable import AreaChain

@MainActor
final class FakeCalendarClient: CalendarEventClient {
    var remote: [String: CalendarRemoteItem] = [:]
    var granted = true
    var failApply = false
    var authorizationStep: (() -> Void)?
    var holdAuthorization = false
    var pendingAuthorization: CheckedContinuation<Bool, Never>?
    var didApply: (() -> Void)?
    var authorizationCount = 0
    var calendarCount = 0
    var batchCount = 0
    var createCount = 0
    var lookupCount = 0
    var lastWindows: [DateInterval] = []
    var normalize: (CalendarContent) -> CalendarContent = { $0 }

    func authorize() async -> Bool {
        authorizationCount += 1
        authorizationStep?()
        if holdAuthorization {
            return await withCheckedContinuation { pendingAuthorization = $0 }
        }
        return granted
    }

    func calendarID(preferred: String?) throws -> String {
        calendarCount += 1
        return "owned"
    }

    func events(in calendarID: String, windows: [DateInterval]) throws -> [CalendarRemoteItem] {
        lastWindows = windows
        return windows.flatMap { window in
            remote.values.filter {
                $0.calendarID == calendarID && DayKey.date(from: $0.content.dayKey).map(window.contains) == true
            }
        }
    }

    func event(id: String) throws -> CalendarRemoteItem? {
        lookupCount += 1
        return remote[id]
    }

    func apply(_ mutations: [CalendarEventMutation], in calendarID: String) throws -> [UUID: CalendarRemoteItem] {
        batchCount += 1
        if failApply { throw CalendarSyncError.unavailable }
        var pending = remote
        var result: [UUID: CalendarRemoteItem] = [:]
        for mutation in mutations {
            switch mutation {
            case let .upsert(id, content, expected):
                if let expected {
                    guard expected.calendarID == calendarID, remote[expected.id] == expected else { throw CalendarSyncError.conflict }
                } else {
                    createCount += 1
                }
                let event = CalendarRemoteItem(
                    id: expected?.id ?? "created-\(createCount)", calendarID: calendarID, todoID: id, content: normalize(content)
                )
                pending[event.id] = event
                result[id] = event
            case .remove(let expected):
                guard expected.calendarID == calendarID, remote[expected.id] == expected else { throw CalendarSyncError.conflict }
                pending.removeValue(forKey: expected.id)
            }
        }
        remote = pending
        didApply?()
        return result
    }
}

@MainActor
final class CalendarSyncFixture {
    let client = FakeCalendarClient()
    var tasks: [CalendarLocalItem] = []
    var checkpoint = CalendarSyncLedger()
    var healthy = true
    var failLoad = false
    var failLocalSave = false
    var failLedgerLoad = false
    var failLedgerSave = false
    var ledgerSaveCount = 0
    var localSaveCount = 0
    var didSaveCount = 0
    var calendar = Calendar.current

    var engine: CalendarSyncEngine {
        CalendarSyncEngine(client: client, local: CalendarLocalAccess(load: {
            if self.failLoad { throw CalendarSyncError.invalidData }
            return self.tasks
        }, apply: { updates in
            if self.failLocalSave { throw CalendarSyncError.invalidData }
            self.localSaveCount += 1
            for update in updates {
                guard let index = self.tasks.firstIndex(where: { $0.id == update.id }) else { throw CalendarSyncError.invalidData }
                if let content = update.content { self.tasks[index].state.content = content }
                self.tasks[index].eventID = update.eventID
            }
            return !updates.isEmpty
        }, didSave: { self.didSaveCount += 1 }), ledger: CalendarLedgerAccess(load: {
            if self.failLedgerLoad { throw CalendarSyncError.invalidLedger }
            return self.checkpoint
        }, save: {
            if self.failLedgerSave { throw CalendarSyncError.invalidLedger }
            self.ledgerSaveCount += 1
            self.checkpoint = $0
        }), isHealthy: { self.healthy }, clock: CalendarSyncClock(now: { DayKey.date(from: "2026-09-11")! }, calendar: calendar))
    }

    @discardableResult
    func seedBound() -> UUID {
        let id = UUID()
        let content = CalendarContent(title: "原内容", dayKey: "2026-09-11", remindMinutes: 600)
        let task = CalendarLocalItem(id: id, state: CalendarLocalState(content: content, isPublished: true), eventID: "event")
        tasks = [task]
        client.remote["event"] = CalendarRemoteItem(id: "event", calendarID: "owned", todoID: id, content: content)
        checkpoint.calendarID = "owned"
        checkpoint.records[id.uuidString] = CalendarSyncRecord(local: task.state, remote: content, eventID: "event")
        return id
    }
}
