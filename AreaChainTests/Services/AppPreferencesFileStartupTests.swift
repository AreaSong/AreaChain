import AppKit
import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct AppPreferencesFileStartupTests {
    @Test func readyLoadsOneRecordWithoutOldKeysOrCommitEvents() throws {
        let fixture = try AppPreferencesFileFixture()
        fixture.legacy.set(.language(.chinese))
        let record = try fixture.legacy.files.seed().changing(AppPreferencesFileFixture.changes)
        try fixture.legacy.files.write(record, name: "current.json")
        let files = try fixture.legacy.files.inventory()
        let oldKeys = fixture.legacy.oldFourKeys()
        let originalAppearance = NSApp.appearance
        let prefs = try fixture.preferences(.ready(record, cleanupPending: false))
        #expect(prefs.committedLocalPreferenceRecord == record && prefs.canWriteLocalPreferences)
        #expect(AppPreferencesFileFixture.values(prefs) == record.values)
        #expect(!prefs.usesLegacyLocalPreferences && prefs.localPreferenceBackend == .ready)
        #expect(prefs.lastLocalPreferenceCommit == nil && prefs.lastLocalPreferenceRecovery == nil)
        #expect(prefs.startupAppearance == .returned && prefs.startupEvent == .notCalled)
        #expect(fixture.appearances == [.dark] && fixture.events.isEmpty)
        #expect(try fixture.legacy.files.inventory() == files)
        #expect(fixture.legacy.oldFourKeys() == oldKeys && fixture.legacy.reads.isEmpty)
        #expect(NSApp.appearance === originalAppearance)
    }

    @Test func allNonReadyStartupStatesAreReadOnlyEvenWithAnExistingHealthyFile() throws {
        let fixture = try AppPreferencesFileFixture()
        let record = try fixture.legacy.files.seed()
        let starts: [LocalPreferenceMigrationResult] = [
            .notMigrated(readOnly: AppPreferencesFileFixture.changedValues),
            .conflict(.sourceChanged), .failed(.legacyReadFailed(.language)),
            .recoveryRequired(.backend(.blocked(.unavailable(.corrupt))))
        ]
        let before = try fixture.legacy.files.inventory()
        for startup in starts {
            let prefs = try fixture.preferences(startup)
            let visible = AppPreferencesFileFixture.values(prefs)
            #expect(!prefs.canWriteLocalPreferences && prefs.committedLocalPreferenceRecord == nil)
            #expect(prefs.localPreferenceBackend == .readOnly(startup))
            AppPreferencesFileFixture.assignAllBindings(prefs)
            let result = prefs.applyLocalPreferences(basedOn: record, changes: AppPreferencesFileFixture.changes)
            guard case .recoveryRequired = result else { Issue.record("只读启动不得提交"); return }
            #expect(AppPreferencesFileFixture.values(prefs) == visible)
        }
        #expect(fixture.events.isEmpty && fixture.legacy.reads.isEmpty)
        #expect(try fixture.legacy.files.inventory() == before)
    }

    @Test func notMigratedDoesNotCreateOrMigrateFiles() throws {
        let fixture = try AppPreferencesFileFixture()
        fixture.legacy.set(.language(.chinese))
        let store = try fixture.legacy.files.store()
        let startup = store.reopen(from: fixture.legacy.source)
        let before = try fixture.legacy.files.inventory()
        let reads = fixture.legacy.reads
        let prefs = AppPreferences(defaults: fixture.legacy.defaults, fileStore: store, startup: startup, effects: fixture.effects)
        #expect(prefs.language == .chinese && !prefs.canWriteLocalPreferences)
        AppPreferencesFileFixture.assignAllBindings(prefs)
        _ = prefs.verifyAndReloadLocalPreferences()
        #expect(try fixture.legacy.files.inventory() == before)
        #expect(fixture.legacy.reads == reads && fixture.events.isEmpty)
    }

    @Test func forgedStaleMalformedAndForeignReadyAreRejected() throws {
        let fixture = try AppPreferencesFileFixture()
        let base = try fixture.legacy.files.seed()
        let forged = try base.changing([.language(.english)])
        let foreign = LocalPreferenceRecord.initial(identity: .init(storeID: UUID(), epoch: UUID()), values: base.values)
        let malformed = LocalPreferenceRecord(schemaVersion: 9, identity: base.identity, recordRevision: 1,
            fieldRevisions: base.fieldRevisions, commitID: base.commitID, parentCommitID: nil, migrationID: nil, values: base.values)
        for record in [forged, foreign, malformed] {
            let prefs = try fixture.preferences(.ready(record, cleanupPending: false))
            #expect(!prefs.canWriteLocalPreferences && prefs.committedLocalPreferenceRecord == nil)
        }
        _ = try fixture.legacy.files.store().commit(basedOn: base, changes: [.language(.english)])
        let stale = try fixture.preferences(.ready(base, cleanupPending: false))
        #expect(!stale.canWriteLocalPreferences && stale.committedLocalPreferenceRecord == nil)
        let other = try LocalPreferenceFileStore(temporaryRoot: fixture.legacy.files.root, identity: foreign.identity)
        let wrongStore = AppPreferences(defaults: fixture.legacy.defaults, fileStore: other,
            startup: .ready(base, cleanupPending: false), effects: fixture.effects)
        #expect(wrongStore.localPreferenceBackend == .verificationRequired(.unavailable(.sourceMismatch)))
        #expect(fixture.events.isEmpty)
    }

    @Test(arguments: [LocalPreferenceFileFault.cleanupBefore, .cleanupAfter])
    func cleanupPendingUsesRealBackendHealth(fault: LocalPreferenceFileFault) throws {
        let fixture = try AppPreferencesFileFixture()
        let base = try fixture.legacy.files.seed()
        let store = try fixture.legacy.files.store(fault)
        guard case .committedCleanupPending(let record) = store.commit(basedOn: base, changes: [.appearance(.dark)]) else {
            Issue.record("需要真实清理失败回执"); return
        }
        let prefs = AppPreferences(defaults: fixture.legacy.defaults, fileStore: store,
            startup: .ready(record, cleanupPending: true), effects: fixture.effects)
        #expect(prefs.committedLocalPreferenceRecord == record)
        #expect(prefs.canWriteLocalPreferences == (fault == .cleanupAfter))
        #expect(fixture.events.isEmpty && fixture.appearances == [.dark])
        if fault == .cleanupBefore {
            let forged = try fixture.preferences(.ready(record, cleanupPending: false), fault: fault)
            #expect(!forged.canWriteLocalPreferences && forged.committedLocalPreferenceRecord == nil)
        }
    }

    @Test func readFailureAndStartupAppearanceFailureRemainSeparate() throws {
        let fixture = try AppPreferencesFileFixture()
        let base = try fixture.legacy.files.seed()
        fixture.failAppearance = true
        let prefs = try fixture.preferences(.ready(base, cleanupPending: false), fault: .readCurrent)
        #expect(!prefs.canWriteLocalPreferences && prefs.committedLocalPreferenceRecord == nil)
        #expect(prefs.startupAppearance == .threw && prefs.startupEvent == .notCalled)
        #expect(prefs.lastLocalPreferenceCommit == nil && fixture.events.isEmpty)
        let healthy = try fixture.preferences(.ready(base, cleanupPending: false))
        #expect(healthy.canWriteLocalPreferences && healthy.startupAppearance == .threw)
    }

    @Test func completeBaseInsideUnknownPendingIsNotWritableReady() throws {
        let fixture = try AppPreferencesFileFixture()
        let base = try fixture.legacy.files.seed()
        let store = try fixture.legacy.files.store(.replaceBefore)
        guard case .unknown = store.commit(basedOn: base, changes: [.language(.english)]) else {
            Issue.record("需要替换前未知证据"); return
        }
        let before = try fixture.legacy.files.inventory()
        let prefs = AppPreferences(defaults: fixture.legacy.defaults, fileStore: store,
            startup: .ready(base, cleanupPending: true), effects: fixture.effects)
        #expect(!prefs.canWriteLocalPreferences && prefs.committedLocalPreferenceRecord == nil)
        #expect(try fixture.legacy.files.inventory() == before)
    }
}
