import Foundation
import SwiftData

extension ClipboardHistorySession {
    /// 与统一动作契约对齐的暂停状态访问器，底层仍读写唯一的 `recording` 状态。
    var isPaused: Bool { !recording }

    func setPaused(_ paused: Bool) { setRecording(!paused) }

    func clearUnpinned() { clear(includingPinned: false) }
}

/// 剪贴板（`ClipboardHistorySession`）与回收站（`TrashRestoreService` / `DayBoardMutations`）的统一动作集合。
@MainActor
enum ClipboardAndTrashActions {
    static var contextProvider: (() -> ModelContext)?
    static var sessionProvider: (() -> ClipboardHistorySession)?

    static func all(context: ModelContext? = nil, session: ClipboardHistorySession? = nil) -> [BaseAction] {
        [
            ClipboardOperationAction(operation: .togglePanel, defaultSession: session),
            ClipboardOperationAction(operation: .toggleRecording, defaultSession: session),
            ClipboardOperationAction(operation: .pin, defaultSession: session),
            ClipboardOperationAction(operation: .delete, defaultSession: session),
            ClipboardOperationAction(operation: .clearUnpinned, defaultSession: session),
            ClipboardOperationAction(operation: .plainDefault, defaultSession: session),
            TrashOperationAction(operation: .restore, defaultContext: context),
            TrashOperationAction(operation: .deletePermanently, defaultContext: context),
            TrashOperationAction(operation: .empty, defaultContext: context),
        ]
    }

    fileprivate static func resolveSession(explicit: ClipboardHistorySession?) -> ClipboardHistorySession {
        explicit ?? sessionProvider?() ?? ClipboardHistorySession.shared
    }

    fileprivate static func resolveContext(explicit: ModelContext?, from context: ActionContext) -> ModelContext {
        explicit ?? context.modelContext ?? contextProvider?() ?? Persistence.session.container.mainContext
    }

    fileprivate static func resolveClipboardTarget(
        arguments: ParsedActionArguments, context: ActionContext, session: ClipboardHistorySession
    ) throws -> ClipboardHistoryRecord {
        let items = session.items
        if let idStr = arguments.option("id"), let uuid = UUID(uuidString: idStr),
           let match = items.first(where: { $0.id == uuid }) { return match }
        let query = (arguments.targetQuery ?? arguments.positional.first)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let query, !query.isEmpty {
            if let uuid = UUID(uuidString: query), let match = items.first(where: { $0.id == uuid }) { return match }
            if let match = items.first(where: { $0.plainText.localizedCaseInsensitiveContains(query) }) { return match }
        }
        if let focused = context.focusedObjectID ?? context.selectedObjectIDs.first,
           let match = items.first(where: { $0.id == focused }) { return match }
        if let selected = session.selectedOrFirst() ?? items.first { return selected }
        throw ActionExecutionError.targetNotFound("剪贴板记录")
    }

    fileprivate static func reingest(_ records: [ClipboardHistoryRecord], into session: ClipboardHistorySession) {
        let wasPaused = session.isPaused
        if wasPaused { session.setPaused(false) }
        defer { if wasPaused { session.setPaused(true) } }
        for record in records.reversed() {
            let draft = ClipboardHistoryDraft(
                plainText: record.plainText, html: record.html, rtf: record.rtf, png: session.imageData(for: record),
                filePaths: record.filePaths, types: [], sourceBundleID: record.sourceBundleID, copiedAt: record.copiedAt
            )
            session.ingest(draft)
            if record.isPinned, let inserted = session.items.first(where: { $0.contentHash == record.contentHash }), !inserted.isPinned {
                _ = session.togglePin(inserted.id)
            }
        }
    }

    fileprivate static func parseBoolToggle(_ raw: String?, current: Bool) -> Bool {
        guard let token = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !token.isEmpty else { return !current }
        switch token {
        case "on", "true", "1", "yes", "enable", "enabled", "开启", "恢复", "打开", "是": return true
        case "off", "false", "0", "no", "disable", "disabled", "pause", "paused", "暂停", "关闭", "否": return false
        default: return !current
        }
    }
}

@MainActor
private final class ClipboardOperationAction: BaseAction {
    struct Spec {
        let id: ActionID
        let en: String
        let zh: String
        let cmds: [String]
        let icon: String
        let risk: ActionRiskLevel
        let undo: Bool
    }

    enum Operation {
        case togglePanel, toggleRecording, pin, delete, clearUnpinned, plainDefault
        var spec: Spec {
            switch self {
            case .togglePanel:
                return Spec(
                    id: "clip.togglePanel", en: "Toggle Clipboard Panel", zh: "剪贴板小窗",
                    cmds: ["clip", "剪贴板", "剪贴板小窗"], icon: "doc.on.clipboard", risk: .direct, undo: false
                )
            case .toggleRecording:
                return Spec(
                    id: "clip.toggleRecording", en: "Toggle Clipboard Recording", zh: "切换剪贴板记录",
                    cmds: ["clip-record", "clip-capture", "暂停记录剪贴板", "切换剪贴板记录"],
                    icon: "pause.circle", risk: .direct, undo: true
                )
            case .pin:
                return Spec(
                    id: "clip.pin", en: "Toggle Pin Clipboard Item", zh: "固定剪贴板",
                    cmds: ["clip-pin", "固定剪贴板"], icon: "pin.fill", risk: .direct, undo: true
                )
            case .delete:
                return Spec(
                    id: "clip.delete", en: "Delete Clipboard Item", zh: "删除剪贴板记录",
                    cmds: ["clip-rm", "删除剪贴板", "删除剪贴板记录"], icon: "trash", risk: .direct, undo: true
                )
            case .clearUnpinned:
                return Spec(
                    id: "clip.clearUnpinned", en: "Clear Unpinned Clipboard Items", zh: "清空剪贴板",
                    cmds: ["clip-clear", "清空剪贴板"], icon: "trash.slash", risk: .confirm, undo: true
                )
            case .plainDefault:
                return Spec(
                    id: "clip.plainDefault", en: "Toggle Plain Text Paste by Default", zh: "默认纯文本粘贴",
                    cmds: ["clip-plain", "默认纯文本粘贴"], icon: "text.alignleft", risk: .direct, undo: true
                )
            }
        }
    }

    private let operation: Operation
    private let defaultSession: ClipboardHistorySession?

    init(operation: Operation, defaultSession: ClipboardHistorySession? = nil) {
        self.operation = operation
        self.defaultSession = defaultSession
        let s = operation.spec
        super.init(
            id: s.id, englishTitle: s.en, chineseTitle: s.zh, commandNames: s.cmds,
            iconName: s.icon, category: .clipboard, riskLevel: s.risk, recordsUndo: s.undo
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let session = ClipboardAndTrashActions.resolveSession(explicit: defaultSession)
        switch operation {
        case .togglePanel:
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                ClipboardHistoryPanel.shared.toggle()
            }
            return ActionExecutionOutput(message: "已切换剪贴板小窗")
        case .toggleRecording, .plainDefault:
            return performSettingToggle(arguments, session: session)
        case .pin, .delete, .clearUnpinned:
            return try performItemMutation(arguments, context: context, session: session)
        }
    }

    private func performSettingToggle(_ arguments: ParsedActionArguments, session: ClipboardHistorySession) -> ActionExecutionOutput {
        let raw = arguments.option("state") ?? arguments.positional.first
        if operation == .toggleRecording {
            let wasPaused = session.isPaused
            let token = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            let nextPaused: Bool
            if ["pause", "paused", "off", "暂停", "关闭"].contains(token) { nextPaused = true }
            else if ["resume", "record", "on", "恢复", "开启"].contains(token) { nextPaused = false }
            else { nextPaused = !wasPaused }
            session.setPaused(nextPaused)
            let diff = ActionDiff(
                actionID: id, actionTitle: chineseTitle, targetTitle: "剪贴板监听",
                changes: [ActionFieldChange(field: "状态", before: wasPaused ? "已暂停" : "记录中", after: session.isPaused ? "已暂停" : "记录中")]
            )
            return ActionExecutionOutput(
                message: session.isPaused ? "已暂停记录剪贴板" : "已恢复记录剪贴板", diff: diff,
                undoClosure: { session.setPaused(wasPaused) }, redoClosure: { session.setPaused(nextPaused) }
            )
        }
        let before = session.plainByDefault
        let next = ClipboardAndTrashActions.parseBoolToggle(raw, current: before)
        session.setPlainByDefault(next)
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: "默认纯文本粘贴",
            changes: [ActionFieldChange(field: "默认纯文本", before: before ? "开启" : "关闭", after: next ? "开启" : "关闭")]
        )
        return ActionExecutionOutput(
            message: next ? "已开启默认纯文本粘贴" : "已关闭默认纯文本粘贴", diff: diff,
            undoClosure: { session.setPlainByDefault(before) }, redoClosure: { session.setPlainByDefault(next) }
        )
    }

    private func performItemMutation(
        _ arguments: ParsedActionArguments, context: ActionContext, session: ClipboardHistorySession
    ) throws -> ActionExecutionOutput {
        if operation == .clearUnpinned {
            let unpinned = session.items.filter { !$0.isPinned }
            let beforeCount = session.items.count
            session.clearUnpinned()
            let diff = ActionDiff(
                actionID: id, actionTitle: chineseTitle, targetTitle: "未固定剪贴板记录",
                changes: [ActionFieldChange(field: "条数", before: "\(beforeCount)", after: "\(session.items.count)")]
            )
            return ActionExecutionOutput(
                message: "已清空 \(unpinned.count) 条未固定剪贴板记录", diff: diff,
                undoClosure: { ClipboardAndTrashActions.reingest(unpinned, into: session) },
                redoClosure: { session.clearUnpinned() }
            )
        }
        let target = try ClipboardAndTrashActions.resolveClipboardTarget(arguments: arguments, context: context, session: session)
        let preview = String(target.preview.prefix(24))
        let title = preview.isEmpty ? "剪贴板记录" : preview
        if operation == .pin {
            let wasPinned = target.isPinned
            guard session.togglePin(target.id) else { throw ActionExecutionError.executionFailed("切换剪贴板固定状态失败") }
            let isNowPinned = session.items.first(where: { $0.id == target.id })?.isPinned ?? !wasPinned
            let diff = ActionDiff(
                actionID: id, actionTitle: chineseTitle, targetTitle: title,
                changes: [ActionFieldChange(field: "固定", before: wasPinned ? "是" : "否", after: isNowPinned ? "是" : "否")]
            )
            return ActionExecutionOutput(
                message: isNowPinned ? "已固定剪贴板记录" : "已取消固定剪贴板记录", diff: diff,
                undoClosure: { _ = session.togglePin(target.id) }, redoClosure: { _ = session.togglePin(target.id) }
            )
        }
        session.delete(target.id)
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: title,
            changes: [ActionFieldChange(field: "状态", before: "已保存", after: "已删除")]
        )
        return ActionExecutionOutput(
            message: "已删除剪贴板记录：\(title)", diff: diff,
            undoClosure: { ClipboardAndTrashActions.reingest([target], into: session) },
            redoClosure: {
                if let match = session.items.first(where: { $0.id == target.id || $0.contentHash == target.contentHash }) {
                    session.delete(match.id)
                }
            }
        )
    }
}

// MARK: - 回收站动作

@MainActor
private enum TrashTargetItem {
    case todo(TodoItem), routine(DailyRoutine), diary(DiaryEntry), tag(TagItem)

    var id: UUID {
        switch self {
        case .todo(let item): return item.id
        case .routine(let item): return item.id
        case .diary(let item): return item.id
        case .tag(let item): return item.id
        }
    }

    var deletedAt: Date? {
        switch self {
        case .todo(let item): return item.deletedAt
        case .routine(let item): return item.deletedAt
        case .diary(let item): return item.deletedAt
        case .tag(let item): return item.deletedAt
        }
    }

    var displayTitle: String {
        switch self {
        case .todo(let item): return item.title
        case .routine(let item): return item.title
        case .diary(let item):
            let first = item.text.split(whereSeparator: \.isNewline).first.map(String.init) ?? item.text
            let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
            return item.hasProtectedContent ? "私密手记" : (trimmed.isEmpty ? "手记" : String(trimmed.prefix(28)))
        case .tag(let item): return "#\(item.name)"
        }
    }

    func restore() -> Bool {
        switch self {
        case .todo(let item): return DayBoardMutations.restoreTodo(item)
        case .routine(let item): return DayBoardMutations.restoreRoutine(item)
        case .diary(let item): return DayBoardMutations.restoreDiary(item)
        case .tag(let item): return DayBoardMutations.restoreTag(item)
        }
    }

    func moveToTrash(in context: ModelContext) -> Bool {
        switch self {
        case .todo(let item): return DayBoardMutations.trashTodo(item)
        case .routine(let item): return DayBoardMutations.trashRoutine(item)
        case .diary(let item): return DayBoardMutations.deleteDiary(item)
        case .tag(let item): return DayBoardMutations.trashTag(id: item.id, context: context)
        }
    }

    func purge() -> Bool {
        switch self {
        case .todo(let item): return DayBoardMutations.purgeTodo(item)
        case .routine(let item): return DayBoardMutations.purgeRoutine(item)
        case .diary(let item): return DayBoardMutations.purgeDiary(item)
        case .tag(let item): return DayBoardMutations.purgeTag(item)
        }
    }

    static func fetchAllDeleted(in context: ModelContext) -> [TrashTargetItem] {
        let todos = ((try? context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.deletedAt != nil }))) ?? []).map(Self.todo)
        let routines = ((try? context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.deletedAt != nil }))) ?? []).map(Self.routine)
        let diaries = ((try? context.fetch(FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.deletedAt != nil }))) ?? []).map(Self.diary)
        let tags = ((try? context.fetch(FetchDescriptor<TagItem>(predicate: #Predicate { $0.deletedAt != nil }))) ?? []).map(Self.tag)
        return (todos + routines + diaries + tags).sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    static func resolve(arguments: ParsedActionArguments, context: ActionContext, modelContext: ModelContext) throws -> TrashTargetItem {
        let deleted = fetchAllDeleted(in: modelContext)
        let query = (arguments.option("id") ?? arguments.targetQuery ?? arguments.positional.first)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let query, !query.isEmpty {
            let cleaned = String(query.trimmingPrefix("#"))
            if let uuid = UUID(uuidString: cleaned), let byID = deleted.first(where: { $0.id == uuid }) { return byID }
            if let exact = deleted.first(where: {
                $0.displayTitle.localizedCaseInsensitiveCompare(query) == .orderedSame
                    || $0.displayTitle.localizedCaseInsensitiveCompare(cleaned) == .orderedSame
            }) { return exact }
            if let partial = deleted.first(where: { $0.displayTitle.localizedCaseInsensitiveContains(cleaned) }) { return partial }
            throw ActionExecutionError.targetNotFound(query)
        }
        if let focused = context.focusedObjectID ?? context.selectedObjectIDs.first,
           let byID = deleted.first(where: { $0.id == focused }) { return byID }
        if let latest = deleted.first { return latest }
        throw ActionExecutionError.targetNotFound("回收站项目")
    }
}

@MainActor
private final class TrashOperationAction: BaseAction {
    struct Spec {
        let id: ActionID
        let en: String
        let zh: String
        let cmds: [String]
        let icon: String
        let risk: ActionRiskLevel
        let perm: ActionPermissionLevel
        let undo: Bool
    }

    enum Operation {
        case restore, deletePermanently, empty
        var spec: Spec {
            switch self {
            case .restore:
                return Spec(
                    id: "trash.restore", en: "Restore from Trash", zh: "从回收站恢复",
                    cmds: ["restore", "还原", "恢复", "从回收站恢复"],
                    icon: "arrow.uturn.backward.circle", risk: .direct, perm: .normal, undo: true
                )
            case .deletePermanently:
                return Spec(
                    id: "trash.deletePermanently", en: "Delete Permanently", zh: "彻底删除",
                    cmds: ["purge", "彻底删除"], icon: "xmark.bin.fill", risk: .confirm, perm: .system, undo: false
                )
            case .empty:
                return Spec(
                    id: "trash.empty", en: "Empty Trash", zh: "清空回收站",
                    cmds: ["empty-trash", "清空回收站"], icon: "trash.slash.fill", risk: .confirm, perm: .system, undo: false
                )
            }
        }
    }

    private let operation: Operation
    private let defaultContext: ModelContext?

    init(operation: Operation, defaultContext: ModelContext? = nil) {
        self.operation = operation
        self.defaultContext = defaultContext
        let s = operation.spec
        super.init(
            id: s.id, englishTitle: s.en, chineseTitle: s.zh, commandNames: s.cmds,
            iconName: s.icon, category: .trash, permissionLevel: s.perm, riskLevel: s.risk, recordsUndo: s.undo
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let ctx = ClipboardAndTrashActions.resolveContext(explicit: defaultContext, from: context)
        if operation == .empty {
            let deleted = TrashTargetItem.fetchAllDeleted(in: ctx)
            guard !deleted.isEmpty else { return ActionExecutionOutput(message: "回收站已为空") }
            var purgedCount = 0
            for item in deleted where item.purge() { purgedCount += 1 }
            let diff = ActionDiff(
                actionID: id, actionTitle: chineseTitle, targetTitle: "回收站",
                changes: [ActionFieldChange(field: "项目数", before: "\(deleted.count)", after: "\(deleted.count - purgedCount)")]
            )
            return ActionExecutionOutput(message: "已清空回收站（共清除 \(purgedCount) 项）", diff: diff)
        }
        let target = try TrashTargetItem.resolve(arguments: arguments, context: context, modelContext: ctx)
        let title = target.displayTitle
        if operation == .restore {
            guard target.restore() else { throw ActionExecutionError.executionFailed("从回收站恢复失败") }
            let diff = ActionDiff(
                actionID: id, actionTitle: chineseTitle, targetTitle: title,
                changes: [ActionFieldChange(field: "状态", before: "回收站", after: "已恢复")]
            )
            return ActionExecutionOutput(
                message: "已从回收站恢复：\(title)", diff: diff,
                undoClosure: { _ = target.moveToTrash(in: ctx) }, redoClosure: { _ = target.restore() }
            )
        }
        guard target.purge() else { throw ActionExecutionError.executionFailed("彻底删除失败") }
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: title,
            changes: [ActionFieldChange(field: "状态", before: "回收站", after: "彻底删除")]
        )
        return ActionExecutionOutput(message: "已彻底删除：\(title)", diff: diff)
    }
}
