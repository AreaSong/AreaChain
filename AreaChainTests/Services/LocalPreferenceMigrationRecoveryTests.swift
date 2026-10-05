import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized)
struct LocalPreferenceMigrationRecoveryTests {
    @Test(arguments: [LocalPreferenceFileFault.migrationWrite, .migrationPartialWrite, .migrationReadback,
        .migrationPrepared, .encoding, .temporaryWrite, .temporaryPartialWrite, .pendingWrite,
        .pendingPartialWrite, .pendingRead, .qualification, .replaceBefore, .replaceAfter, .readback,
        .cleanupBefore, .cleanupAfter])
    func eachInjectedBoundaryReopensWithoutImportOrPreferenceReplay(fault: LocalPreferenceFileFault) throws {
        let fixture = try LocalPreferenceMigrationFixture()
        fixture.set(.language(.english))
        fixture.set(.appearance(.dark))
        let old = fixture.oldFourKeys()
        let result = try fixture.files.store(fault).migrate(from: fixture.source)
        let before = try fixture.files.inventory()
        let readCount = fixture.reads.count
        let reopened = try fixture.files.store()
        let state = reopened.reopen(from: fixture.source)
        let committed: [LocalPreferenceFileFault] = [.replaceAfter, .readback, .cleanupBefore, .cleanupAfter]
        if committed.contains(fault) {
            let current = try fixture.files.current()
            #expect(state == .ready(current, cleanupPending: false))
            #expect(current.values.language == .english && current.values.appearance == .dark)
            #expect(current.migrationID != nil && current.recordRevision == 1)
            #expect(try fixture.files.inventory()["current.json"] == before["current.json"])
            #expect(try fixture.files.inventory()["migration.plist"] == before["migration.plist"])
            if fault == .cleanupBefore || fault == .cleanupAfter {
                #expect(result == .ready(current, cleanupPending: true))
            } else {
                guard case .recoveryRequired(.unverifiedCommit) = result else {
                    Issue.record("提交边界异常必须保留未知调用事实"); return
                }
            }
        } else if fault == .migrationWrite {
            #expect(state == .notMigrated(readOnly: .init(language: .english, appearance: .dark,
                quadrantTitleTruncation: .tail, stampCaptureApp: false)))
            #expect(result == .failed(.file(.migrationWriteFailed)))
        } else {
            guard case .recoveryRequired = state else { Issue.record("中断残留必须要求恢复"); return }
            #expect(before["current.json"] == nil)
            #expect(try fixture.files.inventory() == before)
            guard case .recoveryRequired = reopened.initializeNew(values: .legacyDefaults) else {
                Issue.record("无迁移初建不得覆盖残留"); return
            }
            #expect(try fixture.files.inventory() == before)
        }
        if fault != .migrationWrite { #expect(fixture.reads.count == readCount) }
        #expect(fixture.oldFourKeys() == old)
        let after = try fixture.files.inventory()
        #expect(reopened.reopen(from: fixture.source) == state)
        #expect(try fixture.files.inventory() == after)
    }

    @Test func initialPendingTargetAndMissingCurrentKeepHistoricalUnknown() throws {
        let fixture = try LocalPreferenceMigrationFixture()
        guard case .recoveryRequired(.unverifiedCommit(let pending, _)) =
            try fixture.files.store(.replaceBefore).migrate(from: fixture.source) else {
            Issue.record("应到达替换前未知边界"); return
        }
        let state = LocalPreferenceMigrationResult.recoveryRequired(.backend(.historicalUnknown(pending, current: nil)))
        #expect(try fixture.files.store().reopen(from: fixture.source) == state)
        let before = try fixture.files.inventory()
        #expect(try fixture.files.store().migrate(from: fixture.source) == state)
        #expect(try fixture.files.inventory() == before)
        // 缺失迁移证据也不能从 pending 或 candidate 重新导入。
        try FileManager.default.removeItem(at: fixture.files.root.appendingPathComponent("migration.plist"))
        #expect(try fixture.files.store().reopen(from: fixture.source) == state)
    }

    @Test(arguments: [LocalPreferenceFileFault.replaceBefore, .replaceAfter])
    func migratedUpdatesVerifyBaseTargetAndSupersedingCurrent(fault: LocalPreferenceFileFault) throws {
        let fixture = try LocalPreferenceMigrationFixture()
        let base = try fixture.migrate()
        guard case .unknown(let pending, _) = try fixture.files.store(fault).commit(basedOn: base, changes: [.appearance(.dark)]) else {
            Issue.record("应得到未核实的后续提交"); return
        }
        if fault == .replaceBefore {
            #expect(try fixture.files.store().reopen(from: fixture.source)
                == .recoveryRequired(.backend(.historicalUnknown(pending, current: base))))
        } else {
            let target = try fixture.files.current()
            #expect(try fixture.files.store().reopen(from: fixture.source) == .ready(target, cleanupPending: false))
            #expect(target.migrationID == base.migrationID)
        }
        let current = try fixture.files.current()
        let other = try current.changing([.language(.english)])
        try fixture.files.write(other, name: "current.json")
        try fixture.files.write(pending, name: "pending-write.json")
        let before = try fixture.files.inventory()
        #expect(try fixture.files.store().reopen(from: fixture.source)
            == .recoveryRequired(.backend(.superseded(pending, current: other))))
        guard case .recoveryRequired = try fixture.files.store().commit(basedOn: other, changes: [.stampCaptureApp(true)]) else {
            Issue.record("被替代的旧 pending 仍须显式解决"); return
        }
        #expect(try fixture.files.inventory() == before)
    }

    @Test func cleanupFailureReturnsLoadableCommittedRecordWithoutRewritingIt() throws {
        let fixture = try LocalPreferenceMigrationFixture()
        let record = try fixture.migrate(.cleanupBefore)
        let before = try fixture.files.inventory()
        #expect(try fixture.files.store(.cleanupBefore).reopen(from: fixture.source) == .ready(record, cleanupPending: true))
        #expect(try fixture.files.inventory() == before)
        #expect(try fixture.files.store().reopen(from: fixture.source) == .ready(record, cleanupPending: false))
        #expect(try fixture.files.inventory()["current.json"] == before["current.json"])
    }

    @Test func migrationUsesExistingLockAndNeverReadsSourceWhileBusy() throws {
        let fixture = try LocalPreferenceMigrationFixture()
        let io = try LocalPreferenceFileIO(temporaryRoot: fixture.files.root)
        let lock = try LocalPreferenceFileLock.acquire(io, creating: true)
        let store = try fixture.files.store()
        withExtendedLifetime(lock) {
            #expect(store.migrate(from: fixture.source) == .failed(.file(.reentrant)))
        }
        #expect(fixture.reads.isEmpty)
        #expect(try Set(fixture.files.inventory().keys) == ["writer.lock"])
    }
}
