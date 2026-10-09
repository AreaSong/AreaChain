import Foundation
import SwiftData

/// 目录描述类型；只有显式 P-M2 装配才开放分支和跨类型创建链。
enum CommandMultiPlanOutputCapability: Equatable {
    case taskTitle, typedCreation

    func accepts(_ command: CommandID, parameter: CommandParameterID, type: CommandObjectType) -> Bool {
        if self == .taskTitle { return command.rawValue == "todo.title" && parameter == .target && type == .todo }
        switch (type, parameter) {
        case (.todo, .parent): return command.rawValue == "subtask.create"
        case (.todo, .target): return command.rawValue == "todo.title" || TaskFieldEdit.commands.contains(command.rawValue)
        case (.subtask, .target): return ["subtask.title", "subtask.completion", "subtask.tags"].contains(command.rawValue)
        case (.routine, .target): return CommandRoutineEdit.commands.contains(command.rawValue) || command.rawValue == "routine.enabled"
        default: return false
        }
    }
}

/// 只携带真实保存和调用的身份，不持有实体、可编辑参数或另一份输出缓存。
struct CommandCreationOutput: Equatable {
    let execution: CommandExecutionStamp
    let producer: CommandPlanItemStamp
    let draft: CommandDraftStamp
    let creationAcceptanceID: UUID
    let localAttempt: CommandAttemptStamp
    let assemblyID: UUID
    let environmentID: UUID
    let contextID: ObjectIdentifier
    let storageID: ObjectIdentifier
    let record: PersistentIdentifier
    let object: CommandObjectReference

    func validate(context: ObjectIdentifier, storage: ObjectIdentifier, record: PersistentIdentifier) throws {
        guard contextID == context, storageID == storage, self.record == record else { throw CommandMultiPlanIssue.stale }
    }
}

struct CommandCreationConsumption: Equatable {
    let parameter: CommandParameterID
    let output: CommandCreationOutput

    func input(_ item: CommandPlanItem) throws -> CommandResolvedInput {
        guard let reference = item.links.results[parameter], reference.producer == output.producer,
              reference.outputType == output.object.type, reference.history == nil || reference.history == output else {
            throw CommandMultiPlanIssue.stale
        }
        guard item.links.results == [parameter: reference],
              CommandMultiPlanOutputCapability.typedCreation.accepts(item.draft.commandID, parameter: parameter, type: reference.outputType),
              CommandPlanValidation.acceptsReference(reference, parameter: parameter, item: item),
              let input = item.resolving([parameter: output.object]) else { throw CommandMultiPlanIssue.stale }
        return input
    }

    func validate(in run: CommandExecutionRun, item: CommandPlanItem) throws {
        if let reference = item.links.results[parameter], reference.history == output {
            guard run.multiPlan?.references[item.id] == reference, item.executionOrigin != nil,
                  run.creationOutput(for: reference) == output.object,
                  try run.resolvedInput(item.id) == input(item) else { throw CommandMultiPlanIssue.stale }
            return
        }
        guard let identity = run.multiPlan, identity.references[item.id]?.producer == output.producer,
              run.snapshot.items.first(where: { $0.stamp == output.producer })?.draft.stamp == output.draft,
              let reference = item.links.results[parameter],
              output.execution == run.stamp, run.creationOutput(for: reference) == output.object,
              try run.resolvedInput(item.id) == input(item) else { throw CommandMultiPlanIssue.stale }
    }
}

extension CommandPlanItem {
    /// 只验证解析投影与冻结意图一致；真实来源和调用许可仍由协调者核验。
    func checkedInput(_ resolved: CommandResolvedInput? = nil) throws -> CommandResolvedInput {
        guard let input = resolved ?? resolving(), let command = CommandCatalog.standard.command(id: draft.commandID) else {
            throw CommandMultiPlanIssue.incomplete
        }
        if links.results.isEmpty {
            guard input == resolving() else { throw CommandMultiPlanIssue.stale }
        } else {
            guard resolved != nil, links.results.count == 1, let (parameter, reference) = links.results.first,
                  CommandPlanValidation.acceptsReference(reference, parameter: parameter, item: self) else {
                throw CommandMultiPlanIssue.unsupported
            }
            let object: CommandObjectReference?
            if parameter == .target { object = input.targets.objects.first }
            else if case .object(let value) = input.arguments.first(where: { $0.parameter == parameter })?.value { object = value }
            else { object = nil }
            guard let object, object.type == reference.outputType, object.dayKey == nil,
                  input == resolving([parameter: object]) else { throw CommandMultiPlanIssue.stale }
        }
        guard CommandArgumentValidation.issues(for: input.arguments, command: command).isEmpty,
              input.targets.issues(for: command).isEmpty else { throw CommandMultiPlanIssue.incomplete }
        return input
    }

    /// parent 只进入参数，target 只进入目标；原冻结引用与草稿永不改写。
    func resolving(_ bindings: [CommandParameterID: CommandObjectReference] = [:]) -> CommandResolvedInput? {
        guard !draft.blocksUnprotectedExport, let command = CommandCatalog.standard.command(id: draft.commandID) else { return nil }
        var targets = draft.targets
        var arguments = draft.arguments.filter { bindings[$0.parameter] == nil }
        for (parameter, object) in bindings {
            if parameter == .target { targets = .init(.single, objects: [object]); continue }
            guard let definition = command.parameters.first(where: { $0.id == parameter }) else { return nil }
            let value: CommandValue
            switch definition.type {
            case .object: value = .object(object)
            case .objects: value = .objects([object])
            default: return nil
            }
            arguments.append(.init(parameter: parameter, operation: .assign, value: value))
        }
        arguments += targets.argument(for: command).map { [$0] } ?? []
        return .init(arguments: arguments, targets: targets)
    }
}
