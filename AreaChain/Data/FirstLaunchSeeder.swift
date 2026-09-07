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
        context.insert(DailyRoutine(title: "写日报", sortOrder: 0))
        context.insert(DailyRoutine(title: "复盘", sortOrder: 1))
        defaults.set(true, forKey: defaultsKey)
    }
}
