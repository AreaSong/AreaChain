import Foundation

/// 动作执行时抛出的业务或参数校验错误。
enum ActionExecutionError: LocalizedError, Equatable, Sendable {
    case missingRequiredParameter(String)
    case invalidParameterValue(parameter: String, value: String)
    case targetNotFound(String)
    case unavailable(String)
    case unimplemented(ActionID)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingRequiredParameter(let name):
            return "缺少必填参数：\(name)"
        case .invalidParameterValue(let parameter, let value):
            return "参数 \(parameter) 的值无效：\(value)"
        case .targetNotFound(let target):
            return "未找到目标对象：\(target)"
        case .unavailable(let reason):
            return reason
        case .unimplemented(let id):
            return "动作尚未实现：\(id.rawValue)"
        case .executionFailed(let message):
            return message
        }
    }
}

/// 单次动作执行完成后的产出，包含单行回显、修改明细及双向撤销/重做钩子。
struct ActionExecutionOutput {
    let message: String
    let diff: ActionDiff?
    let undoPayload: ActionUndoPayload?
    let undoClosure: (@MainActor () throws -> Void)?
    let redoClosure: (@MainActor () throws -> Void)?

    init(
        message: String,
        diff: ActionDiff? = nil,
        undoPayload: ActionUndoPayload? = nil,
        undoClosure: (@MainActor () throws -> Void)? = nil,
        redoClosure: (@MainActor () throws -> Void)? = nil
    ) {
        self.message = message
        self.diff = diff
        self.undoPayload = undoPayload
        self.undoClosure = undoClosure
        self.redoClosure = redoClosure
    }
}

/// 统一动作注册表执行后的状态返回，覆盖成功、内联二次确认、系统认证/文件框、权限拦截与不可用。
enum ActionExecutionStatus: Equatable, Sendable {
    case succeeded(message: String, diff: ActionDiff?)
    case requiresConfirmation(actionID: ActionID, prompt: String, arguments: ParsedActionArguments)
    case requiresAuthentication(actionID: ActionID, reason: String)
    case requiresFileDialog(actionID: ActionID, prompt: String)
    case unavailable(ActionAvailability)
    case permissionDenied(required: ActionPermissionLevel, allowed: ActionPermissionLevel)
    case actionNotFound(String)
    case failed(String)

    var isSuccess: Bool {
        if case .succeeded = self { return true }
        return false
    }

    var message: String? {
        switch self {
        case .succeeded(let message, _):
            return message
        case .requiresConfirmation(_, let prompt, _):
            return prompt
        case .requiresAuthentication(_, let reason):
            return reason
        case .requiresFileDialog(_, let prompt):
            return prompt
        case .unavailable(let availability):
            if case .disabled(let reason) = availability { return reason }
            if case .requiresUnlock = availability { return "需要先解锁私密空间" }
            return nil
        case .permissionDenied(let required, let allowed):
            return "权限不足：需要\(required.chineseTitle)权限（当前允许：\(allowed.chineseTitle)）"
        case .actionNotFound(let query):
            return "未找到动作：\(query)"
        case .failed(let reason):
            return reason
        }
    }
}

/// 全软件所有可操作功能的唯一基类，统一承载元数据、可用性判定、执行逻辑与撤销登记。
@MainActor
class BaseAction {
    let id: ActionID
    let titleKey: String
    let englishTitle: String
    let chineseTitle: String
    let commandNames: [String]
    let iconName: String
    let category: ActionCategory
    let parameters: [ActionParameterSpec]
    let permissionLevel: ActionPermissionLevel
    let riskLevel: ActionRiskLevel
    let recordsUndo: Bool

    init(
        id: ActionID,
        titleKey: String? = nil,
        englishTitle: String,
        chineseTitle: String,
        commandNames: [String],
        iconName: String = "bolt.fill",
        category: ActionCategory,
        parameters: [ActionParameterSpec] = [],
        permissionLevel: ActionPermissionLevel = .normal,
        riskLevel: ActionRiskLevel = .direct,
        recordsUndo: Bool = true
    ) {
        self.id = id
        self.titleKey = titleKey ?? "action.\(id.rawValue)"
        self.englishTitle = englishTitle
        self.chineseTitle = chineseTitle
        let cleanedNames = commandNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.hasPrefix("/") ? String($0.dropFirst()) : $0 }
            .filter { !$0.isEmpty }
        self.commandNames = cleanedNames.isEmpty ? [id.rawValue] : cleanedNames
        self.iconName = iconName
        self.category = category
        self.parameters = parameters
        self.permissionLevel = permissionLevel
        self.riskLevel = riskLevel
        self.recordsUndo = recordsUndo
    }

    var metadata: ActionMetadataDescriptor {
        ActionMetadataDescriptor(
            id: id,
            titleKey: titleKey,
            englishTitle: englishTitle,
            chineseTitle: chineseTitle,
            commandNames: commandNames,
            iconName: iconName,
            category: category,
            parameters: parameters,
            permissionLevel: permissionLevel,
            riskLevel: riskLevel,
            recordsUndo: recordsUndo
        )
    }

    func localizedTitle(for locale: Locale = .current) -> String {
        locale.identifier.hasPrefix("zh") ? chineseTitle : englishTitle
    }

    func matchesCommand(_ rawCommand: String) -> Bool {
        let cleaned = rawCommand
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("/")
            .lowercased()
        guard !cleaned.isEmpty else { return false }
        if id.rawValue.lowercased() == cleaned {
            return true
        }
        return commandNames.contains { $0.lowercased() == cleaned }
    }

    /// 评估动作在当前宿主上下文中是否可执行；子类可重载以校验选中对象或窗口状态。
    func availability(in context: ActionContext) -> ActionAvailability {
        if permissionLevel == .privacy && !context.isVaultUnlocked {
            return .requiresUnlock
        }
        return .available
    }

    /// 生成内联二次确认提示文案，供 `riskLevel == .confirm` 在未确认时回显。
    func confirmationPrompt(arguments: ParsedActionArguments, context: ActionContext) -> String {
        let target = arguments.targetQuery
            ?? context.focusedObjectTitle
            ?? (arguments.joinedPositional.isEmpty ? nil : arguments.joinedPositional)
        if let target, !target.isEmpty {
            return "确认执行「\(chineseTitle)」（目标：\(target)）？再次回车或加 --confirm 确认"
        }
        return "确认执行「\(chineseTitle)」？再次回车或加 --confirm 确认"
    }

    /// 执行动作核心逻辑并返回回显文本、修改明细及撤销闭包。
    func perform(
        arguments: ParsedActionArguments,
        context: ActionContext
    ) throws -> ActionExecutionOutput {
        throw ActionExecutionError.unimplemented(id)
    }
}
