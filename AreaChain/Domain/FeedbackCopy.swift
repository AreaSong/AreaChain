import Foundation

enum CalendarSyncPhase: Equatable {
    case off
    case denied
    case unavailable
    case synced
    case failed
    case conflict
    case localUnavailable

    var messageKey: String {
        switch self {
        case .off: "settings.calendar.sync.status.off"
        case .denied: "settings.calendar.sync.status.denied"
        case .unavailable: "settings.calendar.sync.status.unavailable"
        case .synced: "settings.calendar.sync.status.ok"
        case .failed: "settings.calendar.sync.status.failed"
        case .conflict: "settings.calendar.sync.status.conflict"
        case .localUnavailable: "settings.calendar.sync.status.localUnavailable"
        }
    }
}

enum ScreenCaptureFailure: Equatable, Error {
    case noDisplay
    case permission
    case encode
    case unknown

    var messageKey: String {
        switch self {
        case .noDisplay: "screen.capture.fail.display"
        case .permission: "screen.capture.fail.permission"
        case .encode: "screen.capture.fail.encode"
        case .unknown: "screen.capture.fail.unknown"
        }
    }

    static func classify(_ error: Error) -> ScreenCaptureFailure {
        let text = error.localizedDescription.lowercased()
        if text.contains("declin") || text.contains("denied") || text.contains("author")
            || text.contains("permission") || text.contains("tcc") || text.contains("not trusted") {
            return .permission
        }
        return .unknown
    }
}
