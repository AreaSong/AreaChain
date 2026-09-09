import EventKit
import Foundation
import SwiftData

@MainActor
enum CalendarSync {
    static let calendarTitle = "AreaChain"

    private static let store = EKEventStore()
    private static var eventObserver: NSObjectProtocol?
    private static var prefsObserver: NSObjectProtocol?
    private static var ignorePullUntil = Date.distantPast

    static func start() {
        guard !isTestProcess, prefsObserver == nil else { return }
        prefsObserver = NotificationCenter.default.addObserver(
            forName: .appPreferencesDidChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in applyPreference() }
        }
        applyPreference()
    }

    static func refreshIfEnabled() {
        guard wantsSync, !isTestProcess else { return }
        Task { await pushAll() }
    }

    private static var wantsSync: Bool { AppPreferences.shared.syncCalendarEvents }

    private static var isTestProcess: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static func applyPreference() {
        if wantsSync {
            if eventObserver == nil {
                Task { await enable() }
            }
        } else {
            disableEvents()
            CalendarSyncStatus.shared.mark(.off)
        }
    }

    private static func enable() async {
        guard wantsSync else {
            CalendarSyncStatus.shared.mark(.off)
            return
        }
        guard await requestAccess() else {
            CalendarSyncStatus.shared.mark(.denied)
            return
        }
        await pushAll()
        listenToStore()
    }

    private static func disableEvents() {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
            self.eventObserver = nil
        }
    }

    private static func listenToStore() {
        guard eventObserver == nil else { return }
        eventObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { _ in
            Task { @MainActor in pullIfDue() }
        }
    }

    private static func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    private static func pullIfDue() {
        guard wantsSync, Date() >= ignorePullUntil else { return }
        Task { await pullAll() }
    }
}

private extension CalendarSync {
    static func pushAll() async {
        guard wantsSync else {
            CalendarSyncStatus.shared.mark(.off)
            return
        }
        guard await requestAccess() else {
            CalendarSyncStatus.shared.mark(.denied)
            return
        }
        guard let calendar = ensureCalendar() else {
            CalendarSyncStatus.shared.mark(.unavailable)
            return
        }
        let context = Persistence.session.container.mainContext
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        ignorePullUntil = Date().addingTimeInterval(1.5)
        let current = events(in: calendar, covering: todos)
        for todo in todos {
            if CalendarEventPolicy.shouldPublish(isDone: todo.isDone, deletedAt: todo.deletedAt) {
                upsert(todo, calendar: calendar, existing: current)
            } else {
                removeEvent(for: todo, existing: current)
            }
        }
        removeOrphans(todos: todos, existing: current)
        do {
            try store.commit()
            try context.save()
            CalendarSyncStatus.shared.mark(.synced)
        } catch {
            CalendarSyncStatus.shared.mark(.failed)
        }
    }

    static func pullAll() async {
        guard wantsSync else {
            CalendarSyncStatus.shared.mark(.off)
            return
        }
        guard await requestAccess() else {
            CalendarSyncStatus.shared.mark(.denied)
            return
        }
        guard let calendar = ensureCalendar() else {
            CalendarSyncStatus.shared.mark(.unavailable)
            return
        }
        let context = Persistence.session.container.mainContext
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        applyRemote(events: events(in: calendar, covering: todos), todos: todos)
        do {
            try context.save()
            CalendarSyncStatus.shared.mark(.synced)
            BoardEvents.changedLocally()
        } catch {
            CalendarSyncStatus.shared.mark(.failed)
        }
    }

    static func ensureCalendar() -> EKCalendar? {
        if let found = store.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
            return found
        }
        guard let source = store.defaultCalendarForNewEvents?.source ?? store.sources.first else {
            return nil
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = calendarTitle
        calendar.source = source
        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            return nil
        }
    }

    static func events(in calendar: EKCalendar, covering todos: [TodoItem]) -> [EKEvent] {
        let bounds = CalendarEventPolicy.eventQueryBounds(dayKeys: todos.map(\.dayKey))
        return store.events(
            matching: store.predicateForEvents(withStart: bounds.start, end: bounds.end, calendars: [calendar])
        )
    }

    static func upsert(_ todo: TodoItem, calendar: EKCalendar, existing: [EKEvent]) {
        let event = existingEvent(for: todo, in: existing) ?? EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = todo.title
        event.notes = TodoDragToken.encode(todo.id)
        applySchedule(event, todo: todo)
        do {
            try store.save(event, span: .thisEvent, commit: false)
            if let ident = event.eventIdentifier {
                todo.calendarEventID = ident
            }
        } catch {
            return
        }
    }

    static func applySchedule(_ event: EKEvent, todo: TodoItem) {
        if let minutes = todo.remindMinutes, let start = DayKey.date(dayKey: todo.dayKey, minutes: minutes) {
            event.isAllDay = false
            event.startDate = start
            event.endDate = start.addingTimeInterval(30 * 60)
        } else if let bounds = CalendarEventPolicy.allDayBounds(dayKey: todo.dayKey) {
            event.isAllDay = true
            event.startDate = bounds.start
            event.endDate = bounds.end
        }
    }

    static func existingEvent(for todo: TodoItem, in existing: [EKEvent]) -> EKEvent? {
        let token = TodoDragToken.encode(todo.id)
        if let match = existing.first(where: { $0.notes == token }) {
            return match
        }
        if !todo.calendarEventID.isEmpty {
            return store.event(withIdentifier: todo.calendarEventID)
        }
        return nil
    }

    static func removeEvent(for todo: TodoItem, existing: [EKEvent]) {
        if let event = existingEvent(for: todo, in: existing) {
            try? store.remove(event, span: .thisEvent, commit: false)
        }
        todo.calendarEventID = ""
    }

    static func removeOrphans(todos: [TodoItem], existing: [EKEvent]) {
        let liveTokens = Set(
            todos
                .filter { CalendarEventPolicy.shouldPublish(isDone: $0.isDone, deletedAt: $0.deletedAt) }
                .map { TodoDragToken.encode($0.id) }
        )
        let unpublishedEventIDs = Set(
            todos
                .filter { !CalendarEventPolicy.shouldPublish(isDone: $0.isDone, deletedAt: $0.deletedAt) }
                .map(\.calendarEventID)
                .filter { !$0.isEmpty }
        )
        let knownEventIDs = Set(todos.map(\.calendarEventID).filter { !$0.isEmpty })
        for event in existing {
            if CalendarEventPolicy.shouldRemoveOrphanEvent(
                notes: event.notes,
                eventIdentifier: event.eventIdentifier,
                liveTokens: liveTokens,
                knownEventIDs: knownEventIDs,
                unpublishedEventIDs: unpublishedEventIDs
            ) {
                try? store.remove(event, span: .thisEvent, commit: false)
            }
        }
    }

    static func applyRemote(events: [EKEvent], todos: [TodoItem]) {
        let byID = Dictionary(uniqueKeysWithValues: todos.map { ($0.id, $0) })
        var seen: Set<UUID> = []
        for event in events {
            guard let id = TodoDragToken.decode(event.notes ?? "") else { continue }
            seen.insert(id)
            guard let todo = byID[id], todo.deletedAt == nil else { continue }
            if let title = event.title, !title.isEmpty, todo.title != title {
                todo.title = title
            }
            let key = CalendarEventPolicy.remoteDayKey(isAllDay: event.isAllDay, startDate: event.startDate)
            if todo.dayKey != key { todo.dayKey = key }
            todo.remindMinutes = CalendarEventPolicy.remoteRemindMinutes(
                isAllDay: event.isAllDay,
                startDate: event.startDate
            )
            if let ident = event.eventIdentifier {
                todo.calendarEventID = ident
            }
        }
        let bounds = CalendarEventPolicy.eventQueryBounds(dayKeys: todos.map(\.dayKey))
        for todo in todos {
            if CalendarEventPolicy.shouldUnlinkMissingRemote(
                deletedAt: todo.deletedAt,
                calendarEventID: todo.calendarEventID,
                seenRemote: seen.contains(todo.id),
                dayKey: todo.dayKey,
                windowStart: bounds.start,
                windowEnd: bounds.end
            ) {
                todo.calendarEventID = ""
            }
        }
    }
}
