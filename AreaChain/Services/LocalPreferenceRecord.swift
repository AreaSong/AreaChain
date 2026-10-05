import CryptoKit
import Foundation

/// 磁盘身份与旧 LocalPreferenceSource 的运行内句柄无关；epoch 只由显式新建/未来恢复流程分配。
struct LocalPreferenceStoreIdentity: Codable, Equatable, Sendable {
    let storeID: UUID
    let epoch: UUID
}

struct LocalPreferenceValues: Equatable, Sendable, Codable {
    var language: AppLanguage
    var appearance: AppAppearance
    var quadrantTitleTruncation: QuadrantTitleTruncation
    var stampCaptureApp: Bool

    func value(for field: LocalPreferenceField) -> LocalPreferenceValue {
        switch field {
        case .language: .language(language)
        case .appearance: .appearance(appearance)
        case .quadrantTitleTruncation: .quadrantTitleTruncation(quadrantTitleTruncation)
        case .stampCaptureApp: .stampCaptureApp(stampCaptureApp)
        }
    }

    mutating func set(_ value: LocalPreferenceValue) {
        switch value {
        case .language(let value): language = value
        case .appearance(let value): appearance = value
        case .quadrantTitleTruncation(let value): quadrantTitleTruncation = value
        case .stampCaptureApp(let value): stampCaptureApp = value
        }
    }

    enum CodingKeys: String, CodingKey { case language, appearance, quadrantTitleTruncation, stampCaptureApp }

    init(language: AppLanguage, appearance: AppAppearance, quadrantTitleTruncation: QuadrantTitleTruncation, stampCaptureApp: Bool) {
        self.language = language
        self.appearance = appearance
        self.quadrantTitleTruncation = quadrantTitleTruncation
        self.stampCaptureApp = stampCaptureApp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // 必填 decode 不接受 missing；严格解析不调用旧初始化回退。
        let languageRaw = try container.decode(String.self, forKey: .language)
        let appearanceRaw = try container.decode(String.self, forKey: .appearance)
        let truncationRaw = try container.decode(String.self, forKey: .quadrantTitleTruncation)
        guard case .language(let language) = LocalPreferenceRawValue.string(languageRaw).canonicalValue(for: .language),
              case .appearance(let appearance) = LocalPreferenceRawValue.string(appearanceRaw).canonicalValue(for: .appearance),
              case .quadrantTitleTruncation(let truncation) = LocalPreferenceRawValue.string(truncationRaw)
                .canonicalValue(for: .quadrantTitleTruncation) else { throw LocalPreferenceFileIssue.corrupt }
        self.init(language: language, appearance: appearance, quadrantTitleTruncation: truncation,
                  stampCaptureApp: try container.decode(Bool.self, forKey: .stampCaptureApp))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(language.rawValue, forKey: .language)
        try container.encode(appearance.rawValue, forKey: .appearance)
        try container.encode(quadrantTitleTruncation.rawValue, forKey: .quadrantTitleTruncation)
        try container.encode(stampCaptureApp, forKey: .stampCaptureApp)
    }
}

struct LocalPreferenceFieldRevisions: Codable, Equatable, Sendable {
    var language: UInt64
    var appearance: UInt64
    var quadrantTitleTruncation: UInt64
    var stampCaptureApp: UInt64

    subscript(field: LocalPreferenceField) -> UInt64 {
        get {
            switch field {
            case .language: language
            case .appearance: appearance
            case .quadrantTitleTruncation: quadrantTitleTruncation
            case .stampCaptureApp: stampCaptureApp
            }
        }
        set {
            switch field {
            case .language: language = newValue
            case .appearance: appearance = newValue
            case .quadrantTitleTruncation: quadrantTitleTruncation = newValue
            case .stampCaptureApp: stampCaptureApp = newValue
            }
        }
    }
}

/// current.json 的唯一完整记录；非空 migrationID 必须经文件后端核实只读迁移证据。
struct LocalPreferenceRecord: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let identity: LocalPreferenceStoreIdentity
    let recordRevision: UInt64
    let fieldRevisions: LocalPreferenceFieldRevisions
    let commitID: UUID
    let parentCommitID: UUID?
    let migrationID: UUID?
    let values: LocalPreferenceValues

    static func initial(identity: LocalPreferenceStoreIdentity, values: LocalPreferenceValues, migrationID: UUID? = nil) -> Self {
        Self(schemaVersion: 1, identity: identity, recordRevision: 1,
             fieldRevisions: .init(language: 1, appearance: 1, quadrantTitleTruncation: 1, stampCaptureApp: 1),
             commitID: UUID(), parentCommitID: nil, migrationID: migrationID, values: values)
    }

    func validate() throws {
        guard schemaVersion == 1 else { throw LocalPreferenceFileIssue.unsupportedSchema }
        guard recordRevision > 0, parentCommitID != commitID,
              (recordRevision == 1) == (parentCommitID == nil),
              LocalPreferenceField.allCases.allSatisfy({ fieldRevisions[$0] > 0 && fieldRevisions[$0] <= recordRevision }) else {
            throw LocalPreferenceFileIssue.corrupt
        }
    }

    func changing(_ changes: [LocalPreferenceValue]) throws -> Self {
        guard recordRevision < UInt64.max else { throw LocalPreferenceFileIssue.revisionExhausted }
        var nextValues = values
        var nextRevisions = fieldRevisions
        for value in changes {
            guard nextRevisions[value.field] < UInt64.max else { throw LocalPreferenceFileIssue.revisionExhausted }
            nextValues.set(value)
            nextRevisions[value.field] += 1
        }
        return Self(schemaVersion: schemaVersion, identity: identity, recordRevision: recordRevision + 1,
                    fieldRevisions: nextRevisions, commitID: UUID(), parentCommitID: commitID,
                    migrationID: migrationID, values: nextValues)
    }
}

enum LocalPreferenceRecordCodec {
    private struct Version: Decodable { let schemaVersion: Int }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            guard try JSONDecoder().decode(Version.self, from: data).schemaVersion == 1 else {
                throw LocalPreferenceFileIssue.unsupportedSchema
            }
            return try JSONDecoder().decode(type, from: data)
        } catch let issue as LocalPreferenceFileIssue { throw issue }
        catch { throw LocalPreferenceFileIssue.corrupt }
    }

    static func digest<T: Encodable>(_ value: T) throws -> String {
        SHA256.hash(data: try encode(value)).map { String(format: "%02x", $0) }.joined()
    }
}

/// pending 不包含可编辑四值或可执行指令，只绑定完整记录的规范编码摘要。
struct LocalPreferenceRecordEvidence: Codable, Equatable, Sendable {
    let identity: LocalPreferenceStoreIdentity
    let revision: UInt64
    let commitID: UUID
    let digest: String

    init(_ record: LocalPreferenceRecord) throws {
        identity = record.identity
        revision = record.recordRevision
        commitID = record.commitID
        digest = try LocalPreferenceRecordCodec.digest(record)
    }

    func matches(_ record: LocalPreferenceRecord) throws -> Bool { self == (try Self(record)) }
}

struct LocalPreferencePendingWrite: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let base: LocalPreferenceRecordEvidence?
    let target: LocalPreferenceRecordEvidence
    let fields: [String]

    var candidateName: String { "candidate-\(target.commitID.uuidString).json" }

    func validate(identity: LocalPreferenceStoreIdentity) throws {
        guard schemaVersion == 1 else { throw LocalPreferenceFileIssue.unsupportedSchema }
        guard target.identity == identity, base == nil || base?.identity == identity,
              target.revision > 0, target.digest.count == 64,
              target.digest.allSatisfy({ $0.isHexDigit }),
              !fields.isEmpty, fields.count <= 4, Set(fields).count == fields.count,
              fields.allSatisfy({ LocalPreferenceField.allCases.map(\.storageName).contains($0) }) else {
            throw LocalPreferenceFileIssue.inconsistentEvidence
        }
        if let base {
            guard base.revision < UInt64.max, target.revision == base.revision + 1,
                  base.commitID != target.commitID, base.digest.count == 64,
                  base.digest.allSatisfy({ $0.isHexDigit }) else { throw LocalPreferenceFileIssue.inconsistentEvidence }
        } else if target.revision != 1 || fields.count != 4 { throw LocalPreferenceFileIssue.inconsistentEvidence }
    }
}

extension LocalPreferenceField {
    var storageName: String {
        switch self {
        case .language: "language"
        case .appearance: "appearance"
        case .quadrantTitleTruncation: "quadrantTitleTruncation"
        case .stampCaptureApp: "stampCaptureApp"
        }
    }
}
