import Foundation
import Testing
@testable import AreaChain

struct RoutineOccurrenceQueryRequestTests {
    @Test func onlyExplicitTypedScopeReadsOccurrences() {
        for scope in ["", "/tasks", "/routines", "/trash", "/diaries"] {
            var fixture = RoutineOccurrenceQueryFixture()
            fixture.session = TodoQueryFixture.session(scope + " date:today")
            let response = fixture.read()
            #expect(response.state == .notApplicable)
            #expect(response.matches.isEmpty && response.reviewRecords.isEmpty)
            #expect(response.coverage.coveredTypes.isEmpty && response.coverage.window == nil)
        }
        let fixture = RoutineOccurrenceQueryFixture()
        #expect(fixture.read().matches.count == 1)
        #expect(RoutineQueryProvider.read(.init(requestID: fixture.request.requestID, session: fixture.session,
            routines: fixture.routines, tagNames: nil, checks: fixture.checks, checkCoverage: fixture.coverage,
            scheduleEvidence: fixture.evidence)).state == .notApplicable)
        let path = TodoQueryFixture.session("/routines/checks")
        #expect(path.scope != .routineOccurrences)
    }

    @Test func missingWindowNeverDefaultsTodayOrHistory() {
        let response = RoutineOccurrenceQueryFixture("status:open").read()
        #expect(response.state == .requiresInput)
        #expect(response.diagnostics.contains { $0.issue == .missingWindow })
        #expect(response.matches.isEmpty && !response.isCompleteForCoveredTypes)
    }

    @Test func dateOnAndBrowseWindowsAreExplicitAndConsistent() {
        for source in ["date:today", "on:today", "date:2026-09-01..2026-12-31 on:today"] {
            let response = RoutineOccurrenceQueryFixture(source).read()
            #expect(response.state == .evaluated)
            #expect(response.matches.map(\.id.dayKey) == ["2026-10-01"])
        }
        var browse = RoutineOccurrenceQueryFixture("")
        browse.browse = RoutineOccurrenceQueryFixture.window("2026-10-01", "2026-10-03")
        #expect(browse.read().matches.map(\.id.dayKey) == ["2026-10-01", "2026-10-02", "2026-10-03"])
        browse.session = RoutineOccurrenceQueryFixture("date:2026-10-01..2026-10-03 on:2026-10-02").session
        #expect(browse.read().matches.map(\.id.dayKey) == ["2026-10-02"])
        browse.session = RoutineOccurrenceQueryFixture("date:today").session
        #expect(browse.read().state == .invalidQuery)
        #expect(browse.read().diagnostics.contains { $0.issue == .inconsistentWindows })
    }

    @Test func outsideOnMultipleOnAndDisjointDateWindowsDoNotGetOverwritten() {
        for source in ["date:today on:2026-10-02", "on:2026-10-02 date:2026-09-01..2026-10-01"] {
            let response = RoutineOccurrenceQueryFixture(source).read()
            #expect(response.state == .unsatisfiable && response.matches.isEmpty)
            #expect(response.diagnostics.contains { $0.issue == .occurrenceOutsideWindow })
        }
        let multiple = RoutineOccurrenceQueryFixture("on:today on:2026-10-02").read()
        #expect(multiple.state == .invalidQuery)
        let disjoint = RoutineOccurrenceQueryFixture("date:today date:2026-10-02").read()
        #expect(disjoint.state == .unsatisfiable)
        var browse = RoutineOccurrenceQueryFixture("on:today")
        browse.browse = RoutineOccurrenceQueryFixture.window("2026-10-02", "2026-10-03")
        #expect(browse.read().state == .unsatisfiable)
    }

    @Test func fullSessionRejectsEveryUnsupportedOwnAndParentField() {
        for source in ["合成习惯", "-不存在", "#工作", "created:today", "!p1", "has:image", "@15:30"] {
            let response = RoutineOccurrenceQueryFixture("date:today " + source).read()
            #expect(response.state == .inapplicableConditions)
            #expect(response.matches.isEmpty && !response.isCompleteForCoveredTypes)
        }
        let predicates: [ContentQueryPagePredicate] = [.noTags, .tagID(UUID()), .sourceApplication("fixture.app"),
            .routineStatus(.disabled), .todoStatus(.open), .itemKind(.recurring),
            .taskPriority(.init(scope: .p1)), .reminderPresence(.set)]
        for predicate in predicates {
            var fixture = RoutineOccurrenceQueryFixture()
            fixture.session = TodoQueryFixture.add(.page(predicate), to: fixture.session)
            #expect(fixture.read().state == .inapplicableConditions)
        }
    }

    @Test func malformedConditionIdentityAndDateContextFailClosed() {
        var fixture = RoutineOccurrenceQueryFixture()
        fixture.session.conditions.append(fixture.session.conditions[0])
        #expect(fixture.read().state == .invalidQuery)
        let context = QuerySessionFixture.page(.overview)
        fixture.session = .init(page: .init(location: context.location, page: context.page,
            todayKey: "2026-02-30", calendar: context.calendar))
        QuerySessionFixture.apply(.addCondition(.scope(.routineOccurrences)), &fixture.session)
        fixture.browse = RoutineOccurrenceQueryFixture.window("2026-10-01", "2026-10-01")
        #expect(fixture.read().state == .blocked)
    }

    @Test func dateUnionIntersectionAndStateORKeepAllConditionEvidence() {
        let fixture = RoutineOccurrenceQueryFixture(
            "(date:2026-10-01..2026-10-03 | date:2026-10-05) date:2026-10-02..2026-10-05 (status:open | status:done)")
        let response = fixture.read()
        #expect(response.matches.map(\.id.dayKey) == ["2026-10-02", "2026-10-03", "2026-10-05"])
        for match in response.matches {
            #expect(Set(match.evidence.map(\.conditionID)) == Set(fixture.session.conditions.map(\.id)))
            #expect(match.evidence.contains { $0.field == .occurrenceDay })
            #expect(match.evidence.contains { $0.field == .completion && $0.alternativeIndex == 0 })
        }
    }

    @Test func handoffPreservesTypedScopeAndFrozenDateContext() {
        var fixture = RoutineOccurrenceQueryFixture("on:today status:open")
        let original = fixture.session
        let target = QuerySessionFixture.page(.overview, visit: "later", host: "other")
        fixture.session = original.handedOff(to: .init(page: .init(location: target.location, page: target.page,
            todayKey: "2026-10-20", calendar: target.calendar)))
        let response = fixture.read()
        #expect(fixture.session.queryDates.todayKey == "2026-10-01")
        #expect(response.matches.map(\.id.dayKey) == ["2026-10-01"])
        #expect(response.matches.first?.evidence.map(\.conditionID) == original.conditions.map(\.id))
        let rule = ContentQueryPageDateRule(evaluation: .agenda, todayKey: "2026-10-01", calendar: target.calendar)
        fixture.session = TodoQueryFixture.add(.page(.boardDate(.overdue, rule)), to: fixture.session)
        #expect(fixture.read().state == .inapplicableConditions)
    }
}

extension RoutineOccurrenceQueryRequestTests {
    @Test func frozenPagePredicateIsRetainedAndRejectedRatherThanIgnored() throws {
        var fixture = RoutineOccurrenceQueryFixture("on:today")
        let page = fixture.session.page
        let rule = ContentQueryPageDateRule(evaluation: .listedDay, todayKey: page.todayKey, calendar: page.calendar)
        let condition = fixture.session.makeCondition(.page(.boardDate(.today, rule)), origin: .page(visitID: page.location.visitID))
        fixture.session.conditions.append(condition)
        fixture.session = fixture.session.handedOff(to: .init(page: QuerySessionFixture.page(.overview, visit: "target")))
        let preserved = try #require(fixture.session.conditions.first { $0.id == condition.id })
        #expect(preserved.origin.isHandoffPage && preserved.value == condition.value)
        let response = fixture.read()
        #expect(response.state == .inapplicableConditions && response.matches.isEmpty)
        #expect(response.typeAnalysis.assessment(for: .routineOccurrence)?.reasons.contains {
            $0.issue == .fieldNotApplicable && $0.conditionIDs.contains(condition.id)
        } == true)
        #expect(!response.coverage.enumerationIsComplete && !response.coverage.historyIsComplete)
    }

    @Test func bilingualDatesAndDSTUseFrozenCivilCalendar() {
        var fixture = RoutineOccurrenceQueryFixture()
        let base = QuerySessionFixture.page(.overview)
        var calendar = base.calendar
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        fixture.session = .init(page: .init(location: base.location, page: base.page, todayKey: "2024-03-10", calendar: calendar))
        QuerySessionFixture.apply(.setInput("日期:2024-03-09..2024-03-11 状态:未完成"), &fixture.session)
        QuerySessionFixture.apply(.addCondition(.scope(.routineOccurrences)), &fixture.session)
        fixture.routines[0].createdDayKey = "2024-01-01"
        fixture.evidence = [RoutineQueryFixture.evidence("2024-03-09", "2024-03-11")]
        fixture.coverage = [.init(routineID: RoutineQueryFixture.id,
            completeIntervals: [.init(lowerBound: "2024-03-09", upperBound: "2024-03-11")])]
        #expect(fixture.read().matches.map(\.id.dayKey) == ["2024-03-09", "2024-03-10", "2024-03-11"])
    }

    @Test func rawTextDoesNotReplaceEffectiveStructuredConditions() {
        var fixture = RoutineOccurrenceQueryFixture("date:today")
        fixture.session = TodoQueryFixture.add(.atom(.status(.done)), to: fixture.session)
        #expect(fixture.read().matches.isEmpty)
        fixture.checks = [RoutineQueryFixture.check(.completed)]
        #expect(fixture.read().matches.count == 1)
        fixture.session = TodoQueryFixture.add(.atom(.status(.open)), to: fixture.session)
        #expect(fixture.read().state == .unsatisfiable)
    }
}
