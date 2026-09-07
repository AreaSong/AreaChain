import AppKit
import Foundation
import ScreenCaptureKit

enum ScreenCapture {
    @MainActor
    static func pngData() async -> Result<Data, ScreenCaptureFailure> {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return .failure(.noDisplay) }
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

    private static func mapError(_ error: Error) -> ScreenCaptureFailure {
        if let stream = error as? SCStreamError, stream.code == .userDeclined {
            return .permission
        }
        return ScreenCaptureFailure.classify(error)
    }
}
