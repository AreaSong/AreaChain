import Foundation
import SwiftData

extension MultiPlanCommandAdapter {
    func permitsReference(_ producer: CommandPlanItem, consumer: CommandPlanItem, parameter: CommandParameterID) -> Bool {
        guard let type = CommandCatalog.standard.command(id: producer.draft.commandID)?.createdObjectType,
              outputCapability.accepts(consumer.draft.commandID, parameter: parameter, type: type),
              (try? family(for: producer.draft.commandID)) != nil,
              (try? family(for: consumer.draft.commandID)) != nil else { return false }
        if outputCapability == .taskTitle {
            return (try? CommandHandoffCoordinator.validateTaskCreateItem(producer, allowingDependencies: true)) != nil
        }
        return true
    }

    func validateReferenceEnvironments(_ identity: CommandMultiPlanIdentity, items: [CommandPlanItem]) throws {
        for item in items where identity.references[item.id] != nil {
            guard let (parameter, reference) = item.links.results.first,
                  let producer = items.first(where: { $0.stamp == reference.producer }),
                  permitsReference(producer, consumer: item, parameter: parameter),
                  try context(for: family(for: producer.draft.commandID)) === context(for: family(for: item.draft.commandID)) else {
                throw CommandMultiPlanIssue.unsupported
            }
        }
    }

    private func context(for family: CommandMultiPlanFamily) throws -> ModelContext {
        switch family {
        case .taskCreate: if let taskCreate { return try taskCreate.assembled().context }
        case .taskTitle: if let taskTitle { return try taskTitle.assembled().context }
        case .taskField: if let taskField { return try taskField.assembled().context }
        case .subtask: if let subtask { return try subtask.assembled().context }
        case .routine, .routineCreate: if let routine { return try routine.assembled().context }
        default: break
        }
        throw CommandMultiPlanIssue.unassembled
    }

    func consumption(for item: CommandPlanItem, lease: CommandHostLease) throws -> CommandCreationConsumption? {
        guard let (parameter, reference) = item.links.results.first else { return nil }
        guard item.links.results.count == 1,
              outputCapability.accepts(item.draft.commandID, parameter: parameter, type: reference.outputType) else {
            throw CommandMultiPlanIssue.unsupported
        }
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution else { return nil }
        guard coordinator.multiPlans.assemblies[run.stamp] == id, run.multiPlan?.outputCapability == outputCapability else {
            throw CommandMultiPlanIssue.stale
        }
        let output = try coordinator.multiPlanOutput(reference, in: run)
        let context = try context(for: family(for: item.draft.commandID))
        guard output.contextID == ObjectIdentifier(context), output.storageID == ObjectIdentifier(context.container) else {
            throw CommandMultiPlanIssue.stale
        }
        return .init(parameter: parameter, output: output)
    }

    /// 尚无对象时仅核验确定的输入；不调用目标读取器、不预留占位对象或制造基线。
    func validateWaitingInput(_ item: CommandPlanItem) throws {
        let draft = item.draft
        let check = CommandPlanValidation.check([item]).items.first
        guard draft.baseline == CommandDraftBaseline(), draft.targets == .none,
              check?.arguments.isEmpty == true, check?.targets.isEmpty == true else { throw CommandMultiPlanIssue.incomplete }
        let command = draft.commandID.rawValue
        if command == "todo.title" {
            guard draft.arguments.count == 1, case .shortText(let title) = draft.arguments[0].value,
                  !title.contains(where: \.isNewline), !NaturalLanguageParser.hasTaskNoteSeparator(title),
                  let edit = TaskTitleEdit(title), edit.notes == nil, !edit.title.isEmpty else { throw CommandMultiPlanIssue.incomplete }
        } else if TaskFieldEdit.commands.contains(command) {
            guard draft.arguments.count == 1 else { throw CommandMultiPlanIssue.incomplete }
            _ = try TaskFieldEdit(command: draft.commandID, argument: draft.arguments[0])
        } else if CommandRoutineEdit.allCommands.contains(command) {
            _ = try CommandRoutineEdit(command: draft.commandID, arguments: draft.arguments)
        } else {
            try validateWaitingSubtask(item)
        }
        if outputCapability == .typedCreation { try validateWaitingTags(item) }
    }

    private func validateWaitingTags(_ item: CommandPlanItem) throws {
        var selections: [CommandTaskTagSelection] = []
        for argument in item.draft.arguments {
            if argument.parameter == .title, case .shortText(let text) = argument.value {
                selections += TagSyntax.names(in: text).map(CommandTaskTagSelection.name)
            } else if argument.parameter == .tags, case .tags(let ids) = argument.value {
                selections += TagIDList.normalized(ids).map(CommandTaskTagSelection.id)
            } else if item.draft.commandID.rawValue == "todo.createTag", case .shortText(let name) = argument.value {
                selections.append(.name(name))
            }
        }
        guard !selections.isEmpty else { return }
        // 只核验输入中已知的标签资格；没有目标就不构造关联基线或保存效果。
        let context = try context(for: family(for: item.draft.commandID))
        let catalog = try TaskCreateTagCatalogReader(context: context, invalidation: .catalogFacts).current()
        let lookup = CommandTaskTagLookup(catalog)
        guard lookup.catalogProblems.isEmpty else { throw CommandTaskTitlePreviewIssue.tags(lookup.catalogProblems) }
        for selection in selections {
            if case .failure(let failure) = lookup.resolve(selection) {
                throw CommandTaskTitlePreviewIssue.tags([.init(selection: selection, kind: failure.kind)])
            }
        }
    }

    private func validateWaitingSubtask(_ item: CommandPlanItem) throws {
        let arguments = item.draft.arguments
        switch item.draft.commandID.rawValue {
        case "subtask.create", "subtask.title":
            guard (1...2).contains(arguments.count), Set(arguments.map(\.parameter)).isSubset(of: [.title, .tags]),
                  case .shortText(let title) = arguments.first(where: { $0.parameter == .title })?.value,
                  !title.contains(where: \.isNewline), SubtaskTitleEdit(title) != nil else { throw CommandMultiPlanIssue.incomplete }
            if item.draft.commandID.rawValue == "subtask.title", arguments.count != 1 { throw CommandMultiPlanIssue.incomplete }
        case "subtask.completion":
            guard arguments.count == 1, arguments[0].parameter == .enabled,
                  arguments[0].operation == .assign, case .boolean = arguments[0].value else { throw CommandMultiPlanIssue.incomplete }
        case "subtask.tags":
            guard arguments.count == 1, arguments[0].parameter == .tags,
                  [.clear, .add, .remove, .replaceAll].contains(arguments[0].operation) else { throw CommandMultiPlanIssue.incomplete }
        default: throw CommandMultiPlanIssue.unsupported
        }
    }
}
