import Darwin
import Foundation

/// 所有文件名均由后端生成，固定目录句柄避免路径替换后写到另一个目录。
final class LocalPreferenceFileIO {
    let root: URL
    let descriptor: Int32

    init(temporaryRoot: URL) throws {
        let root = temporaryRoot.standardizedFileURL.resolvingSymlinksInPath()
        let allowed = [FileManager.default.temporaryDirectory, URL(fileURLWithPath: "/tmp")]
            .map { $0.standardizedFileURL.resolvingSymlinksInPath().path + "/" }
        guard temporaryRoot.isFileURL, allowed.contains(where: { root.path.hasPrefix($0) }) else {
            throw LocalPreferenceFileIssue.invalidRoot
        }
        self.root = root
        descriptor = Darwin.open(root.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw LocalPreferenceFileIssue.invalidRoot }
    }

    deinit { Darwin.close(descriptor) }

    func read(_ name: String) throws -> Data? {
        let file = openat(descriptor, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard file >= 0 else {
            if errno == ENOENT { return nil }
            throw LocalPreferenceFileIssue.readFailed
        }
        defer { Darwin.close(file) }
        var info = stat()
        guard fstat(file, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_nlink == 1, info.st_size >= 0, info.st_size <= 65_536 else {
            throw LocalPreferenceFileIssue.readFailed
        }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(file, &buffer, buffer.count)
            if count == 0 { return data }
            if count < 0 {
                if errno == EINTR { continue }
                throw LocalPreferenceFileIssue.readFailed
            }
            guard data.count + count <= 65_536 else { throw LocalPreferenceFileIssue.readFailed }
            data.append(contentsOf: buffer.prefix(count))
        }
    }

    func create(_ name: String, data: Data, partial: Bool = false) throws {
        let file = openat(descriptor, name, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard file >= 0 else { throw LocalPreferenceFileIssue.temporaryWriteFailed }
        defer { Darwin.close(file) }
        let bytes = partial ? Data(data.prefix(max(1, data.count / 2))) : data
        try bytes.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.write(file, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw LocalPreferenceFileIssue.temporaryWriteFailed }
                offset += count
            }
        }
        if partial { throw LocalPreferenceFileIssue.temporaryWriteFailed }
    }

    /// 单次同目录命名空间替换；没有先删 current，也没有跨文件/掉电耐久承诺。
    func replace(candidate: String) throws {
        guard renameat(descriptor, candidate, descriptor, "current.json") == 0 else {
            throw LocalPreferenceFileIssue.replacementFailed
        }
    }

    func remove(_ name: String) throws {
        guard unlinkat(descriptor, name, 0) == 0 else { throw LocalPreferenceFileIssue.cleanupFailed }
    }

    func names() throws -> [String] {
        // 此处只检测未认领的准备文件，不按时间排序或从辅助文件提取偏好值。
        var original = stat()
        var current = stat()
        guard fstat(descriptor, &original) == 0, lstat(root.path, &current) == 0,
              original.st_dev == current.st_dev, original.st_ino == current.st_ino else {
            throw LocalPreferenceFileIssue.qualificationChanged
        }
        do { return try FileManager.default.contentsOfDirectory(atPath: root.path) }
        catch { throw LocalPreferenceFileIssue.readFailed }
    }
}

/// 进程内重入单独识别；跨实例/进程互斥仍由稳定锁文件上的 flock 提供。
private final class LocalPreferenceLockOwners: @unchecked Sendable {
    static let shared = LocalPreferenceLockOwners()
    private let mutex = NSLock()
    private var owners: [String: UInt32] = [:]

    func enter(_ key: String) throws {
        mutex.lock()
        defer { mutex.unlock() }
        let thread = pthread_mach_thread_np(pthread_self())
        if let owner = owners[key] {
            throw owner == thread ? LocalPreferenceFileIssue.reentrant : LocalPreferenceFileIssue.lockBusy
        }
        owners[key] = thread
    }

    func leave(_ key: String) {
        mutex.lock()
        defer { mutex.unlock() }
        owners[key] = nil
    }
}

final class LocalPreferenceFileLock {
    private let descriptor: Int32
    private let key: String
    private let directory: LocalPreferenceFileIO

    private init(descriptor: Int32, key: String, directory: LocalPreferenceFileIO) {
        self.descriptor = descriptor
        self.key = key
        self.directory = directory
    }

    static func acquire(_ directory: LocalPreferenceFileIO, creating: Bool) throws -> LocalPreferenceFileLock {
        var directoryInfo = stat()
        guard fstat(directory.descriptor, &directoryInfo) == 0 else { throw LocalPreferenceFileIssue.lockFailed }
        let key = "\(directoryInfo.st_dev):\(directoryInfo.st_ino)"
        try LocalPreferenceLockOwners.shared.enter(key)
        let flags = O_RDWR | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK | (creating ? O_CREAT : 0)
        let file = openat(directory.descriptor, "writer.lock", flags, 0o600)
        guard file >= 0 else {
            LocalPreferenceLockOwners.shared.leave(key)
            throw LocalPreferenceFileIssue.lockFailed
        }
        var info = stat()
        guard fstat(file, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG, info.st_nlink == 1,
              info.st_size == 0 else {
            Darwin.close(file)
            LocalPreferenceLockOwners.shared.leave(key)
            throw LocalPreferenceFileIssue.lockFailed
        }
        guard flock(file, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(file)
            LocalPreferenceLockOwners.shared.leave(key)
            throw LocalPreferenceFileIssue.lockBusy
        }
        return LocalPreferenceFileLock(descriptor: file, key: key, directory: directory)
    }

    func validate() throws {
        var opened = stat()
        var named = stat()
        guard fstat(descriptor, &opened) == 0,
              fstatat(directory.descriptor, "writer.lock", &named, AT_SYMLINK_NOFOLLOW) == 0,
              opened.st_dev == named.st_dev, opened.st_ino == named.st_ino else {
            throw LocalPreferenceFileIssue.qualificationChanged
        }
        _ = try directory.names()
    }

    deinit {
        flock(descriptor, LOCK_UN)
        Darwin.close(descriptor)
        LocalPreferenceLockOwners.shared.leave(key)
    }
}
