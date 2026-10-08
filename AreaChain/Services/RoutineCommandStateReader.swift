import Foundation
import SwiftData

extension RoutineCommandEnvironment {
    /// 只有显式隔离装配才获得状态能力；历史证据与普通输入资格分别绑定。
    struct StateOperations {
        let now: () -> Date
        let calendar: Calendar
        var history: (UUID) throws -> [RoutineScheduleEvidence] = { _ in [] }
    }
}

/// 原 Reader 的状态读取扩展，不建立第二个可变读取所有者。
extension RoutineCommandReader {
    func stateImpact(_ routine: DailyRoutine, edit: CommandRoutineEdit,
                     target: CommandObjectReference) throws -> CommandRoutineStateImpact? {
        guard edit.isState else { return nil }
        guard let configuration = environment.stateOperations else { throw RoutineCommandIssue.unassembled }
        let dates = ContentQueryDateContext(todayKey: DayKey.from(configuration.now(), calendar: configuration.calendar),
                                           calendar: configuration.calendar)
        let reads = RoutineContentQueryReads(context: environment.context)
        let definitions = try reads.definitions()
        let models = try reads.allChecks()
        let projection = RoutineContentQueryCheckProjection(models: models, definitions: definitions, dates: dates)
        guard !projection.globallyIncomplete, !projection.restrictedIDs.contains(routine.id),
              definitions.filter({ $0.id == routine.id }).count == 1 else { throw RoutineStateIssue.incompleteRecords }
        let related = models.filter { $0.routine?.persistentModelID == routine.persistentModelID }
        guard Set(related.map(\.persistentModelID)) == Set(routine.checks.map(\.persistentModelID)),
              related.count == routine.checks.count,
              related.allSatisfy({ $0.modelContext === environment.context && $0.routine === routine }) else {
            throw RoutineStateIssue.incompleteRecords
        }
        let records = related.map {
            CommandRoutineCheckRow(id: $0.id, identity: $0.persistentModelID, parent: routine.id,
                parentIdentity: routine.persistentModelID, day: $0.dayKey, done: $0.isDone, skipped: $0.isSkipped)
        }.sorted { $0.id.uuidString < $1.id.uuidString }
        guard records.allSatisfy({ $0.day >= routine.createdDayKey }) else {
            throw RoutineStateIssue.unreliableStart
        }
        if case .enabled(true) = edit, !routine.isEnabled, records.contains(where: { $0.day > dates.todayKey }) {
            throw RoutineStateIssue.unreliableStart
        }
        let history: [RoutineScheduleEvidence]
        if case .occurrence = edit { history = try configuration.history(routine.id) } else { history = [] }
        let evidence = history + [.currentDefinition(routine.snapshot, observedOn: dates.todayKey)]
        return try CommandRoutineStatePlanning.prepare(.init(definition: routine.snapshot, storedMask: routine.weekdayMask,
            weekdaysOnly: routine.weekdaysOnly, records: records, dates: dates, schedule: evidence), edit: edit, target: target)
    }
}
