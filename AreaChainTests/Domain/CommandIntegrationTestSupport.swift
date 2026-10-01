import Foundation
import Testing
@testable import AreaChain

enum CommandIntegrationFixture {
    // 全部由普通合成文字组成，不从用户库、文件或剪贴板取材料。
    static let body = String(repeating: "合成工作记录：今天整理资料，明天继续核对。👩🏽‍💻\n", count: 120)

    static func notes(host: String) -> CommandDraft {
        let target = CommandObjectReference(type: .todo, id: UUID())
        return .init(id: UUID(), hostID: host, commandID: .init(rawValue: "todo.notes"),
                     targets: .init(.single, objects: [target]),
                     baseline: .init([.init(subject: .object(target), parameter: .notes): .uniform(.longText("合成原备注"))]),
                     arguments: [notesArgument(body)])
    }

    static func notesArgument(_ text: String) -> CommandArgument {
        .init(parameter: .notes, operation: .replace, value: .longText(text))
    }

    static func creation(host: String, child: Bool = false) -> CommandDraft {
        let seed = child ? PlanFixture.child() : PlanFixture.todo()
        return .init(id: seed.id, hostID: host, commandID: seed.commandID, arguments: seed.arguments)
    }
}

extension HandoffFixture {
    func item(_ id: UUID, host: String = source) throws -> CommandPlanItem {
        try #require(state(host).plan.items.first { $0.id == id })
    }

    func reference(_ consumer: UUID, producer: UUID, host: String = source) throws {
        let output = try #require(CommandCatalog.standard.command(id: item(producer, host: host).draft.commandID)?.createdObjectType)
        let reference = CommandCreationReference(producer: try item(producer, host: host).stamp, outputType: output)
        try plan(.link(item(consumer, host: host).stamp, .init(results: [.parent: reference])), host: host)
    }

    func editItem(_ id: UUID, argument: CommandArgument, host: String = source) throws {
        try plan(.beginEditing(item(id, host: host).stamp), host: host)
        try plan(.edit(item(id, host: host).stamp, argument), host: host)
        try plan(.endEditing(item(id, host: host).stamp, .finish), host: host)
    }
}
