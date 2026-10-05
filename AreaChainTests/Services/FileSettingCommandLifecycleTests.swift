import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct FileSettingCommandLifecycleTests {
    @Test(arguments: [false, true])
    func displayLossBeforeCommitRejectsAndAfterCommitKeepsOriginalFacts(lockAfter: Bool) throws {
        let fixture = try FileSettingCommandFixture()
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        let center = NotificationCenter()
        let session = try ContentQueryReadSession(vault: vault, coordinator: fixture.handoff.coordinator,
            ownership: fixture.owned().lease.ownership,
            notifications: .init(privacy: center, model: center, focus: center,
                                 focusLost: .init("synthetic.fileSetting.focusLost"), focusObject: NSObject()))
        session.install()
        defer { session.detach() }
        try fixture.group()
        let request = try fixture.request()
        try session.loseFocus(expecting: request.lease.ownership)
        let rejected = try fixture.adapter.execute(request, displaySession: session)
        #expect(rejected.localReceipt.result == .preferenceGroupCommit(.notCommitted))
        #expect(fixture.store.metrics.snapshot().commits == 0)
        try fixture.adapter.returnUnsubmittedToPlan(request.attempt, expecting: fixture.owned().lease)
        try fixture.prepareGroup()
        try session.resumeDisplay(expecting: fixture.owned().lease)
        fixture.io.onAppearance = {
            if lockAfter { center.post(name: .privacyWillLock, object: vault) }
            else {
                try? session.loseFocus(expecting: request.lease.ownership)
                _ = try? fixture.handoff.send(.query(.privacyInvalidated))
            }
        }
        let report = try fixture.adapter.submit(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease, displaySession: session)
        #expect(!session.hasPublicationPermit)
        if !lockAfter { #expect(session.isMasked) }
        #expect(try fixture.state().query.binding == .independent(.privacyInvalidated))
        #expect(try fixture.unit().local == .committed && fixture.unit().receipt == report.presentationReceipt)
        #expect(report.identity.execution != request.identity.execution)
        #expect(fixture.store.metrics.snapshot().commits == 1)
        #expect(throws: (any Error).self) { try session.validateDisplayHost(expecting: request.lease) }
        #expect(throws: FileLocalSettingCommandIssue.notRetryable) {
            try fixture.adapter.returnUnsubmittedToPlan(report.localReceipt.attempt, expecting: fixture.owned().lease)
        }
    }

    @Test func readonlyAndUnreadableBackendsCannotSignOrSubmit() throws {
        let fixture = try FileSettingCommandFixture()
        try fixture.group(prepare: false)
        let before = try fixture.owned()
        let starts: [LocalPreferenceMigrationResult] = [.notMigrated(readOnly: .legacyDefaults),
            .conflict(.sourceChanged), .failed(.legacyReadFailed(.language)),
            .recoveryRequired(.backend(.blocked(.unavailable(.corrupt))))]
        for startup in starts {
            let prefs = try fixture.io.preferences(startup)
            let adapter = try FileLocalSettingCommandAdapter(coordinator: fixture.handoff.coordinator, filePreferences: prefs)
            #expect(throws: FileLocalSettingCommandIssue.backendNotReady) {
                try adapter.prepareGroup(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease)
            }
        }
        #expect(try fixture.owned() == before && fixture.store.metrics.snapshot().commits == 0)
        let unreadable = try FileSettingCommandFixture(fault: .readCurrent)
        try unreadable.group(prepare: false)
        #expect(throws: FileLocalSettingCommandIssue.backendNotReady) { try unreadable.prepareGroup() }
        #expect(unreadable.store.metrics.snapshot().commits == 0)
    }

    @Test func preparationRejectsUnknownPayloadAndAtomicInstallCannotPartiallySucceed() throws {
        let fixture = try FileSettingCommandFixture()
        try fixture.group(prepare: false)
        let before = try fixture.owned()
        let updates = before.session.plan.items.map { item in
            CommandPreferenceBaselineUpdate(draft: .init(hostID: item.draft.hostID, draftID: item.draft.id,
                version: item.draft.version + (item.id == before.session.plan.items.last?.id ? 1 : 0)),
                baseline: .init(), arguments: item.draft.arguments)
        }
        #expect(throws: CommandPlanError.stale) {
            try fixture.handoff.coordinator.replacePreferenceGroupBaselines(updates,
                plan: before.session.plan.stamp, expecting: before.lease)
        }
        #expect(try fixture.owned() == before)
        let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "setting.language"),
            arguments: [PlanFixture.argument(.value, .choice("english"))], protectionRequirement: .unknown)
        #expect(throws: LocalSettingCommandIssue.protectedContent) {
            try FileLocalSettingCommandMapping.values([.init(id: UUID(), draft: draft)])
        }
        #expect(fixture.store.metrics.snapshot().commits == 0)
    }

    @Test func narrowGroupPresentationDoesNotPermitGenericExternalEffects() throws {
        let fixture = try FileSettingCommandFixture()
        try fixture.group()
        let request = try fixture.request()
        for effects: Set<CommandExternalEffect> in [[.notification], [.calendar], [.preferencePresentation]] {
            #expect(throws: CommandExecutionError.invalidResult) {
                try fixture.handoff.result(.committed(outputs: [:], external: effects), attempt: request.attempt)
            }
        }
        #expect(try fixture.unit().local == .notSubmitted && fixture.unit().effects.isEmpty)
        #expect(fixture.store.metrics.snapshot().commits == 0)
    }
}
