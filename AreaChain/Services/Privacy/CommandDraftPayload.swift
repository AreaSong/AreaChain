import Foundation

struct CommandDraftContents: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    var arguments: [CommandArgument]
    var baseline: CommandDraftBaseline
    var editing: [CommandDraftEditingState] = []
    var description: String { "CommandDraftContents(redacted)" }
    var debugDescription: String { description }
}

/// 命令专用 v2（解码兼容 v1）；不改变 DiaryDraftText，也不编码宿主、闭包、认证或原生能力。
struct CommandDraftPayload: Codable, CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "CommandDraftPayload(redacted)" }
    var debugDescription: String { description }
    let format: Int
    let payloadID: UUID
    let revision: UUID
    let draftID: UUID
    let commandID: String
    let arguments: [Argument]
    let baseline: [Original]
    let editing: [CommandDraftEditingState]

    struct Object: Codable {
        let type: String
        let id: UUID
        let dayKey: String?
        init(_ object: CommandObjectReference) { type = object.type.rawValue; id = object.id; dayKey = object.dayKey }
        func decoded() throws -> CommandObjectReference {
            guard let type = CommandObjectType(rawValue: type) else { throw CommandDraftProtectionError.invalidPayload }
            return .init(type: type, id: id, dayKey: dayKey)
        }
    }

    enum Value: Codable {
        case shortText(String), longText(String), choice(String), boolean(Bool), number(Double)
        case day(String), time(Int), weekdays(Int), tags([UUID]), object(Object), objects([Object])
        init(_ value: CommandValue) throws {
            switch value {
            case .shortText(let x): self = .shortText(x)
            case .longText(let x): self = .longText(x)
            case .choice(let x): self = .choice(x)
            case .boolean(let x): self = .boolean(x)
            case .number(let x): self = .number(x)
            case .day(let x): self = .day(x)
            case .time(let x): self = .time(x)
            case .weekdays(let x): self = .weekdays(x)
            case .tags(let x): self = .tags(x)
            case .object(let x): self = .object(.init(x))
            case .objects(let x): self = .objects(x.map(Object.init))
            case .nativeSelection, .shortcut: throw CommandDraftProtectionError.unsupported
            }
        }
        func decoded() throws -> CommandValue {
            switch self {
            case .shortText(let x): return .shortText(x)
            case .longText(let x): return .longText(x)
            case .choice(let x): return .choice(x)
            case .boolean(let x): return .boolean(x)
            case .number(let x): return .number(x)
            case .day(let x): return .day(x)
            case .time(let x): return .time(x)
            case .weekdays(let x): return .weekdays(x)
            case .tags(let x): return .tags(x)
            case .object(let x): return .object(try x.decoded())
            case .objects(let x): return .objects(try x.map { try $0.decoded() })
            }
        }
    }
    struct Argument: Codable {
        let parameter: String
        let operation: String
        let value: Value?
    }
    struct Original: Codable {
        let object: Object?
        let parameter: String
        let kind: String
        let value: Value?
    }

    init(contents: CommandDraftContents, reference: CommandProtectedReference, draft: CommandDraft) throws {
        format = 2; payloadID = reference.payloadID; revision = reference.revision
        draftID = draft.id; commandID = draft.commandID.rawValue
        guard contents.baseline.isReadable else { throw CommandDraftProtectionError.invalidPayload }
        arguments = try contents.arguments.map {
            Argument(parameter: $0.parameter.rawValue, operation: $0.operation.rawValue, value: try $0.value.map(Value.init))
        }
        baseline = try contents.baseline.values.map { field, original in
            let object: Object?
            if case .object(let ref) = field.subject { object = .init(ref) } else { object = nil }
            switch original {
            case .absent: return Original(object: object, parameter: field.parameter.rawValue, kind: "absent", value: nil)
            case .mixed: return Original(object: object, parameter: field.parameter.rawValue, kind: "mixed", value: nil)
            case .uniform(let value):
                return Original(object: object, parameter: field.parameter.rawValue, kind: "uniform", value: try .init(value))
            }
        }
        editing = contents.editing
        _ = try decoded()
    }

    func decoded() throws -> CommandDraftContents {
        guard format == 1 || format == 2 else { throw CommandDraftProtectionError.invalidPayload }
        var values: [CommandDraftBaseline.Field: CommandOriginalValue] = [:]
        for original in baseline {
            guard let parameter = CommandParameterID(rawValue: original.parameter) else { throw CommandDraftProtectionError.invalidPayload }
            let subject: CommandDraftBaseline.Subject = try original.object.map { .object(try $0.decoded()) } ?? .ambient
            let field = CommandDraftBaseline.Field(subject: subject, parameter: parameter)
            guard values[field] == nil else { throw CommandDraftProtectionError.invalidPayload }
            switch (original.kind, original.value) {
            case ("absent", nil): values[field] = .absent
            case ("mixed", nil): values[field] = .mixed
            case ("uniform", .some(let value)): values[field] = .uniform(try value.decoded())
            default: throw CommandDraftProtectionError.invalidPayload
            }
        }
        let arguments = try arguments.map { argument -> CommandArgument in
            guard let parameter = CommandParameterID(rawValue: argument.parameter), parameter != .target,
                  let operation = CommandFieldOperation(rawValue: argument.operation) else { throw CommandDraftProtectionError.invalidPayload }
            return .init(parameter: parameter, operation: operation, value: try argument.value?.decoded())
        }
        guard Set(arguments.map(\.parameter)).count == arguments.count,
              Set(editing.map(\.parameter)).count == editing.count else { throw CommandDraftProtectionError.invalidPayload }
        for state in editing {
            do { try state.validate() } catch { throw CommandDraftProtectionError.invalidPayload }
            if format == 1, state.composition != nil { throw CommandDraftProtectionError.invalidPayload }
            if state.composition != nil {
                guard arguments.first(where: { $0.parameter.rawValue == state.parameter })?.value == .longText(state.confirmedText)
                else { throw CommandDraftProtectionError.invalidPayload }
            }
        }
        return .init(arguments: arguments, baseline: .init(values), editing: editing)
    }
}
