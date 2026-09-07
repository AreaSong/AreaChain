import AppKit
import Foundation
import SwiftData

enum CaptureStamp {
    static func bundleID(enabled: Bool, frontmost: String?, selfBundle: String?) -> String {
        guard enabled, let frontmost, !frontmost.isEmpty else { return "" }
        if let selfBundle, frontmost == selfBundle { return "" }
        return frontmost
    }

    static func current(enabled: Bool) -> String {
        bundleID(
            enabled: enabled,
            frontmost: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            selfBundle: Bundle.main.bundleIdentifier
        )
    }
}

enum BundleDisplay {
    static func name(for bundleID: String) -> String {
        guard !bundleID.isEmpty else { return "" }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let bundle = Bundle(url: url)
            if let display = bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String, !display.isEmpty {
                return display
            }
            if let name = bundle?.infoDictionary?["CFBundleName"] as? String, !name.isEmpty {
                return name
            }
        }
        return bundleID
    }
}

enum ClipboardCapture {
    @MainActor
    static func ingest(container: ModelContainer, pasteboard: NSPasteboard = .general) {
        let text = pasteboard.string(forType: .string)
        let image = ImageBytes.pasteboardImage(pasteboard)
        let imageTitle = L10n.string("capture.image", locale: AppPreferences.shared.resolvedLocale)
        guard let payload = ClipboardPayload.make(text: text, hasImage: image != nil, imageTitle: imageTitle) else {
            return
        }
        let context = ModelContext(container)
        let todo = TodoItem(
            title: payload.title,
            dayKey: DayClock.shared.todayKey,
            sourceBundleID: CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp)
        )
        context.insert(todo)
        if payload.attachImage, let image, let data = ImageBytes.png(from: image) {
            _ = try? AttachmentStore.save(
                data: data,
                filename: "paste.png",
                ownerKind: .todo,
                ownerID: todo.id,
                context: context
            )
        }
        try? context.save()
        BoardEvents.changed()
    }
}
