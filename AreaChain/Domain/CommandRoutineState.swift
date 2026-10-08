import Foundation
import SwiftData

enum RoutineStateIssue: String, Error, Equatable {
    case incompleteRecords, invalidDate, unreliableStart, intervalLimit, duplicateRows, historyUnknown, notScheduled
}

enum RoutineOccurrenceAction: String, Equatable {
    case complete, skip, reopen
    var done: Bool { self != .reopen }
    var skipped: Bool { self == .skip }
}

/// 物理身份与定义＋日期业务身份分别保存；原始布尔对不被逻辑兼容归并覆盖。
struct CommandRoutineCheckRow: Equatable {
    let id: UUID
    let identity: PersistentIdentifier
    let parent: UUID
    let parentIdentity: PersistentIdentifier
    let day: String
    let done: Bool
    let skipped: Bool
    var logicalState: RoutineCheckState { skipped ? .skipped : (done ? .completed : .unprocessed) }
}

struct CommandRoutineCheckEffect: Equatable, Identifiable {
    enum Action: Equatable { case insert, update, preserve }
    let day: String
    let original: [CommandRoutineCheckRow]
    let action: Action
    let done: Bool
    let skipped: Bool
    let diagnostics: [RoutineCheckIssue]
    var id: String { day }
}

/// 只读影响是完整接受输入的一部分。跨度先验证再枚举，绝不把匹配星期数当作跨度。
struct CommandRoutineStateImpact: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum StartSource: String { case pausedDay, latestRecord, creationDay }
    let definition: RoutineSnapshot
    let storedWeekdayMask: Int?
    let weekdaysOnly: Bool
    let today: String
    let calendar: Calendar
    let records: [CommandRoutineCheckRow]
    let schedule: [RoutineScheduleEvidence]
    let finalEnabled: Bool
    let finalPause: String?
    let start: String?
    let startSource: StartSource?
    let span: Int
    let effects: [CommandRoutineCheckEffect]
    var inserted: Int { effects.filter { $0.action == .insert }.count }
    var modified: Int { effects.filter { $0.action == .update }.reduce(0) { $0 + $1.original.count } }
    var preserved: Int { effects.filter { $0.action == .preserve }.reduce(0) { $0 + $1.original.count } }
    var noChange: Bool {
        finalEnabled == definition.isEnabled && finalPause == definition.pausedOnDayKey && inserted == 0 && modified == 0
    }
    var description: String { "CommandRoutineStateImpact(redacted)" }
    var debugDescription: String { description }
}

/// 启停仅按用户批准的当前星期桥接；单日资格仍须由原历史排程证据证明。
enum CommandRoutineStatePlanning {
    struct Input {
        let definition: RoutineSnapshot
        let storedMask: Int?
        let weekdaysOnly: Bool
        let records: [CommandRoutineCheckRow]
        let dates: ContentQueryDateContext
        let schedule: [RoutineScheduleEvidence]
    }

    static func prepare(_ input: Input, edit: CommandRoutineEdit, target: CommandObjectReference) throws -> CommandRoutineStateImpact {
        let definition = input.definition
        guard valid(definition.createdDayKey, input), valid(input.dates.todayKey, input),
              definition.createdDayKey <= input.dates.todayKey else { throw RoutineStateIssue.invalidDate }
        if let mask = input.storedMask, mask <= 0 || mask & ~WeekdayMask.all != 0 { throw RoutineStateIssue.unreliableStart }
        var enabled = definition.isEnabled, pause = definition.pausedOnDayKey
        var start: String?, source: CommandRoutineStateImpact.StartSource?, span = 0
        var effects: [CommandRoutineCheckEffect] = []
        switch edit {
        case .enabled(let value):
            enabled = value
            pause = value ? nil : (pause ?? input.dates.todayKey)
            if value && !definition.isEnabled {
                let bridge = try bridge(input)
                start = bridge.start; source = bridge.source; span = bridge.span; effects = bridge.effects
            }
        case .occurrence(let action): effects = [try occurrence(input, target: target, action: action)]
        default: throw RoutineCommandIssue.invalidArguments
        }
        return .init(definition: definition, storedWeekdayMask: input.storedMask, weekdaysOnly: input.weekdaysOnly,
            today: input.dates.todayKey, calendar: input.dates.calendar, records: input.records, schedule: input.schedule,
            finalEnabled: enabled, finalPause: pause, start: start, startSource: source, span: span, effects: effects)
    }

    private struct Bridge {
        let start: String
        let source: CommandRoutineStateImpact.StartSource
        let span: Int
        let effects: [CommandRoutineCheckEffect]
    }

    private static func bridge(_ input: Input) throws -> Bridge {
        let routine = input.definition
        let source: CommandRoutineStateImpact.StartSource
        if let pause = routine.pausedOnDayKey {
            guard valid(pause, input) else { throw RoutineStateIssue.unreliableStart }
            source = .pausedDay
        } else { source = input.records.isEmpty ? .creationDay : .latestRecord }
        let start = HabitStreakLogic.skipFillStart(pausedOnDayKey: routine.pausedOnDayKey,
            createdDayKey: routine.createdDayKey, checkDayKeys: input.records.map(\.day))
        guard valid(start, input), start >= routine.createdDayKey, start <= input.dates.todayKey,
              let from = DayKey.date(from: start, calendar: input.dates.calendar),
              let end = DayKey.date(from: input.dates.todayKey, calendar: input.dates.calendar),
              let span = input.dates.calendar.dateComponents([.day], from: from, to: end).day, span >= 0 else {
            throw RoutineStateIssue.unreliableStart
        }
        guard span <= 4000 else { throw RoutineStateIssue.intervalLimit }
        let days = DayKey.keys(from: start, before: input.dates.todayKey, calendar: input.dates.calendar)
        guard days.count == span else { throw RoutineStateIssue.unreliableStart }
        let grouped = Dictionary(grouping: input.records, by: \.day)
        let effects = days.filter { WeekdayMask.contains(routine.weekdayMask, dayKey: $0, calendar: input.dates.calendar) }.map { day in
            let rows = grouped[day] ?? []
            let action: CommandRoutineCheckEffect.Action = rows.isEmpty ? .insert
                : (rows.contains { $0.done || $0.skipped } ? .preserve : .update)
            return effect(day, rows: rows, action: action, done: true, skipped: true, input: input)
        }
        return .init(start: start, source: source, span: span, effects: effects)
    }

    private static func occurrence(_ input: Input, target: CommandObjectReference,
                                   action: RoutineOccurrenceAction) throws -> CommandRoutineCheckEffect {
        guard let day = target.dayKey, valid(day, input) else { throw RoutineStateIssue.invalidDate }
        let rows = input.records.filter { $0.day == day }
        guard rows.count <= 1 else { throw RoutineStateIssue.duplicateRows }
        let qualification = RoutineScheduleHistory(routine: input.definition, evidence: input.schedule, dates: input.dates).day(day)
        guard qualification.state != .unknown else { throw RoutineStateIssue.historyUnknown }
        guard qualification.state == .scheduled else { throw RoutineStateIssue.notScheduled }
        let operation: CommandRoutineCheckEffect.Action
        if rows.isEmpty { operation = action == .reopen ? .preserve : .insert }
        else { operation = rows[0].done == action.done && rows[0].skipped == action.skipped ? .preserve : .update }
        return effect(day, rows: rows, action: operation, done: action.done, skipped: action.skipped, input: input)
    }

    private static func effect(_ day: String, rows: [CommandRoutineCheckRow], action: CommandRoutineCheckEffect.Action,
                               done: Bool, skipped: Bool, input: Input) -> CommandRoutineCheckEffect {
        let read = RoutineCheckReading.read(routineID: input.definition.id, on: day,
            checks: rows.map { .init(routineId: $0.parent, dayKey: $0.day, isDone: $0.done, isSkipped: $0.skipped) },
            coverage: .init(routineID: input.definition.id, completeIntervals: [.init(lowerBound: day, upperBound: day)]), dates: input.dates)
        return .init(day: day, original: rows, action: action, done: done, skipped: skipped, diagnostics: read.diagnostics)
    }

    private static func valid(_ day: String, _ input: Input) -> Bool {
        ContentQuerySnapshotValidation.validDay(day, dates: input.dates)
    }
}
