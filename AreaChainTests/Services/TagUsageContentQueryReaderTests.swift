import Foundation
import Observation
import os
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TagUsageContentQueryReaderTests {
    @Test func allSourcesContributeAndMatchLegacyIncludingDuplicateTagsAndDeletedParent() async throws {
        let f = try SearchReadFixture.tagUsage()
        let tag = f.data.tags.tag()
        let task = f.data.tags.family.task.todo(deleted: TodoQueryFixture.created)
        task.tagIDs = tag.id.uuidString
        let child = f.data.tags.family.task.child(task)
        child.tagIDs = TagIDList.encode([tag.id, tag.id])
        let live = f.data.tags.family.task.todo()
        live.tagIDs = tag.id.uuidString
        let routine = f.data.tags.family.routine()
        routine.tagIDs = tag.id.uuidString
        routine.isEnabled = false
        let diary = f.data.diary()
        diary.tagIDs = tag.id.uuidString
        diary.isPrivate = true
        diary.encryptedText = Data([0, 1, 2]) // 无效合成密文：统计仍无需解密。
        diary.privacyVaultID = UUID()
        f.data.tags.family.task.child(task, deleted: TodoQueryFixture.created).tagIDs = tag.id.uuidString
        f.data.diary(deleted: TodoQueryFixture.created).tagIDs = tag.id.uuidString
        let expected = TagUsage.records(TagUsage.subjects(todos: [task, live], routines: [routine], diaries: [diary]))
        let result = try await f.publishUsage("/tags needle")
        let response = try SearchReadFixture.usageResponse(result)
        #expect(response.coverage.usage == .complete && response.matches.count == 1)
        #expect(response.matches[0].usage?.activeCount == 5)
        #expect(response.matches[0].usage?.activeCount == expected[tag.id]?.activeCount)
        #expect(result.response.matches.allSatisfy { $0.id.type == .tag })
        #expect(f.vault.configuration == nil && !f.vault.isUnlocked && !f.vault.isAuthenticating)
        #expect(await f.system.items.isEmpty)
    }

    @Test func sameBatchReusesFiveEnumerationsAndDoesNotReadChecksForStatistics() async throws {
        let probe = TagUsageReadProbe()
        let f = try SearchReadFixture.tagUsage(configure: probe.configure)
        let tag = f.data.tags.tag()
        f.data.tags.family.task.todo().tagIDs = tag.id.uuidString
        f.data.tags.family.routine().tagIDs = tag.id.uuidString
        f.data.diary().tagIDs = tag.id.uuidString
        let prepared = try f.prepareUsage("")
        #expect(prepared.details.usageOrigin == .stored)
        #expect(prepared.details.sources.count == 5 && prepared.details.sources.values.allSatisfy { $0 == .complete })
        #expect(probe.calls == [.todo: 1, .subtask: 1, .routine: 1, .diary: 1, .tag: 1])
        try f.session.evaluate(prepared.handle)
        try await f.session.publish(prepared.handle)
        let result = try f.session.presentation()
        #expect(try SearchReadFixture.usageResponse(result).matches[0].usage?.activeCount == 3)
        #expect(result.response.matches.contains { $0.id.type == .todo })
        #expect(result.response.matches.contains { $0.id.type == .routine })
        #expect(probe.calls.values.allSatisfy { $0 == 1 })
    }

    @Test(arguments: [TagQueryView.inputOrder, .catalog(.all)])
    func nameOnlyAndAllDoNotReadStatistics(view: TagQueryView) async throws {
        let probe = TagUsageReadProbe()
        let f = try SearchReadFixture.tagUsage(configure: probe.configure)
        f.data.tags.tag()
        let prepared = try f.prepareUsage("/tags needle", view: view)
        #expect(prepared.details.usageOrigin == .notProvided && prepared.details.sources.isEmpty)
        #expect(probe.calls.isEmpty)
        try f.session.evaluate(prepared.handle)
        try await f.session.publish(prepared.handle)
        #expect(try SearchReadFixture.usageResponse(f.session.presentation()).matches[0].usageState == .unavailable)
    }

    @Test func unassociatedCompleteSourcesAloneProveZero() async throws {
        let f = try SearchReadFixture.tagUsage()
        let tag = f.data.tags.tag()
        let response = try SearchReadFixture.usageResponse(await f.publishUsage(view: .catalog(.unused)))
        #expect(response.matches.map(\.tag.id) == [tag.id])
        #expect(response.matches[0].usage == .init(activeCount: 0) && response.matches[0].usageState == .complete)
    }

    @Test func statisticsNeverExplicitlyReadBodyAndBodyEditsDoNotAlterCounts() async throws {
        let f = try SearchReadFixture.tagUsage()
        let tag = f.data.tags.tag()
        let entry = f.data.diary("SYNTHETIC_BODY_NOT_READ")
        entry.tagIDs = tag.id.uuidString
        entry.isPrivate = true
        let observed = OSAllocatedUnfairLock(initialState: false)
        let prepared = withObservationTracking {
            Result { try f.prepareUsage() }
        } onChange: { observed.withLock { $0 = true } }
        entry.text = "SYNTHETIC_CHANGED_BODY"
        #expect(!observed.withLock { $0 })
        try f.session.evaluate(prepared.get().handle)
        try await f.session.publish(prepared.get().handle)
        #expect(try SearchReadFixture.usageResponse(f.session.presentation()).matches[0].usage?.activeCount == 1)
    }
}
