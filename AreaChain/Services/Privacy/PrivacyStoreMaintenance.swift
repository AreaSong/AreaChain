import Foundation
import SQLite3
import SwiftData

/// 更新正文列不足以清除 SQLite 空闲页/WAL。清理标记先于转换落盘，崩溃后仍可重试重建。
enum PrivacyStoreMaintenance {
    #if DEBUG
    /// 进度回调达到该次数后中断正在执行的 VACUUM；0 或 nil 只看任务取消。
    nonisolated(unsafe) static var testingVacuumInterruptAfter: Int?
    /// 进度回调里调用，便于测试卡在语句执行中；夹具必须在 defer 里清掉。
    nonisolated(unsafe) static var testingVacuumProgress: (@Sendable () throws -> Void)?
    #endif

    static func marker(for url: URL) -> URL { url.appendingPathExtension("privacy-cleanup") }

    @MainActor static func storeURL(_ context: ModelContext) -> URL? {
        context.container.configurations.first(where: { !$0.isStoredInMemoryOnly })?.url
    }

    @MainActor static func mark(_ context: ModelContext) throws {
        guard let url = storeURL(context) else { return }
        try Data("AreaChain privacy cleanup v1".utf8).write(to: marker(for: url), options: .atomic)
    }

    @MainActor static func isPending(_ context: ModelContext) -> Bool {
        guard let url = storeURL(context) else { return false }
        return FileManager.default.fileExists(atPath: marker(for: url).path)
    }

    /// 只刷新界面。VACUUM 必须在下次冷启动、SwiftData 容器尚未打开时由 `Persistence.makeSession` 调用 `finish(at:)`。
    @MainActor static func request(_ context: ModelContext) {
        guard storeURL(context) != nil else { return }
        PrivacyVault.shared.changed()
    }

    /// 只操作当前容器的已知库路径；不读取标记中的路径，也不清理用户的其他备份。
    static func finish(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: marker(for: url).path) else { return }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let db else {
            if let db { sqlite3_close(db) }
            throw PrivacyError.storageFailure
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 1_000)
        guard sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil) == SQLITE_OK else {
            throw PrivacyError.storageFailure
        }
        try PrivacyTask.checkCancellation()
        let status = vacuum(db)
        if status != SQLITE_OK {
            // 进度回调中断与打开失败一样保留标记；取消不要报成存储损坏。
            if Task.isCancelled { throw PrivacyError.cancelled }
            throw PrivacyError.storageFailure
        }
        guard sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil) == SQLITE_OK else {
            throw PrivacyError.storageFailure
        }
        try FileManager.default.removeItem(at: marker(for: url))
    }

    private static func vacuum(_ db: OpaquePointer) -> Int32 {
        let probe = VacuumProbe()
        sqlite3_progress_handler(db, 16, vacuumProgress, Unmanaged.passUnretained(probe).toOpaque())
        defer { sqlite3_progress_handler(db, 0, nil, nil) }
        return sqlite3_exec(db, "VACUUM;", nil, nil, nil)
    }
}

private final class VacuumProbe: @unchecked Sendable {
    var ticks = 0
}

private let vacuumProgress: @convention(c) (UnsafeMutableRawPointer?) -> Int32 = { pointer in
    guard let pointer else { return 0 }
    let probe = Unmanaged<VacuumProbe>.fromOpaque(pointer).takeUnretainedValue()
    probe.ticks += 1
    #if DEBUG
    if let hook = PrivacyStoreMaintenance.testingVacuumProgress {
        do { try hook() } catch { return 1 }
    }
    if let limit = PrivacyStoreMaintenance.testingVacuumInterruptAfter, limit > 0, probe.ticks >= limit {
        return 1
    }
    #endif
    return Task.isCancelled ? 1 : 0
}
