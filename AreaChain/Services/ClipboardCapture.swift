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
    nonisolated(unsafe) private static let nameCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 256
        return cache
    }()

    nonisolated(unsafe) private static let iconCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 128
        return cache
    }()

    static func name(for bundleID: String) -> String {
        guard !bundleID.isEmpty else { return "" }
        let key = bundleID as NSString
        if let cached = nameCache.object(forKey: key) {
            return cached as String
        }
        let resolved: String
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let bundle = Bundle(url: url)
            if let display = bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String, !display.isEmpty {
                resolved = display
            } else if let name = bundle?.infoDictionary?["CFBundleName"] as? String, !name.isEmpty {
                resolved = name
            } else {
                resolved = bundleID
            }
        } else {
            resolved = bundleID
        }
        nameCache.setObject(resolved as NSString, forKey: key)
        return resolved
    }

    static func icon(for bundleID: String) -> NSImage? {
        guard !bundleID.isEmpty else { return nil }
        let key = bundleID as NSString
        if let cached = iconCache.object(forKey: key) {
            return cached
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        iconCache.setObject(icon, forKey: key)
        return icon
    }
}

enum ClipboardCapture {
    @MainActor
    @discardableResult
    static func ingest(
        container: ModelContainer,
        pasteboard: NSPasteboard = .general,
        storage: any AttachmentStorageProtocol = AttachmentStore.shared
    ) -> Bool {
        let text = pasteboard.string(forType: .string)
        let image = ImageBytes.pasteboardImage(pasteboard)
        let imageTitle = L10n.string("capture.image", locale: AppPreferences.shared.resolvedLocale)
        guard let payload = ClipboardPayload.make(text: text, hasImage: image != nil, imageTitle: imageTitle) else {
            return false
        }
        let context = container.mainContext
        let todo = TodoItem(
            title: payload.title,
            dayKey: DayClock.shared.todayKey,
            sourceBundleID: CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp)
        )
        let attachmentID = UUID()
        let saved = ModelChanges.perform(in: context) {
            let names = TagSyntax.names(in: payload.title, includesDiaryTags: false)
            todo.tagIDs = try InputTagResolver.merging(names, into: "", in: context)
            context.insert(todo)
            if payload.attachImage {
                guard let image, let data = ImageBytes.png(from: image) else { throw ScreenCaptureFailure.encode }
                if let concreteStore = storage as? AttachmentStore {
                    _ = try AttachmentPoolStore.saveOrLink(
                        data: data, filename: "paste.png", ownerKind: .todo,
                        ownerID: todo.id, context: context, store: concreteStore, id: attachmentID
                    )
                } else {
                    let existing = (try? context.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.liveAttachments)))?.map(\.filename) ?? []
                    let resolvedName = AttachmentSyntax.uniqueFilename(base: "paste.png", existing: existing)
                    _ = try storage.save(
                        data: data, filename: resolvedName, ownerKind: .todo,
                        ownerID: todo.id, context: context, id: attachmentID
                    )
                }
            }
        }
        if !saved, payload.attachImage { storage.removeFile(id: attachmentID) }
        return saved
    }
}
