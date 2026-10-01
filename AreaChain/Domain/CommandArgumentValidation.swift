import Foundation

enum CommandArgumentIssue: Equatable {
    case missing(CommandParameterID), duplicate(CommandParameterID), unknown(CommandParameterID)
    case invalidOperation(CommandParameterID), invalidValue(CommandParameterID), unexpectedValue(CommandParameterID)
    case incompatibleTargets, unavailable
}

/// 只校验参数的静态形状与已知边界；成功不是权限、存活、业务校验或可执行证明。
enum CommandArgumentValidation {
    static func issues(
        for arguments: [CommandArgument], command: CommandDescriptor
    ) -> [CommandArgumentIssue] {
        var issues: [CommandArgumentIssue] = []
        var seen: Set<CommandParameterID> = []
        for argument in arguments {
            guard seen.insert(argument.parameter).inserted else {
                issues.append(.duplicate(argument.parameter))
                continue
            }
            guard let parameter = command.parameters.first(where: { $0.id == argument.parameter }) else {
                issues.append(.unknown(argument.parameter))
                continue
            }
            issues += validate(argument, against: parameter)
        }
        for parameter in command.parameters where !seen.contains(parameter.id) {
            if parameter.required && parameter.defaultValue == nil { issues.append(.missing(parameter.id)) }
        }
        if command.availability != .declared { issues.append(.unavailable) }
        issues += combinationIssues(arguments, command: command)
        return issues
    }

    private static func validate(_ argument: CommandArgument, against parameter: CommandParameter) -> [CommandArgumentIssue] {
        let id = parameter.id
        if argument.operation == .unspecified {
            if argument.value != nil { return [.unexpectedValue(id)] }
            return parameter.required && parameter.defaultValue == nil ? [.missing(id)] : []
        }
        guard parameter.operations.contains(argument.operation) else { return [.invalidOperation(id)] }
        if !argument.operation.requiresValue {
            guard argument.value == nil else { return [.unexpectedValue(id)] }
            if argument.operation == .clear, [.longText, .shortText].contains(parameter.type), !parameter.allowsEmpty {
                return [.invalidValue(id)]
            }
            return []
        }
        guard let value = argument.value else { return [.missing(id)] }
        return accepts(value, type: parameter.type) ? [] : [.invalidValue(id)]
    }

    static func accepts(_ value: CommandValue, type: CommandParameterType) -> Bool {
        switch (type, value) {
        case (.shortText, .shortText(let text)):
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !text.contains(where: \.isNewline)
        case (.longText, .longText(let text)):
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case (.choice(let choices), .choice(let value)): return choices.contains { $0.value == value }
        case (.boolean, .boolean): return true
        case (.number(let range, let integer), .number(let number)):
            return number.isFinite && range.contains(number) && (!integer || Int(exactly: number) != nil)
        case (.day, .day(let key)): return isCanonicalDay(key)
        case (.time, .time(let minutes)): return RemindMinutes.clamped(minutes) != nil
        case (.weekdays, .weekdays(let mask)): return mask > 0 && mask & ~WeekdayMask.all == 0
        case (.tags, .tags(let ids)): return !ids.isEmpty && Set(ids).count == ids.count
        case (.object(let types), .object(let reference)): return valid(reference, types: types)
        case (.objects(let types), .objects(let references)):
            return !references.isEmpty && Set(references).count == references.count
                && references.allSatisfy { valid($0, types: types) }
        case (.nativeFile, .nativeSelection): return true
        case (.nativeShortcut, .shortcut(let chord)): return chord.isBindable
        default: return false
        }
    }

    static func isCanonicalDay(_ key: String) -> Bool {
        // DayKey.date 接受日历归一化；输入契约额外拒绝 2 月 30 日等回卷日期。
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard key.count == 10, let date = DayKey.date(from: key, calendar: calendar) else { return false }
        return DayKey.from(date, calendar: calendar) == key
    }

    private static func valid(_ reference: CommandObjectReference, types: Set<CommandObjectType>) -> Bool {
        guard types.contains(reference.type) else { return false }
        if reference.type == .routineOccurrence {
            return reference.dayKey.map(isCanonicalDay) == true
        }
        return reference.dayKey == nil
    }

    private static func combinationIssues(_ arguments: [CommandArgument], command: CommandDescriptor) -> [CommandArgumentIssue] {
        let values = arguments.filter { $0.operation != .unspecified }
        if command.id.rawValue == "tag.merge",
           case .object(let destination) = values.first(where: { $0.parameter == .destination })?.value,
           case .objects(let sources) = values.first(where: { $0.parameter == .target })?.value,
           sources.contains(destination) { return [.incompatibleTargets] }
        if command.id.rawValue == "gantt.select",
           case .choice("single") = values.first(where: { $0.parameter == .mode })?.value,
           case .objects(let references) = values.first(where: { $0.parameter == .target })?.value,
           references.count != 1 { return [.incompatibleTargets] }
        return []
    }
}
