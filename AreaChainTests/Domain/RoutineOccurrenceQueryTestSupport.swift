import Foundation
@testable import AreaChain

struct RoutineOccurrenceQueryFixture {
    var session: ContentQuerySession
    var routines = [RoutineQueryFixture.routine()]
    var checks: [CheckSnapshot] = []
    var coverage = [RoutineCheckCoverage(routineID: RoutineQueryFixture.id,
        completeIntervals: [.init(lowerBound: "2026-09-01", upperBound: "2026-12-31")])]
    var evidence = [RoutineQueryFixture.evidence("2026-09-01", "2026-12-31")]
    var definitions: RoutineOccurrenceDefinitionCoverage = .complete
    var browse: ContentQueryDateWindow?
    var budget = RoutineOccurrenceQueryBudget()

    init(_ source: String = "date:today") {
        session = TodoQueryFixture.add(.scope(.routineOccurrences), to: TodoQueryFixture.session(source))
    }

    var request: RoutineOccurrenceQueryRequest {
        .init(requestID: TodoQueryFixture.requestID, session: session, routines: routines, checks: checks,
              checkCoverage: coverage, scheduleEvidence: evidence, definitionCoverage: definitions,
              browseWindow: browse, budget: budget)
    }
    func read() -> RoutineOccurrenceQueryResponse { RoutineOccurrenceQueryProvider.read(request) }

    static func window(_ lower: String, _ upper: String) -> ContentQueryDateWindow {
        .init(intervals: [.init(lowerBound: lower, upperBound: upper)], calendar: RoutineQueryFixture.dates.calendar)!
    }
}
