import Foundation
import Observation
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct AppPreferencesFileCompatibilityTests {
    @Test func migrationReopenPreferencesCommitAndReopenShareOneAuthority() throws {
        let fixture = try AppPreferencesFileFixture()
        fixture.legacy.set(.language(.chinese))
        fixture.legacy.set(.stampCaptureApp(true))
        let old = fixture.legacy.oldFourKeys()
        let initialStore = try fixture.legacy.files.store()
        guard case .ready(let initial, _) = initialStore.migrate(from: fixture.legacy.source) else {
            Issue.record("隔离迁移应建立初始记录"); return
        }
        let store = try fixture.legacy.files.store()
        let start = store.reopen(from: fixture.legacy.source)
        let reads = fixture.legacy.reads
        let migration = try fixture.legacy.files.inventory()["migration.plist"]
        let prefs = AppPreferences(defaults: fixture.legacy.defaults, fileStore: store, startup: start, effects: fixture.effects)
        #expect(prefs.committedLocalPreferenceRecord == initial && prefs.language == .chinese)
        let result = prefs.applyLocalPreferences(basedOn: initial, changes: AppPreferencesFileFixture.changes)
        let current = try #require(prefs.committedLocalPreferenceRecord)
        #expect(result == .committed(current) && current.migrationID == initial.migrationID)
        #expect(current.recordRevision == initial.recordRevision + 1)
        let reopened = try fixture.legacy.files.store()
        let reload = reopened.reopen(from: fixture.legacy.source)
        let rebuilt = AppPreferences(defaults: fixture.legacy.defaults, fileStore: reopened, startup: reload, effects: fixture.effects)
        #expect(rebuilt.committedLocalPreferenceRecord == current && rebuilt.canWriteLocalPreferences)
        #expect(try fixture.legacy.files.inventory()["migration.plist"] == migration)
        #expect(fixture.legacy.oldFourKeys() == old && fixture.legacy.reads == reads)
        #expect(fixture.events.count == 1)
    }

    @Test func existingDefaultInitializerAndSameValueBindingRemainLegacy() throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        let prefs = AppPreferences(defaults: fixture.defaults, effects: fixture.effects)
        #expect(prefs.usesLegacyLocalPreferences && prefs.localPreferenceBackend == .legacy)
        #expect(prefs.committedLocalPreferenceRecord == nil && prefs.canWriteLocalPreferences)
        @Bindable var binding = prefs
        $binding.appearance.wrappedValue = .dark
        $binding.appearance.wrappedValue = .dark
        #expect(fixture.appearances == [.system, .dark, .dark] && fixture.events.count == 2)
        #expect(prefs.readLocalSetting(.appearance).revision == 2)
        #expect(fixture.events.allSatisfy { $0.object is LocalPreferenceChange })
    }

    @Test func legacyObservationKeepsItsOriginalPerFieldInvalidation() throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        let prefs = fixture.preferences()
        let probe = LegacyPreferenceObservationProbe()
        withObservationTracking { _ = prefs.language } onChange: {
            MainActor.assumeIsolated { probe.languages.append(prefs.language) }
        }
        prefs.appearance = .dark
        prefs.stampCaptureApp = true
        #expect(probe.languages.isEmpty)
        prefs.language = .english
        #expect(probe.languages == [.system])
    }

    @Test func unmigratedPreferencesKeepTheirOriginalDefaultsPath() throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let files = try fixture.legacy.files.inventory()
        prefs.isTagsExpanded = false
        prefs.syncCalendarEvents = true
        #expect(!fixture.legacy.defaults.bool(forKey: AppPreferences.isTagsExpandedKey))
        #expect(fixture.legacy.defaults.bool(forKey: AppPreferences.syncCalendarEventsKey))
        #expect(fixture.events.count == 2 && fixture.events.allSatisfy { $0.name == .appPreferencesDidChange })
        #expect(fixture.legacy.oldFourKeys() == [.missing, .missing, .missing, .missing])
        #expect(try fixture.legacy.files.inventory() == files)
    }

    @Test func legacySingleCommandHandlerRefusesFileBackendBeforeIssuingOrSealing() throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let handoff = try HandoffFixture()
        let adapter = LocalSettingCommandAdapter(coordinator: handoff.coordinator, preferences: prefs)
        let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "setting.language"),
            arguments: [.init(parameter: .value, operation: .assign, value: .choice("english"))])
        try handoff.start(draft)
        let owned = try handoff.owned()
        let stamp = try #require(handoff.state().operations.active?.stamp)
        #expect(!adapter.isAssembled(for: handoff.coordinator) && !adapter.supports(draft.commandID))
        #expect(throws: LocalSettingCommandIssue.unsupported) { try adapter.prepare(stamp, expecting: owned.lease) }
        #expect(throws: LocalSettingCommandIssue.unsupported) { try adapter.readiness(draft: stamp, expecting: owned.lease) }
        #expect(try handoff.state().operations.active?.baseline.preference == nil)
        try handoff.send(.enqueue(stamp, itemID: UUID(), plan: handoff.state().plan.stamp))
        let queued = try handoff.owned()
        #expect(throws: LocalSettingCommandIssue.unsupported) {
            try adapter.submit(plan: queued.session.plan.stamp, expecting: queued.lease)
        }
        #expect(try handoff.state().execution == nil)
        _ = try handoff.seal()
        let attempt = try handoff.begin()
        let request = try LocalSettingCommandRequest(lease: handoff.owned().lease,
            operation: #require(handoff.state().execution?.operation(attempt.unitID)), attempt: attempt)
        #expect(throws: LocalSettingCommandIssue.unsupported) { try adapter.execute(request) }
        #expect(try fixture.legacy.files.current().recordRevision == 1)
        #expect(fixture.events.isEmpty && prefs.readLocalSetting(.language).storedValue == nil)
    }
}

@MainActor private final class LegacyPreferenceObservationProbe {
    var languages: [AppLanguage] = []
}
