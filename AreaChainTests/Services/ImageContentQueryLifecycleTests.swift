import Foundation
import Testing
import SwiftData
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ImageContentQueryLifecycleTests {
    @Test(arguments: [false, true]) func invalidationBeforeOrAfterOrdinaryProtectionReadRejectsBatch(after: Bool) throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture(imageMode: true, configure: { $0.observeContent = probe.observe })
        let entry = f.data.diary("ordinary")
        f.image(.init(kind: .diary, id: entry.id))
        let revoke = { try f.session.loseFocus(expecting: f.lease.ownership) }
        if after { probe.after = revoke } else { probe.before = revoke }
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareImages() }
        #expect(!f.session.hasPublicationPermit && !f.session.hasRetainedPresentation)
    }

    @Test func metadataChangesDuringOwnerFetchCannotBeRestamped() throws {
        var mutate: (() -> Void)?
        let f = try SearchReadFixture(imageMode: true, configureImages: { reads in
            let original = reads.tasks.todos
            reads.tasks.todos = { let rows = try original(); mutate?(); return rows }
        })
        let task = f.data.tags.family.task.todo()
        let image = f.image(.init(kind: .todo, id: task.id))
        mutate = { image.filename = "CHANGED.png" }
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareImages() }
        #expect(!f.session.hasPublicationPermit)
    }

    @Test(arguments: [0, 1, 2, 3, 4]) func mutationsAfterFreezeRevokeAtEvaluationOrDisplay(kind: Int) async throws {
        let f = try SearchReadFixture(imageMode: true)
        let task = f.data.tags.family.task.todo()
        let tag = f.data.tags.tag("ordinary")
        task.tagIDs = tag.id.uuidString
        let diary = f.data.diary("ordinary")
        let image = f.image(.init(kind: .todo, id: task.id))
        let handle = try f.prepareImages()
        try f.session.evaluate(handle)
        try await f.session.publish(handle)
        switch kind {
        case 0: image.filename = "STALE.png"
        case 1: task.title = "changed"
        case 2: tag.isPrivateDiary = true
        case 3: diary.text = "#password changed"
        default: f.image(.init(kind: .todo, id: task.id)).id = image.id
        }
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.presentation() }
        #expect(!f.session.hasRetainedPresentation && !f.session.hasPublicationPermit)
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(handle) }
    }

    @Test func ordinaryTextMutationAfterReadBeforeFreezeIsObservedWithoutCopyingText() throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture(imageMode: true, configure: { $0.observeContent = probe.observe })
        // 将所有已经读取过的普通行改为敏感；第一条正文的 Observation 必须撤销资格。
        probe.after = {
            let rows = try f.data.context.fetch(FetchDescriptor<DiaryEntry>())
            for row in rows { row.text = "#password CHANGED" }
        }
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareImages() }
        #expect(!f.session.hasPublicationPermit)
    }

    @Test func lockFocusTransferAndLatePublicationNeverRestoreFilenames() async throws {
        let f = try SearchReadFixture(imageMode: true)
        let task = f.data.tags.family.task.todo()
        f.image(.init(kind: .todo, id: task.id), name: "PREVIOUS_FILENAME.png")
        let handle = try f.prepareImages()
        try f.session.evaluate(handle)
        f.vault.lock()
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(handle) }
        try f.expectEmpty()
        await f.settle()
        try f.handoff.send(.query(.enterPage(QuerySessionFixture.page(.overview, host: HandoffFixture.source))))
        _ = try await f.publishImages()
        try f.session.loseFocus(expecting: f.lease.ownership)
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.presentation() }
        try f.session.resumeDisplay(expecting: f.lease)
        #expect(!f.session.hasPublicationPermit)
        let late = try f.prepareImages()
        try f.session.evaluate(late)
        try f.handoff.transfer()
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(late) }
    }

    @Test func reentryKeepsNewTaskAndCancellationClearsResults() async throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture(imageMode: true, configure: { $0.observeContent = probe.observe })
        var newer: ContentQueryReadHandle?
        probe.after = { probe.after = nil; newer = try f.prepareImages() }
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareImages() }
        let handle = try #require(newer)
        try f.session.evaluate(handle)
        try await f.session.publish(handle)
        let next = try f.prepareImages()
        try f.session.cancel(next)
        #expect(!f.session.hasPublicationPermit && !f.session.hasRetainedPresentation)
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(handle) }
    }
}
