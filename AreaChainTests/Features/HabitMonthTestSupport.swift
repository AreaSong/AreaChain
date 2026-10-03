import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
final class HabitMonthTestSupport {
    typealias Native = SettingsButtonTestSupport
    let fixture: Native
    let routine: DailyRoutine
    let other: DailyRoutine
    let checks: [RoutineCheck]
    let restore: () -> Void
    let original: [RoutineSnapshot]
    let originalChecks: [CheckSnapshot]
    var context: ModelContext { fixture.container.mainContext }

    init() throws {
        fixture = try Native()
        let restoreNavigation = CalendarSpanTestSupport.preserveState()
        let now = DayClock.shared.now
        restore = { restoreNavigation(); DayClock.shared.now = now }
        DayClock.shared.now = try #require(DayKey.date(from: "2026-09-09"))
        routine = DailyRoutine(title: "Synthetic habit", sortOrder: 0, createdDayKey: "2026-09-03",
                               weekdayMask: WeekdayMask.workdays, notes: "Synthetic notes")
        other = DailyRoutine(title: "Synthetic other", sortOrder: 1, createdDayKey: "2026-01-01")
        let context = fixture.container.mainContext
        context.insert(routine)
        context.insert(other)
        checks = [
            RoutineCheck(dayKey: "2026-09-07", isDone: true, routine: routine),
            RoutineCheck(dayKey: "2026-09-08", isDone: true, isSkipped: true, routine: routine),
            RoutineCheck(dayKey: "2026-09-04", isDone: true, routine: other)
        ]
        for check in checks { context.insert(check) }
        try context.save()
        original = [routine.snapshot, other.snapshot]
        originalChecks = checks.compactMap(\.snapshot)
        WorkspaceNavigation.shared.inspectTask(routine.id, dayKey: "2026-09-09")
    }

    func cleanup() {
        EditDrafts.shared.titles.removeValue(forKey: "routine-\(routine.id)")
        EditDrafts.shared.notes.removeValue(forKey: "routine-\(routine.id)")
        restore()
        fixture.cleanup()
    }

    func assertUnchanged() throws {
        #expect([routine.snapshot, other.snapshot] == original)
        #expect(checks.compactMap(\.snapshot) == originalChecks)
        #expect(try context.fetchCount(FetchDescriptor<RoutineCheck>()) == 3)
        #expect(!context.hasChanges)
    }

    /// 宿主与完整日键共同定位，多个月历不能靠相同日期取第一个。
    static func belongs(_ node: NSObject, to host: String) -> Bool {
        var current: NSObject? = node
        var visited = Set<ObjectIdentifier>()
        while let item = current, visited.insert(ObjectIdentifier(item)).inserted {
            if Native.value(item, "accessibilityIdentifier") as? String == host { return true }
            current = Native.value(item, "accessibilityParent") as? NSObject
        }
        return false
    }

    static func day(_ key: String, host: String, in window: NSWindow) throws -> NSObject {
        let matches = Native.buttons(in: window).filter {
            Native.value($0, "accessibilityIdentifier") as? String == "daybook.date.\(key)" && belongs($0, to: host)
        }
        try #require(matches.count == 1, "宿主日键必须唯一：\(host) / \(key)")
        return try #require(matches.first)
    }

    static func frames(_ window: NSWindow) throws -> [CGRect] {
        try Native.buttons(in: window).map { try Native.frame($0, in: window) }.sorted {
            $0.midY == $1.midY ? $0.minX < $1.minX : $0.midY > $1.midY
        }
    }
}

struct HabitDrawerTestHost: View {
    @Bindable var navigation = WorkspaceNavigation.shared
    var body: some View {
        TaskDetailDrawer(taskID: $navigation.selectedTaskID)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("habit.drawer.qa")
    }
}
