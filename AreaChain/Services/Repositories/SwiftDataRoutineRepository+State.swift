import Foundation
import SwiftData

extension SwiftDataRoutineRepository {
    /// 预览不调用本入口；只有原共同事务内才能应用精确写集，不重新求桥接日期或挑首条。
    func applyRoutineState(_ accepted: CommandRoutineAcceptance) throws {
        guard let context = routineMutationContext, ModelChanges.hasActiveTransaction(in: context),
              let impact = accepted.preview.stateImpact else { throw RoutineCommandIssue.invalidRepository }
        let definitions = try fetchRoutines(withID: accepted.object.id)
        guard definitions.count == 1, let routine = definitions.first,
              ObjectIdentifier(routine) == accepted.preview.record, routine.snapshot == impact.definition,
              routine.weekdayMask == impact.storedWeekdayMask, routine.weekdaysOnly == impact.weekdaysOnly else {
            throw RoutineCommandIssue.fieldsChanged
        }
        let rows = try context.fetch(FetchDescriptor<RoutineCheck>())
        let byID = Dictionary(grouping: rows, by: \.id)
        for (day, id) in accepted.checkCreationIDs {
            guard byID[id] == nil, impact.effects.contains(where: { $0.day == day && $0.action == .insert }) else {
                throw RoutineCommandIssue.fieldsChanged
            }
        }
        for effect in impact.effects where effect.action != .preserve {
            if effect.action == .insert {
                guard let id = accepted.checkCreationIDs[effect.day] else { throw RoutineCommandIssue.stale }
                context.insert(RoutineCheck(id: id, dayKey: effect.day, isDone: effect.done,
                                           isSkipped: effect.skipped, routine: routine))
            } else {
                for original in effect.original {
                    guard let found = byID[original.id], found.count == 1, let row = found.first,
                          row.persistentModelID == original.identity, row.routine === routine,
                          row.dayKey == original.day, row.isDone == original.done, row.isSkipped == original.skipped else {
                        throw RoutineCommandIssue.fieldsChanged
                    }
                    row.isDone = effect.done
                    row.isSkipped = effect.skipped
                }
            }
        }
        routine.isEnabled = impact.finalEnabled
        routine.pausedOnDayKey = impact.finalPause
        try ModelChanges.commit(context)
    }
}
