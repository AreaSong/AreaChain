import Foundation
import Testing
@testable import AreaChain

struct ContentQueryBatchCompletenessTests {
    @Test func missingPrimarySourceKeepsOtherCertainResults() throws {
        var batch = QueryBatchFixture.mixed()
        batch.snapshots.routines = .notProvided
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.matches.map(\.id.type) == [.todo, .subtask, .diary, .image, .tag])
        #expect(!result.completeness.matchingIsComplete)
        let routine = try #require(result.completeness.providers.first { $0.provider == .routine })
        #expect(routine.evaluatedTypes.isEmpty && routine.limitations == [.source(.routine, .notProvided)])
        #expect(!result.readings.contains { $0.provider == .routine })
        #expect(result.completeness.requestedTypes.contains(.routine))
    }

    @Test func completeEmptyDiffersFromUnavailableFailedAndPartialEmpty() {
        let full = ContentQueryBatchReader.read(QueryBatchFixture.empty())
        #expect(full.canDeclareCompleteNoMatch && full.definiteMatchCount == 0)
        for source in [ContentQueryBatchSource<TagQuerySnapshot>.notProvided, .failed, .partial([])] {
            var batch = QueryBatchFixture.empty()
            batch.snapshots.tags = source
            let result = ContentQueryBatchReader.read(batch)
            #expect(result.definiteMatchCount == 0 && !result.canDeclareCompleteNoMatch)
            #expect(result.completeness.providers.contains { $0.limitations.contains(.source(.tag, source.coverage)) })
        }
    }

    @Test func partialInputDoesNotBecomeCompleteAfterDuplicatesAreIsolated() {
        var batch = QueryBatchFixture.mixed("/tags")
        let tag = batch.snapshots.tags.values![0]
        batch.snapshots.tags = .partial([tag, tag])
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.matches.isEmpty && !result.canDeclareCompleteNoMatch)
        #expect(result.consistencyIssues == [.conflictingIdentity(provider: .tag, object: .init(type: .tag, id: tag.id))])
        #expect(result.completeness.providers[0].limitations.contains(.source(.tag, .partial)))
        guard case .tag(let reading) = result.readings.first else { Issue.record("缺少标签读取"); return }
        #expect(reading.diagnostics.contains { $0.issue == .duplicateTagID && $0.inputIndices == [0, 1] })
    }

    @Test func oneTypeContradictionDoesNotSuppressFeasibleChild() {
        let session = TodoQueryFixture.session("/tasks status:done", page: .pending(lane: .overdue, filter: .init()))
        var batch = QueryBatchFixture.replacingSession(QueryBatchFixture.mixed(), session)
        var todo = batch.snapshots.todos.values![0]
        todo.dayKey = "2026-09-30"
        var child = batch.snapshots.subtasks.values![0]
        child.isDone = true
        batch.snapshots.todos = .complete([todo]); batch.snapshots.subtasks = .complete([child])
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.matches.map(\.id.type) == [.subtask])
        #expect(result.completeness.requestedTypes == [.todo, .subtask, .routine])
        #expect(result.completeness.possibleTypes == [.subtask, .routine])
        #expect(result.completeness.evaluatedTypes == [.subtask])
        #expect(result.typeAnalysis.assessment(for: .todo)?.readRestriction == .unsatisfiable)
        #expect(result.typeAnalysis.assessment(for: .routine)?.readRestriction == .requiresInput)
        #expect(!result.completeness.matchingIsComplete)
    }

    @Test func nestedSecondSubtaskSourceIsRejectedAndOtherTypesStillRead() {
        var batch = QueryBatchFixture.mixed()
        var todo = batch.snapshots.todos.values![0]
        todo.subtasks = batch.snapshots.subtasks.values!
        batch.snapshots.todos = .complete([todo])
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.consistencyIssues.contains(.nestedSubtaskInput))
        #expect(!result.matches.contains { [.todo, .subtask, .image].contains($0.id.type) })
        #expect(result.matches.map(\.id.type) == [.routine, .diary, .tag])
        #expect(!result.completeness.matchingIsComplete)
    }

    @Test func orphanChildIsNotSilentlyDroppedFromCoverage() {
        var batch = QueryBatchFixture.empty("/subtasks")
        batch.snapshots.subtasks = .complete([TrashFixture.child(deleted: nil)])
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.consistencyIssues.contains(.uncontainedSubtasks))
        #expect(!result.canDeclareCompleteNoMatch)
    }

    @Test func frequentOrderingFallbackDoesNotInvalidateKnownMembership() {
        var batch = QueryBatchFixture.mixed("/tags")
        batch.options.tagView = .catalog(.frequent)
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.definiteMatchCount == 1 && result.completeness.matchingIsComplete)
        guard case .tag(let reading) = result.readings.first else { Issue.record("缺少标签读取"); return }
        #expect(!reading.ordering.isComplete && reading.ordering.applied == .inputOrder)
        #expect(!reading.isCompleteForCoveredTypes)
        #expect(result.completeness.providers[0].hints.contains(.tagOrdering(reading.ordering)))
        batch.options.tagView = .catalog(.unused)
        let unused = ContentQueryBatchReader.read(batch)
        #expect(unused.matches.isEmpty && !unused.canDeclareCompleteNoMatch)
    }

    @Test func inputOrderPreservedAndProvidersCannotBeCollectedTwice() {
        var batch = QueryBatchFixture.mixed("/tasks")
        let first = TodoQueryFixture.todo(2)
        let second = TodoQueryFixture.todo(1)
        batch.snapshots.todos = .complete([first, second])
        batch.snapshots.subtasks = .complete([])
        for _ in 0..<2 {
            let result = ContentQueryBatchReader.read(batch)
            #expect(result.matches.prefix(2).map(\.id.id) == [first.id, second.id])
            #expect(result.readings.map(\.provider) == [.todo, .subtask, .routine])
            #expect(result.definiteMatchCount == 3)
        }
    }

    @Test func explicitClipboardModeUsesBatchSessionAndRejectsSecondTextSource() {
        var batch = QueryBatchFixture.mixed("/clipboard")
        batch.options.clipboardMode = .explicit(.regex, needle: "batch.*")
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.definiteMatchCount == 1 && result.completeness.matchingIsComplete)
        batch = QueryBatchFixture.replacingSession(batch, TodoQueryFixture.session("/clipboard second-text"))
        let invalid = ContentQueryBatchReader.read(batch)
        #expect(invalid.readings.isEmpty && !invalid.canDeclareCompleteNoMatch)
        #expect(invalid.completeness.providers[0].limitations.contains(.clipboardMode(.conflictingTextConditions)))
    }
}
