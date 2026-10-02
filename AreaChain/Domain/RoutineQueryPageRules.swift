import Foundation

/// 旧页面投影的适配，不把 first-wins 或任一闭合改成新搜索状态。
enum RoutineQueryPageRules {
    typealias Result = RoutineQueryEvaluationResult

    static func coverage(_ request: RoutineQueryRequest, routineID: UUID) -> RoutineCheckCoverage {
        .init(routineID: routineID, completeIntervals: request.checkCoverage.filter {
            $0.routineID == routineID
        }.flatMap(\.completeIntervals))
    }

    static func date(
        _ scope: DateFilterScope, rule: ContentQueryPageDateRule, request: RoutineQueryRequest,
        routine: RoutineSnapshot, id: ContentQueryConditionID
    ) -> Result {
        // listedDay 缺少“行日期”输入；today 可以唯一确定，其余非 all 不借 on 补造。
        if rule.evaluation == .listedDay && ![.all, .today].contains(scope) {
            return .unknown(.unsupportedListedDay, id: id)
        }
        if rule.evaluation == .agenda && ![.overdue, .upcoming].contains(scope) {
            return .unknown(.unsupportedAgendaDate, id: id)
        }
        if scope == .overdue, routine.isEnabled {
            let end = DayKey.shifted(rule.todayKey, by: -1, calendar: rule.calendar)
            if routine.createdDayKey <= end {
                let interval = ContentQueryDateInterval(lowerBound: routine.createdDayKey, upperBound: end)
                let coverage = coverage(request, routineID: routine.id)
                guard ContentQueryDateWindow(intervals: coverage.completeIntervals, calendar: rule.calendar) != nil else {
                    return .unknown(.invalidPageCheckInput, id: id)
                }
                guard coverage.covers(interval, calendar: rule.calendar) else { return .unknown(.missingPageCheckCoverage, id: id) }
                guard request.checks.filter({ $0.routineId == routine.id }).allSatisfy({
                    ContentQuerySnapshotValidation.validDay($0.dayKey, dates: request.session.queryDates)
                }) else { return .unknown(.invalidPageCheckInput, id: id) }
            }
        }
        let matched: Bool
        switch rule.evaluation {
        case .items:
            let query = ItemsListingQuery(filter: .init(dateScope: scope), todayKey: rule.todayKey)
            matched = !ItemsListing.routines([routine], checks: request.checks, query: query, calendar: rule.calendar).isEmpty
        case .agenda:
            if scope == .overdue {
                matched = !AgendaProjection.overdueRoutines(routines: [routine], checks: request.checks,
                                                            todayKey: rule.todayKey, calendar: rule.calendar).isEmpty
            } else {
                matched = !AgendaProjection.upcomingRoutines(routines: [routine], todayKey: rule.todayKey,
                                                             calendar: rule.calendar).isEmpty
            }
        case .listedDay:
            matched = scope == .all || (DayBoardLogic.isRoutineDue(routine, on: rule.todayKey, calendar: rule.calendar)
                && Classification.matchesDate(dayKey: rule.todayKey,
                    isDone: DayBoardCheckIndex(request.checks).isClosed(routineId: routine.id, dayKey: rule.todayKey),
                    todayKey: rule.todayKey, scope: scope, calendar: rule.calendar))
        }
        return .known(matched, id: id, field: .legacyPageProjection)
    }
}
