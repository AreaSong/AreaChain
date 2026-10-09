import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct MultiPlanRevisionEditingTests {
    @Test func invalidOriginalGraphCannotBeRepairedByVersionMigration() throws {
        let fixture = try MultiPlanOutputFixture(revisions: true)
        let items = try fixture.chain()
        fixture.io.creation.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        try fixture.start()
        _ = try MultiPlanRevisionSupport.returnAll(fixture.adapter, fixture.handoff)
        var candidate = try fixture.handoff.state().plan
        let producer = try #require(candidate.items.first)
        try candidate.apply(.beginEditing(producer.stamp), expecting: candidate.stamp)
        try candidate.apply(.edit(producer.stamp, SubtaskCommandFixture.title("故意生成旧引用")), expecting: candidate.stamp)
        let before = candidate
        #expect(!candidate.check().dependencies.isEmpty)
        #expect(throws: (any Error).self) { try candidate.applyRevision(.reorder(items.map(\.id)), expecting: candidate.stamp) }
        #expect(candidate == before)
    }

    @Test func removeReferencedProducerRequiresExplicitConsumerHandling() throws {
        let fixture = try MultiPlanOutputFixture(revisions: true)
        let items = try fixture.chain()
        fixture.io.creation.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        try fixture.start()
        _ = try MultiPlanRevisionSupport.returnAll(fixture.adapter, fixture.handoff)
        let before = try fixture.handoff.owned()
        #expect(throws: CommandPlanError.dependents([items[1].id])) {
            try fixture.handoff.send(.removeFromPlan(before.session.plan.items[0].stamp, before.session.plan.stamp))
        }
        #expect(try fixture.handoff.owned() == before)
    }

    @Test func removeReturnedSettingsGroupRetainsEveryMemberTogether() throws {
        let fixture = try FileSettingCommandFixture(fault: .temporaryWrite)
        let group = try fixture.group(prepare: false)
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator, adapters: .init(fileSettings: fixture.adapter), supportsRevisions: true)
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        let run = try #require(fixture.state().execution)
        try fixture.adapter.recoverMultiBackend(#require(run.attempt(group)), expecting: fixture.owned().lease)
        _ = try MultiPlanRevisionSupport.returnAll(adapter, fixture.handoff)
        let before = try fixture.state().plan
        try fixture.handoff.send(.removeGroupFromPlan(group, before.stamp))
        #expect(try fixture.state().plan.items.isEmpty)
        #expect(try Set(fixture.state().operations.retained.map(\.id)) == Set(before.items.map { $0.draft.id }))
        #expect(fixture.handoff.coordinator.revisionChain(HandoffFixture.source).first?.run == run)
    }

    @Test(arguments: ["setting.language", "setting.appearance", "setting.truncation", "setting.captureSource"])
    func everyLegacySettingAssignmentUsesRealMergeEvidence(command: String) throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        let values: [CommandValue]
        switch command {
        case "setting.language": values = [.choice("chinese"), .choice("english")]
        case "setting.appearance": values = [.choice("light"), .choice("dark")]
        case "setting.truncation": values = [.choice("tail"), .choice("middle")]
        default: values = [.boolean(false), .boolean(true)]
        }
        for value in values { _ = try fixture.queue(command, value: value, realBaseline: false) }
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator,
            adapters: .init(localSettings: fixture.adapter), supportsRevisions: true)
        let items = try fixture.state().plan.items
        let proof = try adapter.proposeMerge(items[0].stamp, items[1].stamp, expecting: fixture.owned().lease)
        try adapter.acceptMerge(proof, expecting: fixture.owned().lease)
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        #expect(try fixture.state().execution?.units.first?.state == .succeeded)
        #expect(fixture.io.writes.count <= 1)
        let value = try LocalSettingCommandMapping.value(for: items[1].draft)
        #expect(try fixture.prefs.readLocalSetting(value.field).value == value)
        #expect(throws: (any Error).self) { try fixture.handoff.coordinator.mergePlan(proof.proof, assemblyID: adapter.id, expecting: fixture.owned().lease) }
    }
}
