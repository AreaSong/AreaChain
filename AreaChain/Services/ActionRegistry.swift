import Foundation
import Observation

/// 全局统一动作注册表，负责动作登记、命令与别名索引、目录分组导出、权限与确认门禁及执行派发。
@MainActor
@Observable
final class ActionRegistry {
    static let shared = ActionRegistry(historyStore: .shared)

    let historyStore: ActionHistoryStore
    private(set) var actionsByID: [ActionID: BaseAction] = [:]
    private(set) var orderedActionIDs: [ActionID] = []
    private var commandIndex: [String: ActionID] = [:]

    init(
        historyStore: ActionHistoryStore? = nil,
        registerBuiltins: Bool = true
    ) {
        let resolvedStore = historyStore ?? ActionHistoryStore()
        self.historyStore = resolvedStore
        if registerBuiltins {
            registerBuiltinHistoryActions()
        }
    }

    func registerBuiltinHistoryActions() {
        register(UndoAction(historyStore: historyStore))
        register(RedoAction(historyStore: historyStore))
        register(HistoryQueryAction(historyStore: historyStore))
    }

    /// 注册单个动作并建立其 ActionID 与中英文命令名、简写的快速索引。
    func register(_ action: BaseAction) {
        let id = action.id
        if actionsByID[id] == nil {
            orderedActionIDs.append(id)
        } else {
            removeCommandIndexEntries(for: id)
        }
        actionsByID[id] = action
        commandIndex[id.rawValue.lowercased()] = id
        for name in action.commandNames {
            let normalized = Self.normalizeCommandToken(name)
            if !normalized.isEmpty {
                commandIndex[normalized] = id
            }
        }
    }

    /// 批量注册多个动作。
    func register(_ actions: [BaseAction]) {
        for action in actions {
            register(action)
        }
    }

    /// 按稳定标识查找动作。
    func action(for id: ActionID) -> BaseAction? {
        if let direct = actionsByID[id] { return direct }
        switch id.rawValue {
        case "action.undo": return actionsByID[.undo]
        case "action.redo": return actionsByID[.redo]
        case "action.history": return actionsByID[.historyQuery]
        default: return nil
        }
    }

    /// 按命令名、简写或中文命令查找动作。
    func action(forCommand commandName: String) -> BaseAction? {
        let normalized = Self.normalizeCommandToken(commandName)
        guard !normalized.isEmpty else { return nil }
        if let id = commandIndex[normalized], let found = actionsByID[id] {
            return found
        }
        return allActions.first { $0.matchesCommand(normalized) }
    }

    /// 按命令名、简写或稳定 `ActionID` 查找动作。
    func resolve(commandOrID: String) -> BaseAction? {
        action(forCommand: commandOrID) ?? action(for: ActionID(rawValue: commandOrID))
    }

    /// 按搜索词匹配动作元数据描述。
    func matchActions(query: String) -> [ActionMetadataDescriptor] {
        ActionCLIParser.matchActions(query: query, in: allMetadata)
    }

    /// 自动生成统一搜索框命令行帮助概览文本。
    func generateHelpGuide() -> String {
        exportedCatalogGroups().map { group in
            let lines = group.actions.map { desc in
                let cmds = desc.commandNames.map { "/\($0)" }.joined(separator: ", ")
                return "  \(cmds) — \(desc.chineseTitle) (\(desc.englishTitle))"
            }.joined(separator: "\n")
            return "[\(group.category.chineseTitle)]\n\(lines)"
        }.joined(separator: "\n\n")
    }

    /// 按搜索词匹配动作名称、别名或标题，供统一搜索框候选列表与回车直达使用。
    func matchingActions(for query: String) -> [BaseAction] {
        let matchedMetadata = ActionCLIParser.matchActions(query: query, in: allMetadata)
        return matchedMetadata.compactMap { actionsByID[$0.id] }
    }

    /// 计算当前搜索框输入前缀的 Tab 自动补全建议。
    func completions(for rawInput: String) -> [ActionCompletionCandidate] {
        ActionCLIParser.completions(for: rawInput, in: allMetadata)
    }

    /// 按注册顺序返回全部动作实例。
    var allActions: [BaseAction] {
        orderedActionIDs.compactMap { actionsByID[$0] }
    }

    /// 按注册顺序导出全部动作的纯值类型元数据描述。
    var allMetadata: [ActionMetadataDescriptor] {
        allActions.map(\.metadata)
    }

    /// 按业务类别自动导出全量动作目录分组，替代手写指令目录。
    func exportedCatalogGroups() -> [ActionCatalogGroup] {
        let allMeta = allMetadata
        return ActionCategory.allCases.compactMap { category in
            let items = allMeta.filter { $0.category == category }
            guard !items.isEmpty else { return nil }
            return ActionCatalogGroup(category: category, actions: items)
        }
    }

    /// 统一动作执行入口：完成权限校验、可用性拦截、二次确认检查、默认值注入与历史记录落盘。
    @discardableResult
    func execute(
        id: ActionID,
        arguments: ParsedActionArguments? = nil,
        context: ActionContext
    ) -> ActionExecutionStatus {
        guard let action = action(for: id) else {
            return .actionNotFound(id.rawValue)
        }
        let baseArgs = arguments ?? ParsedActionArguments(
            rawInput: "/\(action.metadata.primaryCommand)",
            commandName: action.metadata.primaryCommand
        )
        let resolvedArgs = applyingDefaultParameterValues(to: baseArgs, specs: action.parameters)
        if let gateStatus = verifyExecutionGate(for: action, arguments: resolvedArgs, context: context) {
            return gateStatus
        }
        do {
            let output = try action.perform(arguments: resolvedArgs, context: context)
            guard action.recordsUndo else {
                return .succeeded(message: output.message, diff: output.diff)
            }
            let recordedDiff = output.diff ?? makeDefaultDiff(for: action, arguments: resolvedArgs, context: context)
            historyStore.record(
                diff: recordedDiff, message: output.message, undoPayload: output.undoPayload,
                undoClosure: output.undoClosure, redoClosure: output.redoClosure
            )
            return .succeeded(message: output.message, diff: recordedDiff)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func verifyExecutionGate(
        for action: BaseAction,
        arguments: ParsedActionArguments,
        context: ActionContext
    ) -> ActionExecutionStatus? {
        if action.permissionLevel > context.allowedExternalPermission {
            return .permissionDenied(required: action.permissionLevel, allowed: context.allowedExternalPermission)
        }
        if action.permissionLevel == .privacy && !context.isVaultUnlocked {
            return .unavailable(.requiresUnlock)
        }
        let currentAvailability = action.availability(in: context)
        guard currentAvailability == .available else {
            return .unavailable(currentAvailability)
        }
        let isConfirmed = context.confirmed || arguments.hasFlag("confirm") || arguments.hasFlag("yes")
        if action.riskLevel == .confirm && !isConfirmed {
            let prompt = action.confirmationPrompt(arguments: arguments, context: context)
            return .requiresConfirmation(actionID: action.id, prompt: prompt, arguments: arguments)
        }
        if action.riskLevel == .authentication && !context.isVaultUnlocked && !isConfirmed {
            return .requiresAuthentication(actionID: action.id, reason: "执行「\(action.chineseTitle)」需要先通过身份验证")
        }
        return nil
    }

    /// 解析并执行统一搜索框的原始输入字符串（支持 `/` 命令、`目标 > 命令` 管道及动作名直达）。
    @discardableResult
    func executeCLI(
        _ rawInput: String,
        context: ActionContext
    ) -> ActionExecutionStatus {
        let parsed = ActionCLIParser.parse(rawInput)
        switch parsed {
        case .command(let args), .pipeline(let args):
            guard !args.commandName.isEmpty else {
                return .actionNotFound(rawInput)
            }
            if let action = action(forCommand: args.commandName) {
                return execute(id: action.id, arguments: args, context: context)
            }
            if let fallback = matchingActions(for: args.commandName).first {
                return execute(id: fallback.id, arguments: args, context: context)
            }
            return .actionNotFound(args.commandName)

        case .search(let query):
            guard !query.isEmpty else {
                return .actionNotFound("")
            }
            if let exactAction = action(forCommand: query) {
                let args = ParsedActionArguments(rawInput: rawInput, commandName: query)
                return execute(id: exactAction.id, arguments: args, context: context)
            }
            if let firstMatch = matchingActions(for: query).first {
                let args = ParsedActionArguments(
                    rawInput: rawInput,
                    commandName: firstMatch.metadata.primaryCommand
                )
                return execute(id: firstMatch.id, arguments: args, context: context)
            }
            return .actionNotFound(query)
        }
    }

    // MARK: - 私有辅助

    private static func normalizeCommandToken(_ token: String) -> String {
        token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("/")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
    }

    private func removeCommandIndexEntries(for id: ActionID) {
        let keysToRemove = commandIndex.compactMap { key, value in
            value == id ? key : nil
        }
        for key in keysToRemove {
            commandIndex.removeValue(forKey: key)
        }
    }

    private func applyingDefaultParameterValues(
        to arguments: ParsedActionArguments,
        specs: [ActionParameterSpec]
    ) -> ParsedActionArguments {
        guard !specs.isEmpty else { return arguments }
        var updated = arguments
        for (idx, spec) in specs.enumerated() {
            guard let defaultValue = spec.defaultValue,
                  updated.option(spec.id) == nil,
                  !updated.positional.indices.contains(idx) else {
                continue
            }
            updated.options[spec.id] = defaultValue
        }
        return updated
    }

    private func makeDefaultDiff(
        for action: BaseAction,
        arguments: ParsedActionArguments,
        context: ActionContext
    ) -> ActionDiff {
        let target = arguments.targetQuery
            ?? context.focusedObjectTitle
            ?? (arguments.joinedPositional.isEmpty ? "" : arguments.joinedPositional)
        return ActionDiff(
            actionID: action.id,
            actionTitle: action.chineseTitle,
            targetTitle: target,
            changes: [],
            isSensitive: action.permissionLevel == .privacy
        )
    }
}
