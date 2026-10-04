import Foundation
import Testing
@testable import AreaChain

extension UnifiedSearchResultsFixture {
    @discardableResult
    func enqueueOperation(_ id: String, arguments: [CommandArgument] = []) throws -> CommandPlanItem {
        try startOperation(id)
        for argument in arguments {
            try #require(controller.editParameter(argument, source: controller.buffer) != nil)
        }
        try #require(controller.enqueue(draft.stamp, source: controller.buffer))
        return try #require(controller.plan?.items.last)
    }

    func planItem(_ id: UUID) throws -> CommandPlanItem {
        try #require(controller.plan?.items.first { $0.id == id })
    }

    func planText(_ parameterID: CommandParameterID, _ text: String) throws {
        let draft = try #require(controller.editingDraft)
        let command = try #require(CommandCatalog.standard.command(id: draft.commandID))
        let parameter = try #require(command.parameters.first { $0.id == parameterID })
        let context = UnifiedSearchParameterContext(command: command, parameter: parameter,
            operation: controller.fieldOperation(parameter, draft: draft))
        try #require(controller.editParameterText(.init(source: controller.parameterBuffer(parameter, draft: draft),
            text: text, selection: .init(location: text.utf16.count, length: 0)), context: context) != nil)
    }
}
