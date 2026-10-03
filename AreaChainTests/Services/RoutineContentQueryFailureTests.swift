import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct RoutineContentQueryFailureTests {
    private enum Failure: Error { case rawDatabaseBodyAndIdentity }

    @Test func checkFailureWithNoDefinitionsDoesNotBecomeCompleteEmpty() throws {
        let f = try RoutineContentQueryFixture()
        var reads = RoutineContentQueryReads(context: f.context)
        reads.allChecks = { throw Failure.rawDatabaseBodyAndIdentity }
        let failed = f.records(reads: reads)
        #expect(failed.routine.checkSource == .failed && failed.routine.issues == [.checkFetchFailed])
        #expect(failed.batch.facts.routine.checkSourceProblem == .readFailed)
        #expect(!ContentQueryBatchReader.read(failed.batch).canDeclareCompleteNoMatch)
        let complete = f.records()
        #expect(complete.routine.checkSource == .complete && complete.routine.issues.isEmpty)
        #expect(ContentQueryBatchReader.read(complete.batch).canDeclareCompleteNoMatch)
        #expect(!String(reflecting: failed).contains("rawDatabase"))
        #expect(!String(reflecting: failed.routine.issues).contains("rawDatabase"))
    }

    @Test func definitionFailureKeepsObservedRowsAndIndependentTasks() throws {
        let f = try RoutineContentQueryFixture()
        let parent = f.routine()
        let row = f.check(parent)
        f.task.todo()
        var reads = RoutineContentQueryReads(context: f.context)
        reads.definitions = { throw Failure.rawDatabaseBodyAndIdentity }
        let failed = f.records(reads: reads)
        #expect(failed.batch.snapshots.routines.coverage == .failed)
        #expect(failed.batch.facts.routine.checks == [row.snapshot!])
        #expect(failed.batch.facts.routine.checkCoverage.isEmpty)
        #expect(failed.routine.checkSource == .partial && !failed.routine.issues.isEmpty)
        let tasks = f.read("/tasks needle", reads: reads)
        #expect(ContentQueryBatchReader.read(tasks.batch).definiteMatchCount == 1)
        #expect(!ContentQueryBatchReader.read(tasks.batch).completeness.matchingIsComplete)
    }

    @Test(arguments: ["/go/tasks", "/diaries needle", "/images needle", "/tags needle", "/clipboard needle"])
    func unrelatedScopeNeverTouchesTaskFamily(source: String) throws {
        let f = try RoutineContentQueryFixture()
        var tasks = TaskContentQueryReads(context: f.context)
        var reads = RoutineContentQueryReads(context: f.context)
        tasks.todos = { Issue.record("unexpected todos"); return [] }
        tasks.subtasks = { Issue.record("unexpected subtasks"); return [] }
        tasks.tags = { _ in Issue.record("unexpected tags"); return [] }
        reads.definitions = { Issue.record("unexpected definitions"); return [] }
        reads.allChecks = { Issue.record("unexpected checks"); return [] }
        let result = f.read(source, reads: reads, tasks: tasks)
        #expect(result.batch.snapshots.routines.coverage == .notProvided && result.tagNamesCoverage == .notProvided)
    }

    @Test(arguments: ["missing", "duplicate", "private", "failed"])
    func routineTagNamesKeepOriginalFailureAndPrivacyBoundary(mode: String) throws {
        let f = try RoutineContentQueryFixture()
        let tag = TagItem(name: "工作", sortOrder: 0)
        let routine = f.routine()
        routine.tagIDs = TagIDList.encode([tag.id])
        if mode != "missing" { f.context.insert(tag) }
        if mode == "duplicate" { f.context.insert(TagItem(id: tag.id, name: tag.name, sortOrder: 1)) }
        if mode == "private" { tag.isPrivateDiary = true }
        var tasks = TaskContentQueryReads(context: f.context)
        if mode == "failed" { tasks.tags = { _ in throw Failure.rawDatabaseBodyAndIdentity } }
        let result = f.read("/routines #工作", tasks: tasks)
        #expect(result.batch.facts.metadata.tagNames == nil && !result.tagIssues.isEmpty)
        #expect(result.tagNamesCoverage == (mode == "failed" ? .failed : .partial))
        #expect(result.batch.snapshots.tags.coverage == .notProvided && result.batch.facts.metadata.privateTagIDs == nil)
        #expect(try RoutineContentQueryFixture.definitions(result).undeterminedObjects.count == 1)
        #expect(!String(reflecting: result.tagIssues).contains(tag.id.uuidString))
    }
}
