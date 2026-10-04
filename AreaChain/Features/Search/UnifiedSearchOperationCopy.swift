import Foundation

/// 只投影已有草稿与目录，不把参数默认值冒充应用当前值。
enum UnifiedSearchOperationCopy {
    static func summary(_ command: CommandDescriptor, draft: CommandDraft, locale: Locale, calendar: Calendar) -> String {
        command.parameters.compactMap { parameter in
            guard let argument = draft.arguments.first(where: { $0.parameter == parameter.id }) else { return nil }
            let value = argument.operation.requiresValue
                ? self.value(argument.value, locale: locale, calendar: calendar)
                : L10n.format("unified.operation.mode." + argument.operation.rawValue, locale: locale)
            return L10n.format(parameter.id.nameKey, locale: locale) + ": " + value
        }.joined(separator: " · ")
    }

    static func raw(_ value: CommandValue?) -> String {
        switch value {
        case .shortText(let text): text
        case .choice(let value): value
        case .boolean(let flag): flag ? "true" : "false"
        case .number(let number): number.formatted(.number.grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
        case .day(let key): key
        case .time(let minute): String(format: "%02d:%02d", minute / 60, minute % 60)
        default: ""
        }
    }

    static func value(_ value: CommandValue?, locale: Locale, calendar: Calendar) -> String {
        switch value {
        case .choice(let token): L10n.format(CommandChoice(value: token).nameKey, locale: locale)
        case .boolean(let flag): L10n.format(flag ? "unified.operation.on" : "unified.operation.off", locale: locale)
        case .weekdays(let mask): WeekdayMask.orderedWeekdays(calendar: calendar)
            .filter { WeekdayMask.containsSelection(mask, weekday: $0) }
            .map { WeekdayMask.veryShortSymbol($0, locale: locale, calendar: calendar) }.joined(separator: " · ")
        case .number(let number): number.formatted(.number.locale(locale))
        case .object: L10n.format("unified.objects.count", locale: locale, 1)
        case .objects(let objects): L10n.format("unified.objects.count", locale: locale, objects.count)
        case .longText, .tags, .nativeSelection, .shortcut:
            L10n.format("unified.operation.later", locale: locale)
        case nil: L10n.format("unified.operation.unfilled", locale: locale)
        default: raw(value)
        }
    }

    static func original(_ value: CommandOriginalValue?, locale: Locale, calendar: Calendar) -> String {
        switch value {
        case .uniform(let value): self.value(value, locale: locale, calendar: calendar)
        case .absent: L10n.format("unified.operation.absent", locale: locale)
        case .mixed: L10n.format("unified.operation.mixed", locale: locale)
        case nil: L10n.format("unified.operation.unread", locale: locale)
        }
    }

    static func requirement(_ parameter: CommandParameter, command: CommandDescriptor) -> String {
        if !command.interactions.isDisjoint(with: [.secureInput, .authentication, .freshAuthentication]) {
            return "unified.operation.secure"
        }
        switch parameter.type {
        case .longText: return "unified.operation.longText"
        case .object, .objects: return "unified.operation.objects"
        case .tags: return "unified.operation.tags"
        case .nativeFile: return "unified.operation.file"
        case .nativeShortcut: return "unified.operation.shortcut"
        default: return "unified.operation.later"
        }
    }

    static func issue(_ issue: CommandArgumentIssue, locale: Locale) -> String {
        let parameter: CommandParameterID
        let key: String
        switch issue {
        case .missing(let id): parameter = id; key = "unified.operation.missing"
        case .invalidValue(let id): parameter = id; key = "unified.operation.invalid"
        case .invalidOperation(let id), .unexpectedValue(let id): parameter = id; key = "unified.operation.invalidOperation"
        case .unknown(let id), .duplicate(let id): parameter = id; key = "unified.operation.invalid"
        case .protectedContent: return L10n.format("unified.operation.protected", locale: locale)
        case .unavailable: return L10n.format("unified.operation.unavailable", locale: locale)
        case .incompatibleTargets: return L10n.format("unified.operation.targetIssue", locale: locale)
        }
        return L10n.format(parameter.nameKey, locale: locale) + " · " + L10n.format(key, locale: locale)
    }
}
