import AppKit
import Foundation

/// 只包四键的同步读写；注入的 throw 不是 UserDefaults 提供的持久化失败回执。
@MainActor
struct LocalPreferenceStorage {
    let identity: ObjectIdentifier
    var read: (LocalPreferenceField) throws -> LocalPreferenceRawValue
    var write: (LocalPreferenceValue) throws -> Void

    init(defaults: UserDefaults) {
        identity = ObjectIdentifier(defaults)
        read = { field in
            guard let value = defaults.object(forKey: field.key) else { return .missing }
            if let number = value as? NSNumber {
                if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
                return .number(number.stringValue)
            }
            if let string = value as? String { return .string(string) }
            return .unsupported
        }
        write = { value in
            switch value.raw {
            case .string(let raw): defaults.set(raw, forKey: value.field.key)
            case .bool(let raw): defaults.set(raw, forKey: value.field.key)
            default: preconditionFailure("类型化普通偏好必须有可写值")
            }
        }
    }
}

@MainActor
struct LocalPreferenceEffects {
    var applyAppearance: (AppAppearance) throws -> Void
    var post: (Notification) throws -> Void

    static let live = LocalPreferenceEffects(
        applyAppearance: { appearance in
            switch appearance {
            case .system: NSApp.appearance = nil
            case .light: NSApp.appearance = NSAppearance(named: .aqua)
            case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        },
        post: { NotificationCenter.default.post($0) }
    )
}
