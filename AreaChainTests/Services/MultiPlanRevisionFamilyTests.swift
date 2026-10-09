import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct MultiPlanRevisionFamilyTests {
    @Test func batchReturnsWholeTargetSetAndUsesOneTransaction() throws {
        let fixture = try BatchCommandFixture()
        try fixture.queue()
        try fixture.queue(argument: .init(parameter: .day, operation: .assign, value: .day("2026-10-11")))
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator, adapters: .init(batch: fixture.adapter), supportsRevisions: true)
        fixture.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        let original = try #require(fixture.handoff.state().execution)
        #expect(original.units.allSatisfy { $0.hasSafeLocalFailure })
        _ = try MultiPlanRevisionSupport.returnAll(adapter, fixture.handoff)
        #expect(try fixture.handoff.state().plan.items.allSatisfy { $0.draft.targets.objects == fixture.taskTargets })
        fixture.beforeTransaction = nil
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        if adapter.pending != nil { try adapter.confirmPending(expecting: fixture.handoff.owned().lease) }
        #expect(fixture.todos.allSatisfy { $0.dayKey == "2026-10-11" })
        #expect(fixture.count("save") == 2 && fixture.count("ui") == 2)
        #expect(fixture.handoff.coordinator.revisionChain(HandoffFixture.source).first?.run == original)
    }

    @Test func fileSettingsRemainOneUnitAfterNotCalledReturn() throws {
        let fixture = try FileSettingCommandFixture()
        let first = try fixture.queue(FileSettingCommandFixture.paths[3])
        let group = try fixture.group(prepare: false)
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator, adapters: .init(fileSettings: fixture.adapter), supportsRevisions: true)
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff, maximum: 1)
        let original = try #require(fixture.state().execution)
        #expect(original.units[0].id == first && original.units[1].attempt == 0)
        _ = try MultiPlanRevisionSupport.returnAll(adapter, fixture.handoff)
        let plan = try fixture.state().plan
        #expect(plan.items.count == 2 && plan.items.allSatisfy { $0.atomicGroup == group })
        #expect(throws: CommandPlanError.grouped) { try fixture.handoff.plan(.dissolveGroup(group)) }
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        #expect(try fixture.state().execution?.units.count == 1 && fixture.state().execution?.units[0].state == .succeeded)
        #expect(fixture.store.metrics.snapshot().commits == 2 && fixture.store.metrics.snapshot().replacements == 2)
        #expect(fixture.prefs.language == .english && fixture.prefs.appearance == .dark)
    }

    @Test func fileKnownFailureRequiresBackendRecoveryBeforeReturn() throws {
        let fixture = try FileSettingCommandFixture(fault: .temporaryWrite)
        let group = try fixture.group(prepare: false)
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator, adapters: .init(fileSettings: fixture.adapter), supportsRevisions: true)
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        let original = try #require(fixture.state().execution)
        #expect(original.units[0].hasSafeLocalFailure && original.units[0].preferenceGroupCommit == .notCommitted)
        try fixture.adapter.recoverMultiBackend(#require(original.attempt(group)), expecting: fixture.owned().lease)
        _ = try MultiPlanRevisionSupport.returnAll(adapter, fixture.handoff)
        #expect(try fixture.state().plan.items.count == 2)
        #expect(fixture.store.metrics.snapshot().replacements == 0)
        #expect(fixture.handoff.coordinator.revisionChain(HandoffFixture.source).first?.run == original)
    }

    @Test func localSettingActualReadFailureReturnsWithoutTreatingBoolAsProof() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        _ = try fixture.queue(realBaseline: false)
        _ = try fixture.queue("setting.appearance", value: .choice("dark"), realBaseline: false)
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator,
            adapters: .init(localSettings: fixture.adapter), supportsRevisions: true)
        let preview = try adapter.prepare(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease)
        var failed = false
        fixture.io.onRead = { field, _ in
            if !failed && field == .appearance && !fixture.io.writes.isEmpty { failed = true; throw PreferenceCommandIO.Failure.injected }
        }
        try adapter.submit(preview, expecting: fixture.owned().lease)
        let original = try #require(fixture.state().execution)
        #expect(original.units[0].state == .succeeded && original.units[1].validationFailedBeforeInvocation)
        _ = try MultiPlanRevisionSupport.returnAll(adapter, fixture.handoff)
        fixture.io.onRead = nil
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        #expect(fixture.prefs.appearance == .dark && fixture.io.writes.count == 2)
    }

    @Test func routineMutationAndCreationReturnKeepReservedIdentity() throws {
        let fixture = try RoutineCreateFixture()
        try fixture.queue()
        try fixture.base.queue("routine.priority", .init(parameter: .priority, operation: .assign, value: .choice("p3")))
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator, adapters: .init(routine: fixture.adapter),
                                             outputCapability: .typedCreation, supportsRevisions: true)
        fixture.base.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        let original = try #require(fixture.handoff.state().execution)
        #expect(original.units.allSatisfy { $0.hasSafeLocalFailure })
        let producer = original.snapshot.items[0]
        let id = try #require(fixture.handoff.coordinator.taskCreations.routinePreparations[producer.draft.id]?.creationID)
        _ = try MultiPlanRevisionSupport.returnAll(adapter, fixture.handoff)
        try MultiPlanRevisionSupport.edit(producer.id, argument: RoutineCommandFixture.title("新习惯名"), handoff: fixture.handoff)
        fixture.base.beforeTransaction = nil
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        if adapter.pending != nil { try adapter.confirmPending(expecting: fixture.handoff.owned().lease) }
        #expect(try fixture.stored(id).title == "新习惯名")
        #expect(!fixture.base.routine.isImportant && fixture.base.routine.isUrgent)
        #expect(fixture.base.count("save") == 2 && fixture.base.count("ui") == 2)
    }

    @Test func routinePriorityAndFileSettingsMergeUseTheirRealReaders() throws {
        let routine = try RoutineCommandFixture()
        for value in ["p3", "p1"] { try routine.queue("routine.priority", .init(parameter: .priority, operation: .assign, value: .choice(value))) }
        let adapter = MultiPlanCommandAdapter(coordinator: routine.handoff.coordinator, adapters: .init(routine: routine.adapter), supportsRevisions: true)
        let items = try routine.handoff.state().plan.items
        let proposal = try adapter.proposeMerge(items[0].stamp, items[1].stamp, expecting: routine.handoff.owned().lease)
        try adapter.acceptMerge(proposal, expecting: routine.handoff.owned().lease)
        try MultiPlanRevisionSupport.start(adapter, routine.handoff)
        #expect(routine.routine.isImportant && routine.routine.isUrgent && routine.count("save") == 1)

        let settings = try FileSettingCommandFixture()
        _ = try settings.queue("/setting/appearance/light")
        _ = try settings.queue("/setting/appearance/dark")
        let file = MultiPlanCommandAdapter(coordinator: settings.handoff.coordinator, adapters: .init(fileSettings: settings.adapter), supportsRevisions: true)
        let group = try settings.state().plan.items
        try file.acceptMerge(file.proposeMerge(group[0].stamp, group[1].stamp, expecting: settings.owned().lease), expecting: settings.owned().lease)
        try MultiPlanRevisionSupport.start(file, settings.handoff)
        #expect(settings.prefs.appearance == .dark && settings.store.metrics.snapshot().commits == 1)
    }
}
