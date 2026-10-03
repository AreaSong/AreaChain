import Foundation

/// 剪贴板历史的独立目录。不进 SwiftData，因此不会出现在待办导出或手记备份里。
@MainActor
final class ClipboardHistoryStore {
    let root: URL

    init(root: URL? = nil, fileManager: FileManager = .default) {
        self.root = root ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "areachain-clipboard", directoryHint: .isDirectory)
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
        return name
    }

    func imageData(named name: String) -> Data? {
        guard name.isEmpty == false, !name.contains("/") else { return nil }
        return try? Data(contentsOf: root.appending(path: name))
    }

    func pruneImages(keeping names: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        for url in files where url.pathExtension == "png" && !names.contains(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
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
