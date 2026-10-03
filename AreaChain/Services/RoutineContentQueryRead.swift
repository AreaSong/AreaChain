import Foundation
import SwiftData

/// 每次调用由读取环境采样；不得用查询日、冻结 today 或缓存的上次观察替代。
/// Calendar 必须与解释证据的 Session 一致；这里只接收值，不在读取中执行时钟回调。
struct RoutineContentQueryObservation {
    let instant: Date
    let calendar: Calendar
}

@MainActor
struct RoutineContentQueryReads {
    var definitions: () throws -> [DailyRoutine]
    /// 完整独立表读取，保留孤立行、重复行和非法日键；不使用父项 relationship 枚举。
    var allChecks: () throws -> [RoutineCheck]

    init(context: ModelContext) {
        let repository: any RoutineRepositoryProtocol = SwiftDataRoutineRepository(context: context)
        definitions = { try repository.fetchRoutines(includeDisabled: true, includeDeleted: true) }
        allChecks = { try context.fetch(FetchDescriptor<RoutineCheck>()) }
    }
}

enum RoutineContentQueryReadIssue: Equatable {
    case definitionFetchFailed, checkFetchFailed, observationCalendarMismatch, invalidObservation
    case missingCheckParent(index: Int), uncontainedCheckParent(index: Int), ambiguousCheckParent(index: Int)
    case uncheckedCheckParent(index: Int), invalidCheckDay(index: Int), duplicateCheckID(indices: [Int])
    case unsupportedPageCalendar
}

/// 物理记录身份与 CheckSnapshot 的业务键分离；nil 下标保留无法转换的行证据。
struct RoutineContentQueryCheckRow: CustomStringConvertible, CustomDebugStringConvertible {
    let recordID: UUID
    let inputIndex: Int
    let snapshotIndex: Int?
    var description: String { "RoutineContentQueryCheckRow(redacted)" }
    var debugDescription: String { description }
}

struct RoutineContentQueryReadDetails: CustomStringConvertible, CustomDebugStringConvertible {
    enum FetchScope { case notRequested, allStoredRows }
    var fetchScope: FetchScope = .notRequested
    var checkSource: ContentQuerySourceCoverage = .notProvided
    var requestedCoverage: [RoutineCheckCoverage] = []
    var rows: [RoutineContentQueryCheckRow] = []
    var issues: [RoutineContentQueryReadIssue] = []
    var description: String { "RoutineContentQueryReadDetails(redacted)" }
    var debugDescription: String { description }
}

/// 只计划必要覆盖，不推断历史排程。实际 IO 仍是一次全表读取，非数据库有界查询。
enum RoutineContentQueryCheckPlan {
    static func coverage(in batch: ContentQueryBatch, issues: inout [RoutineContentQueryReadIssue]) -> [RoutineCheckCoverage] {
        let common = commonIntervals(in: batch)
        return (batch.snapshots.routines.values ?? []).map { routine in
            var intervals = common
            for condition in batch.session.conditions {
                guard case .page(.boardDate(let scope, let rule)) = condition.value else { continue }
                guard rule.calendar == batch.dates.calendar else {
                    if !issues.contains(.unsupportedPageCalendar) { issues.append(.unsupportedPageCalendar) }
                    continue
                }
                if scope == .overdue && [.items, .agenda].contains(rule.evaluation), routine.isEnabled {
                    let end = DayKey.shifted(rule.todayKey, by: -1, calendar: rule.calendar)
                    let interval = ContentQueryDateInterval(lowerBound: routine.createdDayKey, upperBound: end)
                    if ContentQueryDateWindow.valid(interval, calendar: rule.calendar) { intervals.append(interval) }
                }
                if scope == .today && rule.evaluation == .listedDay {
                    intervals.append(.init(lowerBound: rule.todayKey, upperBound: rule.todayKey))
                }
            }
            let window = ContentQueryDateWindow(intervals: intervals, calendar: batch.dates.calendar)
            return .init(routineID: routine.id, completeIntervals: window?.intervals ?? [])
        }
    }

    static func needsRecords(in batch: ContentQueryBatch, coverage: [RoutineCheckCoverage]) -> Bool {
        // 即使定义为空/失败，有显式窗口仍要扫描记录，不能丢掉全孤立表的证据。
        !commonIntervals(in: batch).isEmpty || coverage.contains { !$0.completeIntervals.isEmpty }
    }

    private static func commonIntervals(in batch: ContentQueryBatch) -> [ContentQueryDateInterval] {
        let on = batch.session.occurrenceDay.dayKey
        guard batch.session.scope == .routineOccurrences else {
            return on.map { [.init(lowerBound: $0, upperBound: $0)] } ?? []
        }
        let date: ContentQueryDateWindow?
        switch ContentQueryDateWindow.resolve(batch.session.conditions, dates: batch.dates) {
        case .window(let value): date = value
        case .unconstrained: date = nil
        case .invalid: return []
        }
        let browse = batch.options.occurrenceWindow
        if let date, let browse, date != browse { return [] }
        let window = date ?? browse
        if let on {
            if let window, !window.contains(on) { return [] }
            return [.init(lowerBound: on, upperBound: on)]
        }
        return window?.intervals ?? []
    }
}
