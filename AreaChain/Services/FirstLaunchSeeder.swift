import Foundation
import SwiftData

enum FirstLaunchSeeder {
    static let defaultsKey = "areachain.seeded.v1"

    static func shouldSeed(existingCount: Int, alreadySeeded: Bool) -> Bool {
        !alreadySeeded && existingCount == 0
    }

    @MainActor
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
        do {
            try ModelChanges.transaction(in: context) {
                let repo = SwiftDataRoutineRepository(context: context)
                _ = try repo.addRoutine(CreateRoutineParams(
                    title: L10n.string("seed.routine.daily", locale: locale),
                    sortOrder: 0,
                    weekdaysOnly: true
                ))
                _ = try repo.addRoutine(CreateRoutineParams(
                    title: L10n.string("seed.routine.review", locale: locale),
                    sortOrder: 1
                ))
            }
        } catch {
            return
        }
        defaults.set(true, forKey: defaultsKey)
    }
}
