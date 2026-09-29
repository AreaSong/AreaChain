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

    private func open(_ url: URL) throws -> ModelContainer {
        let schema = Schema(AreaChainSchema.models)
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(UUID().uuidString, schema: schema, url: url, cloudKitDatabase: .none)
        )
    }
}
