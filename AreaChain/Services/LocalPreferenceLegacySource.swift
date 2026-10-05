import Foundation

/// 这里只接受受控测试 suite 的显式读取器；没有 standard 或生产域的隐式装配。
struct LocalPreferenceLegacySource {
    let identity: LocalPreferenceLegacyIdentity
    let read: (LocalPreferenceField) throws -> LocalPreferenceLegacyObservation

    func capture() throws -> LocalPreferenceLegacySnapshot {
        guard !identity.isolatedSuiteName.isEmpty, identity.isolatedSuiteName.utf8.count <= 255 else {
            throw LocalPreferenceMigrationIssue.invalidSourceIdentity
        }
        var observations: [LocalPreferenceLegacyObservation] = []
        var values = LocalPreferenceValues.legacyDefaults
        for field in LocalPreferenceField.allCases {
            let observation: LocalPreferenceLegacyObservation
            do { observation = try read(field) }
            catch { throw LocalPreferenceMigrationIssue.legacyReadFailed(field) }
            values.set(try observation.validatedValue(for: field))
            observations.append(observation)
        }
        return .init(source: identity, observations: observations, values: values)
    }
}

struct LocalPreferenceLegacyIdentity: Codable, Equatable, Sendable {
    let isolatedSuiteName: String
}

enum LocalPreferenceLegacyOrigin: String, Equatable, Sendable {
    case persistentDomain, declaredDefault, registration, volatile, managed, unknown, conflict
}

/// 来源证据由读取适配器提供，不能从 object(forKey:) 与原值恰好相等反推来源。
struct LocalPreferenceLegacyObservation: Equatable, Sendable {
    let exists: Bool
    let persistent: LocalPreferenceRawValue
    let effective: LocalPreferenceRawValue
    let origin: LocalPreferenceLegacyOrigin

    func validatedValue(for field: LocalPreferenceField) throws -> LocalPreferenceValue {
        guard persistent != .unavailable, effective != .unavailable else {
            throw LocalPreferenceMigrationIssue.legacyReadFailed(field)
        }
        guard origin == .persistentDomain || origin == .declaredDefault else {
            throw LocalPreferenceMigrationIssue.untrustedSource(field, origin)
        }
        guard exists == (persistent != .missing),
              origin == (exists ? .persistentDomain : .declaredDefault) else {
            throw LocalPreferenceMigrationIssue.untrustedSource(field, .conflict)
        }
        guard let value = persistent.canonicalValue(for: field),
              let visible = effective.canonicalValue(for: field) else {
            throw LocalPreferenceMigrationIssue.invalidLegacyValue(field)
        }
        guard visible == value, !exists || effective == persistent else {
            throw LocalPreferenceMigrationIssue.untrustedSource(field, .conflict)
        }
        return value
    }
}

struct LocalPreferenceLegacySnapshot: Equatable, Sendable {
    let source: LocalPreferenceLegacyIdentity
    let observations: [LocalPreferenceLegacyObservation]
    let values: LocalPreferenceValues
}

extension LocalPreferenceValues {
    static var legacyDefaults: Self {
        .init(language: .system, appearance: .system, quadrantTitleTruncation: .tail, stampCaptureApp: false)
    }
}

enum LocalPreferenceMigrationIssue: Error, Equatable, Sendable {
    case invalidSourceIdentity
    case legacyReadFailed(LocalPreferenceField)
    case invalidLegacyValue(LocalPreferenceField)
    case untrustedSource(LocalPreferenceField, LocalPreferenceLegacyOrigin)
    case sourceChanged
    case file(LocalPreferenceFileIssue)
}

/// 3B2B 的输入：只有 ready 含可发布的完整权威记录；其他分支不能签发可写基线。
enum LocalPreferenceMigrationResult: Equatable, Sendable {
    case notMigrated(readOnly: LocalPreferenceValues)
    case ready(LocalPreferenceRecord, cleanupPending: Bool)
    case conflict(LocalPreferenceMigrationIssue)
    case recoveryRequired(LocalPreferenceMigrationRecovery)
    case failed(LocalPreferenceMigrationIssue)
}

enum LocalPreferenceMigrationRecovery: Equatable, Sendable {
    case backend(LocalPreferenceFileRecovery)
    case unverifiedCommit(LocalPreferencePendingWrite, LocalPreferenceFileIssue)
}
