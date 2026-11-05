import Foundation
import SwiftData

/// 日历、四象限与甘特图规划面板的统一动作集合。
@MainActor
enum PlanningBoardActions {
    static func all() -> [BaseAction] {
        [
            CalendarLayoutAction(),
            CalendarDayStepAction(mode: .today),
            CalendarDayStepAction(mode: .previous),
            CalendarDayStepAction(mode: .next),
            CalendarSelectDayAction(),
            QuadrantMoveAction(),
            GanttShiftAction(),
        ]
    }
}

@MainActor
private final class CalendarLayoutAction: BaseAction {
    init() {
        super.init(
            id: "cal.layout",
            englishTitle: "Toggle Calendar Layout",
            chineseTitle: "切换月历布局",
            commandNames: ["cal-layout", "月历布局"],
            iconName: "rectangle.split.2x1",
            category: .planning,
            parameters: [
                ActionParameterSpec(
                    id: "mode", englishName: "Layout Mode", chineseName: "布局模式",
                    required: false, allowedValues: ["split", "full"]
                ),
            ]
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let prefs = AppPreferences.shared
        let oldMode = prefs.calendarMonthLayoutMode
        let nextMode: CalendarMonthLayoutMode
        if let raw = arguments.value(for: "mode", index: 0)?.lowercased(), !raw.isEmpty {
            switch raw {
            case "split", "分栏": nextMode = .split
            case "full", "平铺", "全月": nextMode = .full
            default:
                throw ActionExecutionError.invalidParameterValue(parameter: "mode", value: raw)
            }
        } else {
            nextMode = (oldMode == .split) ? .full : .split
        }
        prefs.calendarMonthLayoutMode = nextMode
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: "月历布局",
            changes: [ActionFieldChange(field: "模式", before: oldMode.rawValue, after: nextMode.rawValue)]
        )
        return ActionExecutionOutput(
            message: "月历布局已切换为：\(nextMode.rawValue)",
            diff: diff,
            undoClosure: { AppPreferences.shared.calendarMonthLayoutMode = oldMode },
            redoClosure: { AppPreferences.shared.calendarMonthLayoutMode = nextMode }
        )
    }
}

@MainActor
private final class CalendarDayStepAction: BaseAction {
    enum StepMode {
        case today
        case previous
        case next
    }

    private let mode: StepMode

    init(mode: StepMode) {
        self.mode = mode
        switch mode {
        case .today:
            super.init(
                id: "cal.today",
                englishTitle: "Jump to Today",
                chineseTitle: "回到今天",
                commandNames: ["cal-today", "回到今天"],
                iconName: "calendar.circle",
                category: .planning,
                recordsUndo: false
            )
        case .previous:
            super.init(
                id: "cal.prev",
                englishTitle: "Previous Day",
                chineseTitle: "上一天",
                commandNames: ["cal-prev", "上一天"],
                iconName: "chevron.left",
                category: .planning,
                recordsUndo: false
            )
        case .next:
            super.init(
                id: "cal.next",
                englishTitle: "Next Day",
                chineseTitle: "下一天",
                commandNames: ["cal-next", "下一天"],
                iconName: "chevron.right",
                category: .planning,
                recordsUndo: false
            )
        }
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let nav = WorkspaceNavigation.shared
        let nextDay: String
        switch mode {
        case .today:
            nextDay = DayClock.shared.todayKey
        case .previous:
            nextDay = DayKey.shifted(nav.inspectingDayKey, by: -1)
        case .next:
            nextDay = DayKey.shifted(nav.inspectingDayKey, by: 1)
        }
        nav.inspectingDayKey = nextDay
        return ActionExecutionOutput(message: "当前检查日期：\(nextDay)")
    }
}

@MainActor
private final class CalendarSelectDayAction: BaseAction {
    init() {
        super.init(
            id: "cal.selectDay",
            englishTitle: "Select Calendar Day",
            chineseTitle: "跳转到指定日期",
            commandNames: ["day", "跳转到日期"],
            iconName: "calendar",
            category: .planning,
            parameters: [
                ActionParameterSpec(id: "date", englishName: "Date", chineseName: "日期", required: true),
            ],
            recordsUndo: false
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let rawToken = arguments.value(for: "date", index: 0) ?? ""
        let base = WorkspaceNavigation.shared.inspectingDayKey
        guard let targetDay = TaskMutationActions.resolveDayKey(rawToken, baseDayKey: base) else {
            throw ActionExecutionError.invalidParameterValue(parameter: "date", value: rawToken)
        }
        WorkspaceNavigation.shared.inspectingDayKey = targetDay
        return ActionExecutionOutput(message: "已跳转到日期：\(targetDay)")
    }
}

@MainActor
private final class QuadrantMoveAction: BaseAction {
    init() {
        super.init(
            id: "quadrant.move",
            englishTitle: "Move to Quadrant",
            chineseTitle: "移入四象限",
            commandNames: ["quad-move", "移入象限"],
            iconName: "square.grid.2x2",
            category: .planning,
            parameters: [
                ActionParameterSpec(
                    id: "quadrant", englishName: "Quadrant", chineseName: "目标象限",
                    required: true, allowedValues: ["p1", "p2", "p3", "p4"]
                ),
            ]
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let (targets, rest) = try TaskMutationActions.resolveTargetTodos(
            arguments: arguments, context: context, expectsValueArgument: true
        )
        guard let todo = targets.first else { throw ActionExecutionError.targetNotFound("待办") }
        let rawSlot = arguments.option("quadrant") ?? rest.first ?? ""
        guard let newSlot = TaskMutationActions.resolveSlot(rawSlot, inlineNLP: arguments.inlineNLP) else {
            throw ActionExecutionError.invalidParameterValue(parameter: "quadrant", value: rawSlot)
        }
        let oldSlot = QuadrantSlot.of(important: todo.isImportant, urgent: todo.isUrgent)
        guard DayBoardMutations.applyQuadrant(newSlot, to: todo) else {
            throw ActionExecutionError.executionFailed("移入象限失败")
        }
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: todo.title,
            changes: [ActionFieldChange(field: "象限", before: oldSlot.badgeText, after: newSlot.badgeText)]
        )
        return ActionExecutionOutput(
            message: "已将「\(todo.title)」移入 \(newSlot.badgeText) 象限",
            diff: diff,
            undoClosure: { _ = DayBoardMutations.applyQuadrant(oldSlot, to: todo) },
            redoClosure: { _ = DayBoardMutations.applyQuadrant(newSlot, to: todo) }
        )
    }
}

@MainActor
private final class GanttShiftAction: BaseAction {
    init() {
        super.init(
            id: "gantt.shift",
            englishTitle: "Shift Task on Gantt",
            chineseTitle: "甘特图日期顺延",
            commandNames: ["gantt-shift", "甘特顺延"],
            iconName: "chart.bar.xaxis",
            category: .planning,
            parameters: [
                ActionParameterSpec(id: "days", englishName: "Offset Days", chineseName: "偏移天数", required: true),
            ]
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let (targets, rest) = try TaskMutationActions.resolveTargetTodos(
            arguments: arguments, context: context, expectsValueArgument: true
        )
        guard let todo = targets.first else { throw ActionExecutionError.targetNotFound("待办") }
        var rawDays = (arguments.option("days") ?? rest.first ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if rawDays.lowercased().hasSuffix("d") || rawDays.hasSuffix("天") {
            rawDays.removeLast()
        }
        guard let offset = Int(rawDays), offset != 0 else {
            throw ActionExecutionError.invalidParameterValue(parameter: "days", value: rawDays)
        }
        let oldDay = todo.dayKey
        let newDay = DayKey.shifted(oldDay, by: offset)
        guard DayBoardMutations.moveTodo(todo, to: newDay) else {
            throw ActionExecutionError.executionFailed("甘特图顺延失败")
        }
        let diff = ActionDiff(
            actionID: id, actionTitle: chineseTitle, targetTitle: todo.title,
            changes: [ActionFieldChange(field: "日期", before: oldDay, after: newDay)]
        )
        return ActionExecutionOutput(
            message: "已将「\(todo.title)」日期偏移 \(offset > 0 ? "+\(offset)" : "\(offset)") 天至 \(newDay)",
            diff: diff,
            undoClosure: { _ = DayBoardMutations.moveTodo(todo, to: oldDay) },
            redoClosure: { _ = DayBoardMutations.moveTodo(todo, to: newDay) }
        )
    }
}
