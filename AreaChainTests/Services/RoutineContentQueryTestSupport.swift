import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 复用 2K-1 的全 schema 内存库；生产适配器与测试共用同一显式上下文入口。
@MainActor
struct RoutineContentQueryFixture {
    let task: TaskContentQueryFixture
    var context: ModelContext { task.context }
    var reader: TaskFamilyContentQueryReader { .init(context: context) }
    init() throws { task = try .init() }

    @discardableResult
    func routine(_ title: String = "needle", enabled: Bool = true, deleted: Date? = nil) -> DailyRoutine {
        let value = DailyRoutine(title: title, sortOrder: 0, isEnabled: enabled,
                                 createdDayKey: "2026-09-01", weekdayMask: WeekdayMask.all,
                                 createdAt: TodoQueryFixture.created, deletedAt: deleted)
        context.insert(value)
        return value
    }

    @discardableResult
    func check(_ parent: DailyRoutine?, day: String = QuerySessionFixture.today,
               done: Bool = false, skipped: Bool = false) -> RoutineCheck {
        let value = RoutineCheck(dayKey: day, isDone: done, isSkipped: skipped, routine: parent)
        context.insert(value)
        return value
    }

    static func observation(_ day: String = QuerySessionFixture.today) -> RoutineContentQueryObservation {
        let calendar = RoutineQueryFixture.dates.calendar
        return .init(instant: DayKey.date(dayKey: day, minutes: 720, calendar: calendar)!, calendar: calendar)
    }

    func read(_ source: String = "/routines", observed: String = QuerySessionFixture.today,
              reads: RoutineContentQueryReads? = nil, tasks: TaskContentQueryReads? = nil) -> TaskFamilyContentQueryReadResult {
        let adapter = TaskFamilyContentQueryReader(tasks: tasks ?? .init(context: context),
                                                  routines: reads ?? .init(context: context), tags: .init(context: context))
        return adapter.read(session: TodoQueryFixture.session(source), requestID: TodoQueryFixture.requestID,
                            observation: Self.observation(observed))
    }

    func records(_ source: String = "date:today", observed: String = QuerySessionFixture.today,
                 options: ContentQueryBatchOptions = .init(), reads: RoutineContentQueryReads? = nil) -> TaskFamilyContentQueryReadResult {
        let adapter = TaskFamilyContentQueryReader(tasks: .init(context: context),
                                                  routines: reads ?? .init(context: context), tags: .init(context: context))
        return adapter.read(session: RoutineOccurrenceQueryFixture(source).session, requestID: TodoQueryFixture.requestID,
                            observation: Self.observation(observed), options: options)
    }

    static func occurrence(_ result: TaskFamilyContentQueryReadResult) throws -> RoutineOccurrenceQueryResponse {
        let response = ContentQueryBatchReader.read(result.batch)
        return try #require(response.readings.compactMap { if case .routineOccurrence(let value) = $0 { return value }; return nil }.first)
    }

    static func definitions(_ result: TaskFamilyContentQueryReadResult) throws -> RoutineQueryResponse {
        let response = ContentQueryBatchReader.read(result.batch)
        return try #require(response.readings.compactMap { if case .routine(let value) = $0 { return value }; return nil }.first)
    }

    static func covers(_ result: TaskFamilyContentQueryReadResult, _ id: UUID, _ lower: String, _ upper: String? = nil) -> Bool {
        result.batch.facts.routine.checkCoverage.contains {
            $0.routineID == id && $0.covers(.init(lowerBound: lower, upperBound: upper ?? lower), calendar: result.batch.dates.calendar)
        }
    }
}
