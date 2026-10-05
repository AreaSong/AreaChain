import Foundation
import Testing
@testable import AreaChain

@MainActor
final class LocalPreferenceTestSupport {
    let suite = "areachain.local-preference.tests.\(UUID())"
    let defaults: UserDefaults
    let center = NotificationCenter()
    var appearances: [AppAppearance] = []
    var events: [Notification] = []

    init() throws { defaults = try #require(UserDefaults(suiteName: suite)) }

    var effects: LocalPreferenceEffects {
        LocalPreferenceEffects(applyAppearance: { [unowned self] in appearances.append($0) },
            post: { [unowned self] in events.append($0); center.post($0) })
    }

    func preferences(storage: LocalPreferenceStorage? = nil) -> AppPreferences {
        AppPreferences(defaults: defaults, localStorage: storage, effects: effects)
    }

    func cleanup() { defaults.removePersistentDomain(forName: suite) }
}
