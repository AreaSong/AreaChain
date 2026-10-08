import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class RoutineStateFixture {
    let base: RoutineCommandFixture
    var context: ModelContext { base.context }
    var routine: DailyRoutine { base.routine }
    var target: CommandObjectReference { .init(type: .routine, id: routine.id) }
    init(enabled: Bool = false, start: String = "2026-10-05") throws {
        base = try .init(enabled: enabled, stateOperations: true)
        for row in routine.checks { context.delete(row) }
        routine.weekdayMask = WeekdayMask.all
        routine.weekdaysOnly = false
        routine.pausedOnDayKey = enabled ? nil : start
        try context.save()
    }
    @discardableResult func row(_ day: String, _ done: Bool = false, _ skipped: Bool = false) -> RoutineCheck {
        let row = RoutineCheck(dayKey: day, isDone: done, isSkipped: skipped, routine: routine)
        context.insert(row)
        return row
    }
    func queue(_ command: String, day: String? = nil, enabled: Bool = true) throws {
        let target = day.map { CommandObjectReference(type: .routineOccurrence, id: routine.id, dayKey: $0) } ?? self.target
        let arguments: [CommandArgument] = command == "routine.enabled" ? [.init(parameter: .enabled, operation: .assign, value: .boolean(enabled))] : []
        try base.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: command),
                                    targets: .init(.single, objects: [target]), arguments: arguments))
    }
    func accept(_ command: String = "routine.enabled", day: String? = nil, enabled: Bool = true) throws -> CommandRoutineAcceptance {
        try queue(command, day: day, enabled: enabled)
        let accepted = try base.adapter.accept(base.preview(), expecting: base.handoff.owned().lease)
        #expect(base.count("save") == 0 && base.count("ui") == 0 && !context.hasChanges)
        return accepted
    }
    func history(_ day: String) {
        base.stateHistory = [.init(routineID: routine.id, interval: .init(lowerBound: day, upperBound: day),
            rule: .weekdays(WeekdayMask.all), source: .synthetic(reference: "rm3-recorded-schedule"))]
    }
}
