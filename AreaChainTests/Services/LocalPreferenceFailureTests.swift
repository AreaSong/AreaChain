import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct LocalPreferenceFailureTests {
    enum Failure: Error { case injected }

    @Test func preReadFailureNeverCallsWrite() throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        var calls = 0
        var storage = LocalPreferenceStorage(defaults: fixture.defaults)
        storage.read = { _ in throw Failure.injected }
        storage.write = { _ in calls += 1 }
        let prefs = fixture.preferences(storage: storage)
        #expect(prefs.language == .system && prefs.readLocalSetting(.language).raw == .unavailable)
        let result = prefs.applyLocalSetting(.language(.english))
        #expect(result.rejection == .unreadableStorage && result.write == .notCalled && result.readback == .notRead)
        #expect(calls == 0 && fixture.events.isEmpty && prefs.readLocalSetting(.language).revision == 0)
    }

    @Test func droppedWriteIsDifferentNotDurableSuccess() throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        var storage = LocalPreferenceStorage(defaults: fixture.defaults)
        storage.write = { _ in }
        let prefs = fixture.preferences(storage: storage)
        let result = prefs.applyLocalSetting(.appearance(.dark))
        #expect(result.write == .returned && result.readback == .differs)
        #expect(result.after?.raw == .missing && result.after?.revision == 1)
        #expect(prefs.appearance == .system && result.event == .notCalled && result.appearance == .notCalled)
        #expect(fixture.events.isEmpty && fixture.appearances == [.system])
    }

    @Test func readAfterWriteFailureRetainsUncertainty() throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        var wrote = false
        var storage = LocalPreferenceStorage(defaults: fixture.defaults)
        let read = storage.read
        let write = storage.write
        storage.read = { field in if wrote { throw Failure.injected }; return try read(field) }
        storage.write = { value in try write(value); wrote = true }
        let prefs = fixture.preferences(storage: storage)
        let result = prefs.applyLocalSetting(.appearance(.dark))
        #expect(result.write == .returned && result.readback == .unavailable)
        #expect(result.after?.raw == .unavailable && result.after?.revision == 1)
        #expect(fixture.defaults.string(forKey: AppPreferences.appearanceKey) == "dark")
        #expect(prefs.appearance == .system && result.event == .notCalled && result.appearance == .notCalled)
    }

    @Test(arguments: [false, true])
    func thrownWriteDoesNotPretendItWasNeverCalled(writeFirst: Bool) throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        var storage = LocalPreferenceStorage(defaults: fixture.defaults)
        let write = storage.write
        storage.write = { value in
            if writeFirst { try write(value) }
            throw Failure.injected
        }
        let prefs = fixture.preferences(storage: storage)
        let result = prefs.applyLocalSetting(.language(.english))
        #expect(result.write == .threw && result.after?.revision == 1)
        #expect(result.readback == (writeFirst ? .matches : .differs))
        #expect(prefs.language == (writeFirst ? .english : .system))
        #expect(result.event == (writeFirst ? .returned : .notCalled))
    }

    @Test func effectsFailIndependentlyWithoutRewritingOrRollback() throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        var writes = 0
        var posts = 0
        var storage = LocalPreferenceStorage(defaults: fixture.defaults)
        let write = storage.write
        storage.write = { value in writes += 1; try write(value) }
        let effects = LocalPreferenceEffects(applyAppearance: { _ in throw Failure.injected },
            post: { _ in posts += 1; throw Failure.injected })
        let prefs = AppPreferences(defaults: fixture.defaults, localStorage: storage, effects: effects)
        let result = prefs.applyLocalSetting(.appearance(.dark))
        #expect(result.readback == .matches && result.write == .returned)
        #expect(result.appearance == .threw && result.event == .threw)
        #expect(writes == 1 && posts == 1 && prefs.appearance == .dark)
        #expect(fixture.defaults.string(forKey: AppPreferences.appearanceKey) == "dark")
    }

    @Test func synchronousEffectReentryIsNotASecondWrite() throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        var prefs: AppPreferences?
        var nested: LocalPreferenceWriteResult?
        var effects = fixture.effects
        effects.post = { _ in nested = prefs?.applyLocalSetting(.language(.chinese)) }
        prefs = AppPreferences(defaults: fixture.defaults, effects: effects)
        let outer = try #require(prefs).applyLocalSetting(.language(.english))
        #expect(outer.readback == .matches && outer.after?.revision == 1)
        #expect(nested?.rejection == .reentrant && nested?.write == .notCalled && nested?.readback == .notRead)
        #expect(prefs?.language == .english)
    }
}
