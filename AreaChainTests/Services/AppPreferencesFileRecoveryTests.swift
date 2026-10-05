import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct AppPreferencesFileRecoveryTests {
    @Test(arguments: [LocalPreferenceFileFault.encoding, .temporaryWrite, .temporaryPartialWrite, .pendingWrite,
                      .pendingPartialWrite, .pendingRead, .qualification])
    func precommitFailureRetainsWholeStateAndClosesWritesWhenEvidenceRemains(fault: LocalPreferenceFileFault) throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready(fault)
        let base = try #require(prefs.committedLocalPreferenceRecord)
        fixture.resetEffects()
        let result = prefs.applyLocalPreferences(basedOn: base, changes: AppPreferencesFileFixture.changes)
        guard case .notCommitted = result else { Issue.record("替换前失败应保留未提交事实"); return }
        #expect(prefs.committedLocalPreferenceRecord == base && AppPreferencesFileFixture.values(prefs) == base.values)
        #expect(try fixture.legacy.files.current() == base)
        #expect(fixture.appearances.isEmpty && fixture.events.isEmpty)
        #expect(!prefs.canWriteLocalPreferences)
        if fault == .encoding || fault == .temporaryWrite {
            let beforeVerification = try fixture.legacy.files.inventory()
            #expect(prefs.verifyAndReloadLocalPreferences() == .nothingToVerify(.record(base)))
            #expect(prefs.canWriteLocalPreferences && prefs.lastLocalPreferenceCommit == result)
            #expect(try fixture.legacy.files.inventory() == beforeVerification)
            #expect(fixture.appearances.isEmpty && fixture.events.isEmpty)
        }
    }

    @Test(arguments: [LocalPreferenceFileFault.replaceBefore, .replaceAfter, .readback])
    func unknownBlocksBindingsAndOnlyExplicitVerificationCanPublish(fault: LocalPreferenceFileFault) throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready(fault)
        let base = try #require(prefs.committedLocalPreferenceRecord)
        fixture.resetEffects()
        let result = prefs.applyLocalPreferences(basedOn: base, changes: AppPreferencesFileFixture.changes)
        guard case .unknown(let pending, _) = result else { Issue.record("需要未知提交"); return }
        #expect(!prefs.canWriteLocalPreferences && prefs.committedLocalPreferenceRecord == base)
        let files = try fixture.legacy.files.inventory()
        AppPreferencesFileFixture.assignAllBindings(prefs)
        #expect(prefs.lastLocalPreferenceCommit == result)
        #expect(try fixture.legacy.files.inventory() == files)
        #expect(fixture.events.isEmpty && fixture.appearances.isEmpty)
        let recovery = prefs.verifyAndReloadLocalPreferences()
        if fault == .replaceBefore {
            #expect(recovery == .historicalUnknown(pending, current: base))
            #expect(!prefs.canWriteLocalPreferences && prefs.committedLocalPreferenceRecord == base)
            #expect(try fixture.legacy.files.inventory() == files)
        } else {
            let current = try fixture.legacy.files.current()
            #expect(recovery == .confirmed(current) && prefs.canWriteLocalPreferences)
            #expect(prefs.committedLocalPreferenceRecord == current && current.values == AppPreferencesFileFixture.changedValues)
            #expect(current.commitID == pending.target.commitID && current.recordRevision == 2)
            let after = try fixture.legacy.files.inventory()
            #expect(after["current.json"] == files["current.json"])
            #expect(fixture.events.count == 1 && fixture.appearances == [.dark])
            _ = prefs.verifyAndReloadLocalPreferences()
            #expect(prefs.lastLocalPreferenceCommit == result)
            #expect(try fixture.legacy.files.inventory() == after)
            #expect(fixture.events.count == 1 && fixture.appearances == [.dark])
        }
    }

    @Test(arguments: [LocalPreferenceFileFault.cleanupBefore, .cleanupAfter])
    func cleanupFailureIsCommittedAndWritableOnlyWhenBackendReallyAllows(fault: LocalPreferenceFileFault) throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready(fault)
        let base = try #require(prefs.committedLocalPreferenceRecord)
        fixture.resetEffects()
        let result = prefs.applyLocalPreferences(basedOn: base, changes: AppPreferencesFileFixture.changes)
        let current = try #require(prefs.committedLocalPreferenceRecord)
        #expect(result == .committedCleanupPending(current))
        #expect(current.values == AppPreferencesFileFixture.changedValues)
        #expect(prefs.canWriteLocalPreferences == (fault == .cleanupAfter))
        #expect(fixture.events.count == 1 && fixture.appearances == [.dark])
        _ = prefs.verifyAndReloadLocalPreferences()
        #expect(prefs.committedLocalPreferenceRecord == current && fixture.events.count == 1)
    }

    @Test func fieldConflictRequiresExplicitReloadAndNeverLosesExternalValues() throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let base = try #require(prefs.committedLocalPreferenceRecord)
        guard case .committed(let external) = try fixture.legacy.files.store().commit(basedOn: base,
            changes: [.language(.chinese)]) else { Issue.record("需要外部写入"); return }
        let result = prefs.applyLocalPreferences(basedOn: base, changes: [.language(.english), .appearance(.dark)])
        #expect(result == .conflict(current: external) && prefs.committedLocalPreferenceRecord == base)
        #expect(!prefs.canWriteLocalPreferences && fixture.events.isEmpty)
        #expect(prefs.verifyAndReloadLocalPreferences() == .nothingToVerify(.record(external)))
        #expect(prefs.canWriteLocalPreferences && prefs.language == .chinese && prefs.appearance == .system)
        #expect(prefs.applyLocalPreferences(basedOn: base, changes: [.language(.english)]) == .conflict(current: external))
    }

    @Test func epochChangeAndCorruptionRetainLastPublishedStateWithoutFallback() throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let base = try #require(prefs.committedLocalPreferenceRecord)
        let foreign = LocalPreferenceRecord.initial(identity: .init(storeID: base.identity.storeID, epoch: UUID()),
            values: AppPreferencesFileFixture.changedValues)
        try fixture.legacy.files.write(foreign, name: "current.json")
        #expect(prefs.verifyAndReloadLocalPreferences() == .blocked(.unavailable(.sourceMismatch)))
        AppPreferencesFileFixture.assignAllBindings(prefs)
        #expect(!prefs.canWriteLocalPreferences && prefs.committedLocalPreferenceRecord == base)
        #expect(try fixture.legacy.files.current() == foreign)
        try Data("broken".utf8).write(to: fixture.legacy.files.root.appendingPathComponent("current.json"))
        #expect(prefs.verifyAndReloadLocalPreferences() == .blocked(.unavailable(.corrupt)))
        #expect(prefs.committedLocalPreferenceRecord == base && fixture.events.isEmpty)
        #expect(fixture.legacy.oldFourKeys() == [.missing, .missing, .missing, .missing])
    }

    @Test func sameEpochRollbackCannotBePublishedAsContinuousRevision() throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let base = try #require(prefs.committedLocalPreferenceRecord)
        _ = prefs.applyLocalPreferences(basedOn: base, changes: [.language(.english)])
        let current = try #require(prefs.committedLocalPreferenceRecord)
        try fixture.legacy.files.write(base, name: "current.json")
        fixture.resetEffects()
        _ = prefs.verifyAndReloadLocalPreferences()
        #expect(!prefs.canWriteLocalPreferences && prefs.committedLocalPreferenceRecord == current)
        #expect(prefs.localPreferenceBackend == .verificationRequired(.unavailable(.inconsistentEvidence)))
        #expect(fixture.events.isEmpty && fixture.appearances.isEmpty)
    }
}
