import AppKit
import Observation
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct LocalPreferenceTests {
    static let values: [LocalPreferenceValue] = [
        .language(.system), .language(.chinese), .language(.english),
        .appearance(.system), .appearance(.light), .appearance(.dark),
        .quadrantTitleTruncation(.tail), .quadrantTitleTruncation(.middle),
        .stampCaptureApp(false), .stampCaptureApp(true)
    ]

    @Test func legacyKeysDefaultsAndRawMappings() throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        let prefs = fixture.preferences()
        #expect(LocalPreferenceField.allCases.map(\.key) == ["areachain.prefs.language", "areachain.prefs.appearance",
            "areachain.prefs.quadrantTitleTruncation", "areachain.prefs.stampCaptureApp"])
        for field in LocalPreferenceField.allCases {
            let initial = prefs.readLocalSetting(field)
            #expect(initial.raw == .missing && initial.revision == 0 && initial.storedValue == initial.value)
        }
        for value in Self.values {
            let result = prefs.applyLocalSetting(value)
            #expect(result.write == .returned && result.readback == .matches && result.event == .returned)
            #expect(result.after?.value == value && result.after?.raw == value.raw)
            let rebuilt = fixture.preferences()
            #expect(rebuilt.readLocalSetting(value.field).value == value)
        }
        #expect(prefs.language == .english && prefs.resolvedLocale.identifier == "en")
        #expect(AppLanguage.system.resolvedCode(preferredLanguages: ["zh-TW"]) == "zh-Hans")
        #expect(AppLanguage.system.resolvedCode(preferredLanguages: ["fr", "zh"]) == "en")
        #expect(AppAppearance.system.resolvedColorScheme == nil)
    }

    @Test func invalidStorageFallsBackWithoutRepairOrEvents() throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        for field in [LocalPreferenceField.language, .appearance, .quadrantTitleTruncation] {
            fixture.defaults.set("invalid", forKey: field.key)
        }
        fixture.defaults.set("YES", forKey: AppPreferences.stampCaptureAppKey)
        let before = fixture.defaults.persistentDomain(forName: fixture.suite)! as NSDictionary
        let prefs = fixture.preferences()
        #expect(prefs.language == .system && prefs.appearance == .system && prefs.quadrantTitleTruncation == .tail)
        #expect(prefs.stampCaptureApp == fixture.defaults.bool(forKey: AppPreferences.stampCaptureAppKey))
        #expect(prefs.readLocalSetting(.language).raw == .string("invalid"))
        #expect(prefs.readLocalSetting(.language).storedValue == nil)
        #expect(prefs.readLocalSetting(.stampCaptureApp).storedValue == nil)
        #expect(before == fixture.defaults.persistentDomain(forName: fixture.suite)! as NSDictionary)
        #expect(fixture.events.isEmpty && fixture.appearances == [.system])
        fixture.defaults.set(["unexpected"], forKey: AppPreferences.languageKey)
        #expect(prefs.readLocalSetting(.language).raw == .unsupported)
        #expect(prefs.language == .system)
    }

    @Test func bindingAndSharedEntryKeepImmediateAndSameValueWrites() throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        let prefs = fixture.preferences()
        @Bindable var binding = prefs
        $binding.language.wrappedValue = .english
        $binding.appearance.wrappedValue = .dark
        $binding.quadrantTitleTruncation.wrappedValue = .middle
        $binding.stampCaptureApp.wrappedValue = true
        #expect(prefs.resolvedLocale.identifier == "en" && prefs.resolvedColorScheme == .dark)
        #expect(fixture.events.count == 4 && fixture.appearances == [.system, .dark])
        $binding.appearance.wrappedValue = .dark
        #expect(fixture.events.count == 5 && fixture.appearances == [.system, .dark, .dark])
        #expect(prefs.readLocalSetting(.appearance).revision == 2)
        let result = prefs.applyLocalSetting(.appearance(.dark))
        #expect(result.write == .returned && result.event == .returned && result.after?.revision == 3)
        #expect(fixture.events.count == 6 && fixture.appearances.count == 4)
        #expect(prefs.readLocalSetting(.language).revision == 1)
    }

    @Test func everyEventHasOnlyFieldSourceAndItsRevision() throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        let prefs = fixture.preferences()
        for value in Self.values {
            let result = prefs.applyLocalSetting(value)
            let note = try #require(fixture.events.last)
            let change = try #require(note.object as? LocalPreferenceChange)
            #expect(note.name == .localPreferenceDidChange && note.userInfo == nil)
            #expect(change.source == prefs.localPreferenceSource && change.field == value.field)
            #expect(change.revision == result.after?.revision)
        }
        #expect(!fixture.events.contains { $0.name == .appPreferencesDidChange })
    }

    @Test func revisionsArePerFieldAndRawReadsDetectOnlyVisibleExternalChanges() throws {
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        let prefs = fixture.preferences()
        let original = prefs.readLocalSetting(.language)
        prefs.appearance = .dark
        #expect(prefs.readLocalSetting(.language) == original)
        prefs.language = .english
        prefs.language = .system
        #expect(prefs.readLocalSetting(.language).revision == 2)
        fixture.defaults.set("chinese", forKey: AppPreferences.languageKey)
        let external = prefs.readLocalSetting(.language)
        #expect(external.value == .language(.system) && external.storedValue == .language(.chinese))
        #expect(external.revision == 2)
        let other = fixture.preferences()
        #expect(other.localPreferenceSource.instanceID != prefs.localPreferenceSource.instanceID)
        #expect(other.localPreferenceSource.storageID == prefs.localPreferenceSource.storageID)
        #expect(other.readLocalSetting(.language).revision == 0 && other.language == .chinese)
    }

    @Test func observationAndInjectedAppearanceDoNotChangeApplicationAppearance() throws {
        let previous = NSApp.appearance
        let fixture = try LocalPreferenceTestSupport()
        defer { fixture.cleanup() }
        let prefs = fixture.preferences()
        let change = PreferenceObservationProbe()
        withObservationTracking {
            _ = prefs.resolvedLocale
            _ = prefs.resolvedColorScheme
            _ = prefs.quadrantTitleTruncation.textTruncation
        } onChange: { MainActor.assumeIsolated { change.changed = true } }
        prefs.language = .chinese
        #expect(change.changed)
        prefs.appearance = .dark
        prefs.appearance = .system
        #expect(fixture.appearances == [.system, .dark, .system])
        #expect(NSApp.appearance === previous)
    }
}

@MainActor private final class PreferenceObservationProbe {
    var changed = false
}
