import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct AppPreferencesFilePresentationTests {
    @Test(arguments: [true, false])
    func presentationFailureNeverDeniesCommitAndRetriesOnlyFailedSteps(appearanceFails: Bool) throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let base = try #require(prefs.committedLocalPreferenceRecord)
        fixture.failAppearance = appearanceFails
        fixture.failEvent = !appearanceFails
        fixture.resetEffects()
        let result = prefs.applyLocalPreferences(basedOn: base, changes: [.appearance(.dark), .language(.english)])
        let record = try #require(prefs.committedLocalPreferenceRecord)
        let report = try #require(prefs.localPreferencePresentation(for: record.commitID))
        #expect(result == .committed(record) && prefs.canWriteLocalPreferences)
        #expect(report.appearance == (appearanceFails ? .threw : .returned))
        #expect(report.event == (appearanceFails ? .returned : .threw))
        #expect(fixture.events.count == 1 && fixture.appearances == [.dark])
        let before = try fixture.legacy.files.inventory()
        fixture.failAppearance = false
        fixture.failEvent = false
        let retried = prefs.retryLocalPreferencePresentation(for: record.commitID)
        #expect(retried?.appearance == .returned && retried?.event == .returned)
        #expect(fixture.appearances.count == (appearanceFails ? 2 : 1))
        #expect(fixture.events.count == (appearanceFails ? 1 : 2))
        #expect(try fixture.legacy.files.inventory() == before)
        #expect(prefs.lastLocalPreferenceCommit == result)
        _ = prefs.retryLocalPreferencePresentation(for: record.commitID)
        #expect(fixture.appearances.count == (appearanceFails ? 2 : 1))
        #expect(fixture.events.count == (appearanceFails ? 1 : 2))
    }

    @Test func latePresentationCallbackIsSupersededAndCannotReapplyCapturedAppearance() throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let base = try #require(prefs.committedLocalPreferenceRecord)
        fixture.failAppearance = true
        fixture.failEvent = true
        _ = prefs.applyLocalPreferences(basedOn: base, changes: [.appearance(.dark)])
        let first = try #require(prefs.committedLocalPreferenceRecord)
        let lateCallback = { prefs.retryLocalPreferencePresentation(for: first.commitID) }
        fixture.failAppearance = false
        fixture.failEvent = false
        _ = prefs.applyLocalPreferences(basedOn: first, changes: [.appearance(.light)])
        let current = try #require(prefs.committedLocalPreferenceRecord)
        fixture.resetEffects()
        let files = try fixture.legacy.files.inventory()
        let late = lateCallback()
        #expect(late?.appearance == .superseded && late?.event == .superseded)
        #expect(late?.supersededFields == [.appearance])
        #expect(prefs.appearance == .light && prefs.committedLocalPreferenceRecord == current)
        #expect(fixture.appearances.isEmpty && fixture.events.isEmpty)
        #expect(try fixture.legacy.files.inventory() == files)
        #expect(prefs.retryLocalPreferencePresentation(for: UUID()) == nil)
    }

    @Test func unrelatedCommitDoesNotSupersedeAppearanceRetry() throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let base = try #require(prefs.committedLocalPreferenceRecord)
        fixture.failAppearance = true
        _ = prefs.applyLocalPreferences(basedOn: base, changes: [.appearance(.dark)])
        let first = try #require(prefs.committedLocalPreferenceRecord)
        fixture.failAppearance = false
        _ = prefs.applyLocalPreferences(basedOn: first, changes: [.stampCaptureApp(true)])
        fixture.resetEffects()
        let before = try fixture.legacy.files.inventory()
        let retry = prefs.retryLocalPreferencePresentation(for: first.commitID)
        #expect(retry?.appearance == .returned && retry?.supersededFields.isEmpty == true)
        #expect(fixture.appearances == [.dark] && fixture.events.isEmpty)
        #expect(try fixture.legacy.files.inventory() == before)
    }

    @Test func appearanceAndEventReentryCannotInterleaveAnotherCommitOrReload() throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let base = try #require(prefs.committedLocalPreferenceRecord)
        var nested: [LocalPreferenceFileCommit] = []
        var recoveries: [LocalPreferenceFileRecovery] = []
        let reenter = {
            nested.append(prefs.applyLocalPreferences(basedOn: base, changes: [.language(.chinese)]))
            recoveries.append(prefs.verifyAndReloadLocalPreferences())
            AppPreferencesFileFixture.assignAllBindings(prefs)
        }
        fixture.onAppearance = reenter
        fixture.onEvent = reenter
        let result = prefs.applyLocalPreferences(basedOn: base, changes: [.appearance(.dark)])
        let current = try #require(prefs.committedLocalPreferenceRecord)
        #expect(result == .committed(current) && current.recordRevision == 2)
        #expect(nested == [.notCommitted(.reentrant), .notCommitted(.reentrant)])
        #expect(recoveries == [.blocked(.unavailable(.reentrant)), .blocked(.unavailable(.reentrant))])
        #expect(prefs.language == .system && prefs.appearance == .dark && !prefs.stampCaptureApp)
    }
}
