import Foundation
import Testing
@testable import AreaChain

struct CommandLanguageIntegrationTests {
    @Test(arguments: ["en", "zh-Hans"])
    func acceptedPathBecomesOneDraftThenAnUnsubmittedPlan(language: String) throws {
        let parser = CommandPathParser()
        let locale = Locale(identifier: language)
        var host = PlanFixture.host()
        let prefix = parser.parse(.init(text: "/set", locale: locale))
        let group = try #require(prefix.candidates.first { $0.command.id.rawValue == "group.setting" })
        let expanded = try #require(prefix.accepting(group, in: "/set", hasMarkedText: false))
        #expect(expanded.text == "/setting")
        let grouped = parser.parse(.init(text: expanded.text, locale: locale))
        let languageCandidate = try #require(grouped.candidates.first { $0.command.id.rawValue == "setting.language" })
        let languageEdit = try #require(grouped.accepting(languageCandidate, in: expanded.text, hasMarkedText: false))
        let parameters = parser.parse(.init(text: languageEdit.text, locale: locale))
        let chinese = try #require(parameters.candidates.first { $0.id.hasSuffix(":chinese") })
        let accepted = try #require(parameters.accepting(chinese, in: languageEdit.text, hasMarkedText: false))
        #expect(accepted.text == "/setting/language/chinese")
        let parsed = parser.parse(.init(text: accepted.text, locale: locale))
        let descriptor = try #require(CommandCatalog.standard.command(path: "/setting/language"))
        let argument = CommandArgument(parameter: .value, operation: .assign, value: .choice("chinese"))
        #expect(accepted.intent == .setArgument(descriptor.id, argument))
        #expect(parsed.command == descriptor && parsed.arguments == [argument])
        #expect(CommandArgumentValidation.issues(for: parsed.arguments, command: descriptor).isEmpty)
        guard case .choice(let choices) = try #require(descriptor.parameters.first).type else {
            Issue.record("语言仍应使用目录 choice 参数"); return
        }
        #expect(choices.contains { $0.value == "chinese" })
        host.queryEvent(.setInput(accepted.text))
        let querySnapshot = host.query.input
        guard case .command(let queryCommand) = querySnapshot else { Issue.record("应分流为指令"); return }
        #expect(queryCommand.command == descriptor && queryCommand.arguments == parsed.arguments)
        #expect(host.operations.active == nil && host.plan.items.isEmpty)

        // 模拟用户明确接受预览；解析器本身不创建草稿，更不提交。
        let draft = CommandDraft(id: UUID(), hostID: host.hostID, commandID: descriptor.id, arguments: parsed.arguments)
        #expect(host.operationEvent(.start(expectedRevision: host.operations.revision, draft)).isEmpty)
        let active = try #require(host.operations.active)
        #expect(active.arguments == [argument] && active.check().parametersComplete)
        #expect(active.check().staticallyValid && !active.check().isExecutable)
        host.operationEvent(.edit(active.stamp, PlanFixture.argument(.value, .choice("english"))))
        #expect(host.operations.active?.arguments == [PlanFixture.argument(.value, .choice("english"))])
        #expect(host.query.input == querySnapshot) // 解析快照不是可编辑草稿的镜像。
        let stamp = try #require(host.operations.active?.stamp)
        try host.enqueue(stamp, itemID: UUID(), expecting: host.plan.stamp)
        #expect(host.operations.active == nil && host.operations.retained.isEmpty)
        #expect(host.plan.items.count == 1 && host.plan.items[0].draft.id == draft.id)
        #expect(throws: CommandPlanError.stale) { try host.enqueue(stamp, itemID: UUID(), expecting: host.plan.stamp) }
        let plan = host.plan
        host.queryEvent(.setInput("/tasks 汇报"))
        host.queryEvent(.enterPage(QuerySessionFixture.page(.diaries(tagID: nil), visit: "diaries")))
        host.queryEvent(.clearUserQuery)
        #expect(host.plan == plan && host.execution == nil)
        #expect(host.plan.check().canSealProtocol && !host.plan.check().isExecutable)
        #expect(descriptor.execution == .unwired && !descriptor.canEnterOrdinaryQueue)
    }
}
