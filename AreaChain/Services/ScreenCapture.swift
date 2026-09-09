import AppKit
import Foundation
import ScreenCaptureKit

enum ScreenCapture {
    @MainActor
    static func pngData() async -> Result<Data, ScreenCaptureFailure> {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = preferredDisplay(in: content.displays) else { return .failure(.noDisplay) }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            guard let data = ImageBytes.png(from: nsImage) else { return .failure(.encode) }
            return .success(data)
        } catch {
            return .failure(mapError(error))
        }
    }

    private static func preferredDisplay(in displays: [SCDisplay]) -> SCDisplay? {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let targetID = (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        if let targetID, let match = displays.first(where: { $0.displayID == targetID }) {
            return match
        }
        return displays.first
    }

    private static func mapError(_ error: Error) -> ScreenCaptureFailure {
        if let stream = error as? SCStreamError, stream.code == .userDeclined {
            return .permission
        }
        return ScreenCaptureFailure.classify(error)
    }
}
