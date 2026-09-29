import Darwin
import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct PrivacyStoreMaintenanceTests {
    @Test func requestDoesNotVacuumWhileStoreIsOpen() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-vacuum-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "fixture.store")
        try autoreleasepool {
            let container = try open(url)
            let context = container.mainContext
            try PrivacyStoreMaintenance.mark(context)
            #expect(PrivacyStoreMaintenance.isPending(context))
            PrivacyStoreMaintenance.request(context)
            Thread.sleep(forTimeInterval: 0.4)
            #expect(FileManager.default.fileExists(atPath: PrivacyStoreMaintenance.marker(for: url).path))
        }
        try PrivacyStoreMaintenance.finish(at: url)
        #expect(!FileManager.default.fileExists(atPath: PrivacyStoreMaintenance.marker(for: url).path))
    }

    @Test func vacuumInterruptLeavesMarkerAndRetrySucceeds() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-vacuum-interrupt-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            PrivacyStoreMaintenance.testingVacuumInterruptAfter = nil
            PrivacyStoreMaintenance.testingVacuumProgress = nil
            try? FileManager.default.removeItem(at: root)
        }
        let url = root.appending(path: "fixture.store")
        let title = "VACUUM_INTERRUPT_SENTINEL"
        try seed(url, title: title, rows: 400, noteSize: 2_048)
        PrivacyStoreMaintenance.testingVacuumInterruptAfter = 1
        #expect(throws: PrivacyError.storageFailure) {
            try PrivacyStoreMaintenance.finish(at: url)
        }
        #expect(FileManager.default.fileExists(atPath: PrivacyStoreMaintenance.marker(for: url).path))
        try autoreleasepool {
            let container = try open(url)
            #expect(try container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == 400)
            let wanted = "\(title)-0"
            var descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.title == wanted })
            descriptor.fetchLimit = 1
            #expect(try container.mainContext.fetch(descriptor).first?.title == wanted)
        }
        PrivacyStoreMaintenance.testingVacuumInterruptAfter = nil
        try PrivacyStoreMaintenance.finish(at: url)
        #expect(!FileManager.default.fileExists(atPath: PrivacyStoreMaintenance.marker(for: url).path))
    }

    @Test func vacuumCancelDuringStatementLeavesMarker() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-vacuum-cancel-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            PrivacyStoreMaintenance.testingVacuumProgress = nil
            try? FileManager.default.removeItem(at: root)
        }
        let url = root.appending(path: "fixture.store")
        try seed(url, title: "VACUUM_CANCEL_SENTINEL", rows: 400, noteSize: 2_048)
        let gate = CancelGate()
        PrivacyStoreMaintenance.testingVacuumProgress = { try gate.blockUntilCancelled() }
        let task = Task.detached {
            try PrivacyStoreMaintenance.finish(at: url)
        }
        try await Task.detached { try gate.waitUntilWorkStarted() }.value
        task.cancel()
        await #expect(throws: PrivacyError.cancelled) { try await task.value }
        #expect(FileManager.default.fileExists(atPath: PrivacyStoreMaintenance.marker(for: url).path))
        PrivacyStoreMaintenance.testingVacuumProgress = nil
        try PrivacyStoreMaintenance.finish(at: url)
        #expect(!FileManager.default.fileExists(atPath: PrivacyStoreMaintenance.marker(for: url).path))
    }

    @Test func missingStoreKeepsMarker() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-vacuum-missing-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "missing.store")
        let marker = PrivacyStoreMaintenance.marker(for: url)
        try Data("AreaChain privacy cleanup v1".utf8).write(to: marker, options: .atomic)
        #expect(throws: PrivacyError.storageFailure) {
            try PrivacyStoreMaintenance.finish(at: url)
        }
        #expect(FileManager.default.fileExists(atPath: marker.path))
    }

    @Test func unopenableStoreKeepsMarker() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-vacuum-unopenable-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "not-a-store")
        try Data("not sqlite".utf8).write(to: url)
        let marker = PrivacyStoreMaintenance.marker(for: url)
        try Data("AreaChain privacy cleanup v1".utf8).write(to: marker, options: .atomic)
        #expect(throws: PrivacyError.storageFailure) {
            try PrivacyStoreMaintenance.finish(at: url)
        }
        #expect(FileManager.default.fileExists(atPath: marker.path))
    }

    @Test func killedExternalVacuumLeavesStoreReadableAndFinishSucceeds() throws {
        try #require(FileManager.default.isExecutableFile(atPath: "/usr/bin/sqlite3"))
        let root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-vacuum-kill-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "fixture.store")
        let title = "VACUUM_KILL_SENTINEL"
        try seed(url, title: title, rows: 1_500, noteSize: 4_096)
        try interruptExternalVacuum(at: url)
        // sidecar 标记不是库文件；VACUUM 重写库时不得把它删掉。finish 成功后才删除。
        #expect(FileManager.default.fileExists(atPath: PrivacyStoreMaintenance.marker(for: url).path))
        try autoreleasepool {
            let container = try open(url)
            #expect(try container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == 1_500)
            let wanted = "\(title)-0"
            var descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.title == wanted })
            descriptor.fetchLimit = 1
            #expect(try container.mainContext.fetch(descriptor).first?.title == wanted)
        }
        try PrivacyStoreMaintenance.finish(at: url)
        #expect(!FileManager.default.fileExists(atPath: PrivacyStoreMaintenance.marker(for: url).path))
    }

    private func seed(_ url: URL, title: String, rows: Int, noteSize: Int) throws {
        let blob = String(repeating: "n", count: noteSize)
        try autoreleasepool {
            let container = try open(url)
            let context = container.mainContext
            for index in 0..<rows {
                context.insert(TodoItem(title: "\(title)-\(index)", dayKey: "2026-09-29", notes: blob))
            }
            try context.save()
            try PrivacyStoreMaintenance.mark(context)
        }
    }

    /// 杀死独立 `sqlite3 VACUUM`，证明辅助进程被 SIGKILL 后合成库仍可读、随后 `finish` 可完成。
    /// 不杀测试宿主，也不等于应用进程内 `sqlite3_exec(VACUUM)` 被杀。
    private func interruptExternalVacuum(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            url.path,
            "PRAGMA cache_size=1; PRAGMA wal_checkpoint(TRUNCATE); VACUUM;"
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        let started = Date().addingTimeInterval(0.2)
        while !process.isRunning, Date() < started {
            Thread.sleep(forTimeInterval: 0.001)
        }
        try #require(process.isRunning, "未能启动 /usr/bin/sqlite3 VACUUM")
        // 给 checkpoint/VACUUM 一个短窗口再杀；若已经正常退出，夹具太小，不能冒充中途中断。
        let dwell = Date().addingTimeInterval(0.008)
        while process.isRunning, Date() < dwell {
            Thread.sleep(forTimeInterval: 0.001)
        }
        try #require(process.isRunning, "VACUUM 在观察窗口内已结束，无法证明进程被杀死")
        kill(process.processIdentifier, SIGKILL)
        process.waitUntilExit()
        try #require(
            process.terminationReason == .uncaughtSignal,
            "未能 SIGKILL sqlite3 VACUUM：reason=\(process.terminationReason.rawValue)，status=\(process.terminationStatus)"
        )
    }

    private func open(_ url: URL) throws -> ModelContainer {
        let schema = Schema(AreaChainSchema.models)
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(UUID().uuidString, schema: schema, url: url, cloudKitDatabase: .none)
        )
    }
}
