import Foundation
@testable import AreaChain

enum RoutineQueryFixture {
    static let id = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
    static var dates: ContentQueryDateContext { QuerySessionFixture.page().dates }

    static func routine() -> RoutineSnapshot {
        .init(id: id, title: "合成习惯", sortOrder: 0, isEnabled: true, createdDayKey: "2026-09-01")
    }

    static func evidence(
        _ lower: String, _ upper: String, rule: RoutineScheduleEvidence.Rule = .weekdays(WeekdayMask.all),
        id: UUID = id
    ) -> RoutineScheduleEvidence {
        .init(routineID: id, interval: .init(lowerBound: lower, upperBound: upper), rule: rule,
              source: .synthetic(reference: "fixture-schedule"))
    }

    static func check(_ state: RoutineCheckState, day: String = QuerySessionFixture.today, id: UUID = id) -> CheckSnapshot {
        .init(routineId: id, dayKey: day, isDone: state == .completed, isSkipped: state == .skipped)
    }

    static func read(
        _ checks: [CheckSnapshot], day: String = QuerySessionFixture.today,
        complete: [ContentQueryDateInterval] = [QuerySessionFixture.interval()]
    ) -> RoutineCheckRead {
        RoutineCheckReading.read(routineID: id, on: day, checks: checks,
                                 coverage: .init(routineID: id, completeIntervals: complete), dates: dates)
    }

    static func history(_ evidence: [RoutineScheduleEvidence], routine: RoutineSnapshot = routine()) -> RoutineScheduleHistory {
        .init(routine: routine, evidence: evidence, dates: dates)
    }
}
