import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchSettingContractTests {
    @Test(arguments: 0..<4)
    func beginsWithRealBaselineBeforeParametersAndPublishesRevision(index: Int) throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        let controller = fixture.controller
        let old = controller.buffer
        controller.syntheticBaselines[.init(rawValue: UnifiedSearchSettingSamples.ids[index])] = .init([
            .init(subject: .ambient, parameter: .value): .uniform(.choice("synthetic"))])
        try fixture.start(UnifiedSearchSettingSamples.ids[index], value: nil)
        let baseline = try #require(fixture.draft.baseline.preference)
        #expect(try fixture.draft.arguments.isEmpty)
        #expect(baseline.instanceID == fixture.prefs.localPreferenceSource.instanceID)
        #expect(baseline.raw == .missing && baseline.memory != .choice("synthetic"))
        #expect(controller.buffer.lease.revision >= old.lease.revision + 2)
        #expect(try controller.buffer.operation == fixture.draft.stamp)
        #expect(controller.buffer.lease == (try fixture.results.handoff.owned().lease))
        #expect(!controller.validates(old))
        let reads = fixture.io.reads
        for _ in 0..<4 { controller.prepareSettingDraft(); controller.refreshOperationPresentation() }
        #expect(fixture.io.reads == reads)
        try fixture.edit(UnifiedSearchSettingSamples.values[index])
        #expect(try fixture.draft.baseline.preference == baseline)
        #expect(fixture.io.writes.isEmpty && fixture.io.local.appearances.isEmpty && fixture.io.local.events.isEmpty)
    }

    @Test func unreadableBaselineDoesNotInventDefaultAndCanBeReadExplicitly() throws {
        let io = try PreferenceCommandIO()
        io.local.defaults.set("invalid", forKey: AppPreferences.languageKey)
        let fixture = try UnifiedSearchSettingFixture(io: io)
        defer { fixture.stop() }
        try fixture.start()
        #expect(try fixture.draft.baseline.preference == nil)
        fixture.submit()
        #expect(fixture.io.writes.isEmpty && fixture.controller.settingExecution == nil)
        fixture.prefs.language = .system
        fixture.io.resetCounts()
        fixture.controller.requestSettingBaseline(source: fixture.controller.buffer)
        #expect(try fixture.draft.baseline.preference?.memory == .choice("system"))
        #expect(fixture.io.writes.isEmpty)
    }

    @Test func singleDraftTransfersUniqueIdentityAndSuccessfulReleaseIsExplicit() throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start()
        let draft = try fixture.draft
        let source = fixture.controller.buffer
        fixture.io.onWrite = {
            fixture.controller.requestOperationSubmit(source)
            #expect(fixture.controller.settingSubmitting)
            #expect(fixture.controller.operations?.active == nil)
            #expect(fixture.controller.plan?.items.isEmpty == true)
            #expect(fixture.controller.settingExecution?.snapshot.items.first?.draft.id == draft.id)
        }
        fixture.submit()
        fixture.controller.requestOperationSubmit(source)
        #expect(fixture.io.writes == [.language(.english)])
        #expect(try fixture.unit.local == .committed && fixture.unit.state == .succeeded)
        let report = try fixture.report
        #expect(try fixture.run.snapshot.items.first?.draft.id == draft.id)
        #expect(throws: CommandHandoffError.ineligible) { try fixture.results.handoff.transfer() }
        fixture.controller.acknowledgeSettingResult(report, source: fixture.controller.buffer)
        #expect(fixture.controller.settingExecution == nil)
        fixture.controller.acknowledgeSettingResult(report, source: source)
        #expect(fixture.io.writes.count == 1)
    }

    @Test func planOnlySubmitsAndMixedOrMultiplePlansNeverPartiallyWrite() throws {
        for count in [1, 2] {
            let fixture = try UnifiedSearchSettingFixture()
            defer { fixture.stop() }
            try fixture.start(); try fixture.queue()
            if count == 2 { try fixture.start("setting.appearance", value: .choice("dark")); try fixture.queue() }
            let plan = fixture.controller.plan
            fixture.submit()
            if count == 1 { #expect(fixture.io.writes == [.language(.english)]) }
            else { #expect(fixture.io.writes.isEmpty && fixture.controller.plan == plan) }
        }
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start(); try fixture.queue()
        try fixture.start("setting.appearance", value: .choice("dark"))
        let active = try fixture.draft
        fixture.submit()
        #expect(fixture.io.writes.isEmpty && fixture.controller.settingExecution == nil)
        #expect(try fixture.draft == active && fixture.controller.plan?.items.count == 1)
    }

    @Test func editingPendingAndReferencesRemainIneligible() throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start(); try fixture.queue()
        let item = try #require(fixture.controller.plan?.items.first)
        fixture.controller.beginPlanEditing(item.stamp, source: fixture.controller.buffer)
        fixture.submit()
        #expect(fixture.io.writes.isEmpty && fixture.controller.plan?.editing == item.id)
        fixture.controller.endPlanEditing(try #require(fixture.controller.editingPlanItem?.stamp), source: fixture.controller.buffer)
        try fixture.start("setting.appearance", value: .choice("dark"))
        try fixture.results.startOperation("setting.truncation")
        #expect(fixture.controller.operations?.pending != nil)
        fixture.submit()
        #expect(fixture.io.writes.isEmpty && fixture.controller.settingExecution == nil)
    }

    @Test func unassembledAndOtherCommandsStayUnavailable() throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start("clipboard.limit", value: .number(25))
        fixture.submit()
        #expect(fixture.io.writes.isEmpty && fixture.controller.settingExecution == nil)
        #expect(fixture.controller.settingIssue == .unsupported)
        let unwired = try UnifiedSearchResultsFixture()
        defer { unwired.stop() }
        try unwired.startOperation("setting.language")
        unwired.controller.requestOperationSubmit(unwired.controller.buffer)
        #expect(unwired.controller.settingExecution == nil)
        #expect(unwired.controller.operationMessage == "unified.operation.submitBlocked")
        #expect(CommandCatalog.standard.entries.allSatisfy { !$0.isExecutable })
    }
}
