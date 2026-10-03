import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TagUsageContentQueryFailureTests {
    @Test(arguments: [CommandObjectType.todo, .subtask, .routine, .diary, .tag],
          [ContentQuerySourceCoverage.notProvided, .failed, .partial])
    func sourceGapsNeverPublishExactCounts(type: CommandObjectType, state: ContentQuerySourceCoverage) async throws {
        let probe = TagUsageReadProbe()
        probe.replacement = (type, state)
        let f = try SearchReadFixture.tagUsage(configure: probe.configure)
        let tag = f.data.tags.tag()
        f.data.diary().tagIDs = tag.id.uuidString
        let prepared = try f.prepareUsage(view: .catalog(.unused))
        #expect(prepared.details.sources[type] == state)
        #expect(!prepared.details.issues.isEmpty)
        try f.session.evaluate(prepared.handle)
        try await f.session.publish(prepared.handle)
        let publication = try f.session.presentation()
        #expect(publication.response.matches.isEmpty)
        #expect(!publication.response.completeness.matchingIsComplete)
        if type != .tag {
            let response = try SearchReadFixture.usageResponse(publication)
            #expect(response.coverage.usage == .partial(completeTagIDs: []))
            #expect(response.undeterminedObjects.map(\.id) == [tag.id])
        }
    }

    @Test(arguments: ["todo", "subtask", "routine", "diary", "tag", "orphan", "missingTag", "tagFormat", "date", "deletedDate"])
    func malformedRowsAreNotSilentlyDropped(kind: String) async throws {
        let f = try SearchReadFixture.tagUsage()
        let tag = f.data.tags.tag()
        let todo = f.data.tags.family.task.todo()
        todo.tagIDs = tag.id.uuidString
        let child = f.data.tags.family.task.child(todo)
        let routine = f.data.tags.family.routine()
        let diary = f.data.diary()
        switch kind {
        case "todo": f.data.tags.family.task.todo().id = todo.id
        case "subtask": f.data.tags.family.task.child(todo).id = child.id
        case "routine": f.data.tags.family.routine().id = routine.id
        case "diary": f.data.diary().id = diary.id
        case "tag": f.data.tags.tag(id: tag.id)
        case "orphan": child.todo = nil
        case "missingTag": diary.tagIDs = UUID().uuidString
        case "tagFormat": diary.tagIDs = tag.id.uuidString + ",,broken"
        case "date": diary.createdAt = Date(timeIntervalSince1970: .nan)
        default: child.deletedAt = Date(timeIntervalSince1970: .infinity)
        }
        let prepared = try f.prepareUsage()
        #expect(!prepared.details.issues.isEmpty)
        try f.session.evaluate(prepared.handle)
        try await f.session.publish(prepared.handle)
        let response = try SearchReadFixture.usageResponse(f.session.presentation())
        #expect(response.coverage.usage == .partial(completeTagIDs: []))
        #expect(response.matches.allSatisfy { $0.usage == nil && $0.usageState == .partial })
        if kind != "tag" { #expect(response.ordering.applied == .inputOrder && !response.ordering.isComplete) }
    }

    @Test func failedRereadWithdrawsEarlierCompleteResult() async throws {
        let probe = TagUsageReadProbe()
        let f = try SearchReadFixture.tagUsage(configure: probe.configure)
        let tag = f.data.tags.tag()
        f.data.diary().tagIDs = tag.id.uuidString
        let old = try await f.publishUsage()
        probe.replacement = (.diary, .failed)
        let handle = try f.prepareUsage().handle
        #expect(!f.session.hasRetainedPresentation)
        try f.session.evaluate(handle)
        try await f.session.publish(handle)
        let current = try SearchReadFixture.usageResponse(f.session.presentation())
        #expect(current.matches[0].usage == nil && current.matches[0].usageState == .partial)
        #expect(current.ordering.applied == .inputOrder)
        #expect(try SearchReadFixture.usageResponse(old).matches[0].usage?.activeCount == 1)
    }

    @Test func falselyCompleteSubsetIsRejectedAtStorageBoundary() throws {
        let f = try SearchReadFixture.tagUsage { $0.diaries = { .complete([]) } }
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareUsage() }
        #expect(!f.session.hasPublicationPermit)
    }
}
