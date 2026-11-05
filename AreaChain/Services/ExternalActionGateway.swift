import Foundation
import Observation

extension ActionExecutionOutput {
    private static let gatewayFailedSentinelKey = "__gateway_succeeded__"

    /// 供外部网关与动作调用方构造带显式成功/失败状态的执行结果。
    init(
        succeeded: Bool, message: String, diff: ActionDiff? = nil,
        undoClosure: (@MainActor () throws -> Void)? = nil, redoClosure: (@MainActor () throws -> Void)? = nil
    ) {
        let payload: ActionUndoPayload? = succeeded ? nil : ActionUndoPayload(
            actionID: diff?.actionID ?? "gateway.blocked", snapshot: [Self.gatewayFailedSentinelKey: "false"]
        )
        self.init(message: message, diff: diff, undoPayload: payload, undoClosure: undoClosure, redoClosure: redoClosure)
    }

    /// 指示本次动作执行是否成功放行并完成。
    var succeeded: Bool { undoPayload?.snapshot[Self.gatewayFailedSentinelKey] != "false" }
}

/// 外部 URL Scheme 与 CLI 网关的访问权限策略。
enum ExternalAccessPolicy: String, CaseIterable, Codable, Sendable {
    case disabled
    case normalOnly
    case normalAndPrivacy
    case allIncludingSystem

    func canExecute(_ permission: ActionPermissionLevel) -> Bool {
        switch self {
        case .disabled: return false
        case .normalOnly: return permission == .normal
        case .normalAndPrivacy: return permission == .normal || permission == .privacy
        case .allIncludingSystem: return true
        }
    }

    var maxPermissionLevel: ActionPermissionLevel {
        switch self {
        case .disabled, .normalOnly: return .normal
        case .normalAndPrivacy: return .privacy
        case .allIncludingSystem: return .system
        }
    }

    static func parse(_ raw: String) -> ExternalAccessPolicy? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "disabled", "off", "none", "disable", "关闭", "禁用": return .disabled
        case "normal", "normalonly", "default", "普通", "常规": return .normalOnly
        case "privacy", "normalandprivacy", "隐私", "含隐私": return .normalAndPrivacy
        case "system", "all", "allincludingsystem", "系统", "全部": return .allIncludingSystem
        default: return nil
        }
    }
}

/// 外部调用网关，统一收敛 `areachain://` URL Scheme 与外部 CLI 请求的权限门禁、动作派发与历史审计。
@MainActor
@Observable
final class ExternalActionGateway {
    static let policyDefaultsKey = "areachain.prefs.externalAccessPolicy"
    static let shared = ExternalActionGateway()

    private let defaults: UserDefaults
    let registry: ActionRegistry
    let historyStore: ActionHistoryStore

    var policy: ExternalAccessPolicy {
        didSet { defaults.set(policy.rawValue, forKey: Self.policyDefaultsKey) }
    }

    init(defaults: UserDefaults? = nil, registry: ActionRegistry? = nil, historyStore: ActionHistoryStore? = nil) {
        if let defaults {
            self.defaults = defaults
        } else if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            self.defaults = UserDefaults(suiteName: "areachain.gateway.tests") ?? .standard
        } else {
            self.defaults = .standard
        }
        let resolvedRegistry = registry ?? ActionRegistry.shared
        self.registry = resolvedRegistry
        self.historyStore = historyStore ?? resolvedRegistry.historyStore

        if let raw = self.defaults.string(forKey: Self.policyDefaultsKey),
           let saved = ExternalAccessPolicy(rawValue: raw) ?? ExternalAccessPolicy.parse(raw) {
            self.policy = saved
        } else {
            self.policy = .normalOnly
        }
        if resolvedRegistry.action(for: "pref.externalAccess") == nil {
            resolvedRegistry.register(ExternalAccessPreferenceAction(gateway: self))
        }
    }

    func canExecute(_ permission: ActionPermissionLevel) -> Bool {
        policy.canExecute(permission)
    }

    @discardableResult
    func handle(url: URL, context: ActionContext? = nil) -> ActionResult {
        execute(url: url, context: context)
    }

    @discardableResult
    func execute(urlString: String, context: ActionContext? = nil) -> ActionResult {
        guard let url = URL(string: urlString) else {
            return ActionResult(succeeded: false, message: "无效的外部调用 URL：\(urlString)")
        }
        return execute(url: url, context: context)
    }

    @discardableResult
    func execute(url: URL, context: ActionContext? = nil) -> ActionResult {
        guard url.scheme?.lowercased() == "areachain" else {
            return ActionResult(succeeded: false, message: "不支持的 URL Scheme：\(url.scheme ?? "nil")")
        }
        guard policy != .disabled else {
            return ActionResult(succeeded: false, message: "外部调用已关闭（策略：disabled）")
        }
        let host = (url.host ?? "").lowercased()
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        switch host {
        case "action":
            let pathActionID = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let actionIDText = pathActionID.isEmpty
                ? (queryItems.first(where: { $0.name == "id" || $0.name == "action" })?.value ?? "")
                : pathActionID
            guard !actionIDText.isEmpty else {
                return ActionResult(succeeded: false, message: "URL 缺少动作标识（actionID）")
            }
            return executeAction(identifierOrCommand: actionIDText, rawArguments: Self.extractRawArguments(from: queryItems), context: context)

        case "cli":
            let cmdValue = queryItems.first(where: { $0.name == "cmd" || $0.name == "command" || $0.name == "q" })?.value
                ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let trimmed = cmdValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return ActionResult(succeeded: false, message: "URL 缺少 CLI 指令参数（cmd）")
            }
            return executeCLI(trimmed, context: context)

        default:
            guard !host.isEmpty else {
                return ActionResult(succeeded: false, message: "无法识别的外部调用路径：\(url.absoluteString)")
            }
            return executeAction(identifierOrCommand: host, rawArguments: Self.extractRawArguments(from: queryItems), context: context)
        }
    }

    @discardableResult
    func executeAction(identifierOrCommand: String, rawArguments: String = "", context: ActionContext? = nil) -> ActionResult {
        guard policy != .disabled else {
            return ActionResult(succeeded: false, message: "外部调用已关闭（策略：disabled）")
        }
        guard let action = registry.action(for: ActionID(identifierOrCommand)) ?? registry.action(forCommand: identifierOrCommand) else {
            return ActionResult(succeeded: false, message: "未找到动作：\(identifierOrCommand)")
        }
        guard canExecute(action.permissionLevel) else {
            return ActionResult(
                succeeded: false,
                message: "外部接口权限不足：动作 \(action.id) 需要 \(action.permissionLevel.rawValue) 权限（当前策略：\(policy.rawValue)）"
            )
        }
        let cmdLine = rawArguments.isEmpty ? "/\(action.metadata.primaryCommand)" : "/\(action.metadata.primaryCommand) \(rawArguments)"
        let args: ParsedActionArguments
        switch ActionCLIParser.parse(cmdLine) {
        case .command(let p), .pipeline(let p): args = p
        case .search(let q):
            args = ParsedActionArguments(rawInput: cmdLine, commandName: action.metadata.primaryCommand, positional: q.isEmpty ? [] : [q])
        }
        return dispatchVerified(action: action, arguments: args, baseContext: context)
    }

    @discardableResult
    func executeCLI(_ commandLine: String, context: ActionContext? = nil) -> ActionResult {
        guard policy != .disabled else {
            return ActionResult(succeeded: false, message: "外部调用已关闭（策略：disabled）")
        }
        let normalizedInput = commandLine.hasPrefix("/") || commandLine.contains(">") ? commandLine : "/\(commandLine)"
        let args: ParsedActionArguments
        switch ActionCLIParser.parse(normalizedInput) {
        case .command(let p), .pipeline(let p): args = p
        case .search(let query): args = ParsedActionArguments(rawInput: normalizedInput, commandName: query)
        }
        guard let action = registry.action(forCommand: args.commandName)
                ?? registry.action(for: ActionID(args.commandName))
                ?? registry.matchingActions(for: args.commandName).first else {
            return ActionResult(succeeded: false, message: "未找到指令对应的动作：\(args.commandName)")
        }
        guard canExecute(action.permissionLevel) else {
            return ActionResult(
                succeeded: false,
                message: "外部接口权限不足：动作 \(action.id) 需要 \(action.permissionLevel.rawValue) 权限（当前策略：\(policy.rawValue)）"
            )
        }
        return dispatchVerified(action: action, arguments: args, baseContext: context)
    }

    private func dispatchVerified(action: BaseAction, arguments: ParsedActionArguments, baseContext: ActionContext?) -> ActionResult {
        var finalArgs = arguments
        if action.riskLevel == .confirm && !finalArgs.hasFlag("confirm") && !finalArgs.hasFlag("yes") {
            var opts = finalArgs.options
            opts["confirm"] = "true"
            finalArgs = ParsedActionArguments(
                rawInput: finalArgs.rawInput, commandName: finalArgs.commandName, targetQuery: finalArgs.targetQuery,
                positional: finalArgs.positional, options: opts, inlineNLP: finalArgs.inlineNLP
            )
        }
        let gatewayContext = ActionContext(
            modelContext: baseContext?.modelContext, host: "externalGateway",
            currentTab: baseContext?.currentTab,
            selectedObjectIDs: baseContext?.selectedObjectIDs ?? [], focusedObjectID: baseContext?.focusedObjectID,
            todayKey: baseContext?.todayKey ?? DayKey.today(), isVaultUnlocked: baseContext?.isVaultUnlocked ?? true,
            allowedExternalPermission: policy.maxPermissionLevel, confirmed: true
        )
        let beforeTopID = historyStore.appliedEntries.last?.id
        let status = registry.execute(id: action.id, arguments: finalArgs, context: gatewayContext)
        switch status {
        case .succeeded(let message, let diff):
            if historyStore !== registry.historyStore, action.recordsUndo,
               let latest = registry.historyStore.appliedEntries.last, latest.id != beforeTopID {
                historyStore.record(diff: latest.diff, message: latest.message, undoPayload: latest.undoPayload)
            }
            return ActionResult(succeeded: true, message: message, diff: diff)
        case .permissionDenied(let required, _):
            return ActionResult(succeeded: false, message: "外部接口权限不足：需要 \(required.rawValue)")
        case .unavailable(let avail):
            return ActionResult(succeeded: false, message: "动作当前不可用：\(avail)")
        case .actionNotFound(let name):
            return ActionResult(succeeded: false, message: "未找到动作：\(name)")
        case .requiresConfirmation(_, let prompt, _):
            return ActionResult(succeeded: false, message: prompt)
        case .requiresAuthentication(_, let reason), .requiresFileDialog(_, let reason), .failed(let reason):
            return ActionResult(succeeded: false, message: reason)
        }
    }

    private static func extractRawArguments(from queryItems: [URLQueryItem]) -> String {
        guard !queryItems.isEmpty else { return "" }
        if let explicit = queryItems.first(where: { $0.name == "args" || $0.name == "arg" })?.value { return explicit }
        return queryItems.compactMap { item in
            guard item.name != "id" && item.name != "action" else { return nil }
            guard let val = item.value, !val.isEmpty else { return "--\(item.name)" }
            return "--\(item.name) \(val.contains(" ") ? "\"\(val)\"" : val)"
        }.joined(separator: " ")
    }
}

/// 切换外部调用网关三级权限策略的统一动作（`pref.externalAccess`）。
@MainActor
final class ExternalAccessPreferenceAction: BaseAction {
    private weak var gateway: ExternalActionGateway?

    init(gateway: ExternalActionGateway? = nil) {
        self.gateway = gateway
        super.init(
            id: "pref.externalAccess",
            englishTitle: "Set External Access Policy",
            chineseTitle: "外部接口权限",
            commandNames: ["external-access", "ext-access", "外部调用权限", "外部接口权限"],
            iconName: "network.badge.shield.half.filled",
            category: .settings,
            parameters: [
                ActionParameterSpec(
                    id: "policy",
                    englishName: "disabled/normal/privacy/system",
                    chineseName: "disabled/normal/privacy/system",
                    required: true
                ),
            ],
            permissionLevel: .system
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let targetGateway = gateway ?? ExternalActionGateway.shared
        let rawToken = arguments.option("policy") ?? arguments.option("value") ?? arguments.positional.first ?? arguments.inlineNLP.cleanText
        guard let nextPolicy = ExternalAccessPolicy.parse(rawToken) ?? ExternalAccessPolicy(rawValue: rawToken) else {
            throw ActionExecutionError.invalidParameterValue(parameter: "policy", value: rawToken)
        }
        let previousPolicy = targetGateway.policy
        targetGateway.policy = nextPolicy
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: "外部接口权限",
            changes: [ActionFieldChange(field: "权限策略", before: previousPolicy.rawValue, after: nextPolicy.rawValue)]
        )
        return ActionExecutionOutput(
            message: "已将外部接口权限策略切换为 \(nextPolicy.rawValue)", diff: diff,
            undoClosure: { targetGateway.policy = previousPolicy },
            redoClosure: { targetGateway.policy = nextPolicy }
        )
    }
}
