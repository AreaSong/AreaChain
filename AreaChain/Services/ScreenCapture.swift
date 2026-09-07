import AppKit
import Foundation
import ScreenCaptureKit

enum ScreenCapture {
    @MainActor
    static func pngData() async -> Data? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return nil }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            return ImageBytes.png(from: nsImage)
        } catch {
            NSSound.beep()
            return nil
        }
    }
}
