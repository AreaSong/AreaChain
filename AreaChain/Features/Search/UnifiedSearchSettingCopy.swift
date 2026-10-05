import Foundation

/// 仅普通标量及实际结果的本地化投影；不把底层错误或原始存储内容带到界面。
enum UnifiedSearchSettingCopy {
    static func action(_ command: CommandID?) -> String {
        switch command?.rawValue {
        case "setting.language": "unified.setting.language"
        case "setting.appearance": "unified.setting.appearance"
        case "setting.truncation": "unified.setting.truncation"
        case "setting.captureSource": "unified.setting.captureSource"
        default: "unified.setting.apply"
        }
    }

    static func value(_ value: CommandValue?, locale: Locale, calendar: Calendar) -> String {
        if value == .choice("system") { return L10n.format("unified.setting.system", locale: locale) }
        return UnifiedSearchOperationCopy.value(value, locale: locale, calendar: calendar)
    }

    static func issue(_ issue: LocalSettingCommandIssue) -> String {
        switch issue {
        case .unwired, .unsupported: "unified.setting.unavailable"
        case .invalidArguments: "unified.setting.arguments"
        case .invalidTargets, .unsupportedLinks: "unified.setting.links"
        case .protectedContent: "unified.operation.protected"
        case .missingBaseline, .untrustedBaseline, .unreliableOriginal: "unified.setting.unread"
        case .multipleOperations: "unified.setting.singleOnly"
        case .busy: "unified.setting.finishEditing"
        case .stale: "unified.setting.stale"
        case .notRetryable: "unified.setting.noRetry"
        case .conflict: "unified.setting.conflict"
        }
    }

    static func result(_ report: LocalSettingCommandReport, unit: CommandExecutionUnit) -> String {
        if unit.local == .unknown || unit.state == .verificationRequired { return "unified.setting.unknown" }
        if unit.preferencePresentation == .superseded { return "unified.setting.superseded" }
        if unit.local == .committed {
            return unit.state == .succeeded ? "unified.setting.applied" : "unified.setting.presentationFailed"
        }
        switch report.outcome {
        case .noChange where unit.state == .succeeded: return "unified.setting.noChange"
        case .conflict: return "unified.setting.conflict"
        case .rejected(let reason): return issue(reason)
        case .write(let write):
            return write.rejection == .unreadableStorage ? "unified.setting.unread" : "unified.setting.rejected"
        default: return "unified.setting.unknown"
        }
    }
}
