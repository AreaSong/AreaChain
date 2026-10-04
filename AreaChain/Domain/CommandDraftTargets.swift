import Foundation

/// 选择来源只描述用户已接受的固定快照，不持有查询或提供者。
struct CommandDraftTargets: Equatable {
    enum Selection: Equatable { case none, single, selected, allResults }
    let selection: Selection
    let objects: [CommandObjectReference]

    init(_ selection: Selection, objects: [CommandObjectReference] = []) {
        self.selection = selection
        var seen: Set<CommandObjectReference> = []
        self.objects = objects.filter { seen.insert($0).inserted }
    }

    static let none = Self(.none)

    func issues(for command: CommandDescriptor) -> [CommandDraftTargetIssue] {
        var issues: [CommandDraftTargetIssue] = []
        if selection == .none && !objects.isEmpty || selection == .single && objects.count != 1 {
            issues.append(.invalidSelection)
        }
        if selection != .none && objects.isEmpty { issues.append(.emptySelection) }
        if command.targetTypes.isEmpty {
            if selection != .none || !objects.isEmpty { issues.append(.notApplicable) }
        } else if objects.isEmpty {
            issues.append(.missingTargets)
        }
        if objects.contains(where: { !CommandArgumentValidation.accepts(.object($0), type: .object([ $0.type ])) }) {
            issues.append(.invalidIdentity)
        }
        if objects.contains(where: { !command.targetTypes.contains($0.type) }) {
            issues.append(Set(objects.map(\.type)).count > 1 ? .requiresExplicitSelection : .notApplicable)
        }
        if objects.count > 1 && command.batch != .explicitMultiple { issues.append(.multipleNotSupported) }
        return issues
    }

    /// target 参数只从固定集合派生；它不能成为第二个可编辑目标值。
    func argument(for command: CommandDescriptor) -> CommandArgument? {
        guard !objects.isEmpty, let parameter = command.parameters.first(where: { $0.id == .target }) else { return nil }
        switch parameter.type {
        case .object:
            guard objects.count == 1 else { return nil }
            return .init(parameter: .target, operation: .assign, value: .object(objects[0]))
        case .objects: return .init(parameter: .target, operation: .assign, value: .objects(objects))
        default: return nil
        }
    }
}

enum CommandDraftTargetIssue: Equatable {
    case missingTargets, emptySelection, invalidSelection, invalidIdentity
    case requiresExplicitSelection, notApplicable, multipleNotSupported
}

struct CommandDraftBaseline: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum Subject: Hashable { case ambient, object(CommandObjectReference) }
    struct Field: Hashable {
        let subject: Subject
        let parameter: CommandParameterID
    }

    /// 字典缺项表示未提供，不等同于已知 absent；原值从不由领域层读取。
    let values: [Field: CommandOriginalValue]
    let isReadable: Bool
    static let protectedContent = Self(values: [:], isReadable: false)
    private init(values: [Field: CommandOriginalValue], isReadable: Bool) {
        self.values = values
        self.isReadable = isReadable
    }
    init(_ values: [Field: CommandOriginalValue] = [:]) { self.values = values; self.isReadable = true }

    func original(_ parameter: CommandParameterID, targets: CommandDraftTargets) -> CommandOriginalValue? {
        guard isReadable else { return nil }
        let subjects: [Subject] = targets.objects.isEmpty ? [.ambient] : targets.objects.map(Subject.object)
        let originals = subjects.compactMap { values[.init(subject: $0, parameter: parameter)] }
        guard originals.count == subjects.count, let first = originals.first else { return nil }
        return originals.allSatisfy { $0 == first } ? first : .mixed
    }

    var description: String { "CommandDraftBaseline(fields: \(values.count))" }
    var debugDescription: String { description }
}
