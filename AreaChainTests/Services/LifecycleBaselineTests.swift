import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 冷启动、大库重开和加密恢复的可重复上限。数字关联本机 Debug、合成数据和单次冷测量。
@Suite(.serialized)
@MainActor
struct LifecycleBaselineTests {
    private static let schema = Schema(AreaChainSchema.models)

    @Test func emptyDiskStoreOpensUnderStartupBudget() throws {
        let elapsed = try measureColdOpen(seedEmpty: true)
        #expect(elapsed < 3_000, "空库打开加首次预置必须在 3000ms 内，实际 \(elapsed)ms")
        print("STARTUP_BASELINE empty_disk_ms=\(elapsed)")
    }

    @Test func populatedDiskStoreReopensUnderBudget() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-large-\(UUID().uuidString)")
        let storeURL = root.appendingPathComponent("areachain.store")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try autoreleasepool {
            let container = try diskContainer(url: storeURL)
            let context = container.mainContext
            for index in 0..<2_000 {
                context.insert(TodoItem(title: "事项 \(index)", dayKey: "2026-09-01"))
            }
            let routine = DailyRoutine(title: "重复事项", sortOrder: 0)
            context.insert(routine)
            for offset in 0..<365 {
                context.insert(RoutineCheck(dayKey: DayKey.shifted("2025-01-01", by: offset), isDone: true, routine: routine))
            }
            try context.save()
        }
        let elapsed = try measureReopen(url: storeURL)
        #expect(elapsed < 5_000, "2000 条待办加重开必须在 5000ms 内，实际 \(elapsed)ms")
        print("LARGE_STORE_BASELINE reopen_ms=\(elapsed)")
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
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-start-\(UUID().uuidString)")
        let storeURL = root.appendingPathComponent("areachain.store")
        let defaultsName = "areachain.baseline.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defaults.removePersistentDomain(forName: defaultsName)
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            try? FileManager.default.removeItem(at: root)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
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

    private func measureReopen(url: URL) throws -> Double {
        let start = ProcessInfo.processInfo.systemUptime
        let container = try diskContainer(url: url)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == 2_000)
        return (ProcessInfo.processInfo.systemUptime - start) * 1_000
    }

    private func diskContainer(url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration("Baseline", schema: Self.schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: Self.schema, configurations: configuration)
    }
}
