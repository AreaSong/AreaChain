import Foundation
import Testing
@testable import AreaChain

struct StreakInspectionStatusTests {
    @Test func skippedWinsOverCompletedWhenBothFlagsAreSet() {
        #expect(
            StreakInspectionFlags(isCompleted: true, isSkipped: true, isDue: true)
                .status(isEnabled: true) == .skipped
        )
        #expect(
            StreakInspectionFlags(isCompleted: true, isSkipped: false, isDue: true)
                .status(isEnabled: true) == .completed
        )
        #expect(
            StreakInspectionFlags(isCompleted: false, isSkipped: false, isDue: true)
                .status(isEnabled: false) == .paused
        )
        #expect(
            StreakInspectionFlags(isCompleted: false, isSkipped: false, isDue: false)
                .status(isEnabled: true) == .offday
        )
        #expect(
            StreakInspectionFlags(isCompleted: false, isSkipped: false, isDue: true)
                .status(isEnabled: true) == .pending
        )
    }
}
