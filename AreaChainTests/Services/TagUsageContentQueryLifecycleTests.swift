import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TagUsageContentQueryLifecycleTests {
    @Test(arguments: ["tagIDs", "createdAt", "deletedAt", "protected", "catalog", "insert", "parent"])
    func sourceChangesWithdrawStatisticsAndFrozenCopiesRemainUnchanged(kind: String) async throws {
        let f = try SearchReadFixture.tagUsage()
        let tag = f.data.tags.tag()
        let todo = f.data.tags.family.task.todo()
        let child = f.data.tags.family.task.child(todo)
        let diary = f.data.diary()
        diary.tagIDs = tag.id.uuidString
        let original = try await f.publishUsage()
        switch kind {
        case "tagIDs": diary.tagIDs = ""
        case "createdAt": diary.createdAt = TodoQueryFixture.created.addingTimeInterval(1)
        case "deletedAt": diary.deletedAt = TodoQueryFixture.created
        case "protected": diary.isPrivate = true
        case "catalog": tag.isPrivateDiary = true
        case "insert": f.data.diary().tagIDs = tag.id.uuidString
        default: child.todo = nil
        }
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.presentation() }
        #expect(!f.session.hasRetainedPresentation && !f.session.hasPublicationPermit)
        #expect(try SearchReadFixture.usageResponse(original).matches[0].usage?.activeCount == 1)
        let new = try await f.publishUsage()
        #expect(new.task.source != original.task.source && new.task.requestID == original.task.requestID)
        if kind == "insert" { #expect(try SearchReadFixture.usageResponse(new).matches[0].usage?.activeCount == 2) }
    }

    @Test func willLockAndUnlockNeverRestoreOldCountOrRanking() async throws {
        let f = try SearchReadFixture.tagUsage()
        try await f.unlock()
        f.data.tags.tag()
        _ = try await f.publishUsage()
        let old = try f.prepareUsage().handle
        try f.session.evaluate(old)
        f.vault.lock()
        #expect(!f.session.hasRetainedPresentation && !f.session.hasPublicationPermit)
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(old) }
        try f.expectEmpty()
        try await f.unlock()
        #expect(!f.session.hasRetainedPresentation && !f.session.hasPublicationPermit)
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(old) }
    }

    @Test func focusModelNotificationsAndOldHandlesUseExistingGate() async throws {
        let f = try SearchReadFixture.tagUsage()
        f.data.tags.tag()
        let old = try f.prepareUsage().handle
        try f.session.evaluate(old)
        let fresh = try f.prepareUsage().handle
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(old) }
        try f.session.evaluate(fresh)
        try await f.session.publish(fresh)
        try f.session.loseFocus(expecting: f.lease.ownership)
        #expect(!f.session.hasPublicationPermit && !f.session.hasRetainedPresentation)
        try f.session.resumeDisplay(expecting: f.lease)
        #expect(!f.session.hasPublicationPermit)
        _ = try await f.publishUsage()
        f.model.post(name: .boardDidChange, object: nil)
        #expect(!f.session.hasPublicationPermit && !f.session.hasRetainedPresentation)
        _ = try await f.publishUsage()
        try f.session.modelDidChange(expecting: f.lease.ownership)
        #expect(!f.session.hasPublicationPermit && !f.session.hasRetainedPresentation)
    }

    @Test(arguments: ["mutation", "focus", "query", "privacy"])
    func changesInsideFetchCannotBeRestampedAsFresh(kind: String) throws {
        let probe = TagUsageReadProbe()
        let f = try SearchReadFixture.tagUsage(configure: probe.configure)
        let todo = f.data.tags.family.task.todo()
        probe.after = {
            switch kind {
            case "mutation": todo.createdAt = TodoQueryFixture.created.addingTimeInterval(10)
            case "focus": try f.session.loseFocus(expecting: f.lease.ownership)
            case "query": try f.handoff.send(.query(.setInput("/tags changed")))
            default: f.vault.lock()
            }
        }
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareUsage() }
        #expect(!f.session.hasPublicationPermit && !f.session.hasRetainedPresentation)
    }

    @Test func cancelReleasesPublishedStatisticsButPreservesQuery() async throws {
        let f = try SearchReadFixture.tagUsage()
        f.data.tags.tag()
        _ = try await f.publishUsage()
        let handle = try f.prepareUsage().handle
        try f.session.cancel(handle)
        #expect(!f.session.hasPublicationPermit && !f.session.hasRetainedPresentation)
        #expect(try QuerySessionFixture.source(f.query) == "/tags")
    }
}
