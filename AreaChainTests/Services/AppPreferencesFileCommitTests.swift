import Observation
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct AppPreferencesFileCommitTests {
    @Test func bindingUsesAggregateFileAndNeverWritesLegacyKeys() throws {
        let fixture = try AppPreferencesFileFixture()
        fixture.legacy.set(.language(.chinese))
        let old = fixture.legacy.oldFourKeys()
        let prefs = try fixture.ready()
        @Bindable var binding = prefs
        $binding.language.wrappedValue = .english
        let record = try #require(prefs.committedLocalPreferenceRecord)
        #expect(record.values.language == .english && record.recordRevision == 2)
        #expect(record.fieldRevisions.language == 2 && record.fieldRevisions.appearance == 1)
        #expect(try fixture.legacy.files.current() == record)
        #expect(fixture.legacy.oldFourKeys() == old && fixture.legacy.reads.isEmpty)
        let event = try #require(fixture.events.last?.object as? LocalPreferenceGroupChange)
        #expect(event.fields == [.language] && event.fieldRevisions == [.language: 2])
        #expect(prefs.lastLocalPreferenceCommit == .committed(record))
        let bytes = try fixture.legacy.files.inventory()
        fixture.resetEffects()
        $binding.language.wrappedValue = .english
        #expect(prefs.lastLocalPreferenceCommit == .noChange(record))
        #expect(try fixture.legacy.files.inventory() == bytes)
        #expect(fixture.events.isEmpty && fixture.appearances.isEmpty)
        #expect(prefs.readLocalSetting(.language).raw == .unavailable)
        #expect(prefs.applyLocalSetting(.language(.chinese)).rejection == .unsupportedBackend)
        #expect(try fixture.legacy.files.current() == record)
    }

    @Test func wholeCommitPublishesOnceAndCallbacksSeeOnlyCompleteStates() throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let base = try #require(prefs.committedLocalPreferenceRecord)
        let probe = PublicationProbe()
        withObservationTracking {
            _ = AppPreferencesFileFixture.values(prefs)
            _ = prefs.committedLocalPreferenceRecord
        } onChange: {
            MainActor.assumeIsolated {
                probe.observed.append(AppPreferencesFileFixture.values(prefs))
                probe.reentrant = prefs.applyLocalPreferences(basedOn: base, changes: [.language(.chinese)])
            }
        }
        fixture.onAppearance = {
            probe.appearance.append(AppPreferencesFileFixture.values(prefs))
            probe.commitAtAppearance = prefs.lastLocalPreferenceCommit
        }
        fixture.onEvent = {
            probe.events.append(AppPreferencesFileFixture.values(prefs))
            probe.commitAtEvent = prefs.lastLocalPreferenceCommit
        }
        fixture.resetEffects()
        let result = prefs.applyLocalPreferences(basedOn: base, changes: AppPreferencesFileFixture.changes)
        let current = try #require(prefs.committedLocalPreferenceRecord)
        #expect(result == .committed(current) && current.recordRevision == base.recordRevision + 1)
        #expect(current.parentCommitID == base.commitID && current.fieldRevisions.language == 2)
        #expect(probe.observed == [base.values])
        #expect(probe.reentrant == .notCommitted(.reentrant))
        #expect(probe.appearance == [current.values] && probe.events == [current.values])
        #expect(probe.commitAtAppearance == result && probe.commitAtEvent == result)
        #expect(current.values == AppPreferencesFileFixture.changedValues)
        #expect(try fixture.legacy.files.current() == current)
        #expect(fixture.events.count == 1 && fixture.appearances == [.dark])
        let event = try #require(fixture.events.first?.object as? LocalPreferenceGroupChange)
        #expect(event.source == prefs.localPreferenceSource && event.identity == current.identity)
        #expect(event.fields == Set(LocalPreferenceField.allCases))
        #expect(event.recordRevision == current.recordRevision && event.commitID == current.commitID)
        #expect(event.fieldRevisions.values.allSatisfy { $0 == 2 })
        #expect(fixture.events.first?.userInfo == nil)
    }

    @Test func noChangeSkipsEncodingPublishingAndAllEffects() throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready(.encoding)
        let base = try #require(prefs.committedLocalPreferenceRecord)
        let before = try fixture.legacy.files.inventory()
        let probe = PublicationProbe()
        withObservationTracking { _ = AppPreferencesFileFixture.values(prefs) } onChange: {
            MainActor.assumeIsolated { probe.observed.append(AppPreferencesFileFixture.values(prefs)) }
        }
        fixture.resetEffects()
        let result = prefs.applyLocalPreferences(basedOn: base,
            changes: LocalPreferenceField.allCases.map { base.values.value(for: $0) })
        #expect(result == .noChange(base) && prefs.canWriteLocalPreferences)
        #expect(probe.observed.isEmpty && fixture.events.isEmpty && fixture.appearances.isEmpty)
        #expect(try fixture.legacy.files.inventory() == before)
        #expect(prefs.localPreferencePresentation(for: base.commitID) == nil)
    }

    @Test func partialNoChangeIsStillOneCommitAndUnrelatedChangesArePreserved() throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let base = try #require(prefs.committedLocalPreferenceRecord)
        guard case .committed(let external) = try fixture.legacy.files.store().commit(basedOn: base,
            changes: [.stampCaptureApp(true)]) else { Issue.record("需要外部已提交记录"); return }
        let result = prefs.applyLocalPreferences(basedOn: base, changes: [.language(.english), .appearance(.system)])
        let current = try #require(prefs.committedLocalPreferenceRecord)
        #expect(result == .committed(current) && current.recordRevision == external.recordRevision + 1)
        #expect(current.fieldRevisions.language == 2 && current.fieldRevisions.appearance == 2)
        #expect(current.fieldRevisions.stampCaptureApp == external.fieldRevisions.stampCaptureApp)
        #expect(current.values.stampCaptureApp && current.values.appearance == .system)
        let event = try #require(fixture.events.last?.object as? LocalPreferenceGroupChange)
        #expect(event.fields == [.language, .appearance, .stampCaptureApp])
    }

    @Test func duplicateFieldsAreRejectedAsOneRequest() throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let base = try #require(prefs.committedLocalPreferenceRecord)
        let before = try fixture.legacy.files.inventory()
        let result = prefs.applyLocalPreferences(basedOn: base, changes: [.language(.english), .language(.chinese)])
        #expect(result == .notCommitted(.invalidRequest) && !prefs.canWriteLocalPreferences)
        #expect(prefs.committedLocalPreferenceRecord == base && fixture.events.isEmpty)
        #expect(try fixture.legacy.files.inventory() == before)
    }
}

@MainActor private final class PublicationProbe {
    var observed: [LocalPreferenceValues] = []
    var appearance: [LocalPreferenceValues] = []
    var events: [LocalPreferenceValues] = []
    var reentrant: LocalPreferenceFileCommit?
    var commitAtAppearance: LocalPreferenceFileCommit?
    var commitAtEvent: LocalPreferenceFileCommit?
}
