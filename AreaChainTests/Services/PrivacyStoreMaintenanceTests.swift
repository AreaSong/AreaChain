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

    private func open(_ url: URL) throws -> ModelContainer {
        let schema = Schema(AreaChainSchema.models)
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration("VacuumFixture", schema: schema, url: url, cloudKitDatabase: .none)
        )
    }
}
