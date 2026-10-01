import Foundation
import Testing
@testable import AreaChain

struct ContentQueryContractTests {
    private func context(_ today: String = "2026-10-01", zone: String = "Asia/Shanghai") -> ContentQueryDateContext {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return .init(todayKey: today, calendar: calendar)
    }

    @Test func todayFixedDatesAndInclusiveIntervals() throws {
        let today = try ContentQueryDates.parse("today", context: context()).get()
        #expect(today == .init(lowerBound: "2026-10-01", upperBound: "2026-10-01"))
        let range = try ContentQueryDates.parse("2026-10-01..2026-10-07", context: context()).get()
        #expect(range.lowerBound == "2026-10-01" && range.upperBound == "2026-10-07")
        #expect(range.intersection(.init(lowerBound: "2026-10-07", upperBound: "2026-10-09")) ==
                .init(lowerBound: "2026-10-07", upperBound: "2026-10-07"))
        #expect(try ContentQueryDates.parse("2024-02-29", context: context()).get().lowerBound == "2024-02-29")
        #expect(try ContentQueryDates.parse("2000-02-29", context: context()).get().lowerBound == "2000-02-29")
    }

    @Test func invalidAndReversedDatesAreDiagnosed() {
        let cases: [(String, ContentQueryDates.Failure)] = [
            ("2026-02-29", .invalidDate), ("1900-02-29", .invalidDate), ("2026-04-31", .invalidDate),
            ("2026-13-01", .invalidDate), ("2026-00-01", .invalidDate), ("2026-10-00", .invalidDate),
            ("2026-1-01", .invalidDate), ("2026-10-01T00:00:00Z", .invalidDate),
            ("yesterday", .invalidDate), ("tomorrow", .invalidDate), ("", .incompleteCondition),
            ("2026-10-01..", .incompleteCondition), ("..2026-10-01", .incompleteCondition),
            ("2026-10-07..2026-10-01", .reversedDateInterval),
            ("2026-10-01..2026-10-07..2026-10-09", .invalidDate)
        ]
        for (text, issue) in cases {
            #expect(ContentQueryDates.parse(text, context: context()) == .failure(issue), "\(text)")
        }
        #expect(ContentQueryDates.parse("today", context: context("2026-02-30")) == .failure(.invalidDateContext))
    }

    @Test func relativeDatesUseInjectedCivilDayAndCalendar() throws {
        for zone in ["Asia/Shanghai", "America/Los_Angeles", "Pacific/Kiritimati"] {
            let actual = try ContentQueryDates.parse("today", context: context("2026-03-08", zone: zone)).get()
            #expect(actual.lowerBound == "2026-03-08")
        }
        let next = try ContentQueryDates.parse("today", context: context("2030-12-31")).get()
        #expect(next.lowerBound == "2030-12-31")
        let unsupported = ContentQueryDateContext(todayKey: "2026-10-01", calendar: Calendar(identifier: .buddhist))
        #expect(ContentQueryDates.parse("today", context: unsupported) == .failure(.invalidDateContext))
    }

    @Test func scopeCompositionIsExplicitAndDoesNotChangeDiscovery() {
        let tasks = ContentQueryScopeContract.composition(.catalog(.tasks))
        #expect(tasks.types == [.todo, .subtask, .routine])
        #expect(tasks.routines == .enabledOnly && tasks.includesCompletedTasks)
        #expect(tasks.deletion == .liveOnly)
        #expect(CommandContentScope.tasks.inclusion == .ordinaryContent)
        #expect(ContentQueryScopeContract.composition(.catalog(.tasks), includeInactiveRoutines: true).routines == .enabledAndDisabled)
        #expect(ContentQueryScopeContract.composition(.catalog(.subtasks)).types == [.subtask])
        let routines = ContentQueryScopeContract.composition(.catalog(.routines))
        #expect(routines.types == [.routine] && routines.routines == .enabledAndDisabled)
        #expect(routines.requiresRoutineEnabledPresentation)
        let global = ContentQueryScopeContract.composition(.global)
        #expect(!global.types.contains(.routineOccurrence) && !global.types.contains(.clipboardEntry))
        #expect(global.deletion == .liveOnly && !global.restrictsCommandDiscovery)
        #expect(ContentQueryScopeContract.composition(.routineOccurrences).types == [.routineOccurrence])
        #expect(ContentQueryScopeContract.composition(.catalog(.clipboard)).types == [.clipboardEntry])
        #expect(ContentQueryScopeContract.composition(.catalog(.trash)).deletion == .deletedOnly)
        #expect(CommandCatalog.standard.discover(contentScopes: [.tasks]) == CommandCatalog.standard.entries)
    }

    @Test func businessDatesMapToActualFieldsOrProviderProjection() {
        let cases: [(CommandObjectType, ContentQueryFieldBinding)] = [
            (.todo, .scheduledDay), (.subtask, .parentScheduledDay), (.diary, .diaryDay),
            (.routineOccurrence, .occurrenceDay), (.routine, .scheduledDayExistenceReturningOneDefinition),
            (.image, .ownerBusinessDay), (.clipboardEntry, .capturedDay), (.tag, .notApplicable)
        ]
        for (type, expected) in cases {
            #expect(ContentQueryApplicability.binding(.date, to: type) == expected)
        }
        for type in [CommandObjectType.todo, .subtask, .routine, .diary, .image] {
            #expect(ContentQueryApplicability.binding(.created, to: type) == .createdAt)
        }
        for type in [CommandObjectType.tag, .routineOccurrence, .clipboardEntry] {
            #expect(ContentQueryApplicability.binding(.created, to: type) == .notApplicable)
        }
    }

    @Test func statusNeverConfusesEnabledDefinitionsWithCompletion() {
        #expect(ContentQueryApplicability.binding(.status, to: .todo) == .ownCompletion)
        #expect(ContentQueryApplicability.binding(.status, to: .subtask) == .ownCompletion)
        #expect(ContentQueryApplicability.binding(.status, to: .routine) == .requiresOccurrenceDay)
        #expect(ContentQueryApplicability.binding(.status, to: .routine, occurrenceDay: "2026-10-01") == .routineCompletionOnDay("2026-10-01"))
        #expect(ContentQueryApplicability.binding(.status, to: .routine, occurrenceDay: "2026-02-30") == .requiresOccurrenceDay)
        #expect(ContentQueryApplicability.binding(.status, to: .routineOccurrence) == .occurrenceCompletion)
        for type in [CommandObjectType.diary, .tag, .image, .clipboardEntry] {
            #expect(ContentQueryApplicability.binding(.status, to: type) == .notApplicable)
        }
    }

    @Test func unsupportedFieldsAreNotInheritedOrFabricated() {
        for type in [CommandObjectType.subtask, .diary, .tag, .image, .clipboardEntry, .routineOccurrence] {
            #expect(ContentQueryApplicability.binding(.priority, to: type) == .notApplicable)
            #expect(ContentQueryApplicability.binding(.reminder, to: type) == .notApplicable)
        }
        #expect(ContentQueryApplicability.binding(.tag, to: .image) == .notApplicable)
        #expect(ContentQueryApplicability.binding(.tag, to: .clipboardEntry) == .notApplicable)
        #expect(ContentQueryApplicability.binding(.image, to: .subtask) == .notApplicable)
        #expect(ContentQueryApplicability.binding(.image, to: .todo) == .attachedImage)
        #expect(ContentQueryApplicability.binding(.image, to: .clipboardEntry) == .clipboardImage)
    }
}

extension ContentQueryContractTests {
    @Test func applicabilityRetainsTheConditionLocationAndRequiresExplicitDay() throws {
        let source = "/tasks status:open date:today"
        guard case .content(let query) = ContentQueryParser().parse(source, context: context()) else {
            Issue.record("expected content query"); return
        }
        let requirements = ContentQueryApplicability.requirements(for: query, type: .routine)
        #expect(requirements.count == 2)
        #expect(requirements[0].binding == .requiresOccurrenceDay)
        #expect(!requirements[0].isApplicable)
        #expect((source as NSString).substring(with: requirements[0].range) == "status:open")
        #expect(requirements[1].binding == .scheduledDayExistenceReturningOneDefinition)
        let explicit = ContentQueryApplicability.requirements(for: query, type: .routine, occurrenceDay: "2026-10-01")
        #expect(explicit[0].binding == .routineCompletionOnDay("2026-10-01"))
        #expect(explicit.allSatisfy { $0.isApplicable })
        let diary = ContentQueryApplicability.requirements(for: query, type: .diary)
        #expect(diary[0].binding == .notApplicable)
        #expect(!diary[0].isApplicable)
    }
}
