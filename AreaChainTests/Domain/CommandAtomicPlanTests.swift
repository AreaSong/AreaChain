import Foundation
import Testing
@testable import AreaChain

struct CommandAtomicPlanTests {
    @Test func settingsGroupIsOneResultUnitAndConflictPausesAllMembers() throws {
        var host = PlanFixture.host()
        let language = try PlanFixture.queue(PlanFixture.setting(), in: &host)
        let appearance = try PlanFixture.queue(PlanFixture.setting("dark", command: "setting.appearance"), in: &host)
        let independent = try PlanFixture.queue(PlanFixture.todo(), in: &host), group = UUID()
        try host.planEvent(.atomicGroup(group, members: [language, appearance]), expecting: host.plan.stamp)
        #expect(throws: CommandPlanError.grouped) { try host.removeFromPlan(PlanFixture.item(language, in: host).stamp, expecting: host.plan.stamp) }
        #expect(throws: CommandPlanError.self) { try host.planEvent(.reorder([language, independent, appearance]), expecting: host.plan.stamp) }
        #expect(throws: CommandPlanError.self) { try PlanFixture.link(appearance, to: [language], in: &host) }
        let item = try PlanFixture.item(language, in: host)
        try PlanFixture.seal(&host)
        let attempt = try PlanFixture.begin(&host)
        #expect(attempt.unitID == group && host.execution?.units.count == 2)
        #expect(host.execution?.units[0].members == [language, appearance])
        let conflict = CommandFieldConflict(item: item.stamp, field: .init(subject: .ambient, parameter: .value), reason: .valueChanged)
        let unrelated = CommandFieldConflict(item: item.stamp, field: .init(subject: .ambient, parameter: .body), reason: .valueChanged)
        #expect(throws: CommandExecutionError.invalidResult) { try PlanFixture.result(.conflict([unrelated]), attempt: attempt, in: &host) }
        try PlanFixture.result(.conflict([conflict]), attempt: attempt, in: &host)
        #expect(host.execution?.units[0].state == .conflict)
        #expect(host.execution?.units[0].conflicts == [conflict])
        #expect(host.execution?.snapshot.items.first?.draft.baseline == item.draft.baseline)
        #expect(try PlanFixture.begin(&host).unitID == independent)
    }

    @Test func atomicResultRejectsObjectsAndExternalEffectsAndConfirmsWholeGroup() throws {
        var host = PlanFixture.host()
        let first = try PlanFixture.queue(PlanFixture.setting(), in: &host)
        let last = try PlanFixture.queue(PlanFixture.setting("dark", command: "setting.appearance"), in: &host)
        let group = UUID()
        try host.planEvent(.atomicGroup(group, members: [first, last]), expecting: host.plan.stamp)
        try PlanFixture.seal(&host)
        let attempt = try PlanFixture.begin(&host)
        for result in [CommandExecutionResult.committed(outputs: [:], external: [.calendar]),
                       .committed(outputs: [first: .init(type: .todo, id: UUID())], external: [])] {
            #expect(throws: CommandExecutionError.invalidResult) { try PlanFixture.result(result, attempt: attempt, in: &host) }
            #expect(host.execution?.units[0].local == .notSubmitted)
        }
        try PlanFixture.result(.failedWithoutCommit, attempt: attempt, in: &host)
        #expect(host.execution?.units[0].state == .failed)
        try host.retryProtocolStep(attempt, assurance: .safeLocalReplay)
        let retry = try PlanFixture.begin(&host)
        #expect(retry.unitID == group)
        try PlanFixture.result(.committed(outputs: [:], external: []), attempt: retry, in: &host)
        #expect(host.execution?.units[0].state == .succeeded)
    }

    @Test func nonSettingsCannotBecomeAtomicAndDissolvePreservesDrafts() throws {
        var host = PlanFixture.host()
        let first = try PlanFixture.queue(PlanFixture.todo(), in: &host)
        let last = try PlanFixture.queue(PlanFixture.setting(), in: &host)
        #expect(throws: CommandPlanError.invalidInput) {
            try host.planEvent(.atomicGroup(UUID(), members: [first, last]), expecting: host.plan.stamp)
        }
        let next = try PlanFixture.queue(PlanFixture.setting("dark", command: "setting.appearance"), in: &host)
        let group = UUID(), drafts = host.plan.items.map(\.draft)
        try host.planEvent(.atomicGroup(group, members: [last, next]), expecting: host.plan.stamp)
        try host.planEvent(.dissolveGroup(group), expecting: host.plan.stamp)
        #expect(host.plan.items.map(\.draft) == drafts && host.plan.items.allSatisfy { $0.atomicGroup == nil })
    }

    @Test func defaultDescriptionsNeverIncludeSyntheticBody() throws {
        var host = PlanFixture.host()
        let marker = "Synthetic body must stay out of descriptions"
        let argument = PlanFixture.argument(.title, .shortText(marker))
        let draft = CommandDraft(id: UUID(), hostID: "workspace", commandID: .init(rawValue: "todo.create"),
                                 arguments: [argument, PlanFixture.argument(.day, .day("2026-10-01"))])
        try PlanFixture.queue(draft, in: &host)
        host.queryEvent(.setInput("/tasks/add/" + marker))
        let event = CommandPlanEvent.edit(host.plan.items[0].stamp, argument)
        #expect(!String(reflecting: host).contains(marker))
        #expect(!String(reflecting: event).contains(marker))
        try PlanFixture.seal(&host)
        let attempt = try PlanFixture.begin(&host)
        #expect(!String(reflecting: host).contains(marker))
        let inputDescription = String(reflecting: host.execution?.resolvedInput(attempt.unitID))
        #expect(!inputDescription.contains(marker))
    }
}
