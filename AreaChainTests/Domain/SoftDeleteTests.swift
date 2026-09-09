import Foundation
import Testing
@testable import AreaChain

struct SoftDeleteTests {
    @Test func restoreOnlyMatchesIdenticalStamp() {
        let stamp = Date(timeIntervalSince1970: 100)
        #expect(SoftDelete.shouldRestoreChild(parentDeletedAt: stamp, childDeletedAt: stamp))
        #expect(
            !SoftDelete.shouldRestoreChild(
                parentDeletedAt: stamp,
                childDeletedAt: Date(timeIntervalSince1970: 99)
            )
        )
        #expect(!SoftDelete.shouldRestoreChild(parentDeletedAt: stamp, childDeletedAt: nil))
        #expect(!SoftDelete.shouldRestoreChild(parentDeletedAt: nil, childDeletedAt: stamp))
    }
}
