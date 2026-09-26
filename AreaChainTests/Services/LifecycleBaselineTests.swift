import Darwin
import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 冷启动、大库重开、常驻内存和加密恢复的可重复上限。数字关联本机 Debug、合成数据和单次冷测量。
@Suite(.serialized)
@MainActor
struct LifecycleBaselineTests {
    private static let schema = Schema(AreaChainSchema.models)
    private static let populatedTodoCount = 2_000
    /// Debug 测试进程在容器打开时的安全网，不是产品峰值内存 SLA。
    private static let populatedReopenRSSBudget: UInt64 = 1_500_000_000
    /// 连续重开后当前 RSS 相对首次的允许增量，用来挡住明显泄漏，不是完整 leak 审计。
    private static let reopenRSSGrowthBudget: UInt64 = 128 * 1024 * 1024

    @Test func emptyDiskStoreOpensUnderStartupBudget() throws {
        let elapsed = try measureColdOpen(seedEmpty: true)
        #expect(elapsed < 3_000, "空库打开加首次预置必须在 3000ms 内，实际 \(elapsed)ms")
        print("STARTUP_BASELINE empty_disk_ms=\(elapsed)")
    }

    @Test func populatedDiskStoreReopensUnderBudget() throws {
        let storeURL = try makeTemporaryStoreURL()
        defer { removeStore(storeURL) }
        try seedPopulatedStore(url: storeURL)
        let elapsed = try measureReopen(url: storeURL)
        #expect(elapsed < 5_000, "2000 条待办加重开必须在 5000ms 内，实际 \(elapsed)ms")
        print("LARGE_STORE_BASELINE reopen_ms=\(elapsed)")
    }

    @Test func populatedDiskStoreReopenResidentMemoryStaysUnderBudget() throws {
        let storeURL = try makeTemporaryStoreURL()
        defer { removeStore(storeURL) }
        try seedPopulatedStore(url: storeURL)
        let bytes = try autoreleasepool {
            try reopenResidentBytes(url: storeURL)
        }
        #expect(
            bytes < Self.populatedReopenRSSBudget,
            "2000 条重开时进程 RSS 必须低于 \(Self.populatedReopenRSSBudget) 字节，实际 \(bytes)"
        )
        print("PEAK_RSS_BASELINE reopen_bytes=\(bytes)")
    }

    @Test func repeatedLargeStoreReopenResidentMemoryDoesNotGrowUnbounded() throws {
        let storeURL = try makeTemporaryStoreURL()
        defer { removeStore(storeURL) }
        try seedPopulatedStore(url: storeURL)
        var samples: [UInt64] = []
        for _ in 0..<8 {
            let bytes = try autoreleasepool {
                try reopenResidentBytes(url: storeURL)
            }
            samples.append(bytes)
        }
        let first = samples[0]
        let last = samples[samples.count - 1]
        #expect(
            last <= first + Self.reopenRSSGrowthBudget,
            "连续 8 次重开 RSS 增长必须低于 \(Self.reopenRSSGrowthBudget) 字节，首次 \(first) 末次 \(last)"
        )
        print("RSS_GROWTH_BASELINE samples=\(samples)")
    }

    @Test func encryptedBackupRestoreStaysUnderBudget() async throws {
        let source = try await PrivacyFixture.make()
        let destination = try await PrivacyFixture.make(password: "restore-baseline-master")
        defer { source.cleanup(); destination.cleanup() }
        let tag = try source.tag()
        let privateNote = try source.repository.addDiary(text: "RESTORE_BASELINE_PRIVATE", dayKey: "2026-09-15", tagIDs: [tag.id])
        source.context.insert(TodoItem(title: "恢复基线待办", dayKey: "2026-09-15"))
        _ = try source.image(owner: privateNote, data: Data(repeating: 0x11, count: 256 * 1024))
        try source.context.save()
        let url = source.root.appending(path: "baseline.areachainbackup")
        _ = try await PrivateBackupService.export(to: url, password: "independent-backup-passphrase", environment: source.environment)
        let start = ProcessInfo.processInfo.systemUptime
        try await PrivateBackupService.restore(
            from: url, password: "independent-backup-passphrase", environment: destination.environment
        )
        let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1_000
        #expect(elapsed < 8_000, "合成加密恢复必须在 8000ms 内，实际 \(elapsed)ms")
        #expect(try destination.repository.fetchDiary(id: privateNote.id)?.hasProtectedContent == true)
        print("BACKUP_RESTORE_BASELINE restore_ms=\(elapsed)")
    }

    private func measureColdOpen(seedEmpty: Bool) throws -> Double {
        let storeURL = try makeTemporaryStoreURL()
        let defaultsName = "areachain.baseline.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defaults.removePersistentDomain(forName: defaultsName)
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            removeStore(storeURL)
        }
        let start = ProcessInfo.processInfo.systemUptime
        let container = try diskContainer(url: storeURL)
        if seedEmpty {
            let context = container.mainContext
            let existing = (try? context.fetchCount(FetchDescriptor<DailyRoutine>())) ?? 0
            FirstLaunchSeeder.seedIfNeeded(context: context, existingCount: existing, defaults: defaults)
            try context.save()
        }
        let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1_000
        if seedEmpty {
            #expect(try container.mainContext.fetchCount(FetchDescriptor<DailyRoutine>()) == 2)
        }
        return elapsed
    }

    private func seedPopulatedStore(url: URL) throws {
        try autoreleasepool {
            let container = try diskContainer(url: url)
            let context = container.mainContext
            for index in 0..<Self.populatedTodoCount {
                context.insert(TodoItem(title: "事项 \(index)", dayKey: "2026-09-01"))
            }
            let routine = DailyRoutine(title: "重复事项", sortOrder: 0)
            context.insert(routine)
            for offset in 0..<365 {
                context.insert(RoutineCheck(dayKey: DayKey.shifted("2025-01-01", by: offset), isDone: true, routine: routine))
            }
            try context.save()
        }
    }

    private func measureReopen(url: URL) throws -> Double {
        let start = ProcessInfo.processInfo.systemUptime
        let container = try diskContainer(url: url)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == Self.populatedTodoCount)
        return (ProcessInfo.processInfo.systemUptime - start) * 1_000
    }

    private func reopenResidentBytes(url: URL) throws -> UInt64 {
        let container = try diskContainer(url: url)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == Self.populatedTodoCount)
        return ProcessResidentMemory.bytes()
    }

    private func diskContainer(url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration("Baseline", schema: Self.schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: Self.schema, configurations: configuration)
    }

    private func makeTemporaryStoreURL() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-life-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("areachain.store")
    }

    private func removeStore(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

private enum ProcessResidentMemory {
    static func bytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        precondition(result == KERN_SUCCESS, "task_info failed: \(result)")
        return info.resident_size
    }
}
