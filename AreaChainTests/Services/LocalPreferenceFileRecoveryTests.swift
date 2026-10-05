import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized)
struct LocalPreferenceFileRecoveryTests {
    @Test(arguments: [LocalPreferenceFileFault.encoding, .temporaryWrite, .temporaryPartialWrite,
                      .pendingWrite, .pendingPartialWrite, .pendingRead, .qualification])
    func failuresBeforeReplacementLeaveWholeCurrentUnchanged(fault: LocalPreferenceFileFault) throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        let bytes = try fixture.bytes("current.json")
        let result = try fixture.store(fault).commit(basedOn: base, changes: [.language(.english), .appearance(.dark)])
        guard case .notCommitted = result else { Issue.record("替换前应明确未提交"); return }
        #expect(try fixture.current() == base && fixture.bytes("current.json") == bytes)
        if fault == .pendingRead || fault == .qualification {
            guard case .historicalUnknown(_, let current) = try fixture.store().verifyPendingCommit() else {
                Issue.record("重开仅见基记录不能追认历史未提交"); return
            }
            #expect(current == base)
        }
    }

    @Test(arguments: [LocalPreferenceFileFault.replaceBefore, .replaceAfter, .readback])
    func boundaryErrorsStayUnknownBlockFurtherWritesAndReopenWithoutReplay(fault: LocalPreferenceFileFault) throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        let store = try fixture.store(fault)
        guard case .unknown(let pending, _) = store.commit(basedOn: base, changes: [.language(.english), .appearance(.dark)]) else {
            Issue.record("越过调用边界应待核实"); return
        }
        let before = try fixture.inventory()
        guard case .recoveryRequired = store.commit(basedOn: base, changes: [.stampCaptureApp(true)]) else {
            Issue.record("未知不得再次写入"); return
        }
        #expect(try fixture.inventory() == before)
        let reopened = try fixture.store()
        if fault == .replaceBefore {
            #expect(reopened.verifyPendingCommit() == .historicalUnknown(pending, current: base))
            #expect(try fixture.inventory() == before)
        } else {
            let target = try fixture.current()
            #expect(target.values.language == .english && target.values.appearance == .dark)
            #expect(target.recordRevision == 2 && target.commitID == pending.target.commitID)
            #expect(reopened.verifyPendingCommit() == .confirmed(target))
            let after = try fixture.inventory()
            #expect(after["current.json"] == before["current.json"])
            #expect(reopened.verifyPendingCommit() == .nothingToVerify(.record(target)))
            #expect(try fixture.inventory() == after)
        }
    }

    @Test(arguments: [LocalPreferenceFileFault.cleanupBefore, .cleanupAfter])
    func cleanupFailureDoesNotChangeCommitFactAndRetryOnlyCleans(fault: LocalPreferenceFileFault) throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        guard case .committedCleanupPending(let target) = try fixture.store(fault).commit(basedOn: base, changes: [.stampCaptureApp(true)]) else {
            Issue.record("清理失败仍已保存"); return
        }
        let before = try fixture.inventory()
        let result = try fixture.store().verifyPendingCommit()
        #expect(result == (fault == .cleanupBefore ? .confirmed(target) : .nothingToVerify(.record(target))))
        #expect(try fixture.inventory()["current.json"] == before["current.json"])
        #expect(try Set(fixture.inventory().keys) == ["current.json", "writer.lock"])
    }

    @Test func supersededStateKeepsAuthorityAndPendingUntilFutureExplicitResolution() throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        guard case .unknown(let pending, _) = try fixture.store(.replaceAfter).commit(basedOn: base, changes: [.language(.english)]) else {
            Issue.record("应构造未知"); return
        }
        let later = try fixture.current().changing([.appearance(.dark)])
        try fixture.write(later, name: "current.json")
        let before = try fixture.inventory()
        let reopened = try fixture.store()
        #expect(reopened.verifyPendingCommit() == .superseded(pending, current: later))
        guard case .recoveryRequired = reopened.commit(basedOn: later, changes: [.stampCaptureApp(true)]) else {
            Issue.record("替代状态仍需显式接受"); return
        }
        #expect(try fixture.inventory() == before)
    }

    @Test func corruptUnknownAndMissingCurrentKeepEvidenceAndCloseWrites() throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        guard case .unknown(let pending, _) = try fixture.store(.replaceAfter).commit(basedOn: base, changes: [.language(.english)]) else {
            Issue.record("应构造未知"); return
        }
        for (data, issue) in [(Data("broken".utf8), LocalPreferenceFileIssue.corrupt),
                              (Data("{\"schemaVersion\":10}".utf8), .unsupportedSchema)] {
            try data.write(to: fixture.root.appendingPathComponent("current.json"))
            let before = try fixture.inventory()
            #expect(try fixture.store().verifyPendingCommit() == .blocked(.unavailable(issue)))
            #expect(try fixture.store().commit(basedOn: base, changes: [.language(.english)]) == .recoveryRequired(.unavailable(issue)))
            #expect(try fixture.inventory() == before)
        }
        try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("current.json"))
        #expect(try fixture.store().read() == .pending(pending, current: nil))
        #expect(try fixture.store().verifyPendingCommit() == .historicalUnknown(pending, current: nil))
        #expect(try fixture.store(.readCurrent).verifyPendingCommit() == .blocked(.unavailable(.readFailed)))
    }

    @Test func auxiliaryTargetNeverBecomesAuthorityAndIdentityMismatchNeverCleans() throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        guard case .unknown(let pending, _) = try fixture.store(.replaceBefore).commit(basedOn: base, changes: [.language(.english)]) else {
            Issue.record("应构造未知"); return
        }
        #expect(try fixture.store().read() == .pending(pending, current: base))
        #expect(try fixture.current().values.language == .system)
        let target = try LocalPreferenceRecordCodec.decode(LocalPreferenceRecord.self, from: fixture.bytes(pending.candidateName))
        let mismatched = LocalPreferenceRecord(schemaVersion: 1, identity: target.identity, recordRevision: target.recordRevision,
            fieldRevisions: target.fieldRevisions, commitID: target.commitID, parentCommitID: target.parentCommitID,
            migrationID: nil, values: base.values)
        try fixture.write(mismatched, name: "current.json")
        let before = try fixture.inventory()
        #expect(try fixture.store().verifyPendingCommit() == .blocked(.unavailable(.inconsistentEvidence)))
        #expect(try fixture.inventory() == before)
    }

    @Test func unknownInstanceRemembersMissingEvidenceAndPartialPreparationCannotBeReused() throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        let store = try fixture.store(.replaceAfter)
        _ = store.commit(basedOn: base, changes: [.language(.english)])
        try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("pending-write.json"))
        #expect(store.read() == .unavailable(.inconsistentEvidence))
        let other = try LocalPreferenceFileFixture()
        let otherBase = try other.seed()
        _ = try other.store(.temporaryPartialWrite).commit(basedOn: otherBase, changes: [.appearance(.dark)])
        #expect(try other.store().read() == .unavailable(.orphanedPreparation))
        #expect(try other.current() == otherBase)
    }

    @Test func firstCreationUnknownReopensTargetOrKeepsMissingUnresolved() throws {
        for fault in [LocalPreferenceFileFault.replaceBefore, .replaceAfter] {
            let fixture = try LocalPreferenceFileFixture()
            guard case .unknown(let pending, _) = try fixture.store(fault).initializeNew(values: LocalPreferenceFileFixture.values) else {
                Issue.record("初建替换异常应未知"); return
            }
            let reopened = try fixture.store()
            if fault == .replaceBefore {
                #expect(reopened.verifyPendingCommit() == .historicalUnknown(pending, current: nil))
                guard case .recoveryRequired = reopened.initializeNew(values: LocalPreferenceFileFixture.values) else {
                    Issue.record("不能自动重复新建"); return
                }
            } else { #expect(try reopened.verifyPendingCommit() == .confirmed(fixture.current())) }
        }
    }

    @Test func inconsistentPendingAndForeignCandidateRemainUntouched() throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        guard case .unknown(let pending, _) = try fixture.store(.replaceAfter).commit(basedOn: base, changes: [.language(.english)]) else {
            Issue.record("应构造未知"); return
        }
        let bad = LocalPreferencePendingWrite(schemaVersion: 1, base: pending.base, target: pending.target,
                                              fields: ["language", "language"])
        try fixture.write(bad, name: "pending-write.json")
        let before = try fixture.inventory()
        #expect(try fixture.store().read() == .unavailable(.inconsistentEvidence))
        #expect(try fixture.store().verifyPendingCommit() == .blocked(.unavailable(.inconsistentEvidence)))
        #expect(try fixture.inventory() == before)
        try fixture.write(pending, name: "pending-write.json")
        try fixture.write(base, name: pending.candidateName)
        let target = try fixture.current()
        let foreignBefore = try fixture.inventory()
        #expect(try fixture.store().verifyPendingCommit() == .confirmedCleanupPending(target))
        #expect(try fixture.inventory() == foreignBefore)
        try Data("{\"schemaVersion\":9}".utf8).write(to: fixture.root.appendingPathComponent("pending-write.json"))
        #expect(try fixture.store().read() == .unavailable(.unsupportedSchema))
    }
}
