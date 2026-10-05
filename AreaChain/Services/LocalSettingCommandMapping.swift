import Foundation

/// 稳定命令值严格转成原偏好类型；初始化的 system 回退不能用于执行参数。
enum LocalSettingCommandMapping {
    static func field(for id: CommandID) -> LocalPreferenceField? {
        switch id.rawValue {
        case "setting.language": .language
        case "setting.appearance": .appearance
        case "setting.truncation": .quadrantTitleTruncation
        case "setting.captureSource": .stampCaptureApp
        default: nil
        }
    }

    /// 读取基线只需确定字段；参数是否完整仍由实际提交的 value 校验。
    static func field(for draft: CommandDraft) throws -> LocalPreferenceField {
        guard !draft.blocksUnprotectedExport else { throw LocalSettingCommandIssue.protectedContent }
        guard let command = CommandCatalog.standard.command(id: draft.commandID),
              let field = field(for: command.id) else { throw LocalSettingCommandIssue.unsupported }
        guard draft.targets == .none, command.targetTypes.isEmpty else { throw LocalSettingCommandIssue.invalidTargets }
        return field
    }

    static func value(for draft: CommandDraft) throws -> LocalPreferenceValue {
        let field = try field(for: draft)
        guard let command = CommandCatalog.standard.command(id: draft.commandID) else { throw LocalSettingCommandIssue.unsupported }
        guard CommandArgumentValidation.issues(for: draft.arguments, command: command).isEmpty,
              draft.arguments.count == 1, draft.arguments[0].operation == .assign else {
            throw LocalSettingCommandIssue.invalidArguments
        }
        switch (field, draft.arguments[0].parameter, draft.arguments[0].value) {
        case (.language, .value, .choice(let raw)):
            if let value = AppLanguage(rawValue: raw) { return .language(value) }
        case (.appearance, .value, .choice(let raw)):
            if let value = AppAppearance(rawValue: raw) { return .appearance(value) }
        case (.quadrantTitleTruncation, .value, .choice(let raw)):
            if let value = QuadrantTitleTruncation(rawValue: raw) { return .quadrantTitleTruncation(value) }
        case (.stampCaptureApp, .enabled, .boolean(let value)): return .stampCaptureApp(value)
        default: break
        }
        throw LocalSettingCommandIssue.invalidArguments
    }

    static func parameter(_ value: LocalPreferenceValue) -> CommandParameterID {
        value.field == .stampCaptureApp ? .enabled : .value
    }

    static func commandValue(_ value: LocalPreferenceValue) -> CommandValue {
        switch value.raw {
        case .string(let raw): return .choice(raw)
        case .bool(let raw): return .boolean(raw)
        default: preconditionFailure("普通偏好只有选择值和布尔值")
        }
    }

    static func raw(_ value: LocalPreferenceRawValue) -> CommandPreferenceBaseline.Raw {
        switch value {
        case .missing: return .missing
        case .string(let raw): return .string(raw)
        case .bool(let raw): return .bool(raw)
        case .number(let raw): return .number(raw)
        case .unsupported: return .unsupported
        case .unavailable: return .unavailable
        }
    }

    static func matches(_ evidence: CommandPreferenceBaseline, _ snapshot: LocalPreferenceSnapshot) -> Bool {
        evidence.instanceID == snapshot.source.instanceID && evidence.storageID == snapshot.source.storageID
            && evidence.revision == snapshot.revision && evidence.raw == raw(snapshot.raw)
            && evidence.memory == commandValue(snapshot.value)
            && evidence.stored == snapshot.storedValue.map(commandValue)
    }
}

enum LocalSettingCommandIssue: Error, Equatable {
    case unwired, unsupported, invalidArguments, invalidTargets, protectedContent, missingBaseline, untrustedBaseline
    case multipleOperations, unsupportedLinks, busy, stale, notRetryable
    case unreliableOriginal(LocalPreferenceSnapshot)
    case conflict(LocalSettingCommandConflict)
}

struct LocalSettingCommandConflict: Equatable {
    let baseline: CommandPreferenceBaseline
    let current: LocalPreferenceSnapshot
}

struct LocalSettingCommandRequest: Equatable {
    let lease: CommandHostLease
    let operation: CommandOperationIdentity
    let attempt: CommandAttemptStamp
}

struct LocalSettingCommandReport: Equatable {
    enum Outcome: Equatable {
        case noChange, rejected(LocalSettingCommandIssue), conflict(LocalSettingCommandConflict)
        case write(LocalPreferenceWriteResult)
        case presentation(CommandPreferencePresentation)
    }
    let operation: CommandOperationIdentity
    let receipt: CommandExecutionReceipt
    let outcome: Outcome
}
