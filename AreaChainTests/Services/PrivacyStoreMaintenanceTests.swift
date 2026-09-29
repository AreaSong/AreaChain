import Darwin
import Foundation
import SQLite3
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
            PrivacyStoreMaintenance.testingVacuumStatus = nil
            try? FileManager.default.removeItem(at: root)
        }
        let url = root.appending(path: "fixture.store")
        let title = "VACUUM_INTERRUPT_SENTINEL"
        try autoreleasepool {
            let container = try open(url)
            let context = container.mainContext
            context.insert(TodoItem(title: title, dayKey: "2026-09-29"))
            try context.save()
            try PrivacyStoreMaintenance.mark(context)
        }
        PrivacyStoreMaintenance.testingVacuumStatus = SQLITE_INTERRUPT
        #expect(throws: PrivacyError.storageFailure) {
            try PrivacyStoreMaintenance.finish(at: url)
        }
        #expect(FileManager.default.fileExists(atPath: PrivacyStoreMaintenance.marker(for: url).path))
        try autoreleasepool {
            let container = try open(url)
            let todo = try #require(try container.mainContext.fetch(FetchDescriptor<TodoItem>()).first)
            #expect(todo.title == title)
        }
        PrivacyStoreMaintenance.testingVacuumStatus = nil
        try PrivacyStoreMaintenance.finish(at: url)
        #expect(!FileManager.default.fileExists(atPath: PrivacyStoreMaintenance.marker(for: url).path))
        try autoreleasepool {
            let container = try open(url)
            let todo = try #require(try container.mainContext.fetch(FetchDescriptor<TodoItem>()).first)
            #expect(todo.title == title)
        }
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

    @Test func killedVacuumLeavesMarkerAndRetrySucceeds() throws {
        try #require(FileManager.default.isExecutableFile(atPath: "/usr/bin/sqlite3"))
        let root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-vacuum-kill-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "fixture.store")
        let title = "VACUUM_KILL_SENTINEL"
        try seed(url, title: title, rows: 1_500, noteSize: 4_096)
        try killExternalVacuum(at: url)
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

    /// 杀死独立 `sqlite3 VACUUM` 进程，模拟 `finish` 做到一半被 SIGKILL；不杀测试宿主。
    private func killExternalVacuum(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [url.path, "PRAGMA wal_checkpoint(TRUNCATE); VACUUM;"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        // 启动后立刻杀死，避免小库 VACUUM 在等待循环里跑完；Process.run 不会等到语句结束。
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
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
