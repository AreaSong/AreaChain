import Foundation

/// 仅四项普通偏好；值自带字段，调用方不能拼出字段/值类型不匹配的写入。
enum LocalPreferenceField: CaseIterable, Hashable, Sendable {
    case language, appearance, quadrantTitleTruncation, stampCaptureApp

    var key: String {
        switch self {
        case .language: return AppPreferences.languageKey
        case .appearance: return AppPreferences.appearanceKey
        case .quadrantTitleTruncation: return AppPreferences.quadrantTitleTruncationKey
        case .stampCaptureApp: return AppPreferences.stampCaptureAppKey
        }
    }
}

enum LocalPreferenceValue: Equatable, Sendable {
    case language(AppLanguage)
    case appearance(AppAppearance)
    case quadrantTitleTruncation(QuadrantTitleTruncation)
    case stampCaptureApp(Bool)

    var field: LocalPreferenceField {
        switch self {
        case .language: return .language
        case .appearance: return .appearance
        case .quadrantTitleTruncation: return .quadrantTitleTruncation
        case .stampCaptureApp: return .stampCaptureApp
        }
    }

    var raw: LocalPreferenceRawValue {
        switch self {
        case .language(let value): return .string(value.rawValue)
        case .appearance(let value): return .string(value.rawValue)
        case .quadrantTitleTruncation(let value): return .string(value.rawValue)
        case .stampCaptureApp(let value): return .bool(value)
        }
    }
}

/// 非标准类型不复制未知负载；unsupported/unavailable 不能作为可靠的原值比较证据。
enum LocalPreferenceRawValue: Equatable, Sendable {
    case missing, string(String), bool(Bool), number(String), unsupported, unavailable

    func canonicalValue(for field: LocalPreferenceField) -> LocalPreferenceValue? {
        switch (field, self) {
        case (.language, .string(let raw)): return AppLanguage(rawValue: raw).map(LocalPreferenceValue.language)
        case (.appearance, .string(let raw)): return AppAppearance(rawValue: raw).map(LocalPreferenceValue.appearance)
        case (.quadrantTitleTruncation, .string(let raw)):
            return QuadrantTitleTruncation(rawValue: raw).map(LocalPreferenceValue.quadrantTitleTruncation)
        case (.stampCaptureApp, .bool(let value)): return .stampCaptureApp(value)
        case (_, .missing): return initialValue(for: field)
        default: return nil
        }
    }

    /// 只用于装载旧设置，保留 UserDefaults 的布尔转换与枚举回退；不写回修复。
    func initialValue(for field: LocalPreferenceField) -> LocalPreferenceValue {
        switch field {
        case .language:
            if case .string(let raw) = self { return .language(AppLanguage(rawValue: raw) ?? .system) }
            return .language(.system)
        case .appearance:
            if case .string(let raw) = self { return .appearance(AppAppearance(rawValue: raw) ?? .system) }
            return .appearance(.system)
        case .quadrantTitleTruncation:
            if case .string(let raw) = self { return .quadrantTitleTruncation(QuadrantTitleTruncation(rawValue: raw) ?? .tail) }
            return .quadrantTitleTruncation(.tail)
        case .stampCaptureApp:
            switch self {
            case .bool(let value): return .stampCaptureApp(value)
            case .string(let raw): return .stampCaptureApp((raw as NSString).boolValue)
            case .number(let raw): return .stampCaptureApp((Double(raw) ?? 0) != 0)
            default: return .stampCaptureApp(false)
            }
        }
    }
}

/// 运行内实例与存储句柄身份；不声称识别同一 suite 的其他句柄或跨进程身份。
struct LocalPreferenceSource: Equatable, Sendable {
    let instanceID: UUID
    let storageID: ObjectIdentifier
}

struct LocalPreferenceSnapshot: Equatable, Sendable {
    let source: LocalPreferenceSource
    let field: LocalPreferenceField
    let revision: UInt64
    let value: LocalPreferenceValue
    let raw: LocalPreferenceRawValue

    var storedValue: LocalPreferenceValue? { raw.canonicalValue(for: field) }
}

struct LocalPreferenceChange: Equatable, Sendable {
    let source: LocalPreferenceSource
    let field: LocalPreferenceField
    let revision: UInt64
}

struct LocalPreferenceWriteResult: Equatable, Sendable {
    typealias Readback = PreferenceReadback
    enum Rejection: Equatable, Sendable { case reentrant, unreadableStorage, snapshotChanged, executionInvalidated }

    let requested: LocalPreferenceValue
    let before: LocalPreferenceSnapshot?
    let after: LocalPreferenceSnapshot?
    var rejection: Rejection?
    var write: PreferenceCallOutcome = .notCalled
    var readback: Readback = .notRead
    var appearance: PreferenceCallOutcome = .notCalled
    var event: PreferenceCallOutcome = .notCalled
}
