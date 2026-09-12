import Foundation

enum CalendarEventMutation {
    case upsert(todoID: UUID, content: CalendarContent, expected: CalendarRemoteItem?)
    case remove(expected: CalendarRemoteItem)
}

@MainActor
protocol CalendarEventClient: AnyObject {
    func authorize() async -> Bool
    func calendarID(preferred: String?) throws -> String
    func events(in calendarID: String, windows: [DateInterval]) throws -> [CalendarRemoteItem]
    func event(id: String) throws -> CalendarRemoteItem?
    func apply(_ mutations: [CalendarEventMutation], in calendarID: String) throws -> [UUID: CalendarRemoteItem]
}

struct CalendarLocalUpdate {
    var id: UUID
    var content: CalendarContent? = nil
    var eventID: String
}

struct CalendarLocalAccess {
    var load: () throws -> [CalendarLocalItem]
    var apply: ([CalendarLocalUpdate]) throws -> Bool
    var didSave: () -> Void = {}
}

struct CalendarLedgerAccess {
    var load: () throws -> CalendarSyncLedger
    var save: (CalendarSyncLedger) throws -> Void
}

struct CalendarSyncOutcome {
    var phase: CalendarSyncPhase
    var conflicts: Set<UUID> = []
}

@MainActor
final class CalendarSyncEngine {
    private let client: any CalendarEventClient
    private let local: CalendarLocalAccess
    private let ledger: CalendarLedgerAccess
    private let isHealthy: () -> Bool
    private let now: () -> Date

    init(
        client: any CalendarEventClient, local: CalendarLocalAccess, ledger: CalendarLedgerAccess,
        isHealthy: @escaping () -> Bool, now: @escaping () -> Date = { .now }
    ) {
        self.client = client
        self.local = local
        self.ledger = ledger
        self.isHealthy = isHealthy
        self.now = now
    }

    func synchronize(isCurrent: () -> Bool) async -> CalendarSyncOutcome {
        guard isCurrent() else { return CalendarSyncOutcome(phase: .off) }
        guard isHealthy() else { return CalendarSyncOutcome(phase: .localUnavailable) }
        do {
            let previous = try ledger.load()
            guard previous.version == 1 else { throw CalendarSyncError.invalidLedger }
            guard await client.authorize() else { return CalendarSyncOutcome(phase: isCurrent() ? .denied : .off) }
            guard isCurrent(), !Task.isCancelled else { return CalendarSyncOutcome(phase: .off) }
            guard isHealthy() else { return CalendarSyncOutcome(phase: .localUnavailable) }
            // 授权等待期间用户可能编辑待办；必须在 await 之后读取实际已保存状态。
            let tasks = try local.load()
            guard Set(tasks.map(\.id)).count == tasks.count else { throw CalendarSyncError.invalidData }
            let calendarID = try client.calendarID(preferred: previous.calendarID)
            let events = try loadEvents(tasks: tasks, previous: previous, calendarID: calendarID)
            let steps = try CalendarReconciliation.plan(tasks: tasks, events: events, ledger: previous, calendarID: calendarID)
            guard isCurrent(), isHealthy(), !Task.isCancelled else { return CalendarSyncOutcome(phase: .off) }
            return try execute(steps, previous: previous, calendarID: calendarID)
        } catch CalendarSyncError.unavailable {
            return CalendarSyncOutcome(phase: .unavailable)
        } catch CalendarSyncError.conflict {
            return CalendarSyncOutcome(phase: .conflict)
        } catch {
            return CalendarSyncOutcome(phase: .failed)
        }
    }

    private func loadEvents(
        tasks: [CalendarLocalItem], previous: CalendarSyncLedger, calendarID: String
    ) throws -> [CalendarRemoteItem] {
        let keys = tasks.map { $0.state.content.dayKey } + previous.records.values.compactMap { $0.remote?.dayKey }
        let windows = CalendarEventPolicy.eventQueryWindows(now: now(), dayKeys: keys)
        var events = try client.events(in: calendarID, windows: windows)
        let known = Set(tasks.map(\.eventID) + previous.records.values.compactMap(\.eventID)).subtracting([""])
        let fetchedIDs = Set(events.map(\.id))
        for id in known where !fetchedIDs.contains(id) {
            // 远端改期可越过查询窗口，不能因此认定它被删除。
            if let event = try client.event(id: id) { events.append(event) }
        }
        var byID: [String: CalendarRemoteItem] = [:]
        for event in events {
            if let old = byID[event.id], old != event { throw CalendarSyncError.conflict }
            byID[event.id] = event
        }
        return Array(byID.values)
    }

    private func execute(
        _ steps: [CalendarSyncStep], previous: CalendarSyncLedger, calendarID: String
    ) throws -> CalendarSyncOutcome {
        let mutations = steps.compactMap(mutation)
        let written = mutations.isEmpty ? [:] : try client.apply(mutations, in: calendarID)
        var next = previous
        next.calendarID = calendarID
        var updates: [CalendarLocalUpdate] = []
        for step in steps where step.action != .conflict {
            let result = try result(for: step, written: written, previous: previous, calendarID: calendarID)
            if let record = result.record { next.records[step.local.id.uuidString] = record }
            if let update = result.update { updates.append(update) }
        }
        if !updates.isEmpty, try local.apply(updates) { local.didSave() }
        // 不承诺跨 EventKit / SwiftData / 文件的原子回滚：部分提交失败时保留旧基线供重试。
        if next != previous { try ledger.save(next) }
        let conflicts = Set(steps.filter { $0.action == .conflict }.map { $0.local.id })
        return CalendarSyncOutcome(phase: conflicts.isEmpty ? .synced : .conflict, conflicts: conflicts)
    }

    private func mutation(for step: CalendarSyncStep) -> CalendarEventMutation? {
        switch step.action {
        case .create, .update:
            return .upsert(todoID: step.local.id, content: step.local.state.content, expected: step.remote)
        case .remove:
            return step.remote.map { .remove(expected: $0) }
        default:
            return nil
        }
    }

    private func result(
        for step: CalendarSyncStep, written: [UUID: CalendarRemoteItem], previous: CalendarSyncLedger, calendarID: String
    ) throws -> (record: CalendarSyncRecord?, update: CalendarLocalUpdate?) {
        let task = step.local
        let prior = previous.records[task.id.uuidString]
        switch step.action {
        case .create, .update:
            guard let remote = written[task.id], remote.calendarID == calendarID,
                  remote.todoID == task.id, remote.content == task.state.content else { throw CalendarSyncError.invalidData }
            return adopted(task, remote: remote)
        case .adopt:
            guard let remote = step.remote else { throw CalendarSyncError.invalidData }
            return adopted(task, remote: remote)
        case .pull:
            guard let remote = step.remote else { throw CalendarSyncError.invalidData }
            let state = CalendarLocalState(content: remote.content, isPublished: true)
            return (CalendarSyncRecord(local: state, remote: remote.content, eventID: remote.id),
                    CalendarLocalUpdate(id: task.id, content: remote.content, eventID: remote.id))
        case .remove:
            return (CalendarSyncRecord(local: task.state, eventID: nil), bindingUpdate(task, eventID: ""))
        case .detach:
            let id = prior?.eventID ?? (task.eventID.isEmpty ? nil : task.eventID)
            return (CalendarSyncRecord(local: task.state, eventID: id, detached: true), bindingUpdate(task, eventID: ""))
        case .ignore:
            return (prior.map { _ in CalendarSyncRecord(local: task.state, eventID: nil) }, nil)
        case .conflict:
            return (nil, nil)
        }
    }

    private func adopted(_ task: CalendarLocalItem, remote: CalendarRemoteItem) -> (CalendarSyncRecord, CalendarLocalUpdate?) {
        (CalendarSyncRecord(local: task.state, remote: remote.content, eventID: remote.id), bindingUpdate(task, eventID: remote.id))
    }

    private func bindingUpdate(_ task: CalendarLocalItem, eventID: String) -> CalendarLocalUpdate? {
        task.eventID == eventID ? nil : CalendarLocalUpdate(id: task.id, eventID: eventID)
    }
}
