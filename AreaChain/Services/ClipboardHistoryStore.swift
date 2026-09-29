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
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        guard let file = try? JSONDecoder().decode(ClipboardHistoryFile.self, from: data) else { return [] }
        return file.items
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
