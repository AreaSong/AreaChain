import Foundation

struct CalendarContent: Codable, Equatable, Sendable {
    var title: String
    var dayKey: String
    var remindMinutes: Int?
}

struct CalendarLocalState: Codable, Equatable, Sendable {
    var content: CalendarContent
    var isPublished: Bool
}

struct CalendarLocalItem: Equatable, Sendable {
    var id: UUID
    var state: CalendarLocalState
    var eventID: String
}

struct CalendarRemoteItem: Equatable, Sendable {
    var id: String
    var calendarID: String
    var todoID: UUID?
    var content: CalendarContent
    var modifiedAt: Date? = nil
}

struct CalendarSyncRecord: Codable, Equatable, Sendable {
    var local: CalendarLocalState
    var remote: CalendarContent?
    var eventID: String?
    var detached = false
}

struct CalendarSyncLedger: Codable, Equatable, Sendable {
    var version = 1
    var calendarID: String?
    var records: [String: CalendarSyncRecord] = [:]
}

enum CalendarSyncError: Error {
    case invalidData
    case unavailable
    case conflict
    case invalidLedger
}

struct CalendarSyncStep: Equatable {
    enum Action: Equatable { case create, update, pull, remove, adopt, detach, ignore, conflict }
    var local: CalendarLocalItem
    var remote: CalendarRemoteItem?
    var action: Action
}

enum CalendarReconciliation {
    static func plan(
        tasks: [CalendarLocalItem], events: [CalendarRemoteItem], ledger: CalendarSyncLedger, calendarID: String
    ) throws -> [CalendarSyncStep] {
        guard Set(tasks.map(\.id)).count == tasks.count else { throw CalendarSyncError.invalidData }
        var steps = tasks.map { task in
            step(task: task, events: events, record: ledger.records[task.id.uuidString], calendarID: calendarID)
        }
        let claims = Dictionary(grouping: steps.compactMap { step -> (String, UUID)? in
            step.remote.map { ($0.id, step.local.id) }
        }, by: { $0.0 })
        for index in steps.indices {
            if let id = steps[index].remote?.id, (claims[id]?.count ?? 0) > 1 {
                steps[index].action = .conflict
            }
        }
        return steps
    }

    private static func step(
        task: CalendarLocalItem, events: [CalendarRemoteItem], record: CalendarSyncRecord?, calendarID: String
    ) -> CalendarSyncStep {
        let ids = Set([task.eventID, record?.eventID ?? ""].filter { !$0.isEmpty })
        let matches = events.filter { $0.todoID == task.id || ids.contains($0.id) }
        guard !matches.contains(where: { ids.contains($0.id) && $0.calendarID != calendarID }) else {
            return CalendarSyncStep(local: task, action: .conflict)
        }
        let owned = matches.filter { $0.calendarID == calendarID }
        guard owned.count <= 1 else { return CalendarSyncStep(local: task, action: .conflict) }
        let remote = owned.first
        if let otherID = remote?.todoID, otherID != task.id {
            return CalendarSyncStep(local: task, remote: remote, action: .conflict)
        }
        return CalendarSyncStep(local: task, remote: remote, action: decide(task: task, remote: remote, record: record))
    }

    private static func decide(
        task: CalendarLocalItem, remote: CalendarRemoteItem?, record: CalendarSyncRecord?
    ) -> CalendarSyncStep.Action {
        if record?.detached == true {
            if remote == nil {
                // 明确完成后重新打开，才重新发布已解绑的待办；普通编辑不能复活远端删除。
                return record?.local.isPublished == false && task.state.isPublished ? .create : .detach
            }
            return task.state.isPublished && task.state.content == remote?.content ? .adopt : .conflict
        }
        guard let remote else {
            if record?.remote != nil || !task.eventID.isEmpty { return .detach }
            return task.state.isPublished ? .create : .ignore
        }
        guard task.state.isPublished else {
            guard let record, record.remote == remote.content else { return .conflict }
            return .remove
        }
        if task.state.content == remote.content { return .adopt }
        guard let record, let lastRemote = record.remote else { return .conflict }
        let localChanged = task.state != record.local
        let remoteChanged = remote.content != lastRemote
        if localChanged && !remoteChanged { return .update }
        if remoteChanged && !localChanged { return .pull }
        return .conflict
    }
}
