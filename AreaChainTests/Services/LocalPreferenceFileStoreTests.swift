import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized)
struct LocalPreferenceFileStoreTests {
    @Test func absentReadHasNoWritesAndExplicitNewRecordReopens() throws {
        let fixture = try LocalPreferenceFileFixture()
        let store = try fixture.store()
        #expect(store.read() == .absent)
        #expect(try fixture.inventory().isEmpty)
        let initial = try fixture.seed()
        #expect(try fixture.store().read() == .record(initial))
        #expect(initial.values == LocalPreferenceFileFixture.values)
        #expect(initial.recordRevision == 1 && initial.parentCommitID == nil && initial.migrationID == nil)
        #expect(try Set(fixture.inventory().keys) == ["current.json", "writer.lock"])
        #expect(try !String(decoding: fixture.bytes("current.json"), as: UTF8.self).contains("ObjectIdentifier"))
    }

    @Test func singleAndWholeRecordCommitsPreserveTypedSystemSemantics() throws {
        let fixture = try LocalPreferenceFileFixture()
        var baseline = try fixture.seed()
        let store = try fixture.store()
        let changes: [[LocalPreferenceValue]] = [
            [.language(.english)], [.appearance(.dark), .quadrantTitleTruncation(.middle), .stampCaptureApp(true)],
            [.language(.chinese), .appearance(.light)], [.language(.system), .appearance(.system)],
            [.language(.english), .appearance(.dark), .quadrantTitleTruncation(.tail), .stampCaptureApp(false)]
        ]
        for group in changes {
            let result = store.commit(basedOn: baseline, changes: group)
            guard case .committed(let current) = result else { Issue.record("应确认一次完整提交"); return }
            #expect(current.parentCommitID == baseline.commitID && current.commitID != baseline.commitID)
            #expect(current.recordRevision == baseline.recordRevision + 1)
            for field in LocalPreferenceField.allCases {
                let request = group.first { $0.field == field }
                #expect(current.values.value(for: field) == (request ?? baseline.values.value(for: field)))
                #expect(current.fieldRevisions[field] == baseline.fieldRevisions[field] + (request == nil ? 0 : 1))
            }
            #expect(try fixture.store().read() == .record(current))
            baseline = current
        }
    }

    @Test func allNoChangeWritesNothingAndPartialNoChangeIsOneRevision() throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        let before = try fixture.inventory()
        let store = try fixture.store()
        let same = LocalPreferenceField.allCases.map { base.values.value(for: $0) }
        #expect(store.commit(basedOn: base, changes: same) == .noChange(base))
        #expect(try fixture.store(.encoding).commit(basedOn: base, changes: same) == .noChange(base))
        #expect(try fixture.inventory() == before)
        guard case .committed(let current) = store.commit(basedOn: base, changes: [.language(.system), .appearance(.dark)]) else {
            Issue.record("部分无变化仍需整体提交"); return
        }
        #expect(current.recordRevision == 2 && current.fieldRevisions.language == 2 && current.fieldRevisions.appearance == 2)
        #expect(current.fieldRevisions.stampCaptureApp == 1 && current.values.language == .system)
        #expect(try fixture.store().read() == .record(current))
    }

    @Test func duplicateAndEmptyRequestsRejectBeforeAnyIO() throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        let before = try fixture.inventory()
        let store = try fixture.store(.readCurrent)
        #expect(store.commit(basedOn: base, changes: []) == .notCommitted(.invalidRequest))
        #expect(store.commit(basedOn: base, changes: [.language(.english), .language(.english)]) == .notCommitted(.invalidRequest))
        #expect(store.commit(basedOn: base, changes: [.language(.english), .language(.chinese)]) == .notCommitted(.invalidRequest))
        #expect(try fixture.inventory() == before)
    }

    @Test func oldFieldRevisionAndABACannotOverwriteButUnrelatedChangesAreRetained() throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        let first = try fixture.store()
        let second = try fixture.store()
        guard case .committed(let dark) = first.commit(basedOn: base, changes: [.appearance(.dark)]) else {
            Issue.record("初次提交失败"); return
        }
        #expect(second.commit(basedOn: base, changes: [.appearance(.light)]) == .conflict(current: dark))
        guard case .committed(let merged) = second.commit(basedOn: base, changes: [.language(.english)]) else {
            Issue.record("无关字段变化不应冲突"); return
        }
        #expect(merged.values.appearance == .dark && merged.recordRevision == 3)
        guard case .committed(let back) = first.commit(basedOn: merged, changes: [.appearance(.system)]) else {
            Issue.record("回到原值仍是新修订"); return
        }
        #expect(second.commit(basedOn: base, changes: [.appearance(.light)]) == .conflict(current: back))
    }

    @Test func foreignStoreOrEpochIsRejectedWithoutRepair() throws {
        let fixture = try LocalPreferenceFileFixture()
        let base = try fixture.seed()
        let before = try fixture.inventory()
        let foreign = try LocalPreferenceFileStore(temporaryRoot: fixture.root,
            identity: .init(storeID: fixture.identity.storeID, epoch: UUID()))
        #expect(foreign.read() == .unavailable(.sourceMismatch))
        #expect(foreign.commit(basedOn: base, changes: [.stampCaptureApp(true)]) == .notCommitted(.sourceMismatch))
        #expect(try fixture.inventory() == before)
    }

    @Test func badValuesMissingFieldsAndUnknownSchemaNeverInitializeOrFallBack() throws {
        let fixture = try LocalPreferenceFileFixture()
        _ = try fixture.seed()
        let valid = try fixture.bytes("current.json")
        let mutations: [(String, Any?)] = [("language", "unsupported"), ("appearance", NSNull()),
            ("quadrantTitleTruncation", nil), ("stampCaptureApp", "YES"), ("stampCaptureApp", 1)]
        for (key, value) in mutations {
            var object = try #require(JSONSerialization.jsonObject(with: valid) as? [String: Any])
            var values = try #require(object["values"] as? [String: Any])
            values[key] = value
            object["values"] = values
            try JSONSerialization.data(withJSONObject: object).write(to: fixture.root.appendingPathComponent("current.json"))
            let before = try fixture.inventory()
            #expect(try fixture.store().read() == .unavailable(.corrupt))
            #expect(try fixture.store().initializeNew(values: LocalPreferenceFileFixture.values) == .recoveryRequired(.unavailable(.corrupt)))
            #expect(try fixture.inventory() == before)
        }
        try Data("{\"schemaVersion\":99}".utf8).write(to: fixture.root.appendingPathComponent("current.json"))
        #expect(try fixture.store().read() == .unavailable(.unsupportedSchema))
        #expect(try fixture.store(.readCurrent).read() == .unavailable(.readFailed))
    }

    @Test func migrationEvidenceAndUnrelatedFilesPreventSyntheticInitialization() throws {
        let fixture = try LocalPreferenceFileFixture()
        try Data("opaque migration evidence".utf8).write(to: fixture.root.appendingPathComponent("migration.plist"))
        let store = try fixture.store()
        #expect(store.initializeNew(values: LocalPreferenceFileFixture.values) == .recoveryRequired(.unavailable(.corrupt)))
        #expect(try fixture.bytes("migration.plist") == Data("opaque migration evidence".utf8))
        let other = try LocalPreferenceFileFixture()
        try Data([1, 2, 3]).write(to: other.root.appendingPathComponent("unrelated.txt"))
        _ = try other.store().initializeNew(values: LocalPreferenceFileFixture.values)
        #expect(try !other.inventory().keys.contains("current.json"))
        #expect(try other.bytes("unrelated.txt") == Data([1, 2, 3]))
    }

    @Test func rootMustBeExplicitTemporaryChildAndMalformedRevisionsAreNotWritable() throws {
        let fixture = try LocalPreferenceFileFixture()
        #expect(throws: LocalPreferenceFileIssue.invalidRoot) {
            try LocalPreferenceFileStore(temporaryRoot: URL(fileURLWithPath: "/"), identity: fixture.identity)
        }
        let base = try fixture.seed()
        let malformed = LocalPreferenceRecord(schemaVersion: 1, identity: base.identity, recordRevision: 0,
            fieldRevisions: base.fieldRevisions, commitID: base.commitID, parentCommitID: nil, migrationID: nil, values: base.values)
        let before = try fixture.inventory()
        #expect(try fixture.store().commit(basedOn: malformed, changes: [.language(.english)]) == .notCommitted(.corrupt))
        #expect(try fixture.inventory() == before)
        let exhausted = LocalPreferenceRecord(schemaVersion: 1, identity: base.identity, recordRevision: .max,
            fieldRevisions: base.fieldRevisions, commitID: UUID(), parentCommitID: base.commitID, migrationID: nil, values: base.values)
        try fixture.write(exhausted, name: "current.json")
        let exhaustedBefore = try fixture.inventory()
        #expect(try fixture.store().commit(basedOn: exhausted, changes: [.language(.english)]) == .notCommitted(.revisionExhausted))
        #expect(try fixture.inventory() == exhaustedBefore)
    }
}
