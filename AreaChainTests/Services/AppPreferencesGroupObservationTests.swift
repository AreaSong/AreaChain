import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct AppPreferencesGroupObservationTests {
    @Test func groupRoutesOnlyRelevantChromeAndLateCallbacksReadCurrentState() async throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let base = try #require(prefs.committedLocalPreferenceRecord)
        var windows: [LocalPreferenceValues] = []
        var menus: [LocalPreferenceValues] = []
        var diaries: [LocalPreferenceValues] = []
        var bodies = 0, calendars = 0
        let observers = [
            PreferenceObservation(preferences: prefs, consumer: .windowChrome, center: fixture.center,
                presentation: { windows.append(AppPreferencesFileFixture.values(prefs)) }, legacy: {}),
            PreferenceObservation(preferences: prefs, consumer: .statusItem, center: fixture.center,
                presentation: { menus.append(AppPreferencesFileFixture.values(prefs)) }, legacy: {}),
            PreferenceObservation(preferences: prefs, consumer: .diaryWindow, center: fixture.center,
                presentation: { diaries.append(AppPreferencesFileFixture.values(prefs)) }, legacy: { bodies += 1 }),
            PreferenceObservation(preferences: prefs, consumer: .calendar, center: fixture.center,
                presentation: { calendars += 1 }, legacy: { calendars += 1 })
        ]
        defer { observers.forEach { $0.cancel() } }
        _ = prefs.applyLocalPreferences(basedOn: base, changes: AppPreferencesFileFixture.changes)
        let first = try #require(prefs.committedLocalPreferenceRecord)
        let oldEvent = try #require(fixture.events.last)
        _ = prefs.applyLocalPreferences(basedOn: first, changes: [.language(.chinese), .appearance(.light)])
        let current = try #require(prefs.committedLocalPreferenceRecord)
        await drain()
        #expect(windows == [current.values] && menus == [current.values] && diaries == [current.values])
        #expect(bodies == 0 && calendars == 0)
        fixture.center.post(oldEvent)
        await drain()
        #expect(observers[0].lastGroupDelivery == .superseded(first.commitID))
        #expect(windows == [current.values] && bodies == 0 && calendars == 0)
        _ = prefs.applyLocalPreferences(basedOn: current, changes: [.stampCaptureApp(false), .quadrantTitleTruncation(.tail)])
        await drain()
        #expect(windows.count == 1 && menus.count == 1 && diaries.count == 1)
    }

    @Test func fieldIntersectionAndCancellationDoNotOverRefreshDiary() async throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let base = try #require(prefs.committedLocalPreferenceRecord)
        var chrome = 0
        let observer = PreferenceObservation(preferences: prefs, consumer: .diaryWindow, center: fixture.center,
            presentation: { chrome += 1 }, legacy: {})
        _ = prefs.applyLocalPreferences(basedOn: base, changes: [.language(.english), .appearance(.dark)])
        let first = try #require(prefs.committedLocalPreferenceRecord)
        _ = prefs.applyLocalPreferences(basedOn: first, changes: [.appearance(.light)])
        await drain()
        #expect(chrome == 1 && observer.lastGroupDelivery == .refreshed(first.commitID, fields: [.language]))
        let current = try #require(prefs.committedLocalPreferenceRecord)
        _ = prefs.applyLocalPreferences(basedOn: current, changes: [.language(.chinese)])
        observer.cancel()
        await drain()
        #expect(chrome == 1)
    }

    @Test func differentAppPreferencesInstanceCannotDriveThisConsumer() async throws {
        let fixture = try AppPreferencesFileFixture()
        let prefs = try fixture.ready()
        let base = try #require(prefs.committedLocalPreferenceRecord)
        let other = try fixture.preferences(.ready(base, cleanupPending: false))
        var calls = 0
        let observer = PreferenceObservation(preferences: prefs, consumer: .windowChrome, center: fixture.center,
            presentation: { calls += 1 }, legacy: {})
        defer { observer.cancel() }
        _ = other.applyLocalPreferences(basedOn: base, changes: [.language(.english)])
        await drain()
        #expect(calls == 0 && prefs.language == .system && other.language == .english)
    }

    private func drain() async { for _ in 0..<20 { await Task.yield() } }
}
