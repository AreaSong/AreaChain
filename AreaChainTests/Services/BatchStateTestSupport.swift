import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class BatchStateFixture {
    let base: BatchCommandFixture
    let second: DailyRoutine
    let child: SubtaskItem
    let deletedChild: SubtaskItem
    var context: ModelContext { base.context }
    var routines: [DailyRoutine] { [base.routine, second] }
    var definitionTargets: [CommandObjectReference] { routines.map { .init(type: .routine, id: $0.id) } }
    var mixed: [CommandObjectReference] {
        [base.taskTargets[0], occurrence(base.routine, "2026-10-06"), occurrence(base.routine, "2026-10-07"),
         occurrence(second, "2026-10-07"), base.taskTargets[1]]
    }
    init(enabled: Bool = true) throws {
        base = try .init(stateOperations: true)
        second = DailyRoutine(title: "Second synthetic habit", sortOrder: 8, isEnabled: enabled, createdDayKey: "2026-09-01",
                              weekdayMask: WeekdayMask.all, pausedOnDayKey: enabled ? nil : "2026-10-05")
        child = SubtaskItem(title: "Cascade synthetic child", todo: base.todos[0])
        deletedChild = SubtaskItem(title: "Deleted child", todo: base.todos[0])
        deletedChild.deletedAt = Date(timeIntervalSince1970: 10)
        context.insert(second); context.insert(child); context.insert(deletedChild)
        for row in base.routine.checks { context.delete(row) }
        for todo in base.todos { todo.isDone = false }
        base.routine.isEnabled = enabled
        base.routine.weekdayMask = WeekdayMask.all
        base.routine.weekdaysOnly = false
        base.routine.pausedOnDayKey = enabled ? nil : "2026-10-05"
        for routine in routines {
            base.history[routine.id] = [.init(routineID: routine.id,
                interval: .init(lowerBound: "2026-09-01", upperBound: "2026-10-08"),
                rule: .weekdays(WeekdayMask.all), source: .synthetic(reference: "bm2-history"))]
        }
        try context.save()
    }
    func occurrence(_ routine: DailyRoutine, _ day: String) -> CommandObjectReference {
        .init(type: .routineOccurrence, id: routine.id, dayKey: day)
    }
    @discardableResult func row(_ routine: DailyRoutine, _ day: String, done: Bool = false, skipped: Bool = false) -> RoutineCheck {
        let row = RoutineCheck(dayKey: day, isDone: done, isSkipped: skipped, routine: routine)
        context.insert(row)
        return row
    }
    func queue(_ command: String = "batch.completion", value: Bool = true, targets: [CommandObjectReference]? = nil) throws {
        try base.queue(command, argument: .init(parameter: .enabled, operation: .assign, value: .boolean(value)),
                       targets: targets ?? (command == "batch.enabled" ? definitionTargets : mixed))
    }
    func checks(in context: ModelContext? = nil) throws -> [CommandRoutineCheckRow] {
        try (context ?? self.context).fetch(FetchDescriptor<RoutineCheck>()).map { row in
            let parent = try #require(row.routine)
            return .init(id: row.id, identity: row.persistentModelID, parent: parent.id, parentIdentity: parent.persistentModelID,
                         day: row.dayKey, done: row.isDone, skipped: row.isSkipped)
        }.sorted { $0.id.uuidString < $1.id.uuidString }
    }
    func assertCreated(_ accepted: CommandBatchAcceptance) throws {
        let rows = try checks()
        for (target, id) in accepted.checkCreationIDs {
            let found = try #require(rows.first { $0.id == id })
            #expect(found.parent == target.id && found.day == target.dayKey)
        }
    }
}
