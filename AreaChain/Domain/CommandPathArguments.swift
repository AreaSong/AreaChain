import Foundation

/// 只接受无需对象、正文或原生交互即可唯一确定的单个参数。
enum CommandPathArguments {
    static func parameter(for command: CommandDescriptor) -> CommandParameter? {
        guard command.parameters.count == 1, !command.interactions.contains(.secureInput),
              let parameter = command.parameters.first,
              parameter.defaultOperation.requiresValue else { return nil }
        switch parameter.type {
        case .choice, .boolean, .number, .day, .time: return parameter
        default: return nil
        }
    }

    static func values(_ text: String, parameter: CommandParameter) -> [CommandValue] {
        switch parameter.type {
        case .choice(let choices):
            return choices.filter { choice in
                ["en", "zh-Hans"].contains { choice.matches(text, locale: Locale(identifier: $0)) }
            }.map { .choice($0.value) }
        case .boolean:
            switch CommandPathText.folded(text) {
            case "true": return [.boolean(true)]
            case "false": return [.boolean(false)]
            default: return []
            }
        case .number:
            return Double(text).map { [.number($0)] } ?? []
        case .day:
            return [.day(text)]
        case .time:
            let parts = text.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2, parts.allSatisfy({ $0.count == 2 && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
                  let hour = Int(parts[0]), let minute = Int(parts[1]),
                  (0..<24).contains(hour), (0..<60).contains(minute) else { return [] }
            return [.time(hour * 60 + minute)]
        default: return []
        }
    }

    static func argument(_ value: CommandValue, parameter: CommandParameter) -> CommandArgument {
        CommandArgument(parameter: parameter.id, operation: parameter.defaultOperation, value: value)
    }

    static func options(for parameter: CommandParameter, locale: Locale) -> [(String, String, [String], CommandValue)] {
        switch parameter.type {
        case .choice(let choices):
            return choices.map { choice in
                let names = ["en", "zh-Hans"].flatMap { language -> [String] in
                    let locale = Locale(identifier: language)
                    return [L10n.format(choice.nameKey, locale: locale)]
                        + L10n.format(choice.aliasKey, locale: locale).split(separator: "|").map(String.init)
                }
                return (choice.value, L10n.format(choice.nameKey, locale: locale), names, .choice(choice.value))
            }
        case .boolean: return [("true", "true", [], .boolean(true)), ("false", "false", [], .boolean(false))]
        default: return []
        }
    }
}
