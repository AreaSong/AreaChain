import Foundation
import Observation

/// 跟踪 EventKit 日历同步生命周期阶段与时间戳
@Observable
@MainActor
final class CalendarSyncStatus {
    static let shared = CalendarSyncStatus()

    var phase: CalendarSyncPhase = .off
    var lastSyncedAt: Date?

    func mark(_ phase: CalendarSyncPhase) {
        self.phase = phase
        if phase == .synced {
            lastSyncedAt = .now
        }
        if phase == .off {
            lastSyncedAt = nil
        }
    }
}
