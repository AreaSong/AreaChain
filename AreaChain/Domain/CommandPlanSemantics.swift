import Foundation

enum CommandMergeConflict: Equatable {
    case order, differentBusinessField, targets, baseline, sequentialOperation, dependency, atomicGroup, invalidArguments
}

/// 窄白名单只声明普通赋值字段，不把所有同名参数都推断成同一业务字段。
enum CommandPlanSemantics {
    static func isAtomicSetting(_ id: CommandID) -> Bool {
        ["setting.language", "setting.appearance", "setting.truncation", "setting.captureSource"].contains(id.rawValue)
    }

    private static func assignmentField(_ id: CommandID) -> CommandParameterID? {
        switch id.rawValue {
        case "setting.language", "setting.appearance", "setting.truncation": .value
        case "setting.captureSource": .enabled
        // 标题入口可能联动自然语言/标签解析，未核实前不当作单字段赋值合并。
        case "todo.move": .day
        case "todo.priority", "routine.priority": .priority
        default: nil
        }
    }

    static func mergeConflict(_ items: [CommandPlanItem], earlier: Int, later: Int) -> CommandMergeConflict? {
        guard later == earlier + 1 else { return .order }
        let first = items[earlier], last = items[later]
        guard first.draft.commandID == last.draft.commandID else { return .differentBusinessField }
        guard let field = assignmentField(first.draft.commandID),
              first.draft.arguments.count == 1, last.draft.arguments.count == 1,
              first.draft.arguments[0].parameter == field, last.draft.arguments[0].parameter == field,
              first.draft.arguments[0].operation == .assign, last.draft.arguments[0].operation == .assign else {
            return .sequentialOperation
        }
        guard first.draft.check().staticallyValid, last.draft.check().staticallyValid else { return .invalidArguments }
        guard first.draft.targets == last.draft.targets else { return .targets }
        guard first.atomicGroup == nil, last.atomicGroup == nil else { return .atomicGroup }
        let pair: Set<UUID> = [first.id, last.id]
        guard first.links.dependencies.isEmpty, last.links.dependencies.isEmpty,
              !items.contains(where: { !$0.links.dependencies.isDisjoint(with: pair) }) else { return .dependency }
        guard first.draft.baseline == last.draft.baseline,
              let original = first.draft.baseline.original(field, targets: first.draft.targets),
              validOriginal(original, field: field, command: first.draft.commandID) else { return .baseline }
        return nil
    }

    private static func validOriginal(_ original: CommandOriginalValue, field: CommandParameterID, command: CommandID) -> Bool {
        switch original {
        case .absent: return true
        case .mixed: return false
        case .uniform(let value):
            guard let definition = CommandCatalog.standard.command(id: command)?.parameters.first(where: { $0.id == field }) else { return false }
            return CommandArgumentValidation.accepts(value, type: definition.type)
        }
    }
}
