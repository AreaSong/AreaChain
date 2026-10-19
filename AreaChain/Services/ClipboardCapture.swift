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

/// “剪贴板加今天”的唯一业务入口。产品约定：有文字只取文字（保留原文、只解析普通 #标签，不解析时间与优先级，
/// 同时有图也不挂图）；只有图片才挂图；可按偏好附来源 Bundle ID；不写剪贴板，因此不进剪贴板历史。
/// 读剪贴板、附件存储、偏好与日期都可注入；生产默认值与原实现一致，菜单栏调用不变。
enum ClipboardCapture {
    /// 一次读到的剪贴板内容。
    struct Contents {
        var text: String?
        var image: NSImage?
    }

    @MainActor struct Environment {
        var read: @MainActor () -> Contents
        var storage: any AttachmentStorageProtocol
        var locale: @MainActor () -> Locale
        var today: @MainActor () -> String
        /// 按“附来源”偏好给出的 Bundle ID；关闭时为空。
        var sourceBundleID: @MainActor () -> String

        static func production(pasteboard: NSPasteboard, storage: any AttachmentStorageProtocol) -> Environment {
            .init(read: { .init(text: pasteboard.string(forType: .string), image: ImageBytes.pasteboardImage(pasteboard)) },
                  storage: storage,
                  locale: { AppPreferences.shared.resolvedLocale },
                  today: { DayClock.shared.todayKey },
                  sourceBundleID: { CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp) })
        }
    }

    /// 已决定的一次捕获：载荷、身份与日期都在写入前确定，写入只在调用方事务内发生。
    struct Capture {
        let payload: ClipboardPayload.Result
        let image: NSImage?
        let todoID: UUID
        let attachmentID: UUID
        let dayKey: String
        let sourceBundleID: String
    }

    @MainActor
    @discardableResult
    static func ingest(
        container: ModelContainer,
        pasteboard: NSPasteboard = .general,
        storage: any AttachmentStorageProtocol = AttachmentStore.shared
    ) -> Bool {
        ingest(container: container, environment: .production(pasteboard: pasteboard, storage: storage))
    }

    @MainActor
    @discardableResult
    static func ingest(container: ModelContainer, environment: Environment) -> Bool {
        let contents = environment.read()
        guard let payload = payload(contents, locale: environment.locale()) else { return false }
        let context = container.mainContext
        let capture = Capture(payload: payload, image: contents.image, todoID: UUID(), attachmentID: UUID(),
                              dayKey: environment.today(), sourceBundleID: environment.sourceBundleID())
        let saved = ModelChanges.perform(in: context) {
            _ = try apply(capture, storage: environment.storage, in: context)
        }
        if !saved, payload.attachImage { environment.storage.removeFile(id: capture.attachmentID) }
        return saved
    }

    @MainActor
    static func payload(_ contents: Contents, locale: Locale) -> ClipboardPayload.Result? {
        let imageTitle = L10n.string("capture.image", locale: locale)
        return ClipboardPayload.make(text: contents.text, hasImage: contents.image != nil, imageTitle: imageTitle)
    }

    /// 唯一写入：新建今天的待办，只解析普通标签；只有图片时把图写进附件池。不自行保存。
    @MainActor
    static func apply(_ capture: Capture, storage: any AttachmentStorageProtocol, in context: ModelContext) throws -> TodoItem {
        let payload = capture.payload
        let todo = TodoItem(id: capture.todoID, title: payload.title, dayKey: capture.dayKey, sourceBundleID: capture.sourceBundleID)
        let names = TagSyntax.names(in: payload.title, includesDiaryTags: false)
        todo.tagIDs = try InputTagResolver.merging(names, into: "", in: context)
        context.insert(todo)
        if payload.attachImage {
            guard let image = capture.image, let data = ImageBytes.png(from: image) else { throw ScreenCaptureFailure.encode }
            if let concreteStore = storage as? AttachmentStore {
                _ = try AttachmentPoolStore.saveOrLink(
                    data: data, filename: "paste.png", ownerKind: .todo,
                    ownerID: todo.id, context: context, store: concreteStore, id: capture.attachmentID
                )
            } else {
                let existing = (try? context.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.liveAttachments)))?.map(\.filename) ?? []
                let resolvedName = AttachmentSyntax.uniqueFilename(base: "paste.png", existing: existing)
                _ = try storage.save(
                    data: data, filename: resolvedName, ownerKind: .todo,
                    ownerID: todo.id, context: context, id: capture.attachmentID
                )
            }
        }
        return todo
    }
}
