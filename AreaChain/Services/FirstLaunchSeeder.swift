import Foundation
import SwiftData

enum FirstLaunchSeeder {
    static let defaultsKey = "areachain.seeded.v1"

    static func shouldSeed(existingCount: Int, alreadySeeded: Bool) -> Bool {
        !alreadySeeded && existingCount == 0
    }

    static func seedIfNeeded(context: ModelContext, existingCount: Int) {
        let defaults = UserDefaults.standard
        let already = defaults.bool(forKey: defaultsKey)
        guard shouldSeed(existingCount: existingCount, alreadySeeded: already) else {
            if existingCount > 0 {
                defaults.set(true, forKey: defaultsKey)
            }
            return
        }
        let locale = AppPreferences.shared.resolvedLocale
        context.insert(
            DailyRoutine(
                title: L10n.string("seed.routine.daily", locale: locale),
                sortOrder: 0,
                weekdaysOnly: true
            )
        )
        context.insert(
            DailyRoutine(
                title: L10n.string("seed.routine.review", locale: locale),
                sortOrder: 1
            )
        )
        defaults.set(true, forKey: defaultsKey)
    }
}
