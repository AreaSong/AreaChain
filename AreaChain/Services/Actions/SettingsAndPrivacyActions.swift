import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// 隐私锁访问控制器的统一别名，指向全局唯一的 `PrivacyVault`。
typealias VaultAccessController = PrivacyVault

/// 系统偏好设置（`AppPreferences`）、隐私锁（`VaultAccessController`）与数据备份的统一动作集合。
@MainActor
enum SettingsAndPrivacyActions {
    static var preferencesProvider: (() -> AppPreferences)?
    static var vaultProvider: (() -> VaultAccessController)?
    static var contextProvider: (() -> ModelContext)?
    static var unlockHandler: (@MainActor () throws -> Bool)?
    static var exportJSONHandler: (@MainActor (URL?) throws -> URL)?
    static var importJSONHandler: (@MainActor (URL?) throws -> Int)?
    static var exportBackupHandler: (@MainActor (URL?) throws -> URL)?
    static var restoreBackupHandler: (@MainActor (URL?) throws -> Int)?

    static func all(
        preferences: AppPreferences? = nil,
        vault: VaultAccessController? = nil,
        context: ModelContext? = nil,
        unlockHandler: (@MainActor () throws -> Bool)? = nil,
        exportJSONHandler: (@MainActor (URL?) throws -> URL)? = nil,
        importJSONHandler: (@MainActor (URL?) throws -> Int)? = nil,
        exportBackupHandler: (@MainActor (URL?) throws -> URL)? = nil,
        restoreBackupHandler: (@MainActor (URL?) throws -> Int)? = nil
    ) -> [BaseAction] {
        [
            PreferenceOperationAction(kind: .theme, defaultPrefs: preferences),
            PreferenceOperationAction(kind: .language, defaultPrefs: preferences),
            PreferenceOperationAction(kind: .truncation, defaultPrefs: preferences),
            PreferenceOperationAction(kind: .calendarSync, defaultPrefs: preferences),
            PreferenceOperationAction(kind: .stampApp, defaultPrefs: preferences),
            PrivacyLockAction(isUnlock: false, defaultVault: vault, unlockHandler: nil),
            PrivacyLockAction(isUnlock: true, defaultVault: vault, unlockHandler: unlockHandler),
            DataBackupOperationAction(
                operation: .exportJSON, defaultContext: context,
                urlHandler: exportJSONHandler, countHandler: nil
            ),
            DataBackupOperationAction(
                operation: .importJSON, defaultContext: context,
                urlHandler: nil, countHandler: importJSONHandler
            ),
            DataBackupOperationAction(
                operation: .exportBackup, defaultContext: context,
                urlHandler: exportBackupHandler, countHandler: nil
            ),
            DataBackupOperationAction(
                operation: .restoreBackup, defaultContext: context,
                urlHandler: nil, countHandler: restoreBackupHandler
            ),
        ]
    }

    fileprivate static func resolvePrefs(_ explicit: AppPreferences?) -> AppPreferences {
        explicit ?? preferencesProvider?() ?? AppPreferences.shared
    }

    fileprivate static func resolveVault(_ explicit: VaultAccessController?) -> VaultAccessController {
        explicit ?? vaultProvider?() ?? VaultAccessController.shared
    }

    fileprivate static func resolveContext(_ explicit: ModelContext?, from context: ActionContext) -> ModelContext {
        explicit ?? context.modelContext ?? contextProvider?() ?? Persistence.session.container.mainContext
    }

    fileprivate static func extractValueToken(_ arguments: ParsedActionArguments, keys: [String]) -> String {
        for key in keys {
            if let val = arguments.option(key)?.trimmingCharacters(in: .whitespacesAndNewlines), !val.isEmpty {
                return val.lowercased()
            }
        }
        if let first = arguments.positional.first?.trimmingCharacters(in: .whitespacesAndNewlines), !first.isEmpty {
            return first.lowercased()
        }
        return arguments.inlineNLP.cleanText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    fileprivate static func parseToggleValue(_ token: String, current: Bool) throws -> Bool {
        switch token {
        case "", "toggle", "切换": return !current
        case "on", "true", "1", "yes", "enable", "enabled", "开启", "打开", "是": return true
        case "off", "false", "0", "no", "disable", "disabled", "关闭", "否": return false
        default: throw ActionExecutionError.invalidParameterValue(parameter: "value", value: token)
        }
    }
}

// MARK: - 偏好设置动作

@MainActor
private final class PreferenceOperationAction: BaseAction {
    enum Kind {
        case theme, language, truncation, calendarSync, stampApp
        var spec: (id: ActionID, en: String, zh: String, cmds: [String], icon: String, param: String) {
            switch self {
            case .theme:
                return ("pref.theme", "Set Appearance Theme", "切换外观主题", ["theme", "appearance", "外观", "主题"], "circle.lefthalf.filled", "light/dark/system")
            case .language:
                return ("pref.language", "Set App Language", "切换界面语言", ["lang", "language", "语言"], "globe", "zh/en/system")
            case .truncation:
                return ("pref.truncation", "Set Title Truncation", "切换省略方式", ["truncation", "省略方式"], "text.line.first.and.arrowtriangle.forward", "tail/middle")
            case .calendarSync:
                return ("pref.calendarSync", "Set Calendar Sync", "切换日历同步", ["cal-sync", "日历同步"], "calendar.badge.clock", "on/off/toggle")
            case .stampApp:
                return ("pref.stampApp", "Set Capture Source Stamp", "切换记录来源应用", ["stamp-app", "记录来源应用"], "app.badge", "on/off/toggle")
            }
        }
    }

    private let kind: Kind
    private let defaultPrefs: AppPreferences?

    init(kind: Kind, defaultPrefs: AppPreferences? = nil) {
        self.kind = kind
        self.defaultPrefs = defaultPrefs
        let s = kind.spec
        super.init(
            id: s.id, englishTitle: s.en, chineseTitle: s.zh, commandNames: s.cmds,
            iconName: s.icon, category: .settings,
            parameters: [ActionParameterSpec(id: "value", englishName: s.param, chineseName: s.param)]
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let prefs = SettingsAndPrivacyActions.resolvePrefs(defaultPrefs)
        switch kind {
        case .theme: return try performTheme(arguments, prefs: prefs)
        case .language: return try performLanguage(arguments, prefs: prefs)
        case .truncation: return try performTruncation(arguments, prefs: prefs)
        case .calendarSync, .stampApp: return try performBoolPref(arguments, prefs: prefs)
        }
    }

    private func performTheme(_ arguments: ParsedActionArguments, prefs: AppPreferences) throws -> ActionExecutionOutput {
        let token = SettingsAndPrivacyActions.extractValueToken(arguments, keys: ["value", "mode", "theme"])
        let before = prefs.appearance
        let next: AppAppearance
        switch token {
        case "light", "浅色", "亮色", "日间": next = .light
        case "dark", "深色", "暗色", "夜间": next = .dark
        case "system", "auto", "跟随系统", "系统": next = .system
        case "":
            next = (before == .system) ? .light : (before == .light ? .dark : .system)
        default:
            throw ActionExecutionError.invalidParameterValue(parameter: "theme", value: token)
        }
        prefs.appearance = next
        return makePrefOutput(
            target: "外观主题", field: "主题", before: before.rawValue, after: next.rawValue,
            message: "已将外观主题切换为 \(next.rawValue)",
            undo: { prefs.appearance = before }, redo: { prefs.appearance = next }
        )
    }

    private func performLanguage(_ arguments: ParsedActionArguments, prefs: AppPreferences) throws -> ActionExecutionOutput {
        let token = SettingsAndPrivacyActions.extractValueToken(arguments, keys: ["value", "lang", "language"])
        let before = prefs.language
        let next: AppLanguage
        switch token {
        case "zh", "zh-hans", "cn", "chinese", "中文", "简体中文": next = .chinese
        case "en", "english", "英文", "英语": next = .english
        case "system", "auto", "跟随系统", "系统": next = .system
        case "":
            next = (before == .system) ? .chinese : (before == .chinese ? .english : .system)
        default:
            throw ActionExecutionError.invalidParameterValue(parameter: "language", value: token)
        }
        prefs.language = next
        return makePrefOutput(
            target: "界面语言", field: "语言", before: before.rawValue, after: next.rawValue,
            message: "已将界面语言切换为 \(next.rawValue)",
            undo: { prefs.language = before }, redo: { prefs.language = next }
        )
    }

    private func performTruncation(_ arguments: ParsedActionArguments, prefs: AppPreferences) throws -> ActionExecutionOutput {
        let token = SettingsAndPrivacyActions.extractValueToken(arguments, keys: ["value", "mode", "truncation"])
        let before = prefs.contentTruncation
        let next: ContentTruncation
        switch token {
        case "tail", "末尾", "尾部": next = .tail
        case "middle", "中间": next = .middle
        case "", "toggle", "切换": next = (before == .tail) ? .middle : .tail
        default:
            throw ActionExecutionError.invalidParameterValue(parameter: "truncation", value: token)
        }
        prefs.contentTruncation = next
        return makePrefOutput(
            target: "省略方式", field: "省略方式", before: before.rawValue, after: next.rawValue,
            message: "已将省略方式切换为 \(next.rawValue)",
            undo: { prefs.contentTruncation = before }, redo: { prefs.contentTruncation = next }
        )
    }

    private func performBoolPref(_ arguments: ParsedActionArguments, prefs: AppPreferences) throws -> ActionExecutionOutput {
        let token = SettingsAndPrivacyActions.extractValueToken(arguments, keys: ["value", "state", "mode"])
        if kind == .calendarSync {
            let before = prefs.syncCalendarEvents
            let next = try SettingsAndPrivacyActions.parseToggleValue(token, current: before)
            prefs.syncCalendarEvents = next
            return makePrefOutput(
                target: "日历同步", field: "日历同步", before: before ? "on" : "off", after: next ? "on" : "off",
                message: next ? "已开启日历同步" : "已关闭日历同步",
                undo: { prefs.syncCalendarEvents = before }, redo: { prefs.syncCalendarEvents = next }
            )
        }
        let before = prefs.stampCaptureApp
        let next = try SettingsAndPrivacyActions.parseToggleValue(token, current: before)
        prefs.stampCaptureApp = next
        return makePrefOutput(
            target: "记录来源应用", field: "记录来源应用", before: before ? "on" : "off", after: next ? "on" : "off",
            message: next ? "已开启记录来源应用" : "已关闭记录来源应用",
            undo: { prefs.stampCaptureApp = before }, redo: { prefs.stampCaptureApp = next }
        )
    }

    private func makePrefOutput(
        target: String, field: String, before: String, after: String, message: String,
        undo: @escaping @MainActor () -> Void, redo: @escaping @MainActor () -> Void
    ) -> ActionExecutionOutput {
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: target,
            changes: [ActionFieldChange(field: field, before: before, after: after)]
        )
        return ActionExecutionOutput(message: message, diff: diff, undoClosure: undo, redoClosure: redo)
    }
}

// MARK: - 隐私锁与数据备份动作

@MainActor
private final class PrivacyLockAction: BaseAction {
    private let isUnlock: Bool
    private let defaultVault: VaultAccessController?
    private let unlockHandler: (@MainActor () throws -> Bool)?

    init(isUnlock: Bool, defaultVault: VaultAccessController? = nil, unlockHandler: (@MainActor () throws -> Bool)? = nil) {
        self.isUnlock = isUnlock
        self.defaultVault = defaultVault
        self.unlockHandler = unlockHandler
        super.init(
            id: isUnlock ? "privacy.unlock" : "privacy.lock",
            englishTitle: isUnlock ? "Unlock Privacy Vault" : "Lock Privacy Vault",
            chineseTitle: isUnlock ? "隐私解锁" : "隐私锁定",
            commandNames: isUnlock ? ["unlock", "解锁", "隐私解锁"] : ["lock", "锁定", "隐私锁定"],
            iconName: isUnlock ? "lock.open.fill" : "lock.fill",
            category: .privacy,
            permissionLevel: .privacy,
            recordsUndo: false
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let vault = SettingsAndPrivacyActions.resolveVault(defaultVault)
        if !isUnlock {
            vault.lock()
            let diff = ActionDiff(
                actionID: id, actionTitle: chineseTitle, targetTitle: "隐私保险箱",
                changes: [ActionFieldChange(field: "状态", before: "已解锁", after: "已锁定")], isSensitive: true
            )
            return ActionExecutionOutput(message: "已锁定隐私保险箱", diff: diff)
        }
        if let handler = unlockHandler ?? SettingsAndPrivacyActions.unlockHandler {
            guard try handler() else { throw ActionExecutionError.executionFailed("隐私解锁未通过验证") }
        } else if let pwd = arguments.option("password") ?? arguments.positional.first, !pwd.isEmpty, vault.hasMasterPassword {
            Task { @MainActor in try? await vault.unlockWithPassword(pwd) }
        } else if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            let reason = L10n.string("privacy.unlock.reason", locale: AppPreferences.shared.resolvedLocale)
            Task { @MainActor in
                try? await PrivacyUnlockPresenter.shared.request(reason: reason, vault: vault)
            }
        }
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: "隐私保险箱",
            changes: [ActionFieldChange(field: "状态", before: "已锁定", after: "已解锁")], isSensitive: true
        )
        return ActionExecutionOutput(message: "已执行隐私解锁", diff: diff)
    }
}

@MainActor
private final class DataBackupOperationAction: BaseAction {
    enum Operation {
        case exportJSON, importJSON, exportBackup, restoreBackup
        var spec: (id: ActionID, en: String, zh: String, cmds: [String], icon: String, risk: ActionRiskLevel) {
            switch self {
            case .exportJSON:
                return ("data.exportJSON", "Export JSON Snapshot", "导出快照", ["export-json", "导出快照"], "square.and.arrow.up", .direct)
            case .importJSON:
                return ("data.importJSON", "Import JSON Snapshot", "导入快照", ["import-json", "导入快照"], "square.and.arrow.down", .direct)
            case .exportBackup:
                return ("data.exportBackup", "Export Encrypted Backup", "导出加密备份", ["backup-export", "导出加密备份"], "lock.doc.fill", .direct)
            case .restoreBackup:
                return ("data.restoreBackup", "Restore Encrypted Backup", "恢复加密备份", ["backup-restore", "恢复加密备份"], "arrow.counterclockwise.icloud", .confirm)
            }
        }
    }

    private let operation: Operation
    private let defaultContext: ModelContext?
    private let urlHandler: (@MainActor (URL?) throws -> URL)?
    private let countHandler: (@MainActor (URL?) throws -> Int)?

    init(
        operation: Operation, defaultContext: ModelContext? = nil,
        urlHandler: (@MainActor (URL?) throws -> URL)?, countHandler: (@MainActor (URL?) throws -> Int)?
    ) {
        self.operation = operation
        self.defaultContext = defaultContext
        self.urlHandler = urlHandler
        self.countHandler = countHandler
        let s = operation.spec
        super.init(
            id: s.id, englishTitle: s.en, chineseTitle: s.zh, commandNames: s.cmds,
            iconName: s.icon, category: .settings, permissionLevel: .system, riskLevel: s.risk, recordsUndo: false
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let ctx = SettingsAndPrivacyActions.resolveContext(defaultContext, from: context)
        let explicitPath = (arguments.option("path") ?? arguments.positional.first)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitURL = (explicitPath?.isEmpty == false) ? URL(fileURLWithPath: explicitPath!) : nil
        switch operation {
        case .exportJSON, .exportBackup:
            return try performExport(explicitURL: explicitURL, in: ctx)
        case .importJSON, .restoreBackup:
            return try performImport(explicitURL: explicitURL, in: ctx)
        }
    }

    private func performExport(explicitURL: URL?, in ctx: ModelContext) throws -> ActionExecutionOutput {
        let isBackup = operation == .exportBackup
        let handler = urlHandler ?? (isBackup ? SettingsAndPrivacyActions.exportBackupHandler : SettingsAndPrivacyActions.exportJSONHandler)
        let destination: URL
        if let handler {
            destination = try handler(explicitURL)
        } else {
            let ext = isBackup ? "areachainbackup" : "json"
            let target = explicitURL ?? FileManager.default.temporaryDirectory.appendingPathComponent("areachain-\(DayKey.today())-\(UUID().uuidString.prefix(6)).\(ext)")
            let snapshot = SyncPort.makeSnapshot(
                routines: (try? ctx.fetch(FetchDescriptor<DailyRoutine>())) ?? [],
                checks: (try? ctx.fetch(FetchDescriptor<RoutineCheck>())) ?? [],
                todos: (try? ctx.fetch(FetchDescriptor<TodoItem>())) ?? [],
                diaries: (try? ctx.fetch(FetchDescriptor<DiaryEntry>())) ?? [],
                tags: (try? ctx.fetch(FetchDescriptor<TagItem>())) ?? [],
                attachments: (try? ctx.fetch(FetchDescriptor<AttachmentItem>())) ?? []
            )
            let data = try SyncPort.encode(snapshot)
            try data.write(to: target, options: .atomic)
            destination = target
        }
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: destination.lastPathComponent,
            changes: [ActionFieldChange(field: "导出文件", before: "", after: destination.lastPathComponent)],
            isSensitive: isBackup
        )
        return ActionExecutionOutput(message: "已\(chineseTitle)：\(destination.lastPathComponent)", diff: diff)
    }

    private func performImport(explicitURL: URL?, in ctx: ModelContext) throws -> ActionExecutionOutput {
        let isBackup = operation == .restoreBackup
        let handler = countHandler ?? (isBackup ? SettingsAndPrivacyActions.restoreBackupHandler : SettingsAndPrivacyActions.importJSONHandler)
        let importedCount: Int
        if let handler {
            importedCount = try handler(explicitURL)
        } else if let url = explicitURL, FileManager.default.fileExists(atPath: url.path) {
            let rawData = try Data(contentsOf: url)
            let snapshot = try SyncPort.decode(rawData)
            try SnapshotImporter.validate(snapshot, context: ctx)
            try SnapshotImporter.apply(snapshot, context: ctx)
            importedCount = snapshot.todos.count + snapshot.routines.count + snapshot.diaries.count
        } else {
            importedCount = 0
        }
        let targetName = explicitURL?.lastPathComponent ?? chineseTitle
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: targetName,
            changes: [ActionFieldChange(field: "导入条数", before: "0", after: "\(importedCount)")],
            isSensitive: isBackup
        )
        return ActionExecutionOutput(message: "已\(chineseTitle)（共 \(importedCount) 项）", diff: diff)
    }
}
