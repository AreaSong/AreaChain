import AppKit
import Foundation
import ImageIO

struct ClipboardImageMetadata: Equatable, Sendable {
    let pixelWidth: Int
    let pixelHeight: Int
    let byteCount: Int
    let dimensionsLabel: String
    let byteCountLabel: String

    init(pixelWidth: Int, pixelHeight: Int, byteCount: Int) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteCount = byteCount
        self.dimensionsLabel = "\(pixelWidth) × \(pixelHeight)"
        self.byteCountLabel = ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}

private final class ClipboardImageMetadataBox {
    let value: ClipboardImageMetadata
    init(_ value: ClipboardImageMetadata) { self.value = value }
}

/// 剪贴板历史的独立目录。不进 SwiftData，因此不会出现在待办导出或手记备份里。
@MainActor
final class ClipboardHistoryStore {
    let root: URL
    private let thumbnailCache = NSCache<NSString, NSImage>()
    private let fullImageCache = NSCache<NSString, NSImage>()
    private let metadataCache = NSCache<NSString, ClipboardImageMetadataBox>()

    init(root: URL? = nil, fileManager: FileManager = .default) {
        self.root = root ?? AppGroup.containerURL
            .appending(path: "areachain-clipboard", directoryHint: .isDirectory)
        thumbnailCache.countLimit = 300
        fullImageCache.countLimit = 48
        metadataCache.countLimit = 400
    }

    func load() -> [ClipboardHistoryRecord] {
        if case .decoded(let items) = readHistory() { return items }
        return []
    }

    /// 全文件一次读入后按原格式解码；不检查引用文件，也不修复或清理磁盘。
    /// 只有系统读取错误明确表示不存在时才返回 missing，不能用 fileExists 推断空历史。
    func readHistory(readData: (URL) throws -> Data = { try Data(contentsOf: $0) }) -> ClipboardHistoryReadResult {
        let data: Data
        do { data = try readData(fileURL) }
        catch {
            let failure = error as NSError
            if (failure.domain == NSCocoaErrorDomain && failure.code == NSFileReadNoSuchFileError)
                || (failure.domain == NSPOSIXErrorDomain && failure.code == Int(ENOENT)) {
                return .missing
            }
            return .failed(.fileReadFailed)
        }
        do { return .decoded(try JSONDecoder().decode(ClipboardHistoryFile.self, from: data).items) }
        catch { return .failed(.decodingFailed) }
    }

    func save(_ items: [ClipboardHistoryRecord]) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(ClipboardHistoryFile(items: items))
        let temporary = root.appending(path: "history.json.tmp")
        try data.write(to: temporary, options: .atomic)
        let destination = fileURL
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: destination)
        }
    }

    func writeImage(_ data: Data, id: UUID) throws -> String {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let name = id.uuidString + ".png"
        try data.write(to: root.appending(path: name), options: .atomic)
        evictCachedImage(named: name)
        return name
    }

    func imageData(named name: String) -> Data? {
        guard isValidImageName(name) else { return nil }
        return try? Data(contentsOf: root.appending(path: name))
    }

    /// 使用 ImageIO 降采样生成指定最大像素边长的缩略图并缓存，避免列表重绘时反复解码整张原图。
    func thumbnailImage(named name: String, maxPixelSize: Int) -> NSImage? {
        guard isValidImageName(name) else { return nil }
        let clamped = max(32, maxPixelSize)
        let key = "\(name)#\(clamped)" as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        let url = root.appending(path: name)
        guard let cgImage = Self.decodeThumbnailCGImage(at: url, maxPixelSize: clamped) else {
            return nil
        }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    func cachedFullImage(named name: String) -> NSImage? {
        guard isValidImageName(name) else { return nil }
        return fullImageCache.object(forKey: name as NSString)
    }

    func fullImage(named name: String) -> NSImage? {
        guard isValidImageName(name) else { return nil }
        let key = name as NSString
        if let cached = fullImageCache.object(forKey: key) {
            return cached
        }
        let url = root.appending(path: name)
        if let cgImage = Self.decodeFullCGImage(at: url) {
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            fullImageCache.setObject(image, forKey: key)
            return image
        }
        guard let data = imageData(named: name), let image = NSImage(data: data) else {
            return nil
        }
        fullImageCache.setObject(image, forKey: key)
        return image
    }

    /// 在后台线程完成原图位图解压后再交回主线程缓存，保证双栏点击切换 0ms 不阻塞主线程。
    func loadFullImageAsync(named name: String) async -> NSImage? {
        guard isValidImageName(name) else { return nil }
        let key = name as NSString
        if let cached = fullImageCache.object(forKey: key) {
            return cached
        }
        let url = root.appending(path: name)
        let cgImage = await Task.detached(priority: .userInitiated) {
            Self.decodeFullCGImage(at: url)
        }.value
        guard !Task.isCancelled else { return nil }
        if let cgImage {
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            fullImageCache.setObject(image, forKey: key)
            return image
        }
        return fullImage(named: name)
    }

    nonisolated private static func decodeThumbnailCGImage(at url: URL, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    nonisolated private static func decodeFullCGImage(at url: URL) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary)
    }

    /// 免解码读取图片头部宽高属性与磁盘字节大小，供列表/网格直接展示分辨率。
    func imageMetadata(named name: String) -> ClipboardImageMetadata? {
        guard isValidImageName(name) else { return nil }
        let key = name as NSString
        if let cached = metadataCache.object(forKey: key) {
            return cached.value
        }
        let url = root.appending(path: name)
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let byteCount = (attrs[.size] as? NSNumber)?.intValue,
              let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else {
            return nil
        }
        let metadata = ClipboardImageMetadata(pixelWidth: width, pixelHeight: height, byteCount: byteCount)
        metadataCache.setObject(ClipboardImageMetadataBox(metadata), forKey: key)
        return metadata
    }

    func pruneImages(keeping names: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        for url in files where url.pathExtension == "png" && !names.contains(url.lastPathComponent) {
            let name = url.lastPathComponent
            try? FileManager.default.removeItem(at: url)
            evictCachedImage(named: name)
        }
    }

    private func isValidImageName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/")
    }

    private func evictCachedImage(named name: String) {
        let key = name as NSString
        fullImageCache.removeObject(forKey: key)
        metadataCache.removeObject(forKey: key)
        for size in [64, 88, 96, 112, 128, 160, 256, 320, 360] {
            thumbnailCache.removeObject(forKey: "\(name)#\(size)" as NSString)
        }
    }

    private var fileURL: URL {
        root.appending(path: "history.json")
    }
}

private struct ClipboardHistoryFile: Codable {
    var items: [ClipboardHistoryRecord]
}

/// 封闭错误类别不保留路径、原始 JSON 或底层错误；当前磁盘格式没有版本字段。
enum ClipboardHistoryReadFailure: Error, Equatable {
    case fileReadFailed, decodingFailed
}

enum ClipboardHistoryReadResult: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case missing
    case decoded([ClipboardHistoryRecord])
    case failed(ClipboardHistoryReadFailure)

    var description: String { "ClipboardHistoryReadResult(redacted)" }
    var debugDescription: String { description }
}
