import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchPlanRevisionBoundaryTests {
    let support = UnifiedSearchPlanRevisionTests()

    @Test func nativeSettingsGroupReturnsTogetherThenCommitsOnce() async throws {
        let settings = try FileSettingCommandFixture()
        let fields = try TaskFieldCommandFixture()
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        let fixture = try UnifiedSearchResultsFixture(QueryBatchFixture.empty("/tasks"), filePreferences: settings.prefs,
            privacyCenter: NotificationCenter(), taskFieldEnvironment: fields.environment, enableMultiPlan: true,
            outputCapability: .typedCreation, enablePlanRevisions: true)
        defer { fixture.stop() }
        let controller = fixture.controller!
        try support.queueFields(fixture, fields: fields, kinds: [0])
        let first = try #require(controller.plan?.items.first)
        let language = try fixture.enqueueOperation("setting.language", arguments: [.init(parameter: .value, operation: .assign, value: .choice("english"))])
        let appearance = try fixture.enqueueOperation("setting.appearance", arguments: [.init(parameter: .value, operation: .assign, value: .choice("dark"))])
        controller.addPredecessor(first.id, item: language.stamp, source: controller.buffer)
        controller.groupAdjacentSettings(try fixture.planItem(language.id).stamp, source: controller.buffer)
        let group = try #require(controller.plan?.items.last?.atomicGroup)
        fields.io.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        _ = try await fixture.publish()
        let host = support.support.makeHost(controller, compact: true)
        defer { host.close() }
        try await host.start()
        try await host.clickCompositionControl("unified.multi.prepare")
        try await support.submit(host, controller: controller)
        #expect(controller.settingExecution?.units[1].members == [language.id, appearance.id])
        #expect(controller.settingExecution?.units[1].attempt == 0)
        try await host.clickCompositionControl("unified.revision.return")
        #expect(controller.plan?.items.filter { $0.atomicGroup == group }.count == 2)
        fields.io.beforeTransaction = nil
        try await host.clickCompositionControl("unified.multi.prepare")
        try await support.submit(host, controller: controller)
        #expect(controller.settingExecution?.units.allSatisfy { $0.state == .succeeded } == true)
        #expect(settings.store.metrics.snapshot().commits == 1 && settings.store.metrics.snapshot().replacements == 1)
        #expect(settings.prefs.language == .english && settings.prefs.appearance == .dark)
        #expect(fields.count("save") == 1 && fields.count("ui") == 1)
        try await host.revealSettingControlInsidePanel("unified.multi.unit." + group.uuidString)
        try host.snapshot("pm3-settings-group-result")
    }

    @Test func nativeBatchReturnsFixedTargetsAndRetriesWholeUnit() async throws {
        let batch = try BatchCommandFixture()
        let fixture = try UnifiedSearchResultsFixture(QueryBatchFixture.empty("/tasks"), privacyCenter: NotificationCenter(),
            batchEnvironment: batch.environment, enableMultiPlan: true, outputCapability: .typedCreation, enablePlanRevisions: true)
        defer { fixture.stop() }
        let controller = fixture.controller!
        for day in ["2026-10-09", "2026-10-11"] {
            try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "batch.move"),
                targets: .init(.selected, objects: batch.taskTargets), arguments: [.init(parameter: .day, operation: .assign, value: .day(day))]))
        }
        _ = controller.publishOperation(text: "")
        batch.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        _ = try await fixture.publish()
        let host = support.support.makeHost(controller, compact: false)
        defer { host.close() }
        try await host.start()
        try await host.clickCompositionControl("unified.multi.prepare")
        try await support.submit(host, controller: controller)
        try await host.clickCompositionControl("unified.revision.return")
        #expect(controller.plan?.items.allSatisfy { $0.draft.targets.objects == batch.taskTargets } == true)
        batch.beforeTransaction = nil
        try await host.clickCompositionControl("unified.multi.prepare")
        try await support.submit(host, controller: controller)
        try await host.clickCompositionControl("unified.multi.confirm")
        try await support.support.settle(host, controller)
        #expect(batch.todos.allSatisfy { $0.dayKey == "2026-10-11" })
        #expect(batch.count("save") == 2 && batch.count("ui") == 2)
        #expect(controller.settingExecution?.units.count == 2)
        try await host.revealSettingControlInsidePanel("unified.multi.progress")
        try host.snapshot("pm3-batch-result")
    }

    @Test(arguments: [false, true]) func nativeUnknownOrExternalPendingRejectsReturn(external: Bool) async throws {
        let fields = try TaskFieldCommandFixture()
        let fixture = try support.fieldFixture(fields)
        defer { fixture.stop() }
        let controller = fixture.controller!
        try support.queueFields(fixture, fields: fields, kinds: [0, 1])
        if external { fields.io.notificationResult = .failed }
        else { fields.io.saveMode = .throwAfter }
        _ = try await fixture.publish()
        let host = support.support.makeHost(controller, compact: true)
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        editor.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: editor.selectedRange())
        controller.prepareMultiPlan(controller.buffer)
        #expect(controller.multiPlan?.preview == nil)
        editor.unmarkText()
        try await host.clickCompositionControl("unified.multi.prepare")
        let old = controller.buffer
        try await support.submit(host, controller: controller)
        let original = try #require(controller.settingExecution)
        #expect(external ? original.units[0].local == .committed : original.hasUnknownCommit)
        let saves = fields.count("save")
        try await host.clickCompositionControl("unified.revision.return")
        #expect(controller.settingExecution == original && controller.plan?.items.isEmpty == true)
        #expect(controller.coordinator.revisionChain(HandoffFixture.source).isEmpty)
        controller.returnMultiPlan(old)
        #expect(controller.settingExecution == original && fields.count("save") == saves)
        try await host.revealSettingControlInsidePanel("unified.multi.issue")
        try host.snapshot("pm3-return-refused-\(external)")
    }

    @Test func nativeReturnedDraftSurvivesMarkedTextFocusLossAndLock() async throws {
        let fields = try TaskFieldCommandFixture()
        let privacy = NotificationCenter()
        let fixture = try support.fieldFixture(fields, privacy: privacy)
        defer { fixture.stop() }
        let controller = fixture.controller!
        try support.queueFields(fixture, fields: fields, kinds: [0, 1])
        fields.io.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        _ = try await fixture.publish()
        let host = support.support.makeHost(controller, compact: false)
        defer { host.close() }
        try await host.start()
        try await host.clickCompositionControl("unified.multi.prepare")
        try await support.submit(host, controller: controller)
        try await host.clickCompositionControl("unified.revision.return")
        let plan = try #require(controller.plan)
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        let editor = try host.editor
        editor.setMarkedText("保留", selectedRange: .init(location: 2, length: 0), replacementRange: editor.selectedRange())
        let old = controller.buffer
        controller.prepareMultiPlan(old)
        try await host.key(36, "\r", flags: .command)
        #expect(controller.multiPlan?.preview == nil && controller.settingExecution == nil)
        editor.unmarkText()
        try fixture.session.loseFocus(expecting: old.lease.ownership)
        controller.prepareMultiPlan(old)
        #expect(controller.plan?.items == plan.items && fields.count("save") == 0)
        try fixture.session.resumeDisplay(expecting: controller.buffer.lease)
        controller.refreshOperationPresentation()
        try await host.settle()
        fields.io.beforeTransaction = nil
        try await host.clickCompositionControl("unified.multi.prepare")
        #expect(controller.currentMultiPlanPreview != nil && fields.count("save") == 0)
        try host.snapshot("pm3-return-display-reaccept")
        let acceptedSource = controller.buffer
        privacy.post(name: .privacyWillLock, object: fixture.vault)
        controller.requestOperationSubmit(acceptedSource)
        #expect(controller.plan?.items == plan.items && controller.settingExecution == nil && fields.count("save") == 0)
        #expect(controller.currentMultiPlanPreview == nil)
    }
}
