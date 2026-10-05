import Darwin
import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized)
struct LocalPreferenceFileConcurrencyTests {
    @Test func sameThreadReentryIsRejectedAcrossInstancesAndLockReleaseAllowsCommit() throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        let store = try fixture.store()
        let second = try fixture.store()
        let directory = try LocalPreferenceFileIO(temporaryRoot: fixture.root)
        var lock: LocalPreferenceFileLock? = try LocalPreferenceFileLock.acquire(directory, creating: false)
        withExtendedLifetime(lock) {
            #expect(store.commit(basedOn: base, changes: [.language(.english)]) == .notCommitted(.reentrant))
            #expect(second.commit(basedOn: base, changes: [.language(.english)]) == .notCommitted(.reentrant))
        }
        #expect(try fixture.current() == base)
        lock = nil
        guard case .committed = second.commit(basedOn: base, changes: [.language(.english)]) else {
            Issue.record("重入结束释放锁后应可提交"); return
        }
    }

    @Test func twoConcurrentInstancesNeverSilentlyOverwriteSameOldRevision() async throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        let first = try fixture.store()
        let second = try fixture.store()
        let results = await withTaskGroup(of: LocalPreferenceFileCommit.self) { group in
            group.addTask { first.commit(basedOn: base, changes: [.language(.english)]) }
            group.addTask { second.commit(basedOn: base, changes: [.language(.chinese)]) }
            var results: [LocalPreferenceFileCommit] = []
            for await result in group { results.append(result) }
            return results
        }
        #expect(results.filter { if case .committed = $0 { return true }; return false }.count == 1)
        #expect(results.filter {
            if case .conflict = $0 { return true }
            return $0 == .notCommitted(.lockBusy)
        }.count == 1)
        #expect(try fixture.current().recordRevision == 2)
    }

    @Test func independentFileDescriptorLockBlocksProtocolAndDoesNotTouchOtherFiles() throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        let path = fixture.root.appendingPathComponent("writer.lock").path
        let descriptor = Darwin.open(path, O_RDWR)
        #expect(descriptor >= 0)
        defer { Darwin.close(descriptor) }
        #expect(flock(descriptor, LOCK_EX | LOCK_NB) == 0)
        let store = try fixture.store()
        let before = try fixture.inventory()
        #expect(store.commit(basedOn: base, changes: [.language(.english)]) == .notCommitted(.lockBusy))
        #expect(try fixture.inventory() == before)
        #expect(flock(descriptor, LOCK_UN) == 0)
        guard case .committed = store.commit(basedOn: base, changes: [.language(.english)]) else {
            Issue.record("释放后应能提交"); return
        }
    }

    @Test func symlinkCurrentAndForeignCandidateAreNeverDeletedOrUsed() throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        let other = try LocalPreferenceFileFixture()
        let otherBase = try other.seed()
        try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("current.json"))
        try FileManager.default.createSymbolicLink(at: fixture.root.appendingPathComponent("current.json"),
            withDestinationURL: other.root.appendingPathComponent("current.json"))
        #expect(try fixture.store().read() == .unavailable(.readFailed))
        #expect(try fixture.store().commit(basedOn: base, changes: [.language(.english)]) == .recoveryRequired(.unavailable(.readFailed)))
        #expect(try other.current() == otherBase)
    }
}
