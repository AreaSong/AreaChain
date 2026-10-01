import Foundation

enum CommandParameterID: String, CaseIterable, Sendable {
    case target, parent, title, notes, body, tags, name, color, day, time, priority, weekdays
    case enabled, value, query, mode, kind, status, routineStatus, source, dateFilter, reminderFilter
    case file, shortcut, chord, position, offset, period, destination, method
    case duration, pattern, bundleID, pasteboardType, letter, section, example

    var nameKey: String { "command.parameter.\(rawValue)" }
}

struct CommandChoice: Equatable, Sendable {
    let value: String
    var nameKey: String {
        if ["system", "chinese", "english"].contains(value) { return "language.\(value)" }
        if TagColorToken(rawValue: value) != nil { return "tags.color.\(value)" }
        if let shortcut = ShortcutAction(rawValue: value) { return shortcut.titleKey }
        return "command.choice.\(value)"
    }
    var aliasKey: String { "command.choice.\(value).aliases" }

    func matches(_ text: String, locale: Locale) -> Bool {
        let names = [value, L10n.format(nameKey, locale: locale)]
            + L10n.format(aliasKey, locale: locale).split(separator: "|").map(String.init)
        return names.contains { $0.compare(text, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }
}

enum CommandFileKind: Equatable, Sendable {
    case image, jsonSnapshot, encryptedBackup

    // 与 AttachmentPicker 的现有单选图片范围一致，不声明任意附件支持。
    var imageFormats: [String] { self == .image ? ["png", "jpeg", "heic", "gif", "tiff", "webp"] : [] }
    var allowsMultipleSelection: Bool { false }
}

enum CommandParameterType: Equatable, Sendable {
    case shortText, longText
    case choice([CommandChoice])
    case boolean
    case number(ClosedRange<Double>, integer: Bool)
    case day, time, weekdays, tags
    case object(Set<CommandObjectType>)
    case objects(Set<CommandObjectType>)
    case nativeFile(CommandFileKind), nativeShortcut
}

/// 值不含密码、密钥、原生文件路径或认证结果；安全交互只能存在于描述符要求中。
enum CommandValue: Equatable, Sendable {
    case shortText(String), longText(String), choice(String), boolean(Bool), number(Double)
    case day(String), time(Int), weekdays(Int), tags([UUID])
    case object(CommandObjectReference), objects([CommandObjectReference])
    case nativeSelection(UUID), shortcut(ShortcutChord)
}

/// routineOccurrence 的 id 是习惯定义 ID，dayKey 构成业务身份；不解析真实记录。
struct CommandObjectReference: Equatable, Hashable, Sendable {
    let type: CommandObjectType
    let id: UUID
    var dayKey: String?
}

enum CommandFieldOperation: String, CaseIterable, Sendable {
    case unspecified, assign, clear, replace, append, add, remove, replaceAll, setReminder, cancelReminder

    var requiresValue: Bool {
        ![.unspecified, .clear, .cancelReminder].contains(self)
    }
}

struct CommandArgument: Equatable, Sendable {
    let parameter: CommandParameterID
    var operation: CommandFieldOperation
    var value: CommandValue?
}

/// 多对象原值不同与空值是两种事实；这不是冲突基线或草稿状态机。
enum CommandOriginalValue: Equatable, Sendable {
    case absent, uniform(CommandValue), mixed
}

struct CommandParameter: Equatable, Sendable {
    let id: CommandParameterID
    var type: CommandParameterType
    var required = true
    var defaultValue: CommandValue?
    var operations: Set<CommandFieldOperation> = [.assign]
    var defaultOperation: CommandFieldOperation = .assign
    var allowsEmpty = false

    func optional() -> Self {
        var copy = self
        copy.required = false
        return copy
    }

    func defaulting(to value: CommandValue) -> Self {
        var copy = self
        copy.defaultValue = value
        return copy
    }

    func editing(_ operations: Set<CommandFieldOperation>, default operation: CommandFieldOperation) -> Self {
        var copy = self
        copy.operations = operations
        copy.defaultOperation = operation
        return copy
    }
}
