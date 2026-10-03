import Foundation
import Testing
@testable import AreaChain

struct ContentQueryBatchSelectionTests {
    @Test func tagOnlyTrashDoesNotReadUnrelatedFamiliesOrPictures() {
        var batch = QueryBatchFixture.trash()
        var todo = TrashFixture.todo()
        todo.subtasks = [TrashFixture.child()]
        batch.snapshots.todos = .complete([todo])
        var image = TrashFixture.image()
        image.ownerKind = "invalid-kind"
        batch.snapshots.images = .complete([image])
        batch.snapshots.tags = .complete([.init(id: QueryBatchFixture.id, name: "archive", deletedAt: TrashFixture.date)])
        batch = QueryBatchFixture.replacingSession(batch,
            TodoQueryFixture.add(.page(.contentTypes([.tag])), to: batch.session))
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.matches.map(\.id.type) == [.tag] && result.consistencyIssues.isEmpty)
        guard case .trash(let reading) = result.readings.first else { Issue.record("缺少墓碑读取"); return }
        #expect(reading.readingDiagnostics.isEmpty)
    }

    @Test func parserSessionBatchReadsAllOrdinaryTypesWithOneIdentityPerType() {
        let batch = QueryBatchFixture.mixed()
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.queryState == .content)
        #expect(result.readings.map(\.provider) == [.todo, .subtask, .routine, .diary, .image, .tag])
        #expect(result.matches.map(\.id.type) == [.todo, .subtask, .routine, .diary, .image, .tag])
        #expect(Set(result.matches.map(\.id)).count == 6)
        #expect(Set(result.matches.map(\.id.id)) == [QueryBatchFixture.id])
        #expect(result.definiteMatchCount == 6 && result.completeness.matchingIsComplete)
        #expect(result.completeness.requestedTypes == result.completeness.evaluatedTypes)
        #expect(result.order == .temporaryProviderThenInput)
        #expect(result.consistencyIssues.isEmpty)
        #expect(batch.snapshots.todos.values?.first?.subtasks.isEmpty == true)
        for match in result.matches {
            #expect(Set(QueryBatchFixture.evidence(match).map(\.conditionID)) == Set(batch.session.conditions.map(\.id)))
        }
    }

    @Test func tasksAndExplicitSingleTypesChooseOnlyRequiredProviders() {
        let cases: [(String, [ContentQueryProviderID])] = [
            ("/tasks", [.todo, .subtask, .routine]), ("/subtasks", [.subtask]),
            ("/routines", [.routine]), ("/diaries", [.diary]), ("/images", [.image]),
            ("/tags", [.tag]), ("/clipboard", [.clipboard]), ("/trash", [.trash])
        ]
        for (source, providers) in cases {
            let result = ContentQueryBatchReader.read(QueryBatchFixture.mixed(source))
            #expect(result.readings.map(\.provider) == providers)
            #expect(Set(result.readings.map(\.provider)).count == result.readings.count)
        }
        let todoSession = TodoQueryFixture.add(.page(.contentTypes([.todo])), to: TodoQueryFixture.session())
        let todo = ContentQueryBatchReader.read(QueryBatchFixture.replacingSession(QueryBatchFixture.mixed(), todoSession))
        #expect(todo.readings.map(\.provider) == [.todo])
        #expect(ContentQueryBatchReader.read(QueryBatchFixture.occurrences()).readings.map(\.provider) == [.routineOccurrence])
    }

    @Test func noNeedToReadOtherSourcesOrSpecialModes() {
        var batch = QueryBatchFixture.empty("/tags")
        batch.snapshots.todos = .failed
        batch.snapshots.subtasks = .failed
        batch.snapshots.diaries = .failed
        batch.snapshots.routines = .failed
        batch.snapshots.images = .failed
        batch.snapshots.clipboard = .failed
        batch.options.clipboardMode = .explicit(.regex, needle: "[")
        batch.options.occurrenceBudget.maxWork = -1
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.readings.map(\.provider) == [.tag])
        #expect(result.canDeclareCompleteNoMatch)
        #expect(result.consistencyIssues.isEmpty)
    }

    @Test func commandAndMalformedInputNeverExecuteProviders() {
        for source in ["/clipboard/search", "/tasks \"unfinished", "/tasks date:2026-02-30"] {
            let result = ContentQueryBatchReader.read(QueryBatchFixture.mixed(source))
            #expect(result.queryState != .content)
            #expect(result.readings.isEmpty && result.matches.isEmpty)
            #expect(!result.canDeclareCompleteNoMatch)
        }
        let command = ContentQueryBatchReader.read(QueryBatchFixture.mixed("/clipboard/search"))
        #expect(command.queryState == .commandInput)
    }

    @Test func structuredAndFrozenConditionsReachEveryRelevantProvider() {
        var batch = QueryBatchFixture.mixed("#工作")
        batch.facts.metadata = .init(tagNames: [TodoQueryFixture.work: "工作"], privateTagIDs: [])
        var todo = batch.snapshots.todos.values![0]
        todo.tagIDs = TagIDList.encode([TodoQueryFixture.work])
        var child = batch.snapshots.subtasks.values![0]
        child.tagIDs = todo.tagIDs
        var routine = batch.snapshots.routines.values![0]
        routine.tagIDs = todo.tagIDs
        var diary = batch.snapshots.diaries.values![0]
        diary.tagIDs = todo.tagIDs
        batch.snapshots.todos = .complete([todo]); batch.snapshots.subtasks = .complete([child])
        batch.snapshots.routines = .complete([routine]); batch.snapshots.diaries = .complete([diary])
        let session = TodoQueryFixture.add(.page(.contentTypes([.todo, .subtask, .routine, .diary, .image])), to: batch.session)
        let frozen = session.handedOff(to: TodoQueryFixture.session("", page: .tags))
        batch = QueryBatchFixture.replacingSession(batch, frozen)
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.definiteMatchCount == 5)
        #expect(batch.dates.todayKey == frozen.queryDates.todayKey && batch.dates.calendar == frozen.queryDates.calendar)
        for match in result.matches {
            #expect(Set(QueryBatchFixture.evidence(match).map(\.conditionID)) == Set(frozen.conditions.map(\.id)))
        }
    }

    @Test func definitionAndEachOccurrenceKeepDifferentBusinessIdentities() {
        let definition = ContentQueryBatchReader.read(QueryBatchFixture.mixed("/routines"))
        let records = ContentQueryBatchReader.read(QueryBatchFixture.occurrences("date:2026-10-01..2026-10-02"))
        #expect(records.matches.map(\.id.dayKey) == ["2026-10-01", "2026-10-02"])
        #expect(records.matches.allSatisfy { $0.id.type == .routineOccurrence && $0.id.id == QueryBatchFixture.id })
        #expect(Set((definition.matches + records.matches).map(\.id)).count == 3)
        #expect(definition.matches.first?.id.dayKey == nil)
    }
}
