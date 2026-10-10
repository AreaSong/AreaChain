import Foundation

/// 只监视本批明确路径；文件替换、删除或属性变化撤销展示，不生成缓存或副本。
final class WorkspaceContentFile {
    private let source: DispatchSourceFileSystemObject
    private let url: URL
    private let identity: [FileAttributeKey: NSObject]

    init(url: URL, changed: @escaping @MainActor @Sendable () -> Void) throws {
        self.url = url
        identity = try Self.stamp(url)
        let descriptor = open(url.path, O_EVTONLY | O_NOFOLLOW)
        guard descriptor >= 0 else { throw CocoaError(.fileReadNoPermission) }
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .revoke, .attrib, .extend], queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { changed() } }
        source.setCancelHandler { close(descriptor) }
        source.resume()
    }

    func validate() throws {
        guard try Self.stamp(url) == identity else { throw WorkspaceContentFailure.stale }
    }

    private static func stamp(_ url: URL) throws -> [FileAttributeKey: NSObject] {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else { throw WorkspaceContentFailure.invalidImage }
        return [.systemFileNumber, .size, .modificationDate, .posixPermissions].reduce(into: [:]) {
            $0[$1] = attributes[$1] as? NSObject
        }
    }

    deinit { source.cancel() }
}
