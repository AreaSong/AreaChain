import Foundation
import Testing
@testable import AreaChain

/// 只拥有自己新建的 suite；逐键读取确切持久域，不枚举整个 defaults 域。
final class LocalPreferenceMigrationFixture {
    let files: LocalPreferenceFileFixture
    let suiteName = "AreaChain.PreferenceMigrationTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    var origins: [LocalPreferenceField: LocalPreferenceLegacyOrigin] = [:]
    var effectiveOverrides: [LocalPreferenceField: LocalPreferenceRawValue] = [:]
    var reads: [LocalPreferenceField] = []
    var beforeRead: ((LocalPreferenceField, Int) throws -> Void)?

    init() throws {
        files = try LocalPreferenceFileFixture()
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit { defaults.removePersistentDomain(forName: suiteName) }

    var source: LocalPreferenceLegacySource {
        .init(identity: .init(isolatedSuiteName: suiteName), read: { [self] field in
            reads.append(field)
            try beforeRead?(field, reads.count)
            let stored = persistent(field)
            return .init(exists: stored != .missing, persistent: stored,
                         effective: effectiveOverrides[field] ?? Self.raw(defaults.object(forKey: field.key)),
                         origin: origins[field] ?? (stored == .missing ? .declaredDefault : .persistentDomain))
        })
    }

    func persistent(_ field: LocalPreferenceField) -> LocalPreferenceRawValue {
        Self.raw(CFPreferencesCopyValue(field.key as CFString, suiteName as CFString,
                                       kCFPreferencesCurrentUser, kCFPreferencesAnyHost))
    }

    func oldFourKeys() -> [LocalPreferenceRawValue] { LocalPreferenceField.allCases.map(persistent) }

    func set(_ value: LocalPreferenceValue) {
        switch value.raw {
        case .string(let raw): defaults.set(raw, forKey: value.field.key)
        case .bool(let raw): defaults.set(raw, forKey: value.field.key)
        default: preconditionFailure("夹具只写类型化值")
        }
    }

    func migrate(_ fault: LocalPreferenceFileFault? = nil) throws -> LocalPreferenceRecord {
        guard case .ready(let record, _) = try files.store(fault).migrate(from: source) else {
            throw LocalPreferenceFileIssue.invalidRequest
        }
        return record
    }

    func evidence() throws -> LocalPreferenceMigrationEvidence {
        try .decode(files.bytes("migration.plist"))
    }

    private static func raw(_ object: Any?) -> LocalPreferenceRawValue {
        guard let object else { return .missing }
        if let number = object as? NSNumber {
            return CFGetTypeID(number) == CFBooleanGetTypeID() ? .bool(number.boolValue) : .number(number.stringValue)
        }
        if let string = object as? String { return .string(string) }
        return .unsupported
    }
}
