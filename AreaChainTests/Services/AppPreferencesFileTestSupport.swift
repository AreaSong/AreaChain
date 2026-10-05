import Foundation
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
final class AppPreferencesFileFixture {
    enum Failure: Error { case injected }
    let legacy: LocalPreferenceMigrationFixture
    let center = NotificationCenter()
    var appearances: [AppAppearance] = []
    var events: [Notification] = []
    var failAppearance = false
    var failEvent = false
    var onAppearance: (() -> Void)?
    var onEvent: (() -> Void)?

    init() throws { legacy = try LocalPreferenceMigrationFixture() }

    var effects: LocalPreferenceEffects {
        .init(applyAppearance: { [unowned self] value in
            appearances.append(value)
            onAppearance?()
            if failAppearance { throw Failure.injected }
        }, post: { [unowned self] note in
            events.append(note)
            onEvent?()
            if failEvent { throw Failure.injected }
            center.post(note)
        })
    }

    func preferences(_ startup: LocalPreferenceMigrationResult,
                     fault: LocalPreferenceFileFault? = nil) throws -> AppPreferences {
        try AppPreferences(defaults: legacy.defaults, fileStore: legacy.files.store(fault), startup: startup, effects: effects)
    }

    func ready(_ fault: LocalPreferenceFileFault? = nil) throws -> AppPreferences {
        let record = try legacy.files.seed()
        return try preferences(.ready(record, cleanupPending: false), fault: fault)
    }

    func resetEffects() { appearances.removeAll(); events.removeAll() }

    static func values(_ prefs: AppPreferences) -> LocalPreferenceValues {
        .init(language: prefs.language, appearance: prefs.appearance,
              quadrantTitleTruncation: prefs.quadrantTitleTruncation, stampCaptureApp: prefs.stampCaptureApp)
    }

    static func assignAllBindings(_ prefs: AppPreferences) {
        @Bindable var binding = prefs
        $binding.language.wrappedValue = .english
        $binding.appearance.wrappedValue = .dark
        $binding.quadrantTitleTruncation.wrappedValue = .middle
        $binding.stampCaptureApp.wrappedValue = true
    }

    static let changes: [LocalPreferenceValue] = [
        .language(.english), .appearance(.dark), .quadrantTitleTruncation(.middle), .stampCaptureApp(true)
    ]
    static let changedValues = LocalPreferenceValues(language: .english, appearance: .dark,
                                                     quadrantTitleTruncation: .middle, stampCaptureApp: true)
}
