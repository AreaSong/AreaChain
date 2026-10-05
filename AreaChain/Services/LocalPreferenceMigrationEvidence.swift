import Foundation

/// 只读迁移证据只编码合法四值。present 为 false 时原键缺失，原值不由默认补写。
struct LocalPreferenceMigrationEvidence: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let payload: Payload
    let digest: String

    struct Payload: Codable, Equatable, Sendable {
        let migrationID: UUID
        let source: LocalPreferenceLegacyIdentity
        let target: LocalPreferenceRecordEvidence
        let presence: [String: Bool]
        let values: LocalPreferenceValues
    }

    init(snapshot: LocalPreferenceLegacySnapshot, target: LocalPreferenceRecord) throws {
        guard let migrationID = target.migrationID,
              snapshot.observations.count == LocalPreferenceField.allCases.count else {
            throw LocalPreferenceFileIssue.inconsistentEvidence
        }
        let presence = Dictionary(uniqueKeysWithValues: zip(LocalPreferenceField.allCases, snapshot.observations)
            .map { ($0.0.storageName, $0.1.exists) })
        payload = try Payload(migrationID: migrationID, source: snapshot.source,
                              target: LocalPreferenceRecordEvidence(target), presence: presence, values: snapshot.values)
        schemaVersion = 1
        digest = try LocalPreferenceRecordCodec.digest(payload)
        try validate(identity: target.identity)
    }

    func validate(identity: LocalPreferenceStoreIdentity) throws {
        guard schemaVersion == 1 else { throw LocalPreferenceFileIssue.unsupportedSchema }
        guard payload.target.identity == identity else { throw LocalPreferenceFileIssue.sourceMismatch }
        guard !payload.source.isolatedSuiteName.isEmpty, payload.source.isolatedSuiteName.utf8.count <= 255,
              Set(payload.presence.keys) == Set(LocalPreferenceField.allCases.map(\.storageName)),
              try digest == LocalPreferenceRecordCodec.digest(payload) else {
            throw LocalPreferenceFileIssue.inconsistentEvidence
        }
        for field in LocalPreferenceField.allCases where payload.presence[field.storageName] == false {
            guard payload.values.value(for: field) == LocalPreferenceValues.legacyDefaults.value(for: field) else {
                throw LocalPreferenceFileIssue.inconsistentEvidence
            }
        }
        // 初始目标摘要同时绑定 migrationID、四值和初始修订；同一证据不能换源后复用。
        let initial = LocalPreferenceRecord(schemaVersion: 1, identity: identity, recordRevision: 1,
            fieldRevisions: .init(language: 1, appearance: 1, quadrantTitleTruncation: 1, stampCaptureApp: 1),
            commitID: payload.target.commitID, parentCommitID: nil, migrationID: payload.migrationID, values: payload.values)
        guard try payload.target.matches(initial) else { throw LocalPreferenceFileIssue.inconsistentEvidence }
    }

    func validate(record: LocalPreferenceRecord) throws {
        try validate(identity: record.identity)
        guard record.migrationID == payload.migrationID else { throw LocalPreferenceFileIssue.inconsistentEvidence }
        if record.recordRevision == 1 {
            guard try payload.target.matches(record) else { throw LocalPreferenceFileIssue.inconsistentEvidence }
        } else {
            guard record.commitID != payload.target.commitID,
                  record.recordRevision != 2 || record.parentCommitID == payload.target.commitID else {
                throw LocalPreferenceFileIssue.inconsistentEvidence
            }
        }
    }

    func encoded() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> Self {
        struct Version: Decodable { let schemaVersion: Int }
        do {
            let decoder = PropertyListDecoder()
            guard try decoder.decode(Version.self, from: data).schemaVersion == 1 else {
                throw LocalPreferenceFileIssue.unsupportedSchema
            }
            return try decoder.decode(Self.self, from: data)
        } catch let issue as LocalPreferenceFileIssue { throw issue }
        catch { throw LocalPreferenceFileIssue.corrupt }
    }
}
