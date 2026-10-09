import Foundation
import SwiftData

/// 已核对的物理应用步骤。所有成员先解析完毕，再开始赋值，避免本批前序写入使后序快照失效。
@MainActor struct RoutineStateApplication {
    struct Input {
        let target: CommandObjectReference
        private let record: ObjectIdentifier?
        private let savedRecord: PersistentIdentifier?
        let impact: CommandRoutineStateImpact
        let creationIDs: [String: UUID]

        init(target: CommandObjectReference, record: ObjectIdentifier, impact: CommandRoutineStateImpact, creationIDs: [String: UUID]) {
            self.target = target
            self.record = record
            savedRecord = nil
            self.impact = impact
            self.creationIDs = creationIDs
        }

        /// 新创建定义可能重新物化；仍比较真实存储身份，不退化为业务 UUID。
        init(target: CommandObjectReference, record: PersistentIdentifier, impact: CommandRoutineStateImpact, creationIDs: [String: UUID]) {
            self.target = target
            self.record = nil
            savedRecord = record
            self.impact = impact
            self.creationIDs = creationIDs
        }

        func matches(_ routine: DailyRoutine) -> Bool {
            if let savedRecord { return savedRecord == routine.persistentModelID }
            return record == ObjectIdentifier(routine)
        }
    }
    struct Update {
        let row: RoutineCheck
        let done: Bool
        let skipped: Bool
    }
    struct Insertion {
        let id: UUID
        let day: String
        let done: Bool
        let skipped: Bool
    }
    let routine: DailyRoutine
    let impact: CommandRoutineStateImpact
    let updates: [Update]
    let insertions: [Insertion]

    static func prepare(_ inputs: [Input], in context: ModelContext) throws -> [RoutineStateApplication] {
        let definitions = try context.fetch(FetchDescriptor<DailyRoutine>())
        let definitionIndex = Dictionary(grouping: definitions, by: \.id)
        let rows = try context.fetch(FetchDescriptor<RoutineCheck>())
        let byID = Dictionary(grouping: rows, by: \.id)
        var reserved = Set<UUID>()
        return try inputs.map { input in
            let matches = definitionIndex[input.target.id] ?? []
            guard matches.count == 1, let routine = matches.first, routine.modelContext === context,
                  input.matches(routine), routine.snapshot == input.impact.definition,
                  routine.weekdayMask == input.impact.storedWeekdayMask, routine.weekdaysOnly == input.impact.weekdaysOnly else {
                throw RoutineCommandIssue.fieldsChanged
            }
            for id in input.creationIDs.values {
                guard byID[id] == nil, reserved.insert(id).inserted else { throw RoutineCommandIssue.fieldsChanged }
            }
            return try prepare(input, routine: routine, rows: byID)
        }
    }

    private static func prepare(_ input: Input, routine: DailyRoutine,
                                rows: [UUID: [RoutineCheck]]) throws -> RoutineStateApplication {
        let required = Set(input.impact.effects.filter { $0.action == .insert }.map(\.day))
        guard Set(input.creationIDs.keys) == required else { throw RoutineCommandIssue.stale }
        var updates: [Update] = [], insertions: [Insertion] = []
        for effect in input.impact.effects where effect.action != .preserve {
            if effect.action == .insert {
                guard let id = input.creationIDs[effect.day] else { throw RoutineCommandIssue.stale }
                insertions.append(.init(id: id, day: effect.day, done: effect.done, skipped: effect.skipped))
            } else {
                for original in effect.original {
                    guard let found = rows[original.id], found.count == 1, let row = found.first,
                          row.persistentModelID == original.identity, row.routine === routine,
                          row.dayKey == original.day, row.isDone == original.done, row.isSkipped == original.skipped else {
                        throw RoutineCommandIssue.fieldsChanged
                    }
                    updates.append(.init(row: row, done: effect.done, skipped: effect.skipped))
                }
            }
        }
        return .init(routine: routine, impact: input.impact, updates: updates, insertions: insertions)
    }

    func apply(in context: ModelContext) throws {
        guard ModelChanges.hasActiveTransaction(in: context), routine.modelContext === context else {
            throw RoutineCommandIssue.invalidRepository
        }
        for insertion in insertions {
            context.insert(RoutineCheck(id: insertion.id, dayKey: insertion.day, isDone: insertion.done,
                                       isSkipped: insertion.skipped, routine: routine))
        }
        for update in updates { update.row.isDone = update.done; update.row.isSkipped = update.skipped }
        if routine.isEnabled != impact.finalEnabled { routine.isEnabled = impact.finalEnabled }
        if routine.pausedOnDayKey != impact.finalPause { routine.pausedOnDayKey = impact.finalPause }
    }
}
