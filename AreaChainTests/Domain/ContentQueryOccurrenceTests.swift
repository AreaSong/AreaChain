import Foundation
import Testing
@testable import AreaChain

struct ContentQueryOccurrenceTests {
    @Test func explicitDayAndSkippedParseWithBilingualStableValues() throws {
        let source = "/routines on:today status:skipped"
        let session = TodoQueryFixture.session(source)
        let chinese = TodoQueryFixture.session("/routines 执行日:今天 状态:已跳过")
        #expect(session.isStructurallyValid && session.isReady)
        #expect(session.occurrenceDay == .selected(QuerySessionFixture.today))
        #expect(session.conditions.map(\.value) == chinese.conditions.map(\.value))
        #expect(session.typeAnalysis.assessment(for: .routine)?.reasons.isEmpty == true)
        let on = try QuerySessionFixture.condition(.content(.on), in: session)
        #expect(on.value == .atom(.on("2026-10-01")))
        #expect(on.origin == .input(range: (source as NSString).range(of: "on:today")))
        #expect(try QuerySessionFixture.source(session) == source)
        guard case .content(let query) = session.input else { return }
        let requirements = ContentQueryApplicability.requirements(for: query, type: .routine)
        #expect(requirements.map(\.binding) == [.occurrenceDay, .routineCompletionOnDay("2026-10-01")])
        #expect(ContentQueryApplicability.requirements(for: query, type: .todo).allSatisfy { !$0.isApplicable })
    }

    @Test func invalidExecutionDaysRetainEditingDiagnosticsAndUnicodeRanges() throws {
        let cases: [(String, ContentQueryIssue)] = [
            ("on:", .incompleteCondition), ("on:2026-10-", .incompleteCondition), ("on:tod", .incompleteCondition),
            ("on:2026-02-30", .invalidDate), ("on:2026-2-03", .invalidDate), ("on:tomorrow", .invalidDate),
            ("on:today..today", .occurrenceDayMustBeSingle), ("on:2026-10-01..", .occurrenceDayMustBeSingle),
            ("-on:today", .unsupportedExclusion), ("status:skip", .incompleteCondition)
        ]
        let prefix = "/routines 中文 👩🏽‍💻 e\u{301} "
        for (fragment, issue) in cases {
            let source = prefix + fragment
            let state = TodoQueryFixture.session(source)
            let diagnostic = try #require(state.textDiagnostics.first { $0.issue == issue })
            #expect(diagnostic.range == NSRange(location: prefix.utf16.count, length: fragment.utf16.count))
            #expect((source as NSString).substring(with: diagnostic.range) == fragment)
            #expect(try QuerySessionFixture.source(state) == source)
            #expect(!state.isStructurallyValid)
        }
    }

    @Test func differentDaysCannotUseLastWinsOrHideInOR() throws {
        for source in ["on:today on:2026-10-02", "(on:today | on:2026-10-02)",
                       "(on:today | on:2026-10-02) on:today"] {
            let session = TodoQueryFixture.session("/routines " + source)
            #expect(!session.isStructurallyValid)
            #expect(session.textDiagnostics.contains { [.conflictingOccurrenceDays, .multipleOccurrenceDaysInGroup].contains($0.issue) })
            #expect(session.occurrenceDay.dayKey == nil)
        }
        let duplicate = TodoQueryFixture.session("/routines on:today on:2026-10-01")
        #expect(duplicate.isStructurallyValid)
        #expect(duplicate.conditions.filter { $0.value.dimension == .content(.on) }.count == 2)
        let diagnostic = try #require(duplicate.textDiagnostics.first { $0.issue == .duplicateCondition })
        #expect(!diagnostic.relatedRanges.isEmpty)
        #expect(duplicate.occurrenceDay == .selected("2026-10-01"))
        #expect(TodoQueryFixture.session("/routines (on:today | on:today)").isStructurallyValid)
    }

    @Test func structuredConditionsCannotBypassSingleDayValidation() {
        let source = TodoQueryFixture.session("/routines on:today")
        let second = TodoQueryFixture.add(.atom(.on("2026-10-02")), to: source)
        #expect(!second.isStructurallyValid)
        #expect(second.conditionDiagnostics.contains { $0.issue == .conflictingOccurrenceDays && $0.conditionIDs.count == 2 })
        let grouped = TodoQueryFixture.add(.clause([.init(atom: .on("2026-10-01")), .init(atom: .on("2026-10-02"))]), to: source)
        #expect(grouped.conditionDiagnostics.contains { $0.issue == .multipleOccurrenceDaysInGroup })
        for day in ["2026-02-30", "2026-10-01..2026-10-02", ""] {
            #expect(!TodoQueryFixture.add(.atom(.on(day)), to: TodoQueryFixture.session("/routines")).isStructurallyValid)
        }
        let external = ContentQueryTypeValidation.analyze(source.conditions, requestedTypes: [.routine], occurrenceDay: "2026-10-02")
        #expect(external.possibleTypes.isEmpty)
    }

    @Test func statusNeedsOnEvenWhenDateIsTodayAndStatesRemainExclusive() {
        for status in ["open", "done", "skipped"] {
            let session = TodoQueryFixture.session("/routines date:today status:" + status)
            #expect(session.occurrenceDay == .unspecified)
            #expect(session.typeAnalysis.assessment(for: .routine)?.requiresInput == true)
            let selected = TodoQueryFixture.add(.atom(.on("2026-10-01")), to: session)
            #expect(selected.typeAnalysis.assessment(for: .routine)?.requiresInput == false)
        }
        for pair in ["open status:done", "done status:skipped", "skipped status:open"] {
            for day in ["", " on:today"] {
                let state = TodoQueryFixture.session("/routines status:" + pair + day)
                #expect(state.isStructurallyValid && state.typeAnalysis.possibleTypes.isEmpty)
            }
        }
        #expect(TodoQueryFixture.session("/routines on:today (status:done | status:skipped)").typeAnalysis.possibleTypes == [.routine])
    }

    @Test func tasksRejectNewFieldsWithoutExcludingRoutinesFromMixedScope() {
        let parent = SubtaskQueryFixture.parent(1)
        for query in ["status:skipped", "on:today", "on:today status:skipped", "(status:open | status:skipped)"] {
            let session = TodoQueryFixture.session("/tasks " + query)
            #expect(session.isStructurallyValid && session.typeAnalysis.possibleTypes == [.routine])
            for type in [CommandObjectType.todo, .subtask] {
                #expect(session.typeAnalysis.assessment(for: type)?.reasons.contains { $0.issue == .fieldNotApplicable } == true)
            }
            let todo = TodoQueryFixture.read(session, [parent])
            let child = SubtaskQueryFixture.read(session, [parent])
            #expect(todo.state == .inapplicableConditions && todo.matches.isEmpty)
            #expect(child.state == .inapplicableConditions && child.matches.isEmpty)
            #expect(todo.queryIsValid && child.queryIsValid)
            #expect(!todo.isCompleteForCoveredTypes && !child.isCompleteForCoveredTypes)
        }
        for type in [CommandObjectType.diary, .tag, .clipboardEntry] {
            #expect(ContentQueryApplicability.binding(.on, to: type) == .notApplicable)
        }
        let childOnly = TodoQueryFixture.session("/subtasks status:skipped")
        #expect(childOnly.typeAnalysis.possibleTypes.isEmpty)
    }

    @Test func finalDateWindowMustContainOnWhileCreatedAndPageStatesStayIndependent() throws {
        let cases: [(String, Bool)] = [
            ("date:today", true), ("date:2026-09-01..2026-10-07", true),
            ("date:2026-09-01..2026-10-07 date:2026-10-01..2026-10-02", true),
            ("date:2026-10-02..2026-10-07", false),
            ("date:2026-09-01..2026-10-07 date:2026-10-02..2026-10-03", false),
            ("(date:2026-09-01 | date:2026-10-01)", true),
            ("(date:2026-09-01 | date:2026-10-02)", false)
        ]
        for (window, possible) in cases {
            let session = TodoQueryFixture.session("/routines on:today status:done " + window)
            #expect(session.isStructurallyValid)
            #expect(session.typeAnalysis.assessment(for: .routine)?.isPossible == possible)
            let occurrences = TodoQueryFixture.add(.scope(.routineOccurrences), to: TodoQueryFixture.session("on:today " + window))
            #expect(occurrences.typeAnalysis.assessment(for: .routineOccurrence)?.isPossible == possible)
        }
        let enabled = TodoQueryFixture.add(.page(.todoStatus(.open)), to:
            TodoQueryFixture.add(.page(.routineStatus(.enabled)), to:
                TodoQueryFixture.session("/routines on:today status:done created:2025-01-01")))
        #expect(enabled.typeAnalysis.assessment(for: .routine)?.reasons.isEmpty == true)
        let rule = ContentQueryPageDateRule(evaluation: .agenda, todayKey: QuerySessionFixture.today,
                                           calendar: QuerySessionFixture.page().calendar)
        let overdue = TodoQueryFixture.add(.page(.boardDate(.overdue, rule)), to:
            TodoQueryFixture.session("/routines on:today status:done"))
        #expect(overdue.typeAnalysis.assessment(for: .routine)?.reasons.isEmpty == true)
    }

    @Test func executionDayDoesNotTakeOverPageDateAndSurvivesHandoff() throws {
        var source = TodoQueryFixture.session("on:today status:open", page: .today(.init(dateScope: .today)))
        let on = try QuerySessionFixture.condition(.content(.on), in: source)
        let date = try QuerySessionFixture.condition(.content(.date), in: source)
        #expect(date.origin.isPage)
        #expect(source.pageProjection.extendedConditionIDs.contains(on.id))
        #expect(source.pageProjection.boardFilter?.dateScope == .today)
        let target = QuerySessionFixture.page(.overview, visit: "target", host: "other")
        let targetPage = ContentQueryPageContext(location: target.location, page: target.page,
                                                todayKey: "2026-10-02", calendar: target.calendar)
        let moved = source.handedOff(to: .init(page: targetPage))
        #expect(moved.occurrenceDay == .selected("2026-10-01"))
        #expect(moved.queryDates.todayKey == "2026-10-01")
        #expect(moved.conditions.first { $0.id == on.id } == on)
        #expect(moved.conditions.first { $0.id == date.id }?.origin == .handoffPage(source.page.location))
        #expect(moved.input == source.input)
        QuerySessionFixture.apply(.removeCondition(on.id), &source)
        #expect(source.occurrenceDay == .unspecified)
        #expect(source.conditions.contains { $0.id == date.id })
        #expect(!source.suppressed.contains(.content(.date)))
    }

    @Test func todayUsesInjectedCalendarAndProtectedTextRemainsLiteral() {
        let base = QuerySessionFixture.page(.overview)
        var calendar = base.calendar
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let page = ContentQueryPageContext(location: base.location, page: base.page, todayKey: "2024-02-29", calendar: calendar)
        var session = ContentQuerySession(page: page)
        QuerySessionFixture.apply(.setInput("/routines on:today"), &session)
        #expect(session.occurrenceDay == .selected("2024-02-29"))
        let invalid = ContentQueryParser().parse("on:today", context: .init(todayKey: "2024-02-29", calendar: Calendar(identifier: .buddhist)))
        if case .content(let query) = invalid { #expect(!query.isStructurallyValid) }
        else { Issue.record("expected content") }
        let protected = TodoQueryFixture.session(#"`on:today` "on:today" on\:today"#)
        #expect(protected.occurrenceDay == .unspecified)
        #expect(protected.isStructurallyValid)
    }
}
