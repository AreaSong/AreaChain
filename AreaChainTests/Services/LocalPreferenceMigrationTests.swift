import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized)
struct LocalPreferenceMigrationTests {
    @Test(arguments: [0, 1, 4])
    func missingPartialAndCompleteSourcesPreserveSystemAndPhysicalPresence(count: Int) throws {
        let fixture = try LocalPreferenceMigrationFixture()
        let values: [LocalPreferenceValue] = [.language(.system), .appearance(.system),
                                            .quadrantTitleTruncation(.middle), .stampCaptureApp(true)]
        for value in values.prefix(count) { fixture.set(value) }
        let before = fixture.oldFourKeys()
        var expected = LocalPreferenceValues.legacyDefaults
        for value in values.prefix(count) { expected.set(value) }
        let store = try fixture.files.store()
        #expect(store.reopen(from: fixture.source) == .notMigrated(readOnly: expected))
        #expect(try fixture.files.inventory().isEmpty)
        let record = try fixture.migrate()
        let evidence = try fixture.evidence()
        #expect(record.values == expected && record.recordRevision == 1 && record.parentCommitID == nil)
        #expect(record.migrationID == evidence.payload.migrationID)
        #expect(evidence.payload.target == (try LocalPreferenceRecordEvidence(record)))
        #expect(evidence.payload.source.isolatedSuiteName == fixture.suiteName)
        #expect(evidence.payload.presence.values.filter { $0 }.count == count)
        #expect(fixture.oldFourKeys() == before)
        #expect(try Set(fixture.files.inventory().keys) == ["writer.lock", "migration.plist", "current.json"])
        #expect(Set(fixture.reads) == Set(LocalPreferenceField.allCases))
    }

    @Test func malformedRawValuesNeverUseLooseInitializationToMigrate() throws {
        let invalid: [(LocalPreferenceField, Any)] = [(.language, "future"), (.appearance, true),
            (.quadrantTitleTruncation, 7), (.stampCaptureApp, "YES"), (.stampCaptureApp, 1),
            (.language, ["unrelated": ["payload"]])]
        for (field, raw) in invalid {
            let fixture = try LocalPreferenceMigrationFixture()
            fixture.defaults.set(raw, forKey: field.key)
            let old = fixture.oldFourKeys()
            #expect(try fixture.files.store().migrate(from: fixture.source) == .failed(.invalidLegacyValue(field)))
            #expect(fixture.oldFourKeys() == old)
            #expect(try Set(fixture.files.inventory().keys) == ["writer.lock"])
        }
        #expect(LocalPreferenceRawValue.string("YES").initialValue(for: .stampCaptureApp) == .stampCaptureApp(true))
        #expect(LocalPreferenceRawValue.string("YES").canonicalValue(for: .stampCaptureApp) == nil)
    }

    @Test(arguments: [LocalPreferenceLegacyOrigin.registration, .volatile, .managed, .unknown, .conflict])
    func evenEqualOverridesCannotBeFrozenAsUserChoices(origin: LocalPreferenceLegacyOrigin) throws {
        let fixture = try LocalPreferenceMigrationFixture()
        fixture.set(.language(.system))
        fixture.origins[.language] = origin
        // 注册/启动参数域可能影响进程中其他句柄；隔离反例只在此逐键读取器注入覆盖。
        fixture.effectiveOverrides[.language] = .string("system")
        #expect(try fixture.files.store().migrate(from: fixture.source) == .conflict(.untrustedSource(.language, origin)))
        #expect(try Set(fixture.files.inventory().keys) == ["writer.lock"])
        #expect(fixture.persistent(.language) == .string("system"))
    }

    @Test func missingRegisteredValueAndMismatchedEffectiveSourceAreRejected() throws {
        let fixture = try LocalPreferenceMigrationFixture()
        fixture.effectiveOverrides[.language] = .string("english")
        fixture.origins[.language] = .registration
        #expect(try fixture.files.store().migrate(from: fixture.source) == .conflict(.untrustedSource(.language, .registration)))
        #expect(fixture.persistent(.language) == .missing)
        // 即便注入器声称默认，实际非默认有效值也不能通过。
        fixture.origins[.language] = .declaredDefault
        #expect(try fixture.files.store().migrate(from: fixture.source) == .conflict(.untrustedSource(.language, .conflict)))
    }

    @Test func unreadableSourceAndInvalidIdentityDoNotBecomeMissing() throws {
        let fixture = try LocalPreferenceMigrationFixture()
        fixture.beforeRead = { _, _ in throw LocalPreferenceFileIssue.readFailed }
        #expect(try fixture.files.store().reopen(from: fixture.source) == .failed(.legacyReadFailed(.language)))
        #expect(try fixture.files.inventory().isEmpty)
        #expect(try fixture.files.store().migrate(from: fixture.source) == .failed(.legacyReadFailed(.language)))
        let source = LocalPreferenceLegacySource(identity: .init(isolatedSuiteName: ""), read: fixture.source.read)
        #expect(try fixture.files.store().migrate(from: source) == .failed(.invalidSourceIdentity))
        #expect(try Set(fixture.files.inventory().keys) == ["writer.lock"])
    }

    @Test func changedValuePresenceAndOriginAfterEvidenceRefuseCommitAndKeepOriginalEvidence() throws {
        for change in 0..<3 {
            let fixture = try LocalPreferenceMigrationFixture()
            fixture.set(.language(.english))
            fixture.beforeRead = { [unowned fixture] _, count in
                guard count == 5 else { return }
                switch change {
                case 0: fixture.set(.language(.chinese))
                case 1: fixture.defaults.removeObject(forKey: LocalPreferenceField.language.key)
                default: fixture.origins[.language] = .unknown
                }
            }
            let result = try fixture.files.store().migrate(from: fixture.source)
            if change == 2 { #expect(result == .conflict(.untrustedSource(.language, .unknown))) }
            else { #expect(result == .conflict(.sourceChanged)) }
            let evidence = try fixture.evidence()
            #expect(evidence.payload.values.language == .english && evidence.payload.presence["language"] == true)
            let inventory = try fixture.files.inventory()
            let reads = fixture.reads.count
            #expect(try fixture.files.store().reopen(from: fixture.source)
                == .recoveryRequired(.backend(.blocked(.unavailable(.incompleteMigration)))))
            guard case .recoveryRequired = try fixture.files.store().migrate(from: fixture.source) else {
                Issue.record("不能复用已准备的迁移身份"); return
            }
            #expect(fixture.reads.count == reads)
            #expect(try fixture.files.inventory() == inventory)
        }
    }

    @Test func currentRemainsSoleAuthorityAcrossNewWritesOldWritesAndRepeatedLaunches() throws {
        let fixture = try LocalPreferenceMigrationFixture()
        fixture.set(.language(.chinese))
        fixture.set(.stampCaptureApp(true))
        let old = fixture.oldFourKeys()
        let base = try fixture.migrate()
        let evidence = try fixture.files.bytes("migration.plist")
        let store = try fixture.files.store()
        let before = try fixture.files.inventory()
        #expect(store.commit(basedOn: base, changes: [.language(.chinese)]) == .noChange(base))
        #expect(try fixture.files.inventory() == before)
        guard case .committed(let current) = store.commit(basedOn: base, changes: [.language(.english), .appearance(.dark)]) else {
            Issue.record("迁移后仍应支持原共同提交"); return
        }
        #expect(current.migrationID == base.migrationID && fixture.oldFourKeys() == old)
        #expect(fixture.defaults.string(forKey: LocalPreferenceField.language.key) == "chinese")
        fixture.set(.language(.system))
        fixture.defaults.set("bad old value", forKey: LocalPreferenceField.appearance.key)
        let changedOld = fixture.oldFourKeys()
        fixture.beforeRead = { _, _ in throw LocalPreferenceFileIssue.readFailed }
        let after = try fixture.files.inventory()
        let reads = fixture.reads.count
        for _ in 0..<3 {
            #expect(try fixture.files.store().reopen(from: fixture.source) == .ready(current, cleanupPending: false))
            #expect(try fixture.files.store().migrate(from: fixture.source) == .ready(current, cleanupPending: false))
        }
        #expect(fixture.reads.count == reads && fixture.oldFourKeys() == changedOld)
        #expect(try fixture.files.inventory() == after && fixture.files.bytes("migration.plist") == evidence)
    }
}
