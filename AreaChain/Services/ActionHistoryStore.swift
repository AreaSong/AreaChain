import Foundation
import Observation

/// 单条持久化动作历史记录，包含修改明细、回显消息与可选的跨重启撤销载荷。
struct ActionHistoryEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let diff: ActionDiff
    let message: String
    let undoPayload: ActionUndoPayload?
    var isUndone: Bool

    init(
        id: UUID? = nil,
        diff: ActionDiff,
        message: String,
        undoPayload: ActionUndoPayload? = nil,
        isUndone: Bool = false
    ) {
        self.id = id ?? diff.id
        self.diff = diff
        self.message = message
        self.undoPayload = undoPayload
        self.isUndone = isUndone
    }
}

/// 动作历史磁盘 JSON 文件结构，同时保存已生效栈与已撤销栈以支持重启后双向游标。
private struct ActionHistoryStorageFile: Codable, Sendable {
    var schemaVersion: Int = 1
    var appliedEntries: [ActionHistoryEntry]
    var undoneEntries: [ActionHistoryEntry]
}

private struct RuntimeUndoRedoHooks {
    let undo: (@MainActor () throws -> Void)?
    let redo: (@MainActor () throws -> Void)?
}

/// 持久化修改明细历史及双向后退（Undo）/前进（Redo）引擎，默认滚动保留最近 1000 条记录。
@MainActor
@Observable
final class ActionHistoryStore {
    static let shared = ActionHistoryStore()
    nonisolated static let defaultMaxCapacity = 1000

    static var defaultFileURL: URL {
        AppGroup.containerURL.appending(path: "areachain-action-history.json")
    }

    let fileURL: URL
    let maxCapacity: Int
    private let persistToDisk: Bool
    private(set) var appliedEntries: [ActionHistoryEntry] = []
    private(set) var undoneEntries: [ActionHistoryEntry] = []

    @ObservationIgnored
    private var runtimeHooks: [UUID: RuntimeUndoRedoHooks] = [:]

    @ObservationIgnored
    var payloadUndoHandler: (@MainActor (ActionUndoPayload, ActionDiff) throws -> Void)?

    @ObservationIgnored
    var payloadRedoHandler: (@MainActor (ActionUndoPayload, ActionDiff) throws -> Void)?

    init(
        fileURL: URL? = nil,
        maxCapacity: Int = ActionHistoryStore.defaultMaxCapacity,
        persistToDisk: Bool = true
    ) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        self.maxCapacity = max(1, maxCapacity)
        self.persistToDisk = persistToDisk
        if persistToDisk {
            loadFromDisk()
        }
    }

    static func inMemory(maxCapacity: Int = ActionHistoryStore.defaultMaxCapacity) -> ActionHistoryStore {
        let tempURL = FileManager.default.temporaryDirectory
            .appending(path: "areachain-history-memory-\(UUID().uuidString).json")
        return ActionHistoryStore(fileURL: tempURL, maxCapacity: maxCapacity, persistToDisk: false)
    }

    var canUndo: Bool {
        !appliedEntries.isEmpty
    }

    var canRedo: Bool {
        !undoneEntries.isEmpty
    }

    var latestAppliedDiff: ActionDiff? {
        appliedEntries.last?.diff
    }

    var latestUndoneDiff: ActionDiff? {
        undoneEntries.last?.diff
    }

    /// 记录一次已生效的动作修改，清空分叉的已撤销栈并滚动裁剪至容量上限。
    @discardableResult
    func record(
        diff: ActionDiff,
        message: String,
        undoPayload: ActionUndoPayload? = nil,
        undoClosure: (@MainActor () throws -> Void)? = nil,
        redoClosure: (@MainActor () throws -> Void)? = nil
    ) -> ActionHistoryEntry {
        for abandoned in undoneEntries {
            runtimeHooks.removeValue(forKey: abandoned.id)
        }
        undoneEntries.removeAll()

        let entry = ActionHistoryEntry(
            id: diff.id,
            diff: diff,
            message: message,
            undoPayload: undoPayload,
            isUndone: false
        )
        if undoClosure != nil || redoClosure != nil {
            runtimeHooks[entry.id] = RuntimeUndoRedoHooks(undo: undoClosure, redo: redoClosure)
        }
        appliedEntries.append(entry)
        trimToMaxCapacity()
        saveToDisk()
        return entry
    }

    /// 后退上一步（Undo）：弹出最近一条已生效记录并压入已撤销栈。
    @discardableResult
    func undo(isVaultUnlocked: Bool = true) throws -> ActionDiff {
        guard var entry = appliedEntries.popLast() else {
            throw ActionExecutionError.unavailable("没有可撤销的操作")
        }
        if entry.diff.isSensitive && !isVaultUnlocked {
            appliedEntries.append(entry)
            throw ActionExecutionError.unavailable("需要先解锁私密空间")
        }
        do {
            if let hook = runtimeHooks[entry.id]?.undo {
                try hook()
            } else if let payload = entry.undoPayload, let handler = payloadUndoHandler {
                try handler(payload, entry.diff)
            }
        } catch {
            appliedEntries.append(entry)
            throw error
        }
        entry.isUndone = true
        undoneEntries.append(entry)
        saveToDisk()
        return entry.diff
    }

    /// 前进下一步（Redo）：弹出最近一条已撤销记录并重新压回已生效栈。
    @discardableResult
    func redo(isVaultUnlocked: Bool = true) throws -> ActionDiff {
        guard var entry = undoneEntries.popLast() else {
            throw ActionExecutionError.unavailable("没有可重做的操作")
        }
        if entry.diff.isSensitive && !isVaultUnlocked {
            undoneEntries.append(entry)
            throw ActionExecutionError.unavailable("需要先解锁私密空间")
        }
        do {
            if let hook = runtimeHooks[entry.id]?.redo {
                try hook()
            } else if let payload = entry.undoPayload, let handler = payloadRedoHandler {
                try handler(payload, entry.diff)
            }
        } catch {
            undoneEntries.append(entry)
            throw error
        }
        entry.isUndone = false
        appliedEntries.append(entry)
        trimToMaxCapacity()
        saveToDisk()
        return entry.diff
    }

    /// 按关键词过滤历史明细（最新记录排在最前），锁定时自动保护敏感条目。
    func searchEntries(
        keyword: String? = nil,
        includeUndone: Bool = false,
        isVaultUnlocked: Bool = true
    ) -> [ActionHistoryEntry] {
        let base = includeUndone ? (appliedEntries + undoneEntries) : appliedEntries
        let reversed = base.reversed()
        guard let keyword, !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Array(reversed)
        }
        return reversed.filter { entry in
            entry.diff.matches(keyword: keyword, isVaultUnlocked: isVaultUnlocked)
                || (!entry.diff.isSensitive || isVaultUnlocked)
                    && entry.message.localizedCaseInsensitiveContains(keyword)
        }
    }

    /// 生成供 `/history` 命令回显的人类可读历史明细行。
    func formattedHistoryLines(
        keyword: String? = nil,
        limit: Int = 20,
        isVaultUnlocked: Bool = true
    ) -> [String] {
        let matched = searchEntries(keyword: keyword, includeUndone: false, isVaultUnlocked: isVaultUnlocked)
        return matched.prefix(max(1, limit)).map { entry in
            entry.diff.formattedSummary(isVaultUnlocked: isVaultUnlocked)
        }
    }

    func clearAll() {
        appliedEntries.removeAll()
        undoneEntries.removeAll()
        runtimeHooks.removeAll()
        saveToDisk()
    }

    func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(ActionHistoryStorageFile.self, from: data) else {
            return
        }
        appliedEntries = Array(decoded.appliedEntries.suffix(maxCapacity))
        undoneEntries = Array(decoded.undoneEntries.suffix(maxCapacity))
    }

    func saveToDisk() {
        guard persistToDisk else { return }
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let payload = ActionHistoryStorageFile(
            appliedEntries: appliedEntries,
            undoneEntries: undoneEntries
        )
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func trimToMaxCapacity() {
        guard appliedEntries.count > maxCapacity else { return }
        let overflowCount = appliedEntries.count - maxCapacity
        let removed = appliedEntries.prefix(overflowCount)
        for item in removed {
            runtimeHooks.removeValue(forKey: item.id)
        }
        appliedEntries.removeFirst(overflowCount)
    }
}

// MARK: - 内置历史与双向游标动作

/// 撤销上一步动作（支持 `/undo`, `/u`, `/撤销`, `/上一步`）。
@MainActor
final class UndoAction: BaseAction {
    private unowned let historyStore: ActionHistoryStore

    init(historyStore: ActionHistoryStore) {
        self.historyStore = historyStore
        super.init(
            id: .undo,
            titleKey: "action.history.undo",
            englishTitle: "Undo Last Action",
            chineseTitle: "撤销上一步",
            commandNames: ["undo", "u", "撤销", "上一步", "后退", "action.undo"],
            iconName: "arrow.uturn.backward",
            category: .history,
            parameters: [],
            permissionLevel: .normal,
            riskLevel: .direct,
            recordsUndo: false
        )
    }

    override func availability(in context: ActionContext) -> ActionAvailability {
        guard historyStore.canUndo else {
            return .disabled(reason: "没有可撤销的操作")
        }
        if let latest = historyStore.latestAppliedDiff, latest.isSensitive && !context.isVaultUnlocked {
            return .requiresUnlock
        }
        return .available
    }

    override func perform(
        arguments: ParsedActionArguments,
        context: ActionContext
    ) throws -> ActionExecutionOutput {
        let diff = try historyStore.undo(isVaultUnlocked: context.isVaultUnlocked)
        let summary = diff.formattedSummary(isVaultUnlocked: context.isVaultUnlocked)
        return ActionExecutionOutput(message: "已撤销：\(summary)", diff: diff)
    }
}

/// 重做下一步动作（支持 `/redo`, `/r`, `/重做`, `/下一步`）。
@MainActor
final class RedoAction: BaseAction {
    private unowned let historyStore: ActionHistoryStore

    init(historyStore: ActionHistoryStore) {
        self.historyStore = historyStore
        super.init(
            id: .redo,
            titleKey: "action.history.redo",
            englishTitle: "Redo Next Action",
            chineseTitle: "重做下一步",
            commandNames: ["redo", "r", "重做", "下一步", "前进", "action.redo"],
            iconName: "arrow.uturn.forward",
            category: .history,
            parameters: [],
            permissionLevel: .normal,
            riskLevel: .direct,
            recordsUndo: false
        )
    }

    override func availability(in context: ActionContext) -> ActionAvailability {
        guard historyStore.canRedo else {
            return .disabled(reason: "没有可重做的操作")
        }
        if let latest = historyStore.latestUndoneDiff, latest.isSensitive && !context.isVaultUnlocked {
            return .requiresUnlock
        }
        return .available
    }

    override func perform(
        arguments: ParsedActionArguments,
        context: ActionContext
    ) throws -> ActionExecutionOutput {
        let diff = try historyStore.redo(isVaultUnlocked: context.isVaultUnlocked)
        let summary = diff.formattedSummary(isVaultUnlocked: context.isVaultUnlocked)
        return ActionExecutionOutput(message: "已重做：\(summary)", diff: diff)
    }
}

/// 查询动作修改明细历史（支持 `/history`, `/h`, `/历史`）。
@MainActor
final class HistoryQueryAction: BaseAction {
    private unowned let historyStore: ActionHistoryStore

    init(historyStore: ActionHistoryStore) {
        self.historyStore = historyStore
        super.init(
            id: .historyQuery,
            titleKey: "action.history.query",
            englishTitle: "Action History",
            chineseTitle: "操作历史",
            commandNames: ["history", "h", "hist", "历史", "修改记录", "日志", "action.history"],
            iconName: "clock.arrow.circlepath",
            category: .history,
            parameters: [
                ActionParameterSpec(
                    id: "query",
                    englishName: "Keyword",
                    chineseName: "关键词",
                    required: false
                ),
                ActionParameterSpec(
                    id: "limit",
                    englishName: "Limit",
                    chineseName: "条数",
                    required: false,
                    defaultValue: "20"
                ),
            ],
            permissionLevel: .normal,
            riskLevel: .direct,
            recordsUndo: false
        )
    }

    override func perform(
        arguments: ParsedActionArguments,
        context: ActionContext
    ) throws -> ActionExecutionOutput {
        let keyword = arguments.option("query")
            ?? (arguments.joinedPositional.isEmpty ? nil : arguments.joinedPositional)
        let limit = arguments.option("limit").flatMap(Int.init) ?? 20
        let lines = historyStore.formattedHistoryLines(
            keyword: keyword,
            limit: limit,
            isVaultUnlocked: context.isVaultUnlocked
        )
        if lines.isEmpty {
            return ActionExecutionOutput(message: "暂无匹配的操作历史")
        }
        return ActionExecutionOutput(message: lines.joined(separator: "；"))
    }
}
