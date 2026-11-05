import Foundation
import SwiftData

/// 手记（`DiaryEntry`）、标签（`TagItem`）与附件（`AttachmentItem`）的统一动作集合。
@MainActor
enum DiaryAndTagActions {
    static var contextProvider: (() -> ModelContext)?

    static func all(context: ModelContext? = nil) -> [BaseAction] {
        [
            DiaryWriteAction(isEdit: false, defaultContext: context), DiaryWriteAction(isEdit: true, defaultContext: context),
            DiaryEntryOperationAction(operation: .pin, defaultContext: context),
            DiaryEntryOperationAction(operation: .toTodo, defaultContext: context),
            DiaryEntryOperationAction(operation: .openWindow, defaultContext: context),
            DiaryEntryOperationAction(operation: .togglePrivate, defaultContext: context),
            DiaryEntryOperationAction(operation: .trash, defaultContext: context),
            TagOperationAction(operation: .create, defaultContext: context),
            TagOperationAction(operation: .rename, defaultContext: context),
            TagOperationAction(operation: .color, defaultContext: context),
            TagOperationAction(operation: .merge, defaultContext: context),
            TagOperationAction(operation: .trash, defaultContext: context),
            TagOperationAction(operation: .cleanUnused, defaultContext: context),
            AttachmentStatusAction(restore: false, defaultContext: context), AttachmentStatusAction(restore: true, defaultContext: context),
        ]
    }

    fileprivate static func resolveModelContext(explicit: ModelContext?, from context: ActionContext) -> ModelContext {
        explicit ?? context.modelContext ?? contextProvider?() ?? Persistence.session.container.mainContext
    }

    fileprivate static func resolveTargetDiary(
        arguments: ParsedActionArguments, context: ActionContext, modelContext: ModelContext
    ) throws -> DiaryEntry {
        let descriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let allLive = (try? modelContext.fetch(descriptor)) ?? []
        if let idStr = arguments.option("id"), let uuid = UUID(uuidString: idStr),
           let found = allLive.first(where: { $0.id == uuid }) {
            return found
        }
        if let query = arguments.targetQuery?.trimmingCharacters(in: .whitespacesAndNewlines),
           !query.isEmpty, let found = matchDiary(query: query, in: allLive) {
            return found
        }
        if let focused = context.focusedObjectID ?? context.selectedObjectIDs.first, let found = allLive.first(where: { $0.id == focused }) { return found }
        if let firstPos = arguments.positional.first, let found = matchDiary(query: firstPos, in: allLive) { return found }
        if let latest = allLive.first { return latest }
        throw ActionExecutionError.targetNotFound("手记")
    }

    private static func matchDiary(query: String, in entries: [DiaryEntry]) -> DiaryEntry? {
        if let uuid = UUID(uuidString: query), let byID = entries.first(where: { $0.id == uuid }) { return byID }
        return entries.first { $0.text.localizedCaseInsensitiveCompare(query) == .orderedSame }
            ?? entries.first { $0.text.localizedCaseInsensitiveContains(query) }
    }

    fileprivate static func resolveTargetTag(
        query: String?, context: ActionContext, modelContext: ModelContext
    ) throws -> TagItem {
        let liveTags = Catalog.liveTags((try? modelContext.fetch(FetchDescriptor<TagItem>())) ?? [])
        if let raw = query?.trimmingCharacters(in: .whitespacesAndNewlines).trimmingPrefix("#"), !raw.isEmpty {
            let cleaned = String(raw)
            if let uuid = UUID(uuidString: cleaned), let found = liveTags.first(where: { $0.id == uuid }) { return found }
            let normalized = TagSyntax.normalizedName(cleaned)
            if let exact = liveTags.first(where: { TagSyntax.normalizedName($0.name) == normalized }) { return exact }
            if let partial = liveTags.first(where: { $0.name.localizedCaseInsensitiveContains(cleaned) }) { return partial }
            throw ActionExecutionError.targetNotFound(cleaned)
        }
        if let focusedID = context.focusedObjectID ?? context.selectedObjectIDs.first,
           let found = liveTags.first(where: { $0.id == focusedID }) { return found }
        throw ActionExecutionError.missingRequiredParameter("tag")
    }

    fileprivate static func resolveTargetAttachment(
        arguments: ParsedActionArguments, context: ActionContext, modelContext: ModelContext, includeDeleted: Bool
    ) throws -> AttachmentItem {
        let items = DayBoardMutations.ownedAttachments(modelContext).filter { includeDeleted ? $0.deletedAt != nil : $0.deletedAt == nil }
        let query = (arguments.option("id") ?? arguments.targetQuery ?? arguments.positional.first)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let query, !query.isEmpty {
            if let uuid = UUID(uuidString: query), let found = items.first(where: { $0.id == uuid }) { return found }
            if let byName = items.first(where: { $0.filename.localizedCaseInsensitiveContains(query) }) { return byName }
        }
        if let focused = context.focusedObjectID ?? context.selectedObjectIDs.first,
           let found = items.first(where: { $0.id == focused }) { return found }
        if let first = items.first { return first }
        throw ActionExecutionError.targetNotFound("附件")
    }

    fileprivate static func diaryPreviewTitle(_ text: String, isSensitive: Bool) -> String {
        if isSensitive { return "私密手记" }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "手记" : String(trimmed.prefix(32))
    }
}

@MainActor
private class ContextBoundAction: BaseAction {
    let defaultContext: ModelContext?

    init(
        id: ActionID, englishTitle: String, chineseTitle: String, commandNames: [String],
        iconName: String, category: ActionCategory, parameters: [ActionParameterSpec] = [],
        permissionLevel: ActionPermissionLevel = .normal, recordsUndo: Bool = true, defaultContext: ModelContext? = nil
    ) {
        self.defaultContext = defaultContext
        super.init(
            id: id, englishTitle: englishTitle, chineseTitle: chineseTitle, commandNames: commandNames,
            iconName: iconName, category: category, parameters: parameters, permissionLevel: permissionLevel, recordsUndo: recordsUndo
        )
    }

    func modelContext(for context: ActionContext) -> ModelContext {
        DiaryAndTagActions.resolveModelContext(explicit: defaultContext, from: context)
    }

    func makeOutput(
        targetTitle: String, field: String, before: String, after: String, isSensitive: Bool = false,
        message: String, undo: (@MainActor () throws -> Void)? = nil, redo: (@MainActor () throws -> Void)? = nil
    ) -> ActionExecutionOutput {
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: targetTitle,
            changes: [ActionFieldChange(field: field, before: before, after: after)], isSensitive: isSensitive
        )
        return ActionExecutionOutput(message: message, diff: diff, undoClosure: undo, redoClosure: redo)
    }
}

@MainActor
private final class DiaryWriteAction: ContextBoundAction {
    private let isEdit: Bool

    init(isEdit: Bool, defaultContext: ModelContext? = nil) {
        self.isEdit = isEdit
        super.init(
            id: isEdit ? "diary.edit" : "diary.create",
            englishTitle: isEdit ? "Edit Diary Entry" : "Create Diary Entry",
            chineseTitle: isEdit ? "编辑手记" : "新建手记",
            commandNames: isEdit ? ["edit-diary", "编辑手记"] : ["diary", "note-add", "m", "手记", "记手记"],
            iconName: isEdit ? "pencil.line" : "book.pages", category: .diary,
            parameters: [ActionParameterSpec(id: "text", englishName: "Content", chineseName: "手记内容", required: true)],
            defaultContext: defaultContext
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let ctx = modelContext(for: context)
        return isEdit ? try performEdit(arguments, context: context, in: ctx) : try performCreate(arguments, context: context, in: ctx)
    }

    private func performCreate(_ arguments: ParsedActionArguments, context: ActionContext, in ctx: ModelContext) throws -> ActionExecutionOutput {
        let baseText = arguments.option("text")
            ?? (arguments.inlineNLP.cleanText.isEmpty ? arguments.joinedPositional : arguments.inlineNLP.cleanText)
        let trimmedBase = baseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBase.isEmpty else { throw ActionExecutionError.missingRequiredParameter("text") }
        let fullText = arguments.inlineNLP.notes.isEmpty ? trimmedBase : "\(trimmedBase)\n\(arguments.inlineNLP.notes)"
        let dayKey = arguments.option("day") ?? context.todayKey
        let selectedTagIDs = Set(arguments.inlineNLP.tags.compactMap { DayBoardMutations.resolveTag(named: $0, context: ctx)?.id })
        let existingTags = (try? ctx.fetch(FetchDescriptor<TagItem>())) ?? []
        let beforeIDs = Set(((try? ctx.fetch(FetchDescriptor<DiaryEntry>())) ?? []).map(\.id))
        guard DayBoardMutations.addDiary(text: fullText, dayKey: dayKey, selectedTagIDs: selectedTagIDs, tags: existingTags, context: ctx) else {
            throw ActionExecutionError.executionFailed("新建手记失败")
        }
        let created = ((try? ctx.fetch(FetchDescriptor<DiaryEntry>())) ?? []).first { !beforeIDs.contains($0.id) }
        let updatedTags = (try? ctx.fetch(FetchDescriptor<TagItem>())) ?? existingTags
        let isSensitiveDiff = Self.detectSensitivity(
            rawInput: arguments.rawInput, text: fullText, nlpTags: arguments.inlineNLP.tags,
            selectedTagIDs: selectedTagIDs, entry: created, tags: updatedTags
        )
        let title = DiaryAndTagActions.diaryPreviewTitle(fullText, isSensitive: isSensitiveDiff)
        return makeOutput(
            targetTitle: title, field: "内容", before: "", after: isSensitiveDiff ? "******" : title,
            isSensitive: isSensitiveDiff, message: "已新建手记：\(title)",
            undo: { if let created { _ = DayBoardMutations.deleteDiary(created) } },
            redo: { if let created { _ = DayBoardMutations.restoreDiary(created) } }
        )
    }

    private func performEdit(_ arguments: ParsedActionArguments, context: ActionContext, in ctx: ModelContext) throws -> ActionExecutionOutput {
        let entry = try DiaryAndTagActions.resolveTargetDiary(arguments: arguments, context: context, modelContext: ctx)
        let hasContextTarget = arguments.targetQuery != nil || context.focusedObjectID != nil || !context.selectedObjectIDs.isEmpty
        let rawText = arguments.option("text")
            ?? (hasContextTarget ? (arguments.joinedPositional.isEmpty ? arguments.inlineNLP.cleanText : arguments.joinedPositional)
                                 : arguments.positional.dropFirst().joined(separator: " "))
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ActionExecutionError.missingRequiredParameter("text") }
        let oldText = (try? DiaryContent.read(entry)) ?? entry.text
        let tags = (try? ctx.fetch(FetchDescriptor<TagItem>())) ?? []
        let isSensitive = entry.hasProtectedContent || DiaryPrivacy.isSensitive(entry.snapshot, tags: tags) || DiaryPrivacy.hasLegacyPrivateMarker(trimmed)
        guard DayBoardMutations.editDiary(entry, text: trimmed) else { throw ActionExecutionError.executionFailed("编辑手记失败") }
        let targetTitle = DiaryAndTagActions.diaryPreviewTitle(trimmed, isSensitive: isSensitive)
        let oldTitle = isSensitive ? "******" : DiaryAndTagActions.diaryPreviewTitle(oldText, isSensitive: false)
        return makeOutput(
            targetTitle: targetTitle, field: "内容", before: oldTitle, after: isSensitive ? "******" : targetTitle,
            isSensitive: isSensitive, message: "已更新手记",
            undo: { _ = DayBoardMutations.editDiary(entry, text: oldText) },
            redo: { _ = DayBoardMutations.editDiary(entry, text: trimmed) }
        )
    }

    private static func detectSensitivity(
        rawInput: String, text: String, nlpTags: [String], selectedTagIDs: Set<UUID>, entry: DiaryEntry?, tags: [TagItem]
    ) -> Bool {
        if DiaryPrivacy.hasLegacyPrivateMarker(rawInput) || DiaryPrivacy.hasLegacyPrivateMarker(text) { return true }
        if nlpTags.contains(where: { DiaryMemoTags.isPasswordName($0) }) { return true }
        if tags.contains(where: { ($0.isPrivateDiary || DiaryMemoTags.isPasswordName($0.name)) && selectedTagIDs.contains($0.id) }) { return true }
        return entry.map { $0.hasProtectedContent || DiaryPrivacy.isSensitive($0.snapshot, tags: tags) } ?? false
    }
}

@MainActor
private final class DiaryEntryOperationAction: ContextBoundAction {
    struct Spec {
        let id: ActionID
        let en: String
        let zh: String
        let cmds: [String]
        let icon: String
        let perm: ActionPermissionLevel
        let undo: Bool
    }

    enum Operation {
        case pin, toTodo, openWindow, togglePrivate, trash
        var spec: Spec {
            switch self {
            case .pin:
                return Spec(
                    id: "diary.pin", en: "Toggle Pin Diary", zh: "置顶手记",
                    cmds: ["pin-diary", "置顶手记"], icon: "pin", perm: .normal, undo: true
                )
            case .toTodo:
                return Spec(
                    id: "diary.toTodo", en: "Convert Diary to Todo", zh: "手记转待办",
                    cmds: ["diary-to-todo", "手记转待办"], icon: "checklist", perm: .normal, undo: true
                )
            case .openWindow:
                return Spec(
                    id: "diary.openWindow", en: "Open Diary in Window", zh: "小窗打开手记",
                    cmds: ["diary-win", "小窗打开手记"], icon: "macwindow", perm: .normal, undo: false
                )
            case .togglePrivate:
                return Spec(
                    id: "diary.togglePrivate", en: "Toggle Private Diary", zh: "设为私密",
                    cmds: ["private-diary", "diary-lock", "手记上锁", "设为私密"],
                    icon: "lock.fill", perm: .privacy, undo: true
                )
            case .trash:
                return Spec(
                    id: "diary.trash", en: "Move Diary to Trash", zh: "删除手记",
                    cmds: ["rm-diary", "diary-rm", "删除手记"], icon: "trash", perm: .normal, undo: true
                )
            }
        }
    }

    private let operation: Operation

    init(operation: Operation, defaultContext: ModelContext? = nil) {
        self.operation = operation
        let s = operation.spec
        super.init(
            id: s.id, englishTitle: s.en, chineseTitle: s.zh, commandNames: s.cmds,
            iconName: s.icon, category: .diary, permissionLevel: s.perm, recordsUndo: s.undo, defaultContext: defaultContext
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let ctx = modelContext(for: context)
        let entry = try DiaryAndTagActions.resolveTargetDiary(arguments: arguments, context: context, modelContext: ctx)
        switch operation {
        case .pin, .togglePrivate: return try performPinOrPrivate(entry)
        case .toTodo, .openWindow, .trash: return try performLifecycle(entry, in: ctx)
        }
    }

    private func performPinOrPrivate(_ entry: DiaryEntry) throws -> ActionExecutionOutput {
        if operation == .pin {
            let wasPinned = entry.isPinned
            guard DayBoardMutations.togglePinDiary(entry) else { throw ActionExecutionError.executionFailed("切换手记置顶失败") }
            let title = DiaryAndTagActions.diaryPreviewTitle(entry.text, isSensitive: entry.hasProtectedContent)
            return makeOutput(
                targetTitle: title, field: "置顶", before: wasPinned ? "是" : "否", after: entry.isPinned ? "是" : "否",
                isSensitive: entry.hasProtectedContent, message: entry.isPinned ? "已置顶手记" : "已取消置顶手记",
                undo: { _ = DayBoardMutations.togglePinDiary(entry) }, redo: { _ = DayBoardMutations.togglePinDiary(entry) }
            )
        }
        let wasPrivate = entry.isPrivate
        guard DayBoardMutations.togglePrivateDiary(entry) else { throw ActionExecutionError.executionFailed("切换手记私密状态失败") }
        return makeOutput(
            targetTitle: "私密手记", field: "私密状态", before: wasPrivate ? "私密" : "公开", after: entry.isPrivate ? "私密" : "公开",
            isSensitive: true, message: entry.isPrivate ? "已设为私密手记" : "已取消私密标记",
            undo: { _ = DayBoardMutations.togglePrivateDiary(entry) }, redo: { _ = DayBoardMutations.togglePrivateDiary(entry) }
        )
    }

    private func performLifecycle(_ entry: DiaryEntry, in ctx: ModelContext) throws -> ActionExecutionOutput {
        if operation == .openWindow {
            let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            _ = DiaryWindows.shared.open(entry: entry, context: ctx, activate: !isTesting)
            let title = DiaryAndTagActions.diaryPreviewTitle(entry.text, isSensitive: entry.hasProtectedContent)
            return ActionExecutionOutput(message: "已在独立小窗打开手记：\(title)")
        }
        if operation == .toTodo {
            let beforeTodoIDs = Set(((try? ctx.fetch(FetchDescriptor<TodoItem>())) ?? []).map(\.id))
            guard DayBoardMutations.convertDiaryToTodo(entry, context: ctx) else { throw ActionExecutionError.executionFailed("手记转待办失败") }
            let createdTodo = ((try? ctx.fetch(FetchDescriptor<TodoItem>())) ?? []).first { !beforeTodoIDs.contains($0.id) }
            let title = createdTodo?.title ?? DiaryAndTagActions.diaryPreviewTitle(entry.text, isSensitive: false)
            return makeOutput(
                targetTitle: title, field: "转换", before: "手记", after: "待办", message: "已将手记转为待办：\(title)",
                undo: { if let createdTodo { _ = DayBoardMutations.trashTodo(createdTodo) } },
                redo: { if let createdTodo { _ = DayBoardMutations.restoreTodo(createdTodo) } }
            )
        }
        let tags = (try? ctx.fetch(FetchDescriptor<TagItem>())) ?? []
        let isSensitive = entry.hasProtectedContent || DiaryPrivacy.isSensitive(entry.snapshot, tags: tags)
        let title = DiaryAndTagActions.diaryPreviewTitle(entry.text, isSensitive: isSensitive)
        guard DayBoardMutations.deleteDiary(entry) else { throw ActionExecutionError.executionFailed("删除手记失败") }
        return makeOutput(
            targetTitle: title, field: "状态", before: "正常", after: "回收站",
            isSensitive: isSensitive, message: "已移入回收站：\(title)",
            undo: { _ = DayBoardMutations.restoreDiary(entry) }, redo: { _ = DayBoardMutations.deleteDiary(entry) }
        )
    }
}

@MainActor
private final class TagOperationAction: ContextBoundAction {
    enum Operation {
        case create, rename, color, merge, trash, cleanUnused
        var spec: (id: ActionID, en: String, zh: String, cmds: [String], icon: String) {
            switch self {
            case .create: return ("tag.create", "Create Tag", "新建标签", ["tag", "new-tag", "新建标签"], "tag.fill")
            case .rename: return ("tag.rename", "Rename Tag", "重命名标签", ["rename-tag", "tag-rename", "标签改名", "重命名标签"], "tag")
            case .color: return ("tag.color", "Set Tag Color", "标签颜色", ["tag-color", "标签颜色"], "paintpalette")
            case .merge: return ("tag.merge", "Merge Tags", "合并标签", ["merge-tag", "合并标签"], "arrow.triangle.merge")
            case .trash: return ("tag.trash", "Delete Tag", "删除标签", ["rm-tag", "tag-delete", "删除标签"], "trash")
            case .cleanUnused: return ("tag.cleanUnused", "Clean Unused Tags", "清理闲置标签", ["clean-tags", "清理闲置标签"], "sparkles")
            }
        }
    }

    private let operation: Operation

    init(operation: Operation, defaultContext: ModelContext? = nil) {
        self.operation = operation
        let s = operation.spec
        super.init(id: s.id, englishTitle: s.en, chineseTitle: s.zh, commandNames: s.cmds, iconName: s.icon, category: .tag, defaultContext: defaultContext)
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let ctx = modelContext(for: context)
        switch operation {
        case .create: return try performCreate(arguments, in: ctx)
        case .rename, .color: return try performRenameOrColor(arguments, context: context, in: ctx)
        case .merge: return try performMerge(arguments, context: context, in: ctx)
        case .trash, .cleanUnused: return try performTrashOrClean(arguments, context: context, in: ctx)
        }
    }

    private func performCreate(_ arguments: ParsedActionArguments, in ctx: ModelContext) throws -> ActionExecutionOutput {
        let rawName = arguments.option("name") ?? arguments.positional.first ?? arguments.inlineNLP.tags.first ?? ""
        let name = String(rawName.trimmingCharacters(in: .whitespacesAndNewlines).trimmingPrefix("#"))
        guard !name.isEmpty else { throw ActionExecutionError.missingRequiredParameter("name") }
        guard let created = DayBoardMutations.createTag(name: name, context: ctx) else { throw ActionExecutionError.executionFailed("新建标签失败") }
        if let color = arguments.option("color") { _ = DayBoardMutations.setTagColor(id: created.id, colorToken: color, context: ctx) }
        return makeOutput(
            targetTitle: "#\(created.name)", field: "标签", before: "", after: "#\(created.name)", message: "已新建标签：#\(created.name)",
            undo: { _ = DayBoardMutations.trashTag(id: created.id, context: ctx) },
            redo: { _ = DayBoardMutations.restoreTag(created) }
        )
    }

    private func performRenameOrColor(_ arguments: ParsedActionArguments, context: ActionContext, in ctx: ModelContext) throws -> ActionExecutionOutput {
        let isColor = operation == .color
        let hasTarget = arguments.targetQuery != nil || arguments.option("from") != nil || arguments.option("tag") != nil
        let targetQuery = arguments.option("from") ?? arguments.option("tag") ?? arguments.targetQuery ?? arguments.positional.first
        let tag = try DiaryAndTagActions.resolveTargetTag(query: targetQuery, context: context, modelContext: ctx)
        let rawVal = arguments.option(isColor ? "color" : "to") ?? arguments.option("name")
            ?? (hasTarget ? arguments.positional.first : arguments.positional.dropFirst().first) ?? ""
        if isColor {
            guard !rawVal.isEmpty else { throw ActionExecutionError.missingRequiredParameter("color") }
            let oldColor = tag.colorToken
            guard DayBoardMutations.setTagColor(id: tag.id, colorToken: rawVal, context: ctx) else { throw ActionExecutionError.executionFailed("修改标签颜色失败") }
            let resolvedColor = tag.colorToken
            return makeOutput(
                targetTitle: "#\(tag.name)", field: "颜色", before: oldColor, after: resolvedColor, message: "已更新标签 #\(tag.name) 颜色为 \(resolvedColor)",
                undo: { _ = DayBoardMutations.setTagColor(id: tag.id, colorToken: oldColor, context: ctx) },
                redo: { _ = DayBoardMutations.setTagColor(id: tag.id, colorToken: resolvedColor, context: ctx) }
            )
        }
        let newName = String(rawVal.trimmingCharacters(in: .whitespacesAndNewlines).trimmingPrefix("#"))
        guard !newName.isEmpty else { throw ActionExecutionError.missingRequiredParameter("name") }
        let oldName = tag.name
        guard DayBoardMutations.renameTag(id: tag.id, name: newName, context: ctx) else { throw ActionExecutionError.executionFailed("重命名标签失败") }
        return makeOutput(
            targetTitle: "#\(newName)", field: "名称", before: oldName, after: newName, message: "已重命名标签：#\(oldName) → #\(newName)",
            undo: { _ = DayBoardMutations.renameTag(id: tag.id, name: oldName, context: ctx) },
            redo: { _ = DayBoardMutations.renameTag(id: tag.id, name: newName, context: ctx) }
        )
    }

    private func performMerge(_ arguments: ParsedActionArguments, context: ActionContext, in ctx: ModelContext) throws -> ActionExecutionOutput {
        let sourceQuery = arguments.option("from") ?? arguments.targetQuery ?? arguments.positional.first
        let targetQuery = arguments.option("into") ?? arguments.option("to")
            ?? (arguments.targetQuery != nil ? arguments.positional.first : arguments.positional.dropFirst().first)
        let sourceTag = try DiaryAndTagActions.resolveTargetTag(query: sourceQuery, context: context, modelContext: ctx)
        let targetTag = try DiaryAndTagActions.resolveTargetTag(query: targetQuery, context: context, modelContext: ctx)
        let todoSnap = ((try? ctx.fetch(FetchDescriptor<TodoItem>())) ?? []).map { ($0, $0.tagIDs) }
        let routineSnap = ((try? ctx.fetch(FetchDescriptor<DailyRoutine>())) ?? []).map { ($0, $0.tagIDs) }
        let diarySnap = ((try? ctx.fetch(FetchDescriptor<DiaryEntry>())) ?? []).map { ($0, $0.tagIDs) }
        guard DayBoardMutations.mergeTags(sourceIDs: [sourceTag.id], into: targetTag.id, context: ctx) else { throw ActionExecutionError.executionFailed("合并标签失败") }
        return makeOutput(
            targetTitle: "#\(sourceTag.name) → #\(targetTag.name)", field: "合并至", before: "#\(sourceTag.name)", after: "#\(targetTag.name)",
            message: "已将标签 #\(sourceTag.name) 合并至 #\(targetTag.name)",
            undo: {
                _ = DayBoardMutations.restoreTag(sourceTag)
                DayBoardMutations.persist(context: ctx) {
                    for (item, raw) in todoSnap { item.tagIDs = raw }
                    for (item, raw) in routineSnap { item.tagIDs = raw }
                    for (item, raw) in diarySnap { item.tagIDs = raw }
                }
            },
            redo: { _ = DayBoardMutations.mergeTags(sourceIDs: [sourceTag.id], into: targetTag.id, context: ctx) }
        )
    }

    private func performTrashOrClean(_ arguments: ParsedActionArguments, context: ActionContext, in ctx: ModelContext) throws -> ActionExecutionOutput {
        if operation == .trash {
            let query = arguments.option("name") ?? arguments.targetQuery ?? arguments.positional.first ?? arguments.inlineNLP.tags.first
            let tag = try DiaryAndTagActions.resolveTargetTag(query: query, context: context, modelContext: ctx)
            guard DayBoardMutations.trashTag(id: tag.id, context: ctx) else { throw ActionExecutionError.executionFailed("删除标签失败") }
            return makeOutput(
                targetTitle: "#\(tag.name)", field: "状态", before: "正常", after: "回收站", message: "已删除标签：#\(tag.name)",
                undo: { _ = DayBoardMutations.restoreTag(tag) },
                redo: { _ = DayBoardMutations.trashTag(id: tag.id, context: ctx) }
            )
        }
        let liveTags = Catalog.liveTags((try? ctx.fetch(FetchDescriptor<TagItem>())) ?? [])
        let todos = (try? ctx.fetch(FetchDescriptor<TodoItem>())) ?? []
        let routines = (try? ctx.fetch(FetchDescriptor<DailyRoutine>())) ?? []
        let diaries = (try? ctx.fetch(FetchDescriptor<DiaryEntry>())) ?? []
        let usage = TagUsage.records(TagUsage.subjects(todos: todos, routines: routines, diaries: diaries))
        let unused = liveTags.filter { !$0.isDiaryPreset && !DiaryMemoTags.isPresetName($0.name) && (usage[$0.id]?.activeCount ?? 0) == 0 }
        guard !unused.isEmpty else { return ActionExecutionOutput(message: "没有需要清理的闲置标签") }
        let unusedIDs = unused.map(\.id)
        guard DayBoardMutations.batchTrashTags(ids: unusedIDs, context: ctx) else { throw ActionExecutionError.executionFailed("清理闲置标签失败") }
        let names = unused.map { "#\($0.name)" }.joined(separator: "、")
        return makeOutput(
            targetTitle: names, field: "清理数量", before: "\(liveTags.count)", after: "\(liveTags.count - unused.count)",
            message: "已清理 \(unused.count) 个闲置标签：\(names)",
            undo: { _ = DayBoardMutations.batchRestoreTags(unused) },
            redo: { _ = DayBoardMutations.batchTrashTags(ids: unusedIDs, context: ctx) }
        )
    }
}

@MainActor
private final class AttachmentStatusAction: ContextBoundAction {
    private let restore: Bool

    init(restore: Bool, defaultContext: ModelContext? = nil) {
        self.restore = restore
        super.init(
            id: restore ? "attachment.restore" : "attachment.trash",
            englishTitle: restore ? "Restore Attachment" : "Delete Attachment",
            chineseTitle: restore ? "恢复附件" : "删除附件",
            commandNames: restore ? ["restore-attachment", "恢复附件"] : ["rm-attachment", "删除附件"],
            iconName: restore ? "arrow.uturn.backward" : "trash", category: .attachment, defaultContext: defaultContext
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let ctx = modelContext(for: context)
        let item = try DiaryAndTagActions.resolveTargetAttachment(arguments: arguments, context: context, modelContext: ctx, includeDeleted: restore)
        let ok = restore ? DayBoardMutations.restoreAttachment(item) : DayBoardMutations.trashAttachment(item)
        guard ok else { throw ActionExecutionError.executionFailed(restore ? "恢复附件失败（所属对象可能已删除）" : "删除附件失败") }
        return makeOutput(
            targetTitle: item.filename, field: "状态", before: restore ? "回收站" : "正常", after: restore ? "正常" : "回收站",
            message: restore ? "已恢复附件：\(item.filename)" : "已删除附件：\(item.filename)",
            undo: { _ = self.restore ? DayBoardMutations.trashAttachment(item) : DayBoardMutations.restoreAttachment(item) },
            redo: { _ = self.restore ? DayBoardMutations.restoreAttachment(item) : DayBoardMutations.trashAttachment(item) }
        )
    }
}
