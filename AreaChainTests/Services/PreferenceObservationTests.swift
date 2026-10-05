import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct PreferenceObservationTests {
    @Test func realConsumerRoutesExcludeCalendarAndDiaryBody() async throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        let prefs = fixture.preferences()
        var window = 0
        var menu = 0
        var diaryChrome = 0
        var diaryBody = 0
        var calendar = 0
        let observers = [
            PreferenceObservation(source: prefs.localPreferenceSource, consumer: .windowChrome, center: fixture.center,
                presentation: { window += 1 }, legacy: { window += 1 }),
            PreferenceObservation(source: prefs.localPreferenceSource, consumer: .statusItem, center: fixture.center,
                presentation: { menu += 1 }, legacy: { menu += 1 }),
            PreferenceObservation(source: prefs.localPreferenceSource, consumer: .diaryWindow, center: fixture.center,
                presentation: { diaryChrome += 1 }, legacy: { diaryBody += 1; diaryChrome += 1 }),
            PreferenceObservation(source: prefs.localPreferenceSource, consumer: .calendar, center: fixture.center,
                presentation: { Issue.record("日历不应订阅普通事件") }, legacy: { calendar += 1 })
        ]
        defer { observers.forEach { $0.cancel() } }
        prefs.language = .chinese
        prefs.appearance = .dark
        prefs.quadrantTitleTruncation = .middle
        prefs.stampCaptureApp = true
        await drain()
        #expect(window == 2 && menu == 2 && diaryChrome == 1)
        #expect(diaryBody == 0 && calendar == 0)
        // 非四项仍走旧名称和 nil object；仅私有中心中模拟，绝不启动真实服务。
        prefs.isTagsExpanded = false
        await drain()
        #expect(fixture.events.last?.name == .appPreferencesDidChange && fixture.events.last?.object == nil)
        #expect(fixture.defaults.bool(forKey: AppPreferences.isTagsExpandedKey) == false)
        #expect(window == 3 && menu == 3 && diaryChrome == 2 && diaryBody == 1 && calendar == 1)
        #expect(prefs.readLocalSetting(.language).revision == 1)
    }

    @Test func sharedCenterStillRejectsOtherInstanceAndStore() async throws {
        let first = try LocalPreferenceTestSupport()
        let second = try LocalPreferenceTestSupport()
        defer { first.cleanup(); second.cleanup() }
        let prefs = first.preferences()
        let sameStore = first.preferences()
        let otherStore = AppPreferences(defaults: second.defaults, effects: first.effects)
        var calls = 0
        let observer = PreferenceObservation(source: prefs.localPreferenceSource, consumer: .statusItem,
            center: first.center, presentation: { calls += 1 }, legacy: {})
        defer { observer.cancel() }
        sameStore.language = .english
        otherStore.language = .chinese
        await drain()
        #expect(calls == 0 && prefs.language == .system)
        prefs.language = .english
        await drain()
        #expect(calls == 1)
        observer.cancel()
        prefs.language = .chinese
        await drain()
        #expect(calls == 1)
    }

    @Test func canceledPendingCallbacksCannotRefreshClosedConsumer() async throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        let prefs = fixture.preferences()
        var calls = 0
        var observer: PreferenceObservation? = PreferenceObservation(source: prefs.localPreferenceSource,
            consumer: .diaryWindow, center: fixture.center, presentation: { calls += 1 }, legacy: { calls += 1 })
        prefs.language = .chinese
        observer?.cancel()
        observer = nil
        await drain()
        #expect(calls == 0)
    }

    private func drain() async { for _ in 0..<20 { await Task.yield() } }
}
