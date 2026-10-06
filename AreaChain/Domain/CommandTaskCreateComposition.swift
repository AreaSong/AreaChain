import Foundation

/// 取消与未指定是不同来源；发生冲突时不提供一个貌似已选定的值。
struct CommandTaskFieldResolution<Value: Equatable>: Equatable {
    enum Explicit: Equatable { case unspecified, set(Value), clear }
    enum Origin { case unspecified, titleSyntax, explicitSet, explicitClear }
    let syntax: Value?
    let explicit: Explicit
    let value: Value?
    let origins: [Origin]
    let hasConflict: Bool

    init(syntax: Value?, explicit: Explicit) {
        self.syntax = syntax
        self.explicit = explicit
        switch explicit {
        case .unspecified:
            value = syntax
            origins = syntax == nil ? [.unspecified] : [.titleSyntax]
            hasConflict = false
        case .set(let supplied):
            hasConflict = syntax.map { $0 != supplied } ?? false
            value = hasConflict ? nil : supplied
            origins = (syntax == nil ? [] : [.titleSyntax]) + [.explicitSet]
        case .clear:
            hasConflict = syntax != nil
            value = nil
            origins = (syntax == nil ? [] : [.titleSyntax]) + [.explicitClear]
        }
    }
}

struct CommandTaskCreateComposition: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let title: String
    let day: String
    let priority: CommandTaskFieldResolution<PriorityFlags>
    let reminder: CommandTaskFieldResolution<Int>
    let tags: CommandTaskTagPlan

    var priorityFlags: PriorityFlags? {
        priority.hasConflict ? nil : (priority.value ?? .init(isImportant: false, isUrgent: false))
    }

    /// 对照仓储 addTodo 的有效内容条件；本阶段 notes 恒为空，p4/clear 不算有效元数据。
    var hasEffectiveContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !tags.final.isEmpty
            || reminder.value != nil || priority.value?.isImportant == true || priority.value?.isUrgent == true
    }

    static func compose(title: String, day: String, arguments: [CommandArgument],
                        catalog: CommandTaskTagCatalog) -> Self {
        let parsed = NaturalLanguageParser.parseTaskCapture(title.trimmingCharacters(in: .whitespacesAndNewlines))
        let priority = arguments.first { $0.parameter == .priority }
        let reminder = arguments.first { $0.parameter == .time }
        return .init(title: parsed.cleanTitle, day: day,
                     priority: .init(syntax: parsed.hasPriorityToken
                        ? PriorityFlags(isImportant: parsed.isImportant, isUrgent: parsed.isUrgent) : nil,
                                     explicit: explicitPriority(priority)),
                     reminder: .init(syntax: parsed.remindMinutes, explicit: explicitReminder(reminder)),
                     tags: CommandTaskTagPlanning.compose(title: title, argument: arguments.first { $0.parameter == .tags },
                                                          catalog: catalog))
    }

    private static func explicitPriority(_ argument: CommandArgument?) -> CommandTaskFieldResolution<PriorityFlags>.Explicit {
        if argument?.operation == .clear { return .clear }
        if argument?.operation == .assign, case .choice(let token) = argument?.value,
           let flags = PriorityToken.flags(in: "!" + token) { return .set(flags) }
        return .unspecified
    }

    private static func explicitReminder(_ argument: CommandArgument?) -> CommandTaskFieldResolution<Int>.Explicit {
        if argument?.operation == .cancelReminder { return .clear }
        if argument?.operation == .setReminder, case .time(let minutes) = argument?.value { return .set(minutes) }
        return .unspecified
    }

    var description: String { "CommandTaskCreateComposition(redacted)" }
    var debugDescription: String { description }
}
