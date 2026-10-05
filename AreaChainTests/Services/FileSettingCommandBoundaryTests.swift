import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct FileSettingCommandBoundaryTests {
    @Test func ungroupedDuplicateAndMultipleGroupsNeverSealOrWrite() throws {
        let ungrouped = try FileSettingCommandFixture()
        try ungrouped.queue(FileSettingCommandFixture.paths[0])
        try ungrouped.queue(FileSettingCommandFixture.paths[1])
        let before = try ungrouped.owned()
        #expect(throws: FileLocalSettingCommandIssue.needsExplicitGroup) { try ungrouped.prepareGroup() }
        #expect(throws: FileLocalSettingCommandIssue.needsExplicitGroup) { try ungrouped.submit() }
        #expect(try ungrouped.owned() == before && ungrouped.store.metrics.snapshot().commits == 0)
        let duplicate = try FileSettingCommandFixture()
        let pair = try [duplicate.queue(FileSettingCommandFixture.paths[0]), duplicate.queue(FileSettingCommandFixture.paths[0])]
        try duplicate.handoff.plan(.atomicGroup(UUID(), members: pair))
        #expect(throws: FileLocalSettingCommandIssue.duplicateFields([.language])) { try duplicate.prepareGroup() }
        #expect(duplicate.store.metrics.snapshot().commits == 0)
        let multiple = try FileSettingCommandFixture()
        var ids: [UUID] = []
        for path in FileSettingCommandFixture.paths { ids.append(try multiple.queue(path)) }
        try multiple.handoff.plan(.atomicGroup(UUID(), members: Array(ids.prefix(2))))
        try multiple.handoff.plan(.atomicGroup(UUID(), members: Array(ids.suffix(2))))
        #expect(throws: FileLocalSettingCommandIssue.unsupportedScope) { try multiple.prepareGroup() }
        #expect(multiple.store.metrics.snapshot().commits == 0)
    }

    @Test func strictArgumentsTargetsProtectionAndMixedCommandsRejected() throws {
        let fixture = try FileSettingCommandFixture()
        let invalid: [[CommandArgument]] = [[], [.init(parameter: .value, operation: .assign, value: nil)],
            [PlanFixture.argument(.value, .choice("unknown"))], [PlanFixture.argument(.value, .shortText("english"))],
            [.init(parameter: .value, operation: .clear, value: nil)],
            [PlanFixture.argument(.enabled, .boolean(true))],
            [PlanFixture.argument(.value, .choice("english")), PlanFixture.argument(.value, .choice("english"))]]
        for arguments in invalid {
            let item = CommandPlanItem(id: UUID(), draft: .init(id: UUID(), hostID: HandoffFixture.source,
                commandID: .init(rawValue: "setting.language"), arguments: arguments))
            #expect(throws: LocalSettingCommandIssue.invalidArguments) { try FileLocalSettingCommandMapping.values([item]) }
        }
        let ordinary = HandoffFixture.setting()
        let targeted = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: ordinary.commandID,
            targets: .init(.single, objects: [.init(type: .todo, id: UUID())]), arguments: ordinary.arguments)
        #expect(throws: LocalSettingCommandIssue.invalidTargets) {
            try FileLocalSettingCommandMapping.values([.init(id: UUID(), draft: targeted)])
        }
        let protected = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: ordinary.commandID,
            arguments: ordinary.arguments, protectionRequirement: .required)
        #expect(throws: LocalSettingCommandIssue.protectedContent) {
            try FileLocalSettingCommandMapping.values([.init(id: UUID(), draft: protected)])
        }
        try fixture.queue(FileSettingCommandFixture.paths[0])
        try fixture.handoff.queue(CommandIntegrationFixture.creation(host: HandoffFixture.source))
        #expect(throws: LocalSettingCommandIssue.unsupported) { try fixture.prepareGroup() }
        #expect(fixture.store.metrics.snapshot().commits == 0)
    }

    @Test func linksActiveDraftPendingAndEditingAreNotHiddenByGroupPreparation() throws {
        let fixture = try FileSettingCommandFixture()
        try fixture.group(prepare: false)
        let items = try fixture.state().plan.items
        try fixture.handoff.plan(.beginEditing(items[0].stamp))
        #expect(throws: FileLocalSettingCommandIssue.busy) { try fixture.prepareGroup() }
        try fixture.handoff.plan(.endEditing(items[0].stamp, .finish))
        try fixture.handoff.start(HandoffFixture.setting())
        #expect(throws: FileLocalSettingCommandIssue.busy) { try fixture.prepareGroup() }
        try fixture.handoff.start(HandoffFixture.setting(value: "english"))
        #expect(try fixture.state().operations.pending != nil)
        #expect(throws: FileLocalSettingCommandIssue.busy) { try fixture.prepareGroup() }
        var linked = items[0]
        linked.links = .init(predecessors: [UUID()])
        #expect(throws: FileLocalSettingCommandIssue.unsupportedScope) { try FileLocalSettingCommandMapping.values([linked]) }
        linked.links = .init(results: [.value: .init(producer: items[1].stamp, outputType: .todo)])
        #expect(throws: FileLocalSettingCommandIssue.unsupportedScope) { try FileLocalSettingCommandMapping.values([linked]) }
        #expect(fixture.store.metrics.snapshot().commits == 0)
    }

    @Test func fabricatedAndForeignEvidenceCannotAcquireWriteQualification() throws {
        let fixture = try FileSettingCommandFixture()
        try fixture.group()
        let evidence = try #require(fixture.state().plan.items.first?.draft.baseline.preferenceGroup)
        let other = try FileLocalSettingCommandAdapter(coordinator: fixture.handoff.coordinator, filePreferences: fixture.prefs)
        #expect(throws: FileLocalSettingCommandIssue.untrustedBaseline) {
            try other.readiness(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease)
        }
        let item = try fixture.state().plan.items[0]
        let forged = CommandPreferenceGroupBaseline(captureID: UUID(), issuerID: evidence.issuerID,
            instanceID: evidence.instanceID, storageID: evidence.storageID, record: evidence.record, migrationID: evidence.migrationID,
            fieldRevisions: evidence.fieldRevisions, values: evidence.values, groupID: evidence.groupID,
            members: evidence.members, drafts: evidence.drafts, commands: evidence.commands)
        let baseline = CommandDraftBaseline(item.draft.baseline.values, preferenceGroup: forged)
        try fixture.handoff.coordinator.replacePreferenceBaseline(baseline, arguments: item.draft.arguments,
            draft: item.draft.stamp, expecting: fixture.owned().lease)
        let before = try fixture.owned()
        #expect(throws: FileLocalSettingCommandIssue.untrustedBaseline) { try fixture.prepareGroup() }
        #expect(try fixture.owned() == before && fixture.store.metrics.snapshot().commits == 0)
    }

    @Test func staleLeaseGroupMemberAttemptAndRunRejectBeforeIO() throws {
        let fixture = try FileSettingCommandFixture()
        try fixture.group()
        let request = try fixture.request()
        let changedMember = CommandPlanItemStamp(id: request.identity.members[0].id, version: request.identity.members[0].version + 1)
        let identities = [
            CommandPreferenceGroupIdentity(execution: request.identity.execution, unitID: request.identity.members[0].id,
                groupID: request.identity.groupID, members: request.identity.members),
            CommandPreferenceGroupIdentity(execution: request.identity.execution, unitID: request.identity.unitID,
                groupID: request.identity.groupID, members: [changedMember] + request.identity.members.dropFirst())]
        for identity in identities {
            #expect(throws: FileLocalSettingCommandIssue.stale) {
                try fixture.adapter.execute(.init(lease: request.lease, identity: identity, attempt: request.attempt))
            }
        }
        let future = CommandAttemptStamp(execution: request.attempt.execution, unitID: request.attempt.unitID, number: 2, phase: .local)
        #expect(throws: FileLocalSettingCommandIssue.stale) {
            try fixture.adapter.execute(.init(lease: request.lease, identity: request.identity, attempt: future))
        }
        try fixture.handoff.send(.query(.privacyInvalidated))
        #expect(throws: CommandHandoffError.stale) { try fixture.adapter.execute(request) }
        #expect(fixture.store.metrics.snapshot().commits == 0)
    }

    @Test func reentryMultipleAdaptersAndLateCompletionCannotDuplicateCommit() throws {
        let fixture = try FileSettingCommandFixture()
        try fixture.group()
        let request = try fixture.request()
        let other = try FileLocalSettingCommandAdapter(coordinator: fixture.handoff.coordinator, filePreferences: fixture.prefs)
        fixture.io.onAppearance = {
            #expect(throws: FileLocalSettingCommandIssue.busy) { try fixture.adapter.execute(request) }
            #expect(throws: (any Error).self) { try other.execute(request) }
            #expect(throws: CommandExecutionError.busy) {
                try fixture.handoff.send(.result(.init(attempt: request.attempt, result: .failedWithoutCommit)))
            }
            _ = try? fixture.handoff.send(.query(.privacyInvalidated))
        }
        let report = try fixture.adapter.execute(request)
        #expect(try fixture.unit().local == .committed && fixture.unit().receipt == report.presentationReceipt)
        #expect(throws: CommandHandoffError.stale) { try other.execute(request) }
        #expect(throws: CommandHandoffError.ineligible) { try fixture.handoff.prepare() }
        #expect(fixture.store.metrics.snapshot().commits == 1 && fixture.store.metrics.snapshot().replacements == 1)
        #expect(fixture.io.events.count == 1)
    }

    @Test func sharedCoordinatorOccupationPrecedesEveryAdapterCall() throws {
        let fixture = try FileSettingCommandFixture()
        try fixture.group()
        let request = try fixture.request()
        let invocation = try fixture.handoff.coordinator.claimPreferenceGroup(request.identity, attempt: request.attempt, expecting: request.lease)
        #expect(throws: CommandExecutionError.stale) { try fixture.adapter.execute(request) }
        #expect(fixture.store.metrics.snapshot().commits == 0)
        try fixture.handoff.coordinator.recordPreferenceGroup(invocation, result: .notCommitted)
        try fixture.handoff.coordinator.finishPreferenceGroup(invocation)
        #expect(throws: CommandHandoffError.stale) { try fixture.adapter.execute(request) }
    }
}
