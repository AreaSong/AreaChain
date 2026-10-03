import Foundation

/// 显式选中的普通字段上下文；只生成补全意图，既不解析整条查询也不持有参数值。
struct UnifiedSearchParameterContext: Equatable {
    let command: CommandDescriptor
    let parameter: CommandParameter
    let operation: CommandFieldOperation

    func completion(_ text: String, locale: Locale) -> CommandPathResult {
        var result = CommandPathResult(input: text, state: .incompleteArguments, command: command)
        guard operation.requiresValue, Self.supports(parameter, command: command) else { return result }
        let options = CommandPathArguments.options(for: parameter, locale: locale)
        let folded = CommandPathText.folded(text)
        result.candidates = options.filter { token, title, aliases, _ in
            text.isEmpty || ([token, title] + aliases).contains { CommandPathText.folded($0).hasPrefix(folded) }
        }.map { token, title, _, value in
            let name: String
            if case .boolean(let enabled) = value {
                name = L10n.format(enabled ? "unified.operation.on" : "unified.operation.off", locale: locale)
            } else { name = title }
            return .init(id: command.id.rawValue + "." + parameter.id.rawValue + "." + token,
                command: command, title: name, summary: L10n.format(parameter.id.nameKey, locale: locale),
                replacementRange: NSRange(location: 0, length: text.utf16.count), insertText: token,
                intent: .setArgument(command.id, .init(parameter: parameter.id, operation: operation, value: value)),
                match: text == token ? .exactArgument : .argumentPrefix)
        }
        return result
    }

    static func supports(_ parameter: CommandParameter, command: CommandDescriptor) -> Bool {
        guard !command.interactions.contains(.secureInput), !command.interactions.contains(.authentication),
              !command.interactions.contains(.freshAuthentication), parameter.id != .target else { return false }
        switch parameter.type {
        case .choice, .boolean, .number, .day, .time, .weekdays, .shortText: return true
        default: return false
        }
    }

    func value(_ text: String) -> CommandValue? {
        let values: [CommandValue]
        if parameter.type == .shortText { values = [.shortText(text)] }
        else { values = CommandPathArguments.values(text, parameter: parameter) }
        guard values.count == 1, let value = values.first,
              CommandArgumentValidation.accepts(value, type: parameter.type) else { return nil }
        return value
    }
}
