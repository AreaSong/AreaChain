import Foundation
import Observation
import SwiftData
import SwiftUI

/// 统一搜索框与 `ActionRegistry`、`ActionCLIParser`、`ActionHistoryStore` 的命令行交互会话。
@Observable
@MainActor
final class UnifiedSearchCLISession {
    private static var sessions: [ObjectIdentifier: UnifiedSearchCLISession] = [:]

    static func session(for controller: UnifiedSearchController) -> UnifiedSearchCLISession {
        let key = ObjectIdentifier(controller)
        if let existing = sessions[key] { return existing }
        let created = UnifiedSearchCLISession()
        sessions[key] = created
        return created
    }

    static func removeSession(for controller: UnifiedSearchController) {
        sessions.removeValue(forKey: ObjectIdentifier(controller))
    }

    var statusMessage: String?
    var isErrorStatus = false
    var confirmationPrompt: String?
    var pendingConfirmationInput: String?
    var showingHistory = false
    var historyKeyword = ""

    var lastEcho: String? {
        get { statusMessage }
        set { statusMessage = newValue }
    }

    private static func isPureContentSearchScope(_ trimmed: String) -> Bool {
        let lower = trimmed.lowercased()
        return lower == "/trash"
            || lower.hasPrefix("/trash ")
            || lower == "/clipboard"
            || lower.hasPrefix("/clipboard ")
    }

    /// 按命令名、别名或旧式斜杠路径（如 `todo/create`、`win/open`）解析为统一动作。
    func resolveCLIAction(_ commandName: String) -> BaseAction? {
        StandardActionCatalog.bootstrapIfNeeded()
        let cleaned = commandName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("/")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        if let direct = ActionRegistry.shared.resolve(commandOrID: cleaned) {
            return direct
        }
        let dotNormalized = cleaned.replacingOccurrences(of: "/", with: ".")
        if let byDot = ActionRegistry.shared.resolve(commandOrID: dotNormalized) {
            return byDot
        }
        let dashNormalized = cleaned.replacingOccurrences(of: "/", with: "-")
        if let byDash = ActionRegistry.shared.resolve(commandOrID: dashNormalized) {
            return byDash
        }
        return nil
    }

    /// 判断输入是否应由统一搜索 CLI 会话直接拦截。
    func shouldIntercept(text rawText: String) -> Bool {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.hasPrefix("/") {
            return !Self.isPureContentSearchScope(trimmed)
        }
        switch ActionCLIParser.parse(trimmed) {
        case .pipeline(let args):
            return resolveCLIAction(args.commandName) != nil
        case .command(let args):
            let cmd = args.commandName.lowercased()
            guard !cmd.isEmpty, !Self.isPureContentSearchScope("/\(cmd)") else { return false }
            return resolveCLIAction(cmd) != nil
        case .search:
            return false
        }
    }

    /// 判断输入是否应由 Linux 风格 `ActionCLIParser` 与 `ActionRegistry` 直接接管。
    func handlesCLIInput(_ rawText: String) -> Bool {
        shouldIntercept(text: rawText)
    }

    func updateForInput(_ rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != pendingConfirmationInput {
            confirmationPrompt = nil
            pendingConfirmationInput = nil
        }
        if case .command(let args) = ActionCLIParser.parse(trimmed),
           ["history", "日志", "历史", "action.history"].contains(args.commandName.lowercased()) {
            showingHistory = true
            historyKeyword = args.option("query") ?? args.joinedPositional
        } else if !trimmed.isEmpty {
            showingHistory = false
        }
    }

    func cancelConfirmation() {
        confirmationPrompt = nil
        pendingConfirmationInput = nil
        let isZh = AppPreferences.shared.resolvedLocale.identifier.hasPrefix("zh")
        statusMessage = isZh ? "已取消执行" : "Cancelled"
        isErrorStatus = false
    }

    func shouldPresentPanel(for rawText: String) -> Bool {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if confirmationPrompt != nil || statusMessage != nil || showingHistory {
            return true
        }
        if trimmed.hasPrefix("/") {
            return !Self.isPureContentSearchScope(trimmed)
        }
        if shouldIntercept(text: trimmed) || rawText.contains(" > ") {
            return true
        }
        if !trimmed.isEmpty {
            StandardActionCatalog.bootstrapIfNeeded()
            return !ActionRegistry.shared.matchActions(query: trimmed).isEmpty
        }
        return false
    }

    @discardableResult
    func execute(
        text rawText: String,
        context: ActionContext,
        controller: UnifiedSearchController? = nil,
        source: UnifiedSearchBuffer? = nil
    ) -> ActionExecutionStatus {
        StandardActionCatalog.bootstrapIfNeeded()
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let result: ActionExecutionStatus
        switch ActionCLIParser.parse(trimmed) {
        case .command(let args), .pipeline(let args):
            if !args.commandName.isEmpty, let action = resolveCLIAction(args.commandName) {
                result = ActionRegistry.shared.execute(id: action.id, arguments: args, context: context)
            } else {
                result = ActionRegistry.shared.executeCLI(trimmed, context: context)
            }
        case .search:
            result = ActionRegistry.shared.executeCLI(trimmed, context: context)
        }
        applyResult(result, rawInput: trimmed, controller: controller, source: source)
        return result
    }

    @discardableResult
    func execute(
        input rawText: String,
        controller: UnifiedSearchController,
        source: UnifiedSearchBuffer
    ) -> ActionExecutionStatus {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isConfirmed = pendingConfirmationInput == trimmed && confirmationPrompt != nil
        let nav = controller.navigationRouter?.navigation ?? WorkspaceNavigation.shared
        let context = ActionContext(
            modelContext: Persistence.session.container.mainContext,
            selectedObjectIDs: Array(nav.selectedTaskIDs),
            focusedObjectID: nav.selectedTaskID,
            todayKey: DayClock.shared.todayKey,
            isVaultUnlocked: PrivacyVault.shared.isUnlocked,
            allowedExternalPermission: .system,
            confirmed: isConfirmed
        )
        return execute(text: trimmed, context: context, controller: controller, source: source)
    }

    @discardableResult
    func executeAction(
        id: ActionID,
        controller: UnifiedSearchController,
        source: UnifiedSearchBuffer
    ) -> ActionExecutionStatus {
        StandardActionCatalog.bootstrapIfNeeded()
        let cmdName = ActionRegistry.shared.action(for: id)?.commandNames.first ?? id.rawValue
        return execute(input: "/\(cmdName)", controller: controller, source: source)
    }

    private func applyResult(
        _ result: ActionExecutionStatus,
        rawInput: String,
        controller: UnifiedSearchController?,
        source: UnifiedSearchBuffer?
    ) {
        switch result {
        case .succeeded(let message, _):
            confirmationPrompt = nil
            pendingConfirmationInput = nil
            statusMessage = message
            isErrorStatus = false
            if case .command(let args) = ActionCLIParser.parse(rawInput),
               ["history", "日志", "历史", "action.history"].contains(args.commandName.lowercased()) {
                showingHistory = true
                historyKeyword = args.option("query") ?? args.joinedPositional
            } else if let controller {
                _ = controller.publishOperation(text: "")
                controller.refresh()
            }
        case .requiresConfirmation(_, let prompt, _):
            confirmationPrompt = prompt
            pendingConfirmationInput = rawInput
            statusMessage = nil
            isErrorStatus = false
        case .requiresAuthentication(_, let reason):
            confirmationPrompt = nil
            pendingConfirmationInput = nil
            statusMessage = reason
            isErrorStatus = true
        case .requiresFileDialog(_, let prompt):
            confirmationPrompt = nil
            pendingConfirmationInput = nil
            statusMessage = prompt
            isErrorStatus = false
        case .actionNotFound(let commandName):
            confirmationPrompt = nil
            pendingConfirmationInput = nil
            let token = commandName.isEmpty ? rawInput : commandName
            statusMessage = "未找到指令「\(token)」，输入 / 查看可用命令 (Unknown command '\(token)')"
            isErrorStatus = true
        case .unavailable, .permissionDenied, .failed:
            confirmationPrompt = nil
            pendingConfirmationInput = nil
            let isZh = AppPreferences.shared.resolvedLocale.identifier.hasPrefix("zh")
            statusMessage = result.message ?? (isZh ? "执行失败" : "Execution failed")
            isErrorStatus = true
        }
    }
}

extension UnifiedSearchController {
    var cliSession: UnifiedSearchCLISession {
        UnifiedSearchCLISession.session(for: self)
    }

    func handleCLIIntentIfApplicable(_ intent: UnifiedSearchIntent, source: UnifiedSearchBuffer) -> Bool {
        if cliSession.confirmationPrompt != nil {
            switch intent {
            case .escape:
                cliSession.cancelConfirmation()
                return true
            case .open, .submit:
                _ = cliSession.execute(input: source.text, controller: self, source: source)
                return true
            default:
                return false
            }
        }
        guard cliSession.shouldIntercept(text: source.text) else { return false }
        switch intent {
        case .open, .submit:
            _ = cliSession.execute(input: source.text, controller: self, source: source)
            return true
        case .escape:
            cliSession.showingHistory = false
            cliSession.statusMessage = nil
            _ = publishOperation(text: "")
            return true
        default:
            return false
        }
    }
}

/// 统一搜索框下方的零表单 CLI 状态回显、内联二次确认、动作快速触发与持久化 `/history` 面板。
struct UnifiedSearchCLIPanel: View {
    @Bindable var controller: UnifiedSearchController
    private var historyStore: ActionHistoryStore { ActionHistoryStore.shared }
    @Environment(\.locale) private var locale

    private var session: UnifiedSearchCLISession { controller.cliSession }
    private var rawInput: String { controller.buffer.text }
    private var rawText: String { controller.buffer.text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isZh: Bool { locale.identifier.hasPrefix("zh") }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            if let prompt = session.confirmationPrompt {
                confirmationBanner(prompt: prompt)
            }
            if let message = session.statusMessage {
                statusBanner(message: message)
            }
            if session.showingHistory {
                historySection
            } else if rawText.hasPrefix("/") || rawInput.contains(" > ") {
                completionsSection
            } else if !rawText.isEmpty {
                matchedActionsSection
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unified.cli.panel")
    }

    private func confirmationBanner(prompt: String) -> some View {
        HStack(spacing: DaybookSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.status.pending)
            Text(verbatim: prompt)
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(isZh ? "确认 (Return)" : "Confirm (Return)") {
                _ = session.execute(input: controller.buffer.text, controller: controller, source: controller.buffer)
            }
            .buttonStyle(DaybookButtonStyle(.prominent))
            .accessibilityIdentifier("unified.cli.confirm")
            Button(isZh ? "取消 (Esc)" : "Cancel (Esc)") {
                session.cancelConfirmation()
            }
            .buttonStyle(DaybookButtonStyle(.subtle))
            .accessibilityIdentifier("unified.cli.cancel")
        }
        .padding(DaybookSpacing.sm)
        .background(DaybookPalette.fill.surface)
        .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous))
    }

    private func statusBanner(message: String) -> some View {
        HStack(spacing: DaybookSpacing.sm) {
            Image(systemName: session.isErrorStatus ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(DaybookType.caption)
                .foregroundStyle(session.isErrorStatus ? DaybookPalette.status.danger : DaybookPalette.status.success)
            Text(verbatim: message)
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("unified.cli.status")
            if historyStore.canUndo {
                Button(isZh ? "撤销 ⌘Z" : "Undo ⌘Z") {
                    let unlocked = PrivacyVault.shared.isUnlocked
                    if let diff = try? historyStore.undo(isVaultUnlocked: unlocked) {
                        let prefix = isZh ? "已撤销：" : "Undone: "
                        session.statusMessage = "\(prefix)\(diff.formattedSummary(isVaultUnlocked: unlocked))"
                        session.isErrorStatus = false
                    }
                }
                .buttonStyle(DaybookButtonStyle(.subtle))
                .accessibilityIdentifier("unified.cli.undo")
            }
            if historyStore.canRedo {
                Button(isZh ? "前进 ⇧⌘Z" : "Redo ⇧⌘Z") {
                    let unlocked = PrivacyVault.shared.isUnlocked
                    if let diff = try? historyStore.redo(isVaultUnlocked: unlocked) {
                        let prefix = isZh ? "已前进：" : "Redone: "
                        session.statusMessage = "\(prefix)\(diff.formattedSummary(isVaultUnlocked: unlocked))"
                        session.isErrorStatus = false
                    }
                }
                .buttonStyle(DaybookButtonStyle(.subtle))
                .accessibilityIdentifier("unified.cli.redo")
            }
        }
        .padding(DaybookSpacing.sm)
        .background(DaybookPalette.fill.surface)
        .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous))
    }

    private var historySection: some View {
        let unlocked = PrivacyVault.shared.isUnlocked
        let entries = historyStore.searchEntries(
            keyword: session.historyKeyword,
            includeUndone: true,
            isVaultUnlocked: unlocked
        ).prefix(20)
        return VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            HStack(spacing: DaybookSpacing.sm) {
                Text(verbatim: isZh ? "持久化操作历史（最近 \(entries.count) 条）" : "Persistent Action History (Last \(entries.count))")
                    .font(DaybookType.caption.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.secondary)
                Spacer(minLength: 0)
                Button(isZh ? "关闭" : "Close") { session.showingHistory = false }
                    .buttonStyle(DaybookButtonStyle(.quiet))
            }
            if entries.isEmpty {
                Text(verbatim: isZh ? "暂无操作记录" : "No action history")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.tertiary)
            } else {
                ForEach(Array(entries)) { entry in
                    HStack(spacing: DaybookSpacing.sm) {
                        Text(verbatim: entry.isUndone ? (isZh ? "已撤销" : "Undone") : (isZh ? "已生效" : "Applied"))
                            .font(DaybookType.badge)
                            .foregroundStyle(entry.isUndone ? DaybookPalette.text.tertiary : DaybookPalette.accent.base)
                        Text(verbatim: entry.diff.formattedSummary(isVaultUnlocked: unlocked))
                            .font(DaybookType.caption)
                            .foregroundStyle(DaybookPalette.text.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, DaybookSpacing.xxs)
                }
            }
        }
        .padding(DaybookSpacing.sm)
        .background(DaybookPalette.fill.surface)
        .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous))
        .accessibilityIdentifier("unified.cli.history")
    }

    private var resolvedCompletionCandidates: [ActionCompletionCandidate] {
        StandardActionCatalog.bootstrapIfNeeded()
        if rawText == "/" {
            return ActionRegistry.shared.allMetadata.prefix(8).map { meta in
                let cmd = meta.primaryCommand
                return ActionCompletionCandidate(
                    kind: .command,
                    insertText: "/\(cmd)",
                    completedInput: "/\(cmd) ",
                    displayTitle: "\(meta.chineseTitle) (\(meta.englishTitle))",
                    actionID: meta.id
                )
            }
        }
        return Array(ActionRegistry.shared.completions(for: rawInput).prefix(8))
    }

    private var completionsSection: some View {
        let candidates = resolvedCompletionCandidates
        return Group {
            if !candidates.isEmpty {
                VStack(alignment: .leading, spacing: DaybookSpacing.xxs) {
                    ForEach(Array(candidates), id: \.completedInput) { item in
                        Button {
                            _ = controller.publishOperation(text: item.completedInput)
                            controller.cliSession.updateForInput(item.completedInput)
                        } label: {
                            HStack(spacing: DaybookSpacing.sm) {
                                Text(verbatim: item.insertText)
                                    .font(DaybookType.caption.monospaced())
                                    .foregroundStyle(DaybookPalette.accent.base)
                                Text(verbatim: item.displayTitle)
                                    .font(DaybookType.caption)
                                    .foregroundStyle(DaybookPalette.text.secondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(DaybookButtonStyle(.quiet))
                    }
                }
                .padding(DaybookSpacing.sm)
                .background(DaybookPalette.fill.surface)
                .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous))
            }
        }
    }

    private var matchedActionsSection: some View {
        let matched = ActionRegistry.shared.matchActions(query: rawText).prefix(4)
        return Group {
            if !matched.isEmpty {
                HStack(spacing: DaybookSpacing.xs) {
                    ForEach(Array(matched), id: \.id) { descriptor in
                        Button {
                            _ = session.executeAction(id: descriptor.id, controller: controller, source: controller.buffer)
                        } label: {
                            HStack(spacing: DaybookSpacing.xxs) {
                                Image(systemName: descriptor.iconName)
                                    .font(DaybookType.badge)
                                Text(verbatim: descriptor.localizedTitle(for: locale))
                                    .font(DaybookType.caption)
                                if let cmd = descriptor.commandNames.first {
                                    Text(verbatim: "/\(cmd)")
                                        .font(DaybookType.badge.monospaced())
                                        .foregroundStyle(DaybookPalette.text.tertiary)
                                }
                            }
                        }
                        .buttonStyle(DaybookButtonStyle(.subtle))
                        .accessibilityIdentifier("unified.cli.match.\(descriptor.id.rawValue)")
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
