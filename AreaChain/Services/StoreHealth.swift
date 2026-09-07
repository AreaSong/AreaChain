import Foundation
import Observation

@Observable
final class StoreHealth {
    static let shared = StoreHealth()

    var isUsingMemoryFallback = false
    var openError: String?

    func apply(_ session: PersistenceSession) {
        isUsingMemoryFallback = session.isFallback
        openError = session.openError
    }
}
