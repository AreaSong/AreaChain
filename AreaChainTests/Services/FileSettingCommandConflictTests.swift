import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct FileSettingCommandConflictTests {
    @Test func oldIndividualBaselineCannotBeSwallowedByGroupPreparation() throws {
        let fixture = try FileSettingCommandFixture()
        let first = try fixture.queue(FileSettingCommandFixture.paths[0], individual: true)
        let second = try fixture.queue(FileSettingCommandFixture.paths[1], individual: true)
        try fixture.handoff.plan(.atomicGroup(UUID(), members: [first, second]))
        let before = try fixture.owned()
        try fixture.external([.language(.chinese)])
        #expect(throws: FileLocalSettingCommandIssue.conflict([.language])) { try fixture.prepareGroup() }
        #expect(try fixture.owned() == before)
        #expect(fixture.store.metrics.snapshot().commits == 0 && fixture.io.events.isEmpty)
    }

    @Test func unrelatedChangePreservedButSameFieldABAConflicts() throws {
        let fixture = try FileSettingCommandFixture()
        try fixture.group()
        try fixture.external([.stampCaptureApp(true)])
        _ = try fixture.submit()
        #expect(try fixture.io.legacy.files.current().values.stampCaptureApp)
        #expect(fixture.store.metrics.snapshot().replacements == 1)
        let aba = try FileSettingCommandFixture()
        try aba.group()
        try aba.external([.language(.chinese)])
        try aba.external([.language(.system)])
        #expect(throws: FileLocalSettingCommandIssue.conflict([.language])) { try aba.submit() }
        #expect(aba.store.metrics.snapshot().commits == 0)
    }

    @Test func conflictReturnsWholeGroupAndConfirmationBindsEvidence() throws {
        let fixture = try FileSettingCommandFixture()
        let group = try fixture.group()
        let originals = try fixture.state().plan.items
        let request = try fixture.request()
        try fixture.external([.language(.chinese)])
        let report = try fixture.adapter.execute(request)
        guard case .preferenceGroupCommit(.conflict(let diagnostics)) = report.localReceipt.result else {
            Issue.record("应暂停整个组"); return
        }
        #expect(diagnostics.count == 1 && diagnostics[0].item == originals[0].stamp)
        #expect(try fixture.unit().local == .notSubmitted && fixture.unit().effects.isEmpty)
        try fixture.adapter.returnUnsubmittedToPlan(request.attempt, expecting: fixture.owned().lease)
        let returned = try fixture.state().plan.items
        #expect(returned.map(\.id) == originals.map(\.id) && returned.allSatisfy { $0.atomicGroup == group })
        #expect(returned.allSatisfy { $0.returnedAttempts == [request.attempt] })
        #expect(returned.map { $0.draft.id } == originals.map { $0.draft.id })
        let confirmation = try fixture.adapter.rereadConflict(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease)
        #expect(confirmation.affectedFields == [.language])
        try fixture.external([.language(.system)])
        #expect(throws: FileLocalSettingCommandIssue.stale) { try fixture.adapter.resolveConflict(confirmation, choice: .confirmOverwrite) }
        let fresh = try fixture.adapter.rereadConflict(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease)
        try fixture.adapter.resolveConflict(fresh, choice: .confirmOverwrite)
        #expect(fixture.store.metrics.snapshot().commits == 0)
        let committed = try fixture.submit()
        #expect(committed.identity.execution != request.identity.execution)
        #expect(throws: CommandHandoffError.stale) { try fixture.adapter.execute(request) }
        #expect(fixture.store.metrics.snapshot().commits == 1)
    }

    @Test(arguments: [LocalSettingConflictChoice.adoptCurrent, .continueEditing])
    func conflictChoicesPreserveIntentAndDoNotSubmit(choice: LocalSettingConflictChoice) throws {
        let fixture = try FileSettingCommandFixture()
        try fixture.group()
        try fixture.external([.language(.chinese)])
        let before = try fixture.state().plan
        let confirmation = try fixture.adapter.rereadConflict(plan: before.stamp, expecting: fixture.owned().lease)
        try fixture.adapter.resolveConflict(confirmation, choice: choice)
        #expect(fixture.store.metrics.snapshot().commits == 0)
        if choice == .continueEditing {
            #expect(try fixture.state().plan == before)
            #expect(throws: FileLocalSettingCommandIssue.conflict([.language])) { try fixture.submit() }
        } else {
            #expect(try fixture.state().plan.items[0].draft.arguments[0].value == .choice("chinese"))
            #expect(try fixture.submit().localReceipt.result == .preferenceGroupCommit(.noChange))
        }
    }
}
