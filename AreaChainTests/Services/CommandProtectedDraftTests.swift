import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CommandProtectedDraftTests {
    @Test func initialCheckpointAndExplicitRestorePreserveContents() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        let original = try f.draft()
        let reference = try f.protect()
        let draft = try f.draft()
        #expect(draft.protectedReference == reference)
        #expect(draft.version == original.version + 1)
        #expect(draft.arguments.isEmpty && !draft.baseline.isReadable)
        #expect(draft.check().parameterCompleteness == .protectedUnknown)
        #expect(draft.modification == .modified)
        let contents = try f.contents(f.restore())
        #expect(contents.arguments == original.arguments)
        #expect(contents.baseline == original.baseline)
        #expect(contents.editing.first?.spelling == "合成未完成🙂")
        #expect(contents.editing.first?.selectionLocation == 2)
    }

    @Test func unconfiguredConversionKeepsOrdinaryMemoryDraft() throws {
        let f = try ProtectedDraftFixture(configured: false)
        try f.start()
        let old = try f.host.owned()
        #expect(throws: CommandDraftProtectionError.notProtected) { try f.protect() }
        #expect(try f.host.owned() == old)
        #expect(try f.draft().protectedReference == nil)
        try f.host.send(.operation(.edit(f.draft().stamp,
            .init(parameter: .notes, operation: .replace, value: .longText("ordinary-edit")))))
        #expect(try f.draft().arguments.first?.value == .longText("ordinary-edit"))
    }

    @Test func eachAcceptedRevisionHasMatchingRecoveryAndRejectsOldAccess() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        let first = try f.protect()
        let oldHost = try f.host.owned()
        for index in 1...3 {
            let access = try f.restore()
            var contents = try f.contents(access)
            contents.arguments[0].value = .longText("synthetic-revision-\(index)")
            let next = try f.service.acceptRevision(contents, using: access)
            #expect(next.payloadID == first.payloadID && next.revision != first.revision)
            #expect(throws: (any Error).self) { try f.contents(access) }
            #expect(try f.contents(f.restore()) == contents)
        }
        #expect(throws: (any Error).self) {
            try f.service.explicitlyRestore(#require(oldHost.session.operations.active).stamp, expecting: oldHost.lease)
        }
    }

    @Test func encodingAndKeyFailureKeepPreviousAcceptedRevision() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        _ = try f.protect()
        let access = try f.restore()
        let original = try f.contents(access)
        let host = try f.host.owned()
        var candidate = original
        candidate.arguments[0].value = .number(.nan)
        #expect(throws: CommandDraftProtectionError.revisionNotAccepted) {
            try f.service.acceptRevision(candidate, using: access)
        }
        #expect(try f.host.owned() == host)
        #expect(try f.contents(access) == original)
        f.vault.keys.clear()
        #expect(throws: CommandDraftProtectionError.revisionNotAccepted) {
            try f.service.acceptRevision(original, using: access)
        }
        #expect(try f.host.owned() == host)
        try f.unlock()
        #expect(try f.contents(f.restore()) == original)
    }

    @Test func injectedSealFailuresNeverAcceptUnrecoverableDrafts() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        let ordinary = try f.host.owned()
        SealedCommandDraft.testingBeforeSeal = { throw PrivacyError.corruptData }
        defer { SealedCommandDraft.testingBeforeSeal = nil }
        #expect(throws: CommandDraftProtectionError.notProtected) { try f.protect() }
        #expect(try f.host.owned() == ordinary)
        SealedCommandDraft.testingBeforeSeal = nil
        _ = try f.protect()
        let access = try f.restore()
        var candidate = try f.contents(access)
        candidate.arguments[0].value = .longText("unaccepted-synthetic")
        let accepted = try f.host.owned()
        SealedCommandDraft.testingBeforeSeal = { throw PrivacyError.corruptData }
        #expect(throws: CommandDraftProtectionError.revisionNotAccepted) {
            try f.service.acceptRevision(candidate, using: access)
        }
        #expect(try f.host.owned() == accepted)
        #expect(try f.contents(f.restore()).arguments.first?.value == .longText("synthetic-body"))
    }

    @Test func recoveryInvalidatedAfterDecryptionCannotPublish() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        _ = try f.protect()
        SealedCommandDraft.testingAfterOpen = { f.vault.lock() }
        defer { SealedCommandDraft.testingAfterOpen = nil }
        #expect(throws: (any Error).self) { try f.restore() }
        SealedCommandDraft.testingAfterOpen = nil
        try f.unlock()
        #expect(try f.contents(f.restore()).arguments.first?.value == .longText("synthetic-body"))
    }

    @Test func lockRevokesAccessAndUnlockDoesNotRestoreIt() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        _ = try f.protect()
        let access = try f.restore()
        let original = try f.contents(access)
        f.vault.lock()
        #expect(throws: (any Error).self) { try f.contents(access) }
        #expect(throws: (any Error).self) { try f.restore() }
        try f.unlock()
        #expect(throws: (any Error).self) { try f.contents(access) }
        #expect(try f.contents(f.restore()) == original)
    }

    @Test func willLockClosesAccessBeforeVaultGenerationChanges() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        _ = try f.protect()
        let access = try f.restore()
        let generation = f.vault.generation
        NotificationCenter.default.post(name: .privacyWillLock, object: f.vault)
        #expect(f.vault.generation == generation)
        #expect(throws: (any Error).self) { try f.contents(access) }
        #expect(throws: (any Error).self) { try f.restore() }
    }

    @Test func lateBorrowAndHostEventsInvalidateOldQualification() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        _ = try f.protect()
        let access = try f.restore()
        #expect(throws: (any Error).self) {
            try f.service.withRestoredContents(access) { _ in f.vault.lock() }
        }
        try f.unlock()
        let fresh = try f.restore()
        try f.host.send(.query(.privacyInvalidated))
        #expect(throws: (any Error).self) { try f.contents(fresh) }
        _ = try f.restore()
    }

    @Test func wrongKeyRecoveryFailureKeepsOriginalCiphertext() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        let reference = try f.protect()
        let config = try #require(f.vault.configuration)
        f.vault.keys.install(Data(repeating: 7, count: 32), vaultID: config.vaultID)
        #expect(throws: CommandDraftProtectionError.invalidPayload) { try f.restore() }
        #expect(try f.draft().protectedReference == reference)
        try f.unlock()
        #expect(try f.contents(f.restore()).arguments.first?.value == .longText("synthetic-body"))
    }

    @Test func retainedPendingAndPlanKeepProtectionAndRejectOrdinaryMutation() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        _ = try f.protect()
        let original = try f.draft()
        let transition = CommandDraftReducer.reduce(try f.host.state().operations,
            .edit(original.stamp, .init(parameter: .notes, operation: .clear, value: nil)))
        #expect(transition.intents == [.rejectedEvent])
        try f.host.start(HandoffFixture.setting())
        #expect(try f.host.state().operations.unsavedDrafts.count == 2)
        let decision = try #require(f.host.state().operations.pending)
        #expect(throws: CommandDraftProtectionError.notProtected) {
            if case .start(let incoming) = decision.destination {
                try f.service.protect(incoming.stamp, expecting: f.host.owned().lease)
            }
        }
        try f.host.send(.operation(.resolve(decision, .retain)))
        let retained = try #require(f.host.state().operations.retained.first)
        #expect(retained.protectedReference == original.protectedReference)
        let itemID = UUID()
        try f.host.send(.enqueue(retained.stamp, itemID: itemID, plan: f.host.state().plan.stamp))
        let item = try #require(f.host.state().plan.items.first)
        #expect(try f.host.state().requiresUnsavedContentHandling)
        #expect(try f.host.state().plan.check().items.first?.status == .blocked)
        #expect(throws: CommandPlanError.protectedContent) { try f.host.seal() }
        try f.host.plan(.beginEditing(item.stamp))
        #expect(throws: CommandPlanError.protectedContent) {
            try f.host.plan(.edit(item.stamp, .init(parameter: .notes, operation: .clear, value: nil)))
        }
        let access = try f.service.explicitlyRestore(item.draft.stamp, expecting: f.host.owned().lease)
        var contents = try f.contents(access)
        contents.arguments[0].value = .longText("plan-revision")
        _ = try f.service.acceptRevision(contents, using: access)
        let edited = try #require(f.host.state().plan.items.first)
        try f.host.plan(.endEditing(edited.stamp, .finish))
        try f.host.send(.removeFromPlan(edited.stamp, f.host.state().plan.stamp))
        #expect(try f.host.state().operations.retained.first?.protectedReference == edited.draft.protectedReference)
    }

    @Test func protectedHandoffAndMergeFailWithoutMovingOwnership() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        _ = try f.protect()
        let original = try f.host.owned()
        #expect(throws: CommandHandoffError.protectedContent) { try f.host.prepare() }
        #expect(try f.host.owned() == original)
        let first = CommandPlanItem(id: UUID(), draft: try f.draft())
        let last = CommandPlanItem(id: UUID(), draft: try f.draft())
        #expect(CommandPlanSemantics.mergeConflict([first, last], earlier: 0, later: 1) == .protectedContent)
        #expect(try f.contents(f.restore()).arguments.first?.value == .longText("synthetic-body"))
    }

    @Test func explicitlyRequiredOrUnknownSourcesCannotEnterOrdinaryEditing() throws {
        let f = try ProtectedDraftFixture(configured: false)
        for requirement in [CommandProtectionRequirement.required, .unknown] {
            let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source,
                commandID: .init(rawValue: "setting.language"),
                arguments: [.init(parameter: .value, operation: .assign, value: .choice("chinese"))],
                protectionRequirement: requirement)
            let state = try f.host.state().operations
            let result = CommandDraftReducer.reduce(state, .start(expectedRevision: state.revision, draft))
            #expect(result.state == state && result.intents == [.rejectedEvent])
            var plan = CommandPlan(hostID: HandoffFixture.source)
            #expect(throws: CommandPlanError.protectedContent) { try plan.add(draft, id: UUID(), expecting: plan.stamp) }
        }
    }

    @Test func descriptionsDoNotExportSyntheticContents() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        _ = try f.protect()
        let access = try f.restore()
        let contents = try f.contents(access)
        let text = String(reflecting: try f.host.owned()) + String(reflecting: try f.draft())
            + String(reflecting: contents) + String(reflecting: contents.editing) + String(reflecting: access)
        #expect(!text.contains("synthetic-body") && !text.contains("synthetic-baseline") && !text.contains("合成未完成"))
    }
}
