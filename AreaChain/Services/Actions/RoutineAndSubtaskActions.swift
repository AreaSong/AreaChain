import Foundation
import SwiftData

/// 习惯（`DailyRoutine`）与子任务（`SubtaskItem`）的统一动作集合。
@MainActor
enum RoutineAndSubtaskActions {
    static func all() -> [BaseAction] {
        [
            RoutineCreateAction(),
            RoutineCheckAction(isSkip: false),
            RoutineCheckAction(isSkip: true),
            RoutineEnableAction(enable: false),
            RoutineEnableAction(enable: true),
            RoutineWeekdaysAction(),
            RoutineConvertTodoAction(),
            RoutineTrashAction(),
            SubtaskAddAction(),
            SubtaskToggleAction(),
            SubtaskRenameAction(),
            SubtaskDeleteAction(),
        ]
    }

    fileprivate static func resolveRoutine(
        arguments: ParsedActionArguments, context: ActionContext, expectsValueArgument: Bool
    ) throws -> (routine: DailyRoutine, remainingPositional: [String]) {
        let modelContext = TaskMutationActions.resolveModelContext(from: context)
        let allLive = (try? modelContext.fetch(
            FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.deletedAt == nil })
        )) ?? []

        if let query = arguments.targetQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            if let matched = matchRoutine(query: query, in: allLive) { return (matched, arguments.positional) }
            throw ActionExecutionError.targetNotFound(query)
        }
        if let focusedID = context.focusedObjectID, let matched = allLive.first(where: { $0.id == focusedID }) {
            return (matched, arguments.positional)
        }
        if let firstSelected = context.selectedObjectIDs.first, let matched = allLive.first(where: { $0.id == firstSelected }) {
            return (matched, arguments.positional)
        }
        if !arguments.positional.isEmpty && (!expectsValueArgument || arguments.positional.count >= 2) {
            if let matched = matchRoutine(query: arguments.positional[0], in: allLive) {
                return (matched, Array(arguments.positional.dropFirst()))
            }
        }
        throw ActionExecutionError.targetNotFound("未选中或匹配到习惯事项")
    }

    private static func matchRoutine(query: String, in routines: [DailyRoutine]) -> DailyRoutine? {
        if let uuid = UUID(uuidString: query) { return routines.first { $0.id == uuid } }
        if let exact = routines.first(where: { $0.title.caseInsensitiveCompare(query) == .orderedSame }) { return exact }
        return routines.first { $0.title.localizedCaseInsensitiveContains(query) }
    }

    fileprivate static func resolveSubtask(
        arguments: ParsedActionArguments, context: ActionContext, expectsValueArgument: Bool
    ) throws -> (subtask: SubtaskItem, remainingPositional: [String]) {
        let modelContext = TaskMutationActions.resolveModelContext(from: context)
        let allLive = (try? modelContext.fetch(
            FetchDescriptor<SubtaskItem>(predicate: #Predicate { $0.deletedAt == nil })
        )) ?? []

        if let query = arguments.targetQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            if let matched = matchSubtask(query: query, in: allLive) { return (matched, arguments.positional) }
            throw ActionExecutionError.targetNotFound(query)
        }
        if let focusedID = context.focusedObjectID, let matched = allLive.first(where: { $0.id == focusedID }) {
            return (matched, arguments.positional)
        }
        if let firstSelected = context.selectedObjectIDs.first, let matched = allLive.first(where: { $0.id == firstSelected }) {
            return (matched, arguments.positional)
        }
        if !arguments.positional.isEmpty && (!expectsValueArgument || arguments.positional.count >= 2) {
            if let matched = matchSubtask(query: arguments.positional[0], in: allLive) {
                return (matched, Array(arguments.positional.dropFirst()))
            }
        }
        throw ActionExecutionError.targetNotFound("未选中或匹配到子任务")
    }

    private static func matchSubtask(query: String, in subtasks: [SubtaskItem]) -> SubtaskItem? {
        if let uuid = UUID(uuidString: query) { return subtasks.first { $0.id == uuid } }
        if let exact = subtasks.first(where: { $0.title.caseInsensitiveCompare(query) == .orderedSame }) { return exact }
        return subtasks.first { $0.title.localizedCaseInsensitiveContains(query) }
    }

    fileprivate static func parseWeekdayMask(_ token: String) -> Int? {
        let lower = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch lower {
        case "all", "everyday", "daily", "每天", "每日": return WeekdayMask.all
        case "workdays", "weekdays", "工作日": return WeekdayMask.workdays
        case "weekend", "weekends", "周末": return 0b1000001
        default:
            let parts = lower.split { $0 == "," || $0 == "、" || $0 == " " }
            var mask = 0
            for part in parts {
                if let num = Int(part), (1...7).contains(num) { mask |= (1 << (num - 1)) }
            }
            if mask != 0 { return WeekdayMask.sanitized(mask) }
            if let direct = Int(lower), direct > 0 { return WeekdayMask.sanitized(direct) }
            return nil
        }
    }
}

@MainActor
private final class RoutineCreateAction: BaseAction {
    init() {
        super.init(
            id: "routine.create", englishTitle: "Create Routine", chineseTitle: "新增习惯",
            commandNames: ["habit", "routine", "习惯", "新增习惯"], iconName: "repeat.circle", category: .routine,
            parameters: [ActionParameterSpec(id: "title", englishName: "Title", chineseName: "标题", required: true)]
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let modelContext = TaskMutationActions.resolveModelContext(from: context)
        var text = arguments.option("title") ?? arguments.joinedPositional
        for tag in arguments.inlineNLP.tags { text += " #\(tag)" }
        if let time = arguments.inlineNLP.timeLabel { text += " @\(time)" }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ActionExecutionError.missingRequiredParameter("title") }

        let beforeRoutines = (try? modelContext.fetch(FetchDescriptor<DailyRoutine>())) ?? []
        let existingIDs = Set(beforeRoutines.map(\.id))
        let nextOrder = (beforeRoutines.map(\.sortOrder).max() ?? -1) + 1
        guard DayBoardMutations.addCapturedRoutine(text: trimmed, sortOrder: nextOrder, context: modelContext) else {
            throw ActionExecutionError.executionFailed("新增习惯失败")
        }
        let afterRoutines = (try? modelContext.fetch(FetchDescriptor<DailyRoutine>())) ?? []
        guard let created = afterRoutines.first(where: { !existingIDs.contains($0.id) }) else {
            throw ActionExecutionError.executionFailed("未找到新建的习惯记录")
        }
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: created.title,
            changes: [ActionFieldChange(field: "新建习惯", before: "", after: created.title)]
        )
        return ActionExecutionOutput(
            message: "已新增习惯：\(created.title)", diff: diff,
            undoClosure: { _ = DayBoardMutations.trashRoutine(created) },
            redoClosure: { _ = DayBoardMutations.restoreRoutine(created) }
        )
    }
}

@MainActor
private final class RoutineCheckAction: BaseAction {
    private let isSkip: Bool

    init(isSkip: Bool) {
        self.isSkip = isSkip
        super.init(
            id: isSkip ? "routine.skip" : "routine.check",
            englishTitle: isSkip ? "Skip Routine" : "Check Routine",
            chineseTitle: isSkip ? "跳过习惯打卡" : "习惯打卡",
            commandNames: isSkip ? ["skip", "跳过"] : ["check", "打卡"],
            iconName: isSkip ? "forward.end.fill" : "checkmark.seal.fill", category: .routine
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let modelContext = TaskMutationActions.resolveModelContext(from: context)
        let (routine, rest) = try RoutineAndSubtaskActions.resolveRoutine(arguments: arguments, context: context, expectsValueArgument: false)
        let dayToken = arguments.option("date") ?? rest.first ?? context.todayKey
        let dayKey = TaskMutationActions.resolveDayKey(dayToken, baseDayKey: context.todayKey) ?? context.todayKey
        let ok = isSkip
            ? DayBoardMutations.skipRoutine(routine, on: dayKey, checks: routine.checks, context: modelContext)
            : DayBoardMutations.toggleRoutine(routine, on: dayKey, checks: routine.checks, context: modelContext)
        guard ok else { throw ActionExecutionError.executionFailed("\(chineseTitle)失败") }
        let label = isSkip ? "已跳过" : "已打卡"
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: routine.title,
            changes: [ActionFieldChange(field: "打卡(\(dayKey))", before: "变更前", after: label)]
        )
        let skipMode = isSkip
        return ActionExecutionOutput(
            message: "\(label)习惯「\(routine.title)」（\(dayKey)）", diff: diff,
            undoClosure: {
                _ = skipMode
                    ? DayBoardMutations.skipRoutine(routine, on: dayKey, checks: routine.checks, context: modelContext)
                    : DayBoardMutations.toggleRoutine(routine, on: dayKey, checks: routine.checks, context: modelContext)
            },
            redoClosure: {
                _ = skipMode
                    ? DayBoardMutations.skipRoutine(routine, on: dayKey, checks: routine.checks, context: modelContext)
                    : DayBoardMutations.toggleRoutine(routine, on: dayKey, checks: routine.checks, context: modelContext)
            }
        )
    }
}

@MainActor
private final class RoutineEnableAction: BaseAction {
    private let enable: Bool

    init(enable: Bool) {
        self.enable = enable
        super.init(
            id: enable ? "routine.resume" : "routine.pause",
            englishTitle: enable ? "Resume Routine" : "Pause Routine",
            chineseTitle: enable ? "恢复习惯" : "暂停习惯",
            commandNames: enable ? ["resume-habit", "恢复习惯"] : ["pause-habit", "routine-pause", "暂停习惯"],
            iconName: enable ? "play.circle" : "pause.circle", category: .routine
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let modelContext = TaskMutationActions.resolveModelContext(from: context)
        let (routine, _) = try RoutineAndSubtaskActions.resolveRoutine(arguments: arguments, context: context, expectsValueArgument: false)
        let wasEnabled = routine.isEnabled
        let targetEnabled = enable
        guard DayBoardMutations.setRoutineEnabled(
            routine, enabled: targetEnabled, todayKey: context.todayKey,
            checks: routine.checks, context: modelContext
        ) else {
            throw ActionExecutionError.executionFailed("\(chineseTitle)失败")
        }
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: routine.title,
            changes: [ActionFieldChange(field: "状态", before: wasEnabled ? "启用" : "暂停", after: targetEnabled ? "启用" : "暂停")]
        )
        return ActionExecutionOutput(
            message: "已\(chineseTitle)：\(routine.title)", diff: diff,
            undoClosure: {
                _ = DayBoardMutations.setRoutineEnabled(
                    routine, enabled: wasEnabled, todayKey: context.todayKey,
                    checks: routine.checks, context: modelContext
                )
            },
            redoClosure: {
                _ = DayBoardMutations.setRoutineEnabled(
                    routine, enabled: targetEnabled, todayKey: context.todayKey,
                    checks: routine.checks, context: modelContext
                )
            }
        )
    }
}

@MainActor
private final class RoutineWeekdaysAction: BaseAction {
    init() {
        super.init(
            id: "routine.weekdays", englishTitle: "Set Routine Weekdays", chineseTitle: "设置习惯周期",
            commandNames: ["weekdays", "routine-freq", "周期", "习惯周期"], iconName: "calendar.day.timeline.left", category: .routine,
            parameters: [
                ActionParameterSpec(
                    id: "mask", englishName: "Weekdays", chineseName: "周期",
                    required: true, allowedValues: ["all", "workdays", "weekend"]
                ),
            ]
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let (routine, rest) = try RoutineAndSubtaskActions.resolveRoutine(arguments: arguments, context: context, expectsValueArgument: true)
        let token = arguments.option("mask") ?? rest.joined(separator: ",")
        guard let newMask = RoutineAndSubtaskActions.parseWeekdayMask(token) else {
            throw ActionExecutionError.invalidParameterValue(parameter: "mask", value: token)
        }
        let oldMask = routine.resolvedWeekdayMask
        guard DayBoardMutations.setWeekdayMask(routine, mask: newMask) else {
            throw ActionExecutionError.executionFailed("设置周期失败")
        }
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: routine.title,
            changes: [ActionFieldChange(field: "周期掩码", before: "\(oldMask)", after: "\(newMask)")]
        )
        return ActionExecutionOutput(
            message: "已更新「\(routine.title)」的重复周期", diff: diff,
            undoClosure: { _ = DayBoardMutations.setWeekdayMask(routine, mask: oldMask) },
            redoClosure: { _ = DayBoardMutations.setWeekdayMask(routine, mask: newMask) }
        )
    }
}

@MainActor
private final class RoutineConvertTodoAction: BaseAction {
    init() {
        super.init(
            id: "routine.convertTodo", englishTitle: "Convert Routine to Todo", chineseTitle: "习惯转为待办",
            commandNames: ["to-todo", "转为待办"], iconName: "arrow.triangle.2.circlepath", category: .routine
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let modelContext = TaskMutationActions.resolveModelContext(from: context)
        let (routine, _) = try RoutineAndSubtaskActions.resolveRoutine(arguments: arguments, context: context, expectsValueArgument: false)
        let title = routine.title
        guard var currentTodoID = DayBoardMutations.convertRoutineToTodo(routine) else {
            throw ActionExecutionError.executionFailed("转为待办失败")
        }
        var currentRoutineID: UUID?
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: title,
            changes: [ActionFieldChange(field: "类型", before: "习惯", after: "待办")]
        )
        return ActionExecutionOutput(
            message: "已将习惯「\(title)」转为待办", diff: diff,
            undoClosure: {
                let tID = currentTodoID
                if let todo = (try? modelContext.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == tID })))?.first {
                    currentRoutineID = DayBoardMutations.convertTodoToRoutine(todo)
                }
            },
            redoClosure: {
                guard let rID = currentRoutineID,
                      let restoredRoutine = (try? modelContext.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.id == rID })))?.first,
                      let nextTodoID = DayBoardMutations.convertRoutineToTodo(restoredRoutine) else { return }
                currentTodoID = nextTodoID
            }
        )
    }
}

@MainActor
private final class RoutineTrashAction: BaseAction {
    init() {
        super.init(
            id: "routine.trash", englishTitle: "Move Routine to Trash", chineseTitle: "删除习惯",
            commandNames: ["rm-habit", "routine-rm", "删除习惯"], iconName: "trash", category: .routine
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let (routine, _) = try RoutineAndSubtaskActions.resolveRoutine(arguments: arguments, context: context, expectsValueArgument: false)
        guard DayBoardMutations.trashRoutine(routine) else { throw ActionExecutionError.executionFailed("删除习惯失败") }
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: routine.title,
            changes: [ActionFieldChange(field: "状态", before: "正常", after: "回收站")]
        )
        return ActionExecutionOutput(
            message: "已将习惯「\(routine.title)」移入回收站", diff: diff,
            undoClosure: { _ = DayBoardMutations.restoreRoutine(routine) },
            redoClosure: { _ = DayBoardMutations.trashRoutine(routine) }
        )
    }
}

@MainActor
private final class SubtaskAddAction: BaseAction {
    init() {
        super.init(
            id: "subtask.add", englishTitle: "Add Subtask", chineseTitle: "新增子任务",
            commandNames: ["sub", "subtask", "add-sub", "添加子任务", "新增子任务"], iconName: "list.bullet.indent", category: .subtask,
            parameters: [ActionParameterSpec(id: "title", englishName: "Subtask Title", chineseName: "子任务标题", required: true)]
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let modelContext = TaskMutationActions.resolveModelContext(from: context)
        let (todos, rest) = try TaskMutationActions.resolveTargetTodos(arguments: arguments, context: context, expectsValueArgument: true)
        guard let parentTodo = todos.first else { throw ActionExecutionError.targetNotFound("父待办") }
        let subTitle = (arguments.option("title") ?? rest.joined(separator: " ")).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subTitle.isEmpty else { throw ActionExecutionError.missingRequiredParameter("title") }
        let beforeIDs = Set(parentTodo.subtasks.map(\.id))
        guard DayBoardMutations.addSubtask(to: parentTodo, title: subTitle, context: modelContext),
              let created = parentTodo.subtasks.first(where: { !beforeIDs.contains($0.id) }) else {
            throw ActionExecutionError.executionFailed("新增子任务失败")
        }
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: parentTodo.title,
            changes: [ActionFieldChange(field: "新增子任务", before: "", after: created.title)]
        )
        return ActionExecutionOutput(
            message: "已为「\(parentTodo.title)」新增子任务：\(created.title)", diff: diff,
            undoClosure: { _ = DayBoardMutations.deleteSubtask(created) },
            redoClosure: { _ = DayBoardMutations.persist(context: modelContext) { created.deletedAt = nil } }
        )
    }
}

@MainActor
private final class SubtaskToggleAction: BaseAction {
    init() {
        super.init(
            id: "subtask.toggle", englishTitle: "Toggle Subtask Completion", chineseTitle: "切换子任务完成状态",
            commandNames: ["done-sub", "sub-done", "toggle-sub", "完成子任务"], iconName: "checkmark.square", category: .subtask
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let (subtask, _) = try RoutineAndSubtaskActions.resolveSubtask(arguments: arguments, context: context, expectsValueArgument: false)
        let wasDone = subtask.isDone
        guard DayBoardMutations.toggleSubtask(subtask) else { throw ActionExecutionError.executionFailed("切换子任务状态失败") }
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: subtask.title,
            changes: [ActionFieldChange(field: "状态", before: wasDone ? "已完成" : "未完成", after: subtask.isDone ? "已完成" : "未完成")]
        )
        return ActionExecutionOutput(
            message: "已切换子任务「\(subtask.title)」状态", diff: diff,
            undoClosure: { _ = DayBoardMutations.toggleSubtask(subtask) },
            redoClosure: { _ = DayBoardMutations.toggleSubtask(subtask) }
        )
    }
}

@MainActor
private final class SubtaskRenameAction: BaseAction {
    init() {
        super.init(
            id: "subtask.rename", englishTitle: "Rename Subtask", chineseTitle: "修改子任务标题",
            commandNames: ["rename-sub", "sub-rename", "子任务改名", "改子任务"], iconName: "pencil", category: .subtask,
            parameters: [ActionParameterSpec(id: "title", englishName: "New Title", chineseName: "新标题", required: true)]
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let (subtask, rest) = try RoutineAndSubtaskActions.resolveSubtask(arguments: arguments, context: context, expectsValueArgument: true)
        let newTitle = (arguments.option("title") ?? rest.joined(separator: " ")).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty else { throw ActionExecutionError.missingRequiredParameter("title") }
        let oldTitle = subtask.title
        guard DayBoardMutations.editSubtask(subtask, title: newTitle) else { throw ActionExecutionError.executionFailed("修改子任务标题失败") }
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: newTitle,
            changes: [ActionFieldChange(field: "子任务标题", before: oldTitle, after: newTitle)]
        )
        return ActionExecutionOutput(
            message: "子任务改名：\(oldTitle) → \(newTitle)", diff: diff,
            undoClosure: { _ = DayBoardMutations.editSubtask(subtask, title: oldTitle) },
            redoClosure: { _ = DayBoardMutations.editSubtask(subtask, title: newTitle) }
        )
    }
}

@MainActor
private final class SubtaskDeleteAction: BaseAction {
    init() {
        super.init(
            id: "subtask.delete", englishTitle: "Delete Subtask", chineseTitle: "删除子任务",
            commandNames: ["rm-sub", "sub-rm", "删除子任务"], iconName: "trash", category: .subtask
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let modelContext = TaskMutationActions.resolveModelContext(from: context)
        let (subtask, _) = try RoutineAndSubtaskActions.resolveSubtask(arguments: arguments, context: context, expectsValueArgument: false)
        guard DayBoardMutations.deleteSubtask(subtask) else { throw ActionExecutionError.executionFailed("删除子任务失败") }
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: subtask.title,
            changes: [ActionFieldChange(field: "状态", before: "正常", after: "已删除")]
        )
        return ActionExecutionOutput(
            message: "已删除子任务：\(subtask.title)", diff: diff,
            undoClosure: { _ = DayBoardMutations.persist(context: modelContext) { subtask.deletedAt = nil } },
            redoClosure: { _ = DayBoardMutations.deleteSubtask(subtask) }
        )
    }
}
