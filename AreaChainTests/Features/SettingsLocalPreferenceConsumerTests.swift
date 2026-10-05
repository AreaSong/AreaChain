import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct SettingsLocalPreferenceConsumerTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func captureToggleUsesSameAuthorityWithoutOtherSettings(locale: String, scheme: ColorScheme) async throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { fixture.cleanup() }
        let state = SettingsPickerProbe()
        let window = fixture.window(SettingsPickerForm(prefs: fixture.prefs, state: state), locale: locale, scheme: scheme,
            size: NSSize(width: 420, height: 720))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        var changes: [LocalPreferenceChange] = []
        let observer = fixture.preferenceCenter.addObserver(forName: .localPreferenceDidChange, object: nil, queue: .main) { note in
            MainActor.assumeIsolated {
                if let change = note.object as? LocalPreferenceChange { changes.append(change) }
            }
        }
        defer { fixture.preferenceCenter.removeObserver(observer) }
        let toggle = try #require(SettingsButtonTestSupport.elements(window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == "settings.capture"
                && SettingsButtonTestSupport.value($0, "accessibilityRole") as? String == "AXCheckBox"
        })
        try await SettingsButtonTestSupport.reveal(toggle, in: window)
        try await SettingsButtonTestSupport.click(toggle, in: window)
        #expect(fixture.prefs.stampCaptureApp)
        #expect(fixture.defaults.bool(forKey: AppPreferences.stampCaptureAppKey))
        #expect(changes.count == 1 && changes.first?.field == .stampCaptureApp)
        fixture.prefs.applyLocalSetting(.stampCaptureApp(false))
        try await SystemPageHost.settle(window)
        #expect((SettingsButtonTestSupport.value(toggle, "accessibilityValue") as? NSNumber)?.boolValue == false)
        #expect(changes.count == 2 && changes.last?.revision == 2)
        #expect(state.loginRequests.isEmpty && !fixture.prefs.syncCalendarEvents)
        #expect(fixture.defaults.persistentDomain(forName: fixture.suite)?.keys.sorted() == [AppPreferences.stampCaptureAppKey])
    }
}
