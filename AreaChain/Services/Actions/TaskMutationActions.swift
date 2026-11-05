import Foundation
import SwiftData

@MainActor
private enum ActionContextModelStore {
    private final class WeakBox {
        weak var context: ModelContext?
        init(_ context: ModelContext?) { self.context = context }
    }

    private static var table: [UUID: WeakBox] = [:]
    static weak var fallbackContext: ModelContext?

    static func get(for id: UUID) -> ModelContext? {
        table[id]?.context ?? fallbackContext
    }

    static func set(_ context: ModelContext?, for id: UUID) {
        if let context {
            table[id] = WeakBox(context)
            fallbackContext = context
        } else {
            table.removeValue(forKey: id)
        }
    }
}

@MainActor
extension ActionContext {
    var modelContext: ModelContext? {
        get { ActionContextModelStore.get(for: instanceID) }
        set { ActionContextModelStore.set(newValue, for: instanceID) }
    }

    init(
        modelContext: ModelContext?, host: String = "workspace", activeWindowID: String? = nil,
        currentTab: String? = nil, selectedObjectIDs: [UUID] = [], focusedObjectID: UUID? = nil,
        focusedObjectTitle: String? = nil, todayKey: String = DayKey.today(),
        isVaultUnlocked: Bool = false, allowedExternalPermission: ActionPermissionLevel = .system,
        confirmed: Bool = false
    ) {
        self.init(
            host: host, activeWindowID: activeWindowID, currentTab: currentTab,
            selectedObjectIDs: selectedObjectIDs, focusedObjectID: focusedObjectID,
            focusedObjectTitle: focusedObjectTitle, todayKey: todayKey,
            isVaultUnlocked: isVaultUnlocked, allowedExternalPermission: allowedExternalPermission,
            confirmed: confirmed
        )
        ActionContextModelStore.set(modelContext, for: self.instanceID)
    }
}

/// 待办（`TodoItem`）全量变更动作集合及共享目标解析辅助。
@MainActor
enum TaskMutationActions {
    static func all() -> [BaseAction] {
        [
            TodoCreateAction(), TodoSetDoneAction(markDone: true), TodoSetDoneAction(markDone: false),
            TodoRenameAction(), TodoNotesAction(), TodoMoveDateAction(), TodoPriorityAction(),
            TodoTimeFieldAction(isDue: false), TodoTimeFieldAction(isDue: true),
            TodoTagAction(), TodoConvertRoutineAction(), TodoTrashAction(),
        ]
    }

    static func resolveModelContext(from context: ActionContext) -> ModelContext {
        context.modelContext ?? Persistence.session.container.mainContext
    }

    static func resolveTargetTodos(
        arguments: ParsedActionArguments, context: ActionContext, expectsValueArgument: Bool
    ) throws -> (todos: [TodoItem], remainingPositional: [String]) {
        let modelContext = resolveModelContext(from: context)
        let allLive = (try? modelContext.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        if let query = arguments.targetQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            let matched = matchTodos(query: query, in: allLive)
            guard !matched.isEmpty else { throw ActionExecutionError.targetNotFound(query) }
            return (matched, arguments.positional)
        }
        if !context.selectedObjectIDs.isEmpty {
            let idSet = Set(context.selectedObjectIDs)
            let matched = allLive.filter { idSet.contains($0.id) }
            if !matched.isEmpty { return (matched, arguments.positional) }
        }
        if let focusedID = context.focusedObjectID, let matched = allLive.first(where: { $0.id == focusedID }) {
            return ([matched], arguments.positional)
        }
        if !arguments.positional.isEmpty && (!expectsValueArgument || arguments.positional.count >= 2) {
            let matched = matchTodos(query: arguments.positional[0], in: allLive)
            if !matched.isEmpty { return (matched, Array(arguments.positional.dropFirst())) }
        }
        if let navSelected = WorkspaceNavigation.shared.selectedTaskID,
           let matched = allLive.first(where: { $0.id == navSelected }) {
            return ([matched], arguments.positional)
        }
        throw ActionExecutionError.targetNotFound("未选中或匹配到待办事项")
    }

    static func matchTodos(query: String, in todos: [TodoItem]) -> [TodoItem] {
        if let uuid = UUID(uuidString: query) { return todos.filter { $0.id == uuid } }
        let exact = todos.filter { $0.title.caseInsensitiveCompare(query) == .orderedSame }
        return exact.isEmpty ? todos.filter { $0.title.localizedCaseInsensitiveContains(query) } : exact
    }

    static func resolveDayKey(_ token: String, baseDayKey: String) -> String? {
        let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch cleaned {
        case "today", "今天", "今日": return baseDayKey
        case "tomorrow", "tmr", "明天", "明日": return DayKey.shifted(baseDayKey, by: 1)
        case "yesterday", "昨天", "昨日": return DayKey.shifted(baseDayKey, by: -1)
        default:
            var offsetText = cleaned
            if offsetText.hasSuffix("d") || offsetText.hasSuffix("天") { offsetText.removeLast() }
            if offsetText.hasPrefix("+") || offsetText.hasPrefix("-"), let offset = Int(offsetText) {
                return DayKey.shifted(baseDayKey, by: offset)
            }
            if let date = DayKey.date(from: cleaned), DayKey.from(date) == cleaned { return cleaned }
            return nil
        }
    }

    static func resolveSlot(_ token: String, inlineNLP: ActionInlineNLP) -> QuadrantSlot? {
        if inlineNLP.hasPriorityToken {
            return QuadrantSlot.of(important: inlineNLP.isImportant, urgent: inlineNLP.isUrgent)
        }
        switch token.trimmingCharacters(in: .whitespacesAndNewlines).trimmingPrefix("!").lowercased() {
        case "p1", "1", "iu", "重要紧急", "紧急重要": return .importantUrgent
        case "p2", "2", "i", "重要", "重要不紧急": return .important
        case "p3", "3", "u", "紧急", "不重要紧急": return .urgent
        case "p4", "4", "rest", "不重要不紧急", "普通": return .rest
        default: return nil
        }
    }

    static func parseMinutesToken(_ token: String?, inlineRemind: Int?) throws -> Int? {
        if let token {
            let lower = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["clear", "off", "none", "清除", "取消"].contains(lower) { return nil }
            let normalized = lower.hasPrefix("@") ? String(lower.dropFirst()) : lower
            let parts = normalized.replacingOccurrences(of: "：", with: ":").split(separator: ":")
            if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]), (0..<24).contains(h), (0..<60).contains(m) {
                return h * 60 + m
            }
        }
        if let inlineRemind { return inlineRemind }
        throw ActionExecutionError.invalidParameterValue(parameter: "time", value: token ?? "")
    }

    static func formatMinutes(_ minutes: Int?) -> String {
        guard let minutes else { return "无" }
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

@MainActor
private final class TodoCreateAction: BaseAction {
    init() {
        super.init(
            id: "todo.create", englishTitle: "Create Todo", chineseTitle: "新增待办",
            commandNames: ["todo", "add", "t", "待办", "新增待办"], iconName: "plus.circle", category: .task,
            parameters: [
                ActionParameterSpec(id: "title", englishName: "Title", chineseName: "标题", required: true),
                ActionParameterSpec(id: "date", englishName: "Date", chineseName: "日期"),
            ]
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let modelContext = TaskMutationActions.resolveModelContext(from: context)
        let dayToken = arguments.option("date") ?? context.todayKey
        let dayKey = TaskMutationActions.resolveDayKey(dayToken, baseDayKey: context.todayKey) ?? context.todayKey
        let rawText = Self.extractCaptureText(from: arguments)
        guard !rawText.isEmpty else { throw ActionExecutionError.missingRequiredParameter("title") }
        let existingIDs = Set(((try? modelContext.fetch(FetchDescriptor<TodoItem>())) ?? []).map(\.id))
        guard DayBoardMutations.addCapturedTodo(text: rawText, dayKey: dayKey, context: modelContext),
              let created = ((try? modelContext.fetch(FetchDescriptor<TodoItem>())) ?? []).first(where: { !existingIDs.contains($0.id) }) else {
            throw ActionExecutionError.executionFailed("待办创建失败")
        }
        let diff = ActionDiff(actionID: id, actionTitle: chineseTitle, targetTitle: created.title,
                              changes: [ActionFieldChange(field: "新建待办", before: "", after: created.title)])
        return ActionExecutionOutput(message: "已新增待办：\(created.title)", diff: diff,
            undoPayload: ActionUndoPayload(actionID: id, targetIDs: [created.id]),
            undoClosure: { _ = DayBoardMutations.trashTodo(created) },
            redoClosure: { _ = DayBoardMutations.restoreTodo(created) })
    }

    private static func extractCaptureText(from arguments: ParsedActionArguments) -> String {
        var parts = arguments.positional
        if let titleOpt = arguments.option("title"), !titleOpt.isEmpty, parts.isEmpty { parts.append(titleOpt) }
        for tag in arguments.inlineNLP.tags { parts.append("#\(tag)") }
        if let timeLabel = arguments.inlineNLP.timeLabel { parts.append("@\(timeLabel)") }
        if arguments.inlineNLP.hasPriorityToken {
            let slot = QuadrantSlot.of(important: arguments.inlineNLP.isImportant, urgent: arguments.inlineNLP.isUrgent)
            parts.append("!\(slot.badgeText.lowercased())")
        }
        let base = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !arguments.inlineNLP.notes.isEmpty else { return base }
        return base.isEmpty ? "// \(arguments.inlineNLP.notes)" : "\(base) // \(arguments.inlineNLP.notes)"
    }
}

@MainActor
private final class TodoSetDoneAction: BaseAction {
    private let markDone: Bool

    init(markDone: Bool) {
        self.markDone = markDone
        super.init(id: markDone ? "todo.complete" : "todo.reopen",
                   englishTitle: markDone ? "Complete Todo" : "Reopen Todo",
                   chineseTitle: markDone ? "完成待办" : "重开待办",
                   commandNames: markDone ? ["done", "complete", "完成"] : ["reopen", "undone", "未完成", "重开"],
                   iconName: markDone ? "checkmark.circle.fill" : "circle", category: .task)
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let (targets, _) = try TaskMutationActions.resolveTargetTodos(arguments: arguments, context: context, expectsValueArgument: false)
        let priorStates = targets.map { (todo: $0, wasDone: $0.isDone) }
        let ids = Set(targets.map(\.id))
        guard DayBoardMutations.batchToggleDone(ids, markDone: markDone, todos: targets) else {
            throw ActionExecutionError.executionFailed("\(chineseTitle)失败")
        }
        let titleLabel = targets.count == 1 ? targets[0].title : "\(targets.count) 项待办"
        let diff = ActionDiff(actionID: id, actionTitle: chineseTitle, targetTitle: titleLabel,
                              changes: [ActionFieldChange(field: "状态", before: markDone ? "未完成" : "已完成", after: markDone ? "已完成" : "未完成")])
        let targetDone = markDone
        return ActionExecutionOutput(message: "已\(chineseTitle)：\(titleLabel)", diff: diff,
            undoPayload: ActionUndoPayload(actionID: id, targetIDs: Array(ids)),
            undoClosure: {
                for item in priorStates where item.todo.isDone != item.wasDone {
                    _ = DayBoardMutations.batchToggleDone([item.todo.id], markDone: item.wasDone, todos: [item.todo])
                }
            },
            redoClosure: { _ = DayBoardMutations.batchToggleDone(ids, markDone: targetDone, todos: targets) })
    }
}

@MainActor
private final class TodoRenameAction: BaseAction {
    init() {
        super.init(
            id: "todo.title", englishTitle: "Rename Todo", chineseTitle: "修改待办标题",
            commandNames: ["rename", "rename-todo", "title", "改名", "改标题"], iconName: "pencil", category: .task,
            parameters: [ActionParameterSpec(id: "title", englishName: "New Title", chineseName: "新标题", required: true)]
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let (targets, rest) = try TaskMutationActions.resolveTargetTodos(arguments: arguments, context: context, expectsValueArgument: true)
        guard let todo = targets.first else { throw ActionExecutionError.targetNotFound("待办") }
        let newTitle = (arguments.option("title") ?? rest.joined(separator: " ")).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty else { throw ActionExecutionError.missingRequiredParameter("title") }
        let oldTitle = todo.title
        guard DayBoardMutations.editTodo(todo, title: newTitle) else { throw ActionExecutionError.executionFailed("修改标题失败") }
        let updatedTitle = todo.title
        let diff = ActionDiff(actionID: id, actionTitle: chineseTitle, targetTitle: updatedTitle,
                              changes: [ActionFieldChange(field: "标题", before: oldTitle, after: updatedTitle)])
        return ActionExecutionOutput(message: "已修改标题：\(oldTitle) → \(updatedTitle)", diff: diff,
            undoClosure: { _ = DayBoardMutations.editTodo(todo, title: oldTitle) },
            redoClosure: { _ = DayBoardMutations.editTodo(todo, title: updatedTitle) })
    }
}

@MainActor
private final class TodoNotesAction: BaseAction {
    init() {
        super.init(id: "todo.notes", englishTitle: "Update Todo Notes", chineseTitle: "修改待办备注",
                   commandNames: ["note", "notes", "备注"], iconName: "note.text", category: .task,
                   parameters: [ActionParameterSpec(id: "notes", englishName: "Notes", chineseName: "备注内容")])
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let (targets, rest) = try TaskMutationActions.resolveTargetTodos(arguments: arguments, context: context, expectsValueArgument: true)
        guard let todo = targets.first else { throw ActionExecutionError.targetNotFound("待办") }
        let newNotes = arguments.option("notes") ?? (!arguments.inlineNLP.notes.isEmpty ? arguments.inlineNLP.notes : rest.joined(separator: " "))
        let oldNotes = todo.notes
        guard DayBoardMutations.updateNotes(for: todo, notes: newNotes) else { throw ActionExecutionError.executionFailed("修改备注失败") }
        let diff = ActionDiff(actionID: id, actionTitle: chineseTitle, targetTitle: todo.title,
                              changes: [ActionFieldChange(field: "备注", before: "\(oldNotes.utf8.count)B", after: "\(newNotes.utf8.count)B")])
        return ActionExecutionOutput(message: "已更新「\(todo.title)」的备注", diff: diff,
            undoClosure: { _ = DayBoardMutations.updateNotes(for: todo, notes: oldNotes) },
            redoClosure: { _ = DayBoardMutations.updateNotes(for: todo, notes: newNotes) })
    }
}

@MainActor
private final class TodoMoveDateAction: BaseAction {
    init() {
        super.init(
            id: "todo.move", englishTitle: "Move Todo Date", chineseTitle: "移动待办日期",
            commandNames: ["move", "mv", "defer", "推迟", "移到", "改期"], iconName: "calendar.badge.clock", category: .task,
            parameters: [
                ActionParameterSpec(
                    id: "date", englishName: "Target Date", chineseName: "目标日期",
                    required: true, allowedValues: ["today", "tomorrow", "yesterday"]
                ),
            ]
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let (targets, rest) = try TaskMutationActions.resolveTargetTodos(arguments: arguments, context: context, expectsValueArgument: true)
        let rawToken = arguments.option("date") ?? rest.first ?? ""
        guard let firstTodo = targets.first,
              let newDayKey = TaskMutationActions.resolveDayKey(rawToken, baseDayKey: firstTodo.dayKey) else {
            throw ActionExecutionError.invalidParameterValue(parameter: "date", value: rawToken)
        }
        let oldDays = targets.map { (todo: $0, dayKey: $0.dayKey) }
        let ids = Set(targets.map(\.id))
        guard DayBoardMutations.batchMoveTodos(ids, to: newDayKey, todos: targets) else {
            throw ActionExecutionError.executionFailed("改期失败")
        }
        let titleLabel = targets.count == 1 ? firstTodo.title : "\(targets.count) 项待办"
        let diff = ActionDiff(actionID: id, actionTitle: chineseTitle, targetTitle: titleLabel,
                              changes: [ActionFieldChange(field: "日期", before: oldDays[0].dayKey, after: newDayKey)])
        return ActionExecutionOutput(message: "已将「\(titleLabel)」移到 \(newDayKey)", diff: diff,
            undoClosure: { for item in oldDays { _ = DayBoardMutations.moveTodo(item.todo, to: item.dayKey) } },
            redoClosure: { _ = DayBoardMutations.batchMoveTodos(ids, to: newDayKey, todos: targets) })
    }
}

@MainActor
private final class TodoPriorityAction: BaseAction {
    init() {
        super.init(
            id: "todo.priority", englishTitle: "Set Todo Priority", chineseTitle: "设置待办优先级",
            commandNames: ["prio", "priority", "p", "优先级"], iconName: "flag.fill", category: .task,
            parameters: [
                ActionParameterSpec(
                    id: "level", englishName: "Priority", chineseName: "优先级",
                    required: true, allowedValues: ["p1", "p2", "p3", "p4"]
                ),
            ]
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let (targets, rest) = try TaskMutationActions.resolveTargetTodos(arguments: arguments, context: context, expectsValueArgument: true)
        guard let todo = targets.first else { throw ActionExecutionError.targetNotFound("待办") }
        let rawLevel = arguments.option("level") ?? rest.first ?? ""
        guard let newSlot = TaskMutationActions.resolveSlot(rawLevel, inlineNLP: arguments.inlineNLP) else {
            throw ActionExecutionError.invalidParameterValue(parameter: "level", value: rawLevel)
        }
        let oldSlot = QuadrantSlot.of(important: todo.isImportant, urgent: todo.isUrgent)
        guard DayBoardMutations.applyQuadrant(newSlot, to: todo) else { throw ActionExecutionError.executionFailed("设置优先级失败") }
        let diff = ActionDiff(actionID: id, actionTitle: chineseTitle, targetTitle: todo.title,
                              changes: [ActionFieldChange(field: "优先级", before: oldSlot.badgeText, after: newSlot.badgeText)])
        return ActionExecutionOutput(message: "已将「\(todo.title)」优先级设为 \(newSlot.badgeText)", diff: diff,
            undoClosure: { _ = DayBoardMutations.applyQuadrant(oldSlot, to: todo) },
            redoClosure: { _ = DayBoardMutations.applyQuadrant(newSlot, to: todo) })
    }
}

@MainActor
private final class TodoTimeFieldAction: BaseAction {
    private let isDue: Bool

    init(isDue: Bool) {
        self.isDue = isDue
        super.init(id: isDue ? "todo.due" : "todo.remind",
                   englishTitle: isDue ? "Set Todo Due Time" : "Set Todo Reminder",
                   chineseTitle: isDue ? "设置截止时刻" : "设置提醒时刻",
                   commandNames: isDue ? ["due", "截止"] : ["remind", "at", "提醒"],
                   iconName: isDue ? "hourglass" : "bell.fill", category: .task,
                   parameters: [ActionParameterSpec(id: "time", englishName: "HH:mm or clear", chineseName: "时刻或清除", required: true)])
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let (targets, rest) = try TaskMutationActions.resolveTargetTodos(arguments: arguments, context: context, expectsValueArgument: true)
        guard let todo = targets.first else { throw ActionExecutionError.targetNotFound("待办") }
        let newMinutes = try TaskMutationActions.parseMinutesToken(arguments.option("time") ?? rest.first, inlineRemind: arguments.inlineNLP.remindMinutes)
        let oldMinutes = isDue ? todo.dueMinutes : todo.remindMinutes
        let updated = isDue ? DayBoardMutations.setDue(todo, minutes: newMinutes) : DayBoardMutations.setRemind(todo, minutes: newMinutes)
        guard updated else {
            throw ActionExecutionError.executionFailed("\(chineseTitle)失败")
        }
        let fieldName = isDue ? "截止" : "提醒"
        let beforeText = TaskMutationActions.formatMinutes(oldMinutes)
        let afterText = TaskMutationActions.formatMinutes(newMinutes)
        let diff = ActionDiff(actionID: id, actionTitle: chineseTitle, targetTitle: todo.title,
                              changes: [ActionFieldChange(field: fieldName, before: beforeText, after: afterText)])
        let dueFlag = isDue
        return ActionExecutionOutput(message: "已设置「\(todo.title)」\(fieldName)：\(afterText)", diff: diff,
            undoClosure: { _ = dueFlag ? DayBoardMutations.setDue(todo, minutes: oldMinutes) : DayBoardMutations.setRemind(todo, minutes: oldMinutes) },
            redoClosure: { _ = dueFlag ? DayBoardMutations.setDue(todo, minutes: newMinutes) : DayBoardMutations.setRemind(todo, minutes: newMinutes) })
    }
}

@MainActor
private final class TodoTagAction: BaseAction {
    init() {
        super.init(id: "todo.tag", englishTitle: "Tag Todo", chineseTitle: "为待办打标签",
                   commandNames: ["tag-todo", "tag-add", "tag-rm", "贴标签", "打标"], iconName: "tag.fill", category: .task,
                   parameters: [ActionParameterSpec(id: "tag", englishName: "Tag Name", chineseName: "标签名", required: true)])
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let modelContext = TaskMutationActions.resolveModelContext(from: context)
        let (targets, rest) = try TaskMutationActions.resolveTargetTodos(arguments: arguments, context: context, expectsValueArgument: true)
        guard let todo = targets.first else { throw ActionExecutionError.targetNotFound("待办") }
        let rawTag = arguments.option("tag") ?? arguments.inlineNLP.tags.first ?? rest.first ?? ""
        let tagName = rawTag.trimmingCharacters(in: .whitespacesAndNewlines).trimmingPrefix("#")
        guard !tagName.isEmpty, let tag = DayBoardMutations.resolveTaskTag(named: String(tagName), context: modelContext) else {
            throw ActionExecutionError.invalidParameterValue(parameter: "tag", value: String(tagName))
        }
        let hadTag = TagIDList.contains(todo.tagIDs, tag.id)
        guard DayBoardMutations.toggleTag(for: todo, tagID: tag.id) else { throw ActionExecutionError.executionFailed("变更待办标签失败") }
        let diff = ActionDiff(actionID: id, actionTitle: chineseTitle, targetTitle: todo.title,
                              changes: [ActionFieldChange(field: "标签", before: hadTag ? "#\(tag.name)" : "无", after: hadTag ? "无" : "#\(tag.name)")])
        return ActionExecutionOutput(message: "\(hadTag ? "已移除" : "已添加")标签 #\(tag.name)", diff: diff,
            undoClosure: { _ = DayBoardMutations.toggleTag(for: todo, tagID: tag.id) },
            redoClosure: { _ = DayBoardMutations.toggleTag(for: todo, tagID: tag.id) })
    }
}

@MainActor
private final class TodoConvertRoutineAction: BaseAction {
    init() {
        super.init(id: "todo.convertRoutine", englishTitle: "Convert Todo to Routine", chineseTitle: "待办转为习惯",
                   commandNames: ["to-routine", "转为习惯"], iconName: "arrow.triangle.2.circlepath", category: .task)
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let modelContext = TaskMutationActions.resolveModelContext(from: context)
        let (targets, _) = try TaskMutationActions.resolveTargetTodos(arguments: arguments, context: context, expectsValueArgument: false)
        guard let todo = targets.first else { throw ActionExecutionError.targetNotFound("待办") }
        let title = todo.title
        guard var currentRoutineID = DayBoardMutations.convertTodoToRoutine(todo) else {
            throw ActionExecutionError.executionFailed("转为习惯失败")
        }
        var currentTodoID: UUID?
        let diff = ActionDiff(actionID: id, actionTitle: chineseTitle, targetTitle: title,
                              changes: [ActionFieldChange(field: "类型", before: "待办", after: "习惯")])
        return ActionExecutionOutput(message: "已将待办「\(title)」转为习惯", diff: diff,
            undoClosure: {
                let rID = currentRoutineID
                if let routine = (try? modelContext.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.id == rID })))?.first {
                    currentTodoID = DayBoardMutations.convertRoutineToTodo(routine)
                }
            },
            redoClosure: {
                guard let tID = currentTodoID,
                      let restoredTodo = (try? modelContext.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == tID })))?.first,
                      let nextRoutineID = DayBoardMutations.convertTodoToRoutine(restoredTodo) else { return }
                currentRoutineID = nextRoutineID
            })
    }
}

@MainActor
private final class TodoTrashAction: BaseAction {
    init() {
        super.init(id: "todo.trash", englishTitle: "Move Todo to Trash", chineseTitle: "删除待办",
                   commandNames: ["rm-todo", "trash-todo", "rm", "del", "delete", "删除待办", "删除任务"], iconName: "trash", category: .task)
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let (targets, _) = try TaskMutationActions.resolveTargetTodos(arguments: arguments, context: context, expectsValueArgument: false)
        for todo in targets {
            guard DayBoardMutations.trashTodo(todo) else { throw ActionExecutionError.executionFailed("删除待办失败") }
        }
        let label = targets.count == 1 ? targets[0].title : "\(targets.count) 项待办"
        let diff = ActionDiff(actionID: id, actionTitle: chineseTitle, targetTitle: label,
                              changes: [ActionFieldChange(field: "状态", before: "正常", after: "回收站")])
        return ActionExecutionOutput(message: "已将「\(label)」移入回收站", diff: diff,
            undoClosure: { for todo in targets { _ = DayBoardMutations.restoreTodo(todo) } },
            redoClosure: { for todo in targets { _ = DayBoardMutations.trashTodo(todo) } })
    }
}
