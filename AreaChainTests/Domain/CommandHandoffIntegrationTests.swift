import Foundation
import Testing
@testable import AreaChain

@MainActor struct CommandHandoffIntegrationTests {
    @Test func longDraftSurvivesQueryAndPresentationSignalsBeforePlanEditing() throws {
        var host = PlanFixture.host()
        let seed = CommandIntegrationFixture.notes(host: host.hostID)
        host.operationEvent(.start(expectedRevision: host.operations.revision, seed))
        let edited = CommandIntegrationFixture.notesArgument(CommandIntegrationFixture.body + "合成补充段落")
        host.operationEvent(.edit(try #require(host.operations.active?.stamp), edited))
        let draft = try #require(host.operations.active)
        host.queryEvent(.setInput("/tasks 汇报 (#工作 | #学习) -#归档 status:open"))
        host.queryEvent(.enterPage(QuerySessionFixture.page(.settings, visit: "settings")))
        host.queryEvent(.clearUserQuery)
        for event in CommandHostPresentationEvent.allCases { host.presentationEvent(event) }
        #expect(host.operations.active == draft && host.requiresUnsavedContentHandling)
        let item = UUID()
        try host.enqueue(draft.stamp, itemID: item, expecting: host.plan.stamp)
        try PlanFixture.edit(item, argument: CommandIntegrationFixture.notesArgument(CommandIntegrationFixture.body + "计划内修改"), in: &host)
        #expect(host.operations.active == nil && host.operations.retained.isEmpty)
        let planned = try PlanFixture.item(item, in: host).draft
        try host.removeFromPlan(PlanFixture.item(item, in: host).stamp, expecting: host.plan.stamp)
        #expect(host.plan.items.isEmpty && host.operations.retained.count == 1)
        #expect(host.operations.retained[0].arguments == planned.arguments)
        #expect(host.operations.retained[0].targets == seed.targets && host.operations.retained[0].baseline == seed.baseline)
    }

    @Test func longContentRetainRestoreEditAndTransferKeepOneOwner() throws {
        let fixture = try HandoffFixture(targetPage: .diaries(tagID: UUID()))
        let source = HandoffFixture.source, target = HandoffFixture.target
        let targetPage = try fixture.state(target).query.page
        let producer = try fixture.queue(CommandIntegrationFixture.creation(host: source))
        let child = try fixture.queue(CommandIntegrationFixture.creation(host: source, child: true))
        try fixture.reference(child, producer: producer)
        let longDraft = CommandIntegrationFixture.notes(host: source)
        try fixture.start(longDraft)
        let active = try #require(fixture.state().operations.active)
        try fixture.send(.operation(.edit(active.stamp, CommandIntegrationFixture.notesArgument(CommandIntegrationFixture.body + "合成修改"))))
        try fixture.start(HandoffFixture.setting())
        let oldDecision = try #require(fixture.state().operations.pending)
        let confirmationLease = try fixture.owned().lease
        try fixture.send(.operation(.resolve(oldDecision, .retain)))
        let saved = try #require(fixture.state().operations.retained.first)
        try fixture.send(.operation(.restore(expectedRevision: fixture.state().operations.revision, saved.stamp)))
        try fixture.send(.operation(.resolve(#require(fixture.state().operations.pending), .retain)))
        let restored = try #require(fixture.state().operations.active)
        #expect(restored.id == longDraft.id && restored.arguments == saved.arguments && restored.version > saved.version)
        let itemID = UUID()
        try fixture.send(.enqueue(restored.stamp, itemID: itemID, plan: fixture.state().plan.stamp))
        try fixture.editItem(itemID, argument: CommandIntegrationFixture.notesArgument(CommandIntegrationFixture.body + "就地修改"))
        let edited = try fixture.item(itemID).draft
        try fixture.send(.removeFromPlan(fixture.item(itemID).stamp, fixture.state().plan.stamp))
        #expect(try fixture.state().operations.retained.filter { $0.id == longDraft.id }.count == 1)
        #expect(try fixture.state().plan.items.allSatisfy { $0.draft.id != longDraft.id })
        try fixture.send(.query(.setInput("/tasks 汇报 (#工作 | #学习) -#归档 status:open")))
        let before = try fixture.owned()
        let failed = try fixture.prepare()
        try fixture.coordinator.fail(failed, reason: .receiverUnavailable)
        #expect(try fixture.owned() == before)
        #expect(fixture.coordinator.status(failed.id) == .failed(.receiverUnavailable))
        let ticket = try fixture.transfer()
        let received = try fixture.owned(target)
        #expect(fixture.coordinator.status(ticket.id) == .completed)
        let moved = try #require(received.session.operations.retained.first { $0.id == longDraft.id })
        #expect(moved.arguments == edited.arguments && moved.baseline == longDraft.baseline)
        #expect(moved.targets == longDraft.targets && moved.modification == edited.modification)
        #expect(moved.hostID == target && moved.version > edited.version)
        #expect(received.session.plan.id == before.session.plan.id)
        #expect(received.session.plan.items.map(\.id) == before.session.plan.items.map(\.id))
        #expect(try fixture.item(child, host: target).links.results[.parent]?.producer == fixture.item(producer, host: target).stamp)
        #expect(received.session.plan.check().dependencies.isEmpty)
        #expect(try fixture.state().operations.retained.isEmpty && fixture.state().plan.items.isEmpty)
        try assertOldEventsRejected(fixture, old: before, draft: restored, decision: oldDecision, lease: confirmationLease)
        #expect(try fixture.owned(target) == received)
        let conditions = received.session.query.conditions
        try fixture.send(.query(.refreshPage(targetPage)), host: target)
        try fixture.send(.query(.enterPage(QuerySessionFixture.page(.diaries(tagID: UUID()), visit: "other", host: target))), host: target)
        #expect(try fixture.state(target).query.conditions == conditions)
        #expect(try fixture.state(target).query.binding == .independent(.handoff))
        #expect(try fixture.state(target).query.input == before.session.query.input)
        #expect(try fixture.state(target).operations.retained.first { $0.id == longDraft.id } == moved)
    }

    private func assertOldEventsRejected(
        _ fixture: HandoffFixture, old: CommandOwnedHost, draft: CommandDraft,
        decision: CommandDraftDecision, lease: CommandHostLease
    ) throws {
        let candidateEvent = CommandHostEvent.operation(.edit(draft.stamp, CommandIntegrationFixture.notesArgument("过期候选")))
        #expect(throws: CommandHandoffError.stale) { try fixture.coordinator.send(candidateEvent, expecting: old.lease) }
        #expect(throws: CommandHandoffError.stale) {
            try fixture.coordinator.send(.operation(.resolve(decision, .discard)), expecting: lease)
        }
        #expect(throws: CommandHandoffError.stale) {
            try fixture.coordinator.send(.sealPlan(old.session.plan.stamp, runID: UUID()), expecting: old.lease)
        }
    }

    @Test func occupiedTargetPreservesBothSidesAndDescriptionsHideContent() throws {
        let fixture = try HandoffFixture()
        try fixture.start(CommandIntegrationFixture.notes(host: HandoffFixture.source))
        try fixture.start(.init(id: UUID(), hostID: HandoffFixture.target, commandID: .init(rawValue: "todo.create")))
        let source = try fixture.owned(), target = try fixture.owned(HandoffFixture.target)
        #expect(throws: CommandHandoffError.targetOccupied) { try fixture.prepare() }
        #expect(try fixture.owned() == source && fixture.owned(HandoffFixture.target) == target)
        let sourceDescriptions = [String(describing: source), String(reflecting: source.session),
                                  String(describing: source.session.operations), String(reflecting: source.session.operations.active)]
        #expect(sourceDescriptions.allSatisfy { !$0.contains("合成工作记录") && !$0.contains("合成原备注") })
    }

    @Test func argumentAndBaselineValueDescriptionsDoNotExposeDraftBody() throws {
        let draft = CommandIntegrationFixture.notes(host: HandoffFixture.source)
        let descriptions = [String(describing: draft.arguments), String(reflecting: draft.arguments),
                            String(describing: draft.baseline.values), String(reflecting: draft.baseline.values)]
        // 断言只报告布尔值，避免失败报告自身再次展开合成正文。
        let hidesBody = descriptions.allSatisfy { !$0.contains("合成工作记录") && !$0.contains("合成原备注") }
        #expect(hidesBody)
    }
}
