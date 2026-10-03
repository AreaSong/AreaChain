import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TrashContentQueryLifecycleTests {
    @Test(arguments: [false, true]) func focusLossAroundBodyReadRevokesPreparation(after: Bool) throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture.trash(bodies: { $0.observeContent = probe.observe })
        f.data.diary("ordinary", deleted: TodoQueryFixture.created)
        let revoke = { try f.session.loseFocus(expecting: f.lease.ownership) }
        if after { probe.after = revoke } else { probe.before = revoke }
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareTrash() }
        #expect(!f.session.hasPublicationPermit && !f.session.hasRetainedPresentation)
    }

    @Test(arguments: [0, 1, 2, 3, 4, 5]) func metadataOrProtectionChangeDuringReadRejectsOldEvidence(kind: Int) throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture.trash(bodies: { $0.observeContent = probe.observe })
        let task = f.data.tags.family.task.todo(deleted: TodoQueryFixture.created)
        let tag = f.data.tags.tag("ordinary")
        let entry = f.data.diary("ordinary", deleted: TodoQueryFixture.created)
        let child = f.data.tags.family.task.child(task, deleted: TodoQueryFixture.created)
        probe.after = {
            switch kind {
            case 0: entry.deletedAt = nil
            case 1: entry.isPrivate = true
            case 2: tag.isPrivateDiary = true
            case 3: f.data.diary("collision").id = entry.id
            case 4: child.todo = nil
            default: tag.name = "changed"
            }
        }
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareTrash() }
        #expect(!f.session.hasPublicationPermit)
    }

    @Test func mutationInsideFirstSourceCallbackIsNotRestamped() throws {
        var mutate: (() -> Void)?
        let f = try SearchReadFixture.trash { reads in
            let original = reads.todos
            reads.todos = { let values = try original(); mutate?(); return values }
        }
        let task = f.data.tags.family.task.todo(deleted: TodoQueryFixture.created)
        mutate = { task.deletedAt = nil }
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareTrash() }
    }

    @Test func afterFreezeMutationRevokesDisplayAndOldValueStaysFrozen() async throws {
        let f = try SearchReadFixture.trash()
        let entry = f.data.diary("ORIGINAL_PUBLIC_BODY", deleted: TodoQueryFixture.created)
        let image = f.image(.init(kind: .diary, id: entry.id), deleted: TodoQueryFixture.created)
        let publication = try await f.publishTrash()
        image.filename = "LATE_FILENAME.png"
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.presentation() }
        #expect(!f.session.hasRetainedPresentation)
        #expect(!TrashQueryFixture.strings(publication).contains("LATE_FILENAME.png"))
        _ = try await f.publishTrash()
        entry.text = "#password LATE_SECRET"
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.presentation() }
        #expect(!f.session.hasPublicationPermit)
    }

    @Test func sameRequestIDOldHandlesAndExternalReadableBatchesCannotUpgradeAuthority() async throws {
        let f = try SearchReadFixture.trash()
        f.data.diary("ordinary", deleted: TodoQueryFixture.created)
        let old = try f.prepareTrash().handle
        try f.session.evaluate(old)
        let current = try f.prepareTrash().handle
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(old) }
        try f.session.evaluate(current)
        try await f.session.publish(current)
        #expect(throws: ContentQueryReadSessionError.metadataOnlyRequired) {
            try f.session.prepare { query in
                var batch = ContentQueryBatch(requestID: TodoQueryFixture.requestID, session: query)
                batch.snapshots.diaries = .complete([.init(id: UUID(), text: "EXTERNAL_BODY", dayKey: QuerySessionFixture.today,
                    createdAt: TodoQueryFixture.created, deletedAt: TodoQueryFixture.created)])
                return batch
            }
        }
        #expect(!f.session.hasPublicationPermit)
    }

    @Test func willLockFocusAndTransferRejectLatePublicationWithoutRestoringResults() async throws {
        let f = try SearchReadFixture.trash()
        try await f.unlock()
        f.data.diary("PUBLIC_TOMBSTONE", deleted: TodoQueryFixture.created)
        let old = try f.prepareTrash().handle
        try f.session.evaluate(old)
        f.vault.lock()
        #expect(!f.session.hasPublicationPermit && !f.session.hasRetainedPresentation)
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(old) }
        try f.expectEmpty()
        try await f.unlock()
        #expect(!f.session.hasPublicationPermit)
        try f.handoff.send(.query(.enterPage(QuerySessionFixture.page(.overview, host: HandoffFixture.source))))
        _ = try await f.publishTrash()
        try f.session.loseFocus(expecting: f.lease.ownership)
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.presentation() }
        try f.session.resumeDisplay(expecting: f.lease)
        #expect(!f.session.hasPublicationPermit)
        let transferring = try f.prepareTrash().handle
        try f.session.evaluate(transferring)
        try f.handoff.transfer()
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(transferring) }
        #expect(!f.session.hasPublicationPermit)
    }

    @Test func reentryPreservesNewPreparationAndCancelDoesNotInvalidateQuery() async throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture.trash(bodies: { $0.observeContent = probe.observe })
        var newer: ContentQueryReadHandle?
        probe.after = { probe.after = nil; newer = try f.prepareTrash().handle }
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareTrash() }
        let handle = try #require(newer)
        try f.session.evaluate(handle)
        try await f.session.publish(handle)
        let query = try f.query
        let cancel = try f.prepareTrash().handle
        try f.session.cancel(cancel)
        #expect(!f.session.hasRetainedPresentation && !f.session.hasPublicationPermit)
        #expect(try f.query == query)
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(handle) }
    }
}
