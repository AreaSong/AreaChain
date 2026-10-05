import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized)
struct LocalPreferenceMigrationEvidenceTests {
    @Test func missingCorruptAndUnknownEvidenceNeverFallBackOrInitialize() throws {
        for mutation in 0..<3 {
            let fixture = try LocalPreferenceMigrationFixture()
            let base = try fixture.migrate()
            let path = fixture.files.root.appendingPathComponent("migration.plist")
            let issue: LocalPreferenceFileIssue
            switch mutation {
            case 0:
                try FileManager.default.removeItem(at: path)
                issue = .inconsistentEvidence
            case 1:
                try Data("broken evidence".utf8).write(to: path)
                issue = .corrupt
            default:
                try PropertyListSerialization.data(fromPropertyList: ["schemaVersion": 99], format: .binary, options: 0).write(to: path)
                issue = .unsupportedSchema
            }
            try assertClosed(fixture, base: base, issue: issue)
        }
    }

    @Test func corruptedCurrentUnknownSchemaAndMissingCurrentKeepEvidence() throws {
        for mutation in 0..<3 {
            let fixture = try LocalPreferenceMigrationFixture()
            let base = try fixture.migrate()
            let path = fixture.files.root.appendingPathComponent("current.json")
            if mutation == 2 { try FileManager.default.removeItem(at: path) }
            else { try Data((mutation == 0 ? "broken current" : "{\"schemaVersion\":9}").utf8).write(to: path) }
            let issue: LocalPreferenceFileIssue = mutation == 0 ? .corrupt : mutation == 1 ? .unsupportedSchema : .incompleteMigration
            try assertClosed(fixture, base: base, issue: issue)
        }
    }

    @Test func foreignStoreOrMigrationIdentityAndTamperedEvidenceAreRejected() throws {
        let fixture = try LocalPreferenceMigrationFixture()
        let base = try fixture.migrate()
        let original = try fixture.files.bytes("migration.plist")
        let other = try LocalPreferenceMigrationFixture()
        _ = try other.migrate()
        try other.files.bytes("migration.plist").write(to: fixture.files.root.appendingPathComponent("migration.plist"))
        try assertClosed(fixture, base: base, issue: .sourceMismatch)
        try original.write(to: fixture.files.root.appendingPathComponent("migration.plist"))
        let mismatched = LocalPreferenceRecord(schemaVersion: 1, identity: base.identity, recordRevision: base.recordRevision,
            fieldRevisions: base.fieldRevisions, commitID: base.commitID, parentCommitID: nil, migrationID: UUID(), values: base.values)
        try fixture.files.write(mismatched, name: "current.json")
        try assertClosed(fixture, base: base, issue: .inconsistentEvidence)
        try fixture.files.write(base, name: "current.json")
        var object = try #require(PropertyListSerialization.propertyList(from: original, format: nil) as? [String: Any])
        var payload = try #require(object["payload"] as? [String: Any])
        payload["source"] = ["isolatedSuiteName": other.suiteName]
        object["payload"] = payload
        try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)
            .write(to: fixture.files.root.appendingPathComponent("migration.plist"))
        try assertClosed(fixture, base: base, issue: .inconsistentEvidence)
    }

    @Test func initialRecordCannotChangeValuesWhileKeepingMigrationIdentity() throws {
        let fixture = try LocalPreferenceMigrationFixture()
        let base = try fixture.migrate()
        var values = base.values
        values.language = .english
        let changed = LocalPreferenceRecord(schemaVersion: 1, identity: base.identity, recordRevision: 1,
            fieldRevisions: base.fieldRevisions, commitID: base.commitID, parentCommitID: nil,
            migrationID: base.migrationID, values: values)
        try fixture.files.write(changed, name: "current.json")
        try assertClosed(fixture, base: base, issue: .inconsistentEvidence)
    }

    @Test func mismatchedInitialPendingDoesNotClaimTheMigrationTarget() throws {
        let fixture = try LocalPreferenceMigrationFixture()
        _ = try fixture.files.store(.replaceBefore).migrate(from: fixture.source)
        let target = LocalPreferenceRecord.initial(identity: fixture.files.identity, values: .legacyDefaults)
        let pending = try LocalPreferencePendingWrite(schemaVersion: 1, base: nil,
            target: LocalPreferenceRecordEvidence(target), fields: LocalPreferenceField.allCases.map(\.storageName))
        // 原候选另存不参与选择；先移除自己生成的候选以单独检查 pending 的迁移关联。
        for name in try fixture.files.inventory().keys where name.hasPrefix("candidate-") {
            try FileManager.default.removeItem(at: fixture.files.root.appendingPathComponent(name))
        }
        try fixture.files.write(pending, name: "pending-write.json")
        #expect(try fixture.files.store().read() == .unavailable(.inconsistentEvidence))
    }

    private func assertClosed(_ fixture: LocalPreferenceMigrationFixture, base: LocalPreferenceRecord,
                              issue: LocalPreferenceFileIssue) throws {
        let before = try fixture.files.inventory()
        let reads = fixture.reads.count
        let store = try fixture.files.store()
        #expect(store.read() == .unavailable(issue))
        #expect(store.reopen(from: fixture.source) == .recoveryRequired(.backend(.blocked(.unavailable(issue)))))
        #expect(store.initializeNew(values: .legacyDefaults) == .recoveryRequired(.unavailable(issue)))
        #expect(store.commit(basedOn: base, changes: [.appearance(.dark)]) == .recoveryRequired(.unavailable(issue)))
        #expect(store.migrate(from: fixture.source) == .recoveryRequired(.backend(.blocked(.unavailable(issue)))))
        #expect(fixture.reads.count == reads)
        #expect(try fixture.files.inventory() == before)
    }
}
