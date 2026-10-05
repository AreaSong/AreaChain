import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct LocalSettingCommandConflictTests {
    @Test func invalidRawTypesAndUnreadableOriginalCannotBecomeDefaults() throws {
        let rawValues: [Any] = [17, true, ["unexpected"], "future-language"]
        for raw in rawValues {
            let io = try PreferenceCommandIO()
            io.local.defaults.set(raw, forKey: AppPreferences.languageKey)
            let fixture = try LocalSettingCommandFixture(io: io)
            defer { fixture.cleanup() }
            #expect(throws: LocalSettingCommandIssue.self) { try fixture.queue(value: .choice("system")) }
            #expect(fixture.prefs.language == .system && fixture.prefs.readLocalSetting(.language).storedValue == nil)
            #expect(io.writes.isEmpty && io.local.events.isEmpty)
        }
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        fixture.io.unreadable = true
        #expect(throws: LocalSettingCommandIssue.self) { try fixture.queue() }
        #expect(fixture.io.writes.isEmpty)
    }

    @Test func externalStorageTargetDoesNotProduceFalseNoChange() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        fixture.io.local.defaults.set("english", forKey: AppPreferences.languageKey)
        let request = try fixture.request()
        let report = try fixture.adapter.execute(request)
        guard case .conflict(let conflict) = report.outcome else { Issue.record("必须保留内存/存储分歧"); return }
        #expect(conflict.current.value == .language(.system) && conflict.current.storedValue == .language(.english))
        #expect(try fixture.unit().state == .conflict && fixture.unit().local == .notSubmitted)
        #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty)
        try fixture.adapter.returnUnsubmittedToPlan(request.attempt, expecting: fixture.owned().lease)
        #expect(throws: LocalSettingCommandIssue.self) {
            try fixture.adapter.rereadConflict(fixture.state().plan.items[0].draft.stamp, expecting: fixture.owned().lease)
        }
    }

    @Test func sameFieldABAConflictsButDifferentFieldDoesNot() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        fixture.prefs.appearance = .dark
        try fixture.adapter.readiness(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease)
        fixture.prefs.language = .chinese
        fixture.prefs.language = .system
        fixture.io.resetCounts()
        let before = try fixture.owned()
        #expect(throws: LocalSettingCommandIssue.self) { try fixture.submit() }
        #expect(try fixture.owned() == before)
        #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty)
        let request = try fixture.request()
        guard case .conflict(let conflict) = try fixture.adapter.execute(request).outcome else {
            Issue.record("字段修订必须保留 ABA 冲突"); return
        }
        #expect(conflict.current.revision == 2 && conflict.baseline.revision == 0)
    }

    @Test func newPreferenceInstanceOrStorageIdentityCannotReuseBaseline() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        let other = fixture.io.preferences()
        let otherAdapter = LocalSettingCommandAdapter(coordinator: fixture.handoff.coordinator, preferences: other)
        #expect(other.localPreferenceSource.storageID == fixture.prefs.localPreferenceSource.storageID)
        #expect(other.localPreferenceSource.instanceID != fixture.prefs.localPreferenceSource.instanceID)
        #expect(throws: LocalSettingCommandIssue.self) {
            try otherAdapter.readiness(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease)
        }
        let anotherIO = try PreferenceCommandIO()
        defer { anotherIO.cleanup() }
        let another = anotherIO.preferences()
        let anotherAdapter = LocalSettingCommandAdapter(coordinator: fixture.handoff.coordinator, preferences: another)
        #expect(another.localPreferenceSource.storageID != fixture.prefs.localPreferenceSource.storageID)
        #expect(throws: LocalSettingCommandIssue.self) {
            try anotherAdapter.submit(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease)
        }
        #expect(fixture.io.writes.isEmpty && anotherIO.writes.isEmpty)
    }

    @Test func conflictReturnsSameOperationAndExplicitOverwriteIsOneUse() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        let id = try fixture.queue()
        let request = try fixture.request()
        fixture.prefs.language = .chinese
        fixture.io.resetCounts()
        _ = try fixture.adapter.execute(request)
        try fixture.adapter.returnUnsubmittedToPlan(request.attempt, expecting: fixture.owned().lease)
        let item = try #require(fixture.state().plan.items.first)
        #expect(item.id == id && item.stamp.version > request.operation.item.version)
        #expect(item.returnedAttempts == [request.attempt])
        #expect(try fixture.state().execution == nil)
        #expect(throws: CommandPlanError.duplicate) {
            try fixture.handoff.send(.sealPlan(fixture.state().plan.stamp, runID: request.operation.execution.runID))
        }
        #expect(throws: CommandHandoffError.stale) { try fixture.adapter.execute(request) }
        let confirmation = try fixture.adapter.rereadConflict(item.draft.stamp, expecting: fixture.owned().lease)
        try fixture.adapter.resolveConflict(confirmation, choice: .confirmOverwrite)
        #expect(throws: LocalSettingCommandIssue.stale) { try fixture.adapter.resolveConflict(confirmation, choice: .confirmOverwrite) }
        #expect(fixture.io.writes.isEmpty)
        let report = try fixture.submit()
        #expect(report.operation.operationID == id && report.operation.execution != request.operation.execution)
        #expect(fixture.io.writes == [.language(.english)])
        #expect(throws: LocalSettingCommandIssue.notRetryable) {
            try fixture.adapter.returnUnsubmittedToPlan(report.receipt.attempt, expecting: fixture.owned().lease)
        }
    }

    @Test func adoptCurrentEndsWithNoChangeAndContinueEditingDoesNotAuthorizeOverwrite() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        fixture.prefs.language = .chinese
        fixture.io.resetCounts()
        let draft = try fixture.state().plan.items[0].draft
        let edit = try fixture.adapter.rereadConflict(draft.stamp, expecting: fixture.owned().lease)
        try fixture.adapter.resolveConflict(edit, choice: .continueEditing)
        #expect(throws: LocalSettingCommandIssue.self) { try fixture.submit() }
        #expect(try fixture.state().plan.items[0].draft == draft)
        let adopt = try fixture.adapter.rereadConflict(draft.stamp, expecting: fixture.owned().lease)
        try fixture.adapter.resolveConflict(adopt, choice: .adoptCurrent)
        #expect(try fixture.state().plan.items[0].draft.arguments[0].value == .choice("chinese"))
        #expect(try fixture.submit().outcome == .noChange)
        #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty)
    }

    @Test func changedConflictEvidenceOrOldLeaseCannotConfirm() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        fixture.prefs.language = .chinese
        let first = try fixture.adapter.rereadConflict(fixture.state().plan.items[0].draft.stamp, expecting: fixture.owned().lease)
        fixture.prefs.language = .system
        #expect(throws: LocalSettingCommandIssue.self) { try fixture.adapter.resolveConflict(first, choice: .confirmOverwrite) }
        let second = try fixture.adapter.rereadConflict(fixture.state().plan.items[0].draft.stamp, expecting: fixture.owned().lease)
        try fixture.handoff.send(.query(.privacyInvalidated))
        #expect(throws: CommandHandoffError.stale) { try fixture.adapter.resolveConflict(second, choice: .confirmOverwrite) }
        fixture.io.resetCounts()
        #expect(throws: LocalSettingCommandIssue.self) { try fixture.submit() }
        #expect(fixture.io.writes.isEmpty)
    }

    @Test func protocolReadyNeverAuthorizesAConflictingOverwrite() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        let first = try fixture.request()
        fixture.prefs.language = .chinese
        fixture.io.resetCounts()
        _ = try fixture.adapter.execute(first)
        try fixture.handoff.send(.resolveValidation(first.attempt, .readyForProtocol))
        let next = try fixture.handoff.begin()
        let request = try LocalSettingCommandRequest(lease: fixture.owned().lease, operation: first.operation, attempt: next)
        _ = try fixture.adapter.execute(request)
        #expect(try fixture.unit().state == .conflict && fixture.unit().local == .notSubmitted)
        #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty)
    }

    @Test func changedSourceAfterSealingIsReturnedAsConflictAndCanBeExplicitlyRebased() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        let request = try fixture.request()
        let replacement = LocalSettingCommandAdapter(coordinator: fixture.handoff.coordinator, preferences: fixture.io.preferences())
        guard case .conflict = try replacement.execute(request).outcome else { Issue.record("来源改变必须保留冲突"); return }
        #expect(fixture.io.writes.isEmpty)
        try replacement.returnUnsubmittedToPlan(request.attempt, expecting: fixture.owned().lease)
        let confirmation = try replacement.rereadConflict(fixture.state().plan.items[0].draft.stamp, expecting: fixture.owned().lease)
        try replacement.resolveConflict(confirmation, choice: .adoptCurrent)
        let report = try replacement.submit(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease)
        #expect(report.outcome == .noChange && fixture.io.writes.isEmpty)
    }
}
