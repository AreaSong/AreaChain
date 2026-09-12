import EventKit
import Foundation

@MainActor
final class EventKitCalendarClient: CalendarEventClient {
    private let store = EKEventStore()
    var notificationSource: AnyObject { store }

    func authorize() async -> Bool {
        do { return try await store.requestFullAccessToEvents() }
        catch { return false }
    }

    func calendarID(preferred: String?) throws -> String {
        if let preferred, let calendar = store.calendar(withIdentifier: preferred) {
            guard calendar.allowsContentModifications else { throw CalendarSyncError.unavailable }
            return calendar.calendarIdentifier
        }
        let existing = store.calendars(for: .event).filter { $0.title == CalendarSync.calendarTitle }
        guard existing.count <= 1 else { throw CalendarSyncError.conflict }
        if let calendar = existing.first {
            guard calendar.allowsContentModifications else { throw CalendarSyncError.unavailable }
            return calendar.calendarIdentifier
        }
        guard let source = store.sources.first(where: { $0.sourceType == .local })
                ?? store.defaultCalendarForNewEvents?.source else { throw CalendarSyncError.unavailable }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = CalendarSync.calendarTitle
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        return calendar.calendarIdentifier
    }

    func events(in calendarID: String, windows: [DateInterval]) throws -> [CalendarRemoteItem] {
        guard let calendar = store.calendar(withIdentifier: calendarID) else { throw CalendarSyncError.unavailable }
        return try windows.flatMap { window in
            let predicate = store.predicateForEvents(withStart: window.start, end: window.end, calendars: [calendar])
            return try store.events(matching: predicate).map(snapshot)
        }
    }

    func event(id: String) throws -> CalendarRemoteItem? {
        try store.event(withIdentifier: id).map(snapshot)
    }

    func apply(_ mutations: [CalendarEventMutation], in calendarID: String) throws -> [UUID: CalendarRemoteItem] {
        guard let calendar = store.calendar(withIdentifier: calendarID), calendar.allowsContentModifications else {
            throw CalendarSyncError.unavailable
        }
        var saved: [UUID: EKEvent] = [:]
        do {
            for mutation in mutations {
                switch mutation {
                case let .upsert(id, content, expected):
                    let event = try expected.map { try checkedEvent($0, calendarID: calendarID) } ?? EKEvent(eventStore: store)
                    event.calendar = calendar
                    event.title = content.title
                    event.notes = TodoDragToken.encode(id)
                    if expected?.content.dayKey != content.dayKey || expected?.content.remindMinutes != content.remindMinutes {
                        try applySchedule(event, content: content)
                    }
                    try store.save(event, span: .thisEvent, commit: false)
                    saved[id] = event
                case .remove(let expected):
                    try store.remove(checkedEvent(expected, calendarID: calendarID), span: .thisEvent, commit: false)
                }
            }
            if !mutations.isEmpty { try store.commit() }
            return try saved.mapValues(snapshot)
        } catch {
            store.reset()
            throw error
        }
    }

    private func checkedEvent(_ expected: CalendarRemoteItem, calendarID: String) throws -> EKEvent {
        guard let event = store.event(withIdentifier: expected.id),
              event.calendar.calendarIdentifier == calendarID,
              try snapshot(event) == expected else { throw CalendarSyncError.conflict }
        return event
    }

    private func applySchedule(_ event: EKEvent, content: CalendarContent) throws {
        if let minutes = content.remindMinutes, let start = DayKey.date(dayKey: content.dayKey, minutes: minutes) {
            let duration = event.startDate.flatMap { start in event.endDate.map { $0.timeIntervalSince(start) } }
            event.isAllDay = false
            event.startDate = start
            event.endDate = start.addingTimeInterval(duration.flatMap { $0 > 0 && $0 < 86_400 ? $0 : nil } ?? 1800)
        } else if content.remindMinutes == nil, let bounds = CalendarEventPolicy.allDayBounds(dayKey: content.dayKey) {
            event.isAllDay = true
            event.startDate = bounds.start
            event.endDate = bounds.end
        } else {
            throw CalendarSyncError.invalidData
        }
    }

    private func snapshot(_ event: EKEvent) throws -> CalendarRemoteItem {
        guard let id = event.eventIdentifier, let start = event.startDate, let calendar = event.calendar else {
            throw CalendarSyncError.invalidData
        }
        return CalendarRemoteItem(
            id: id, calendarID: calendar.calendarIdentifier, todoID: TodoDragToken.decode(event.notes ?? ""),
            content: CalendarContent(
                title: event.title ?? "",
                dayKey: CalendarEventPolicy.remoteDayKey(isAllDay: event.isAllDay, startDate: start),
                remindMinutes: CalendarEventPolicy.remoteRemindMinutes(isAllDay: event.isAllDay, startDate: start)
            ),
            modifiedAt: event.lastModifiedDate
        )
    }
}
