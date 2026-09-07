import Foundation
import SwiftData
import Testing
@testable import AreaChain

struct AttachmentStoreTests {
    @Test func writesReadsAndPurgesFile() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "areachain-att-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let id = UUID()
        let owner = UUID()
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        _ = try AttachmentStore.save(
            data: data,
            filename: "shot.png",
            ownerKind: .todo,
            ownerID: owner,
            context: context,
            root: root,
            id: id
        )
        #expect(AttachmentStore.loadData(id: id, root: root) == data)
        let items = try context.fetch(FetchDescriptor<AttachmentItem>())
        #expect(items.first?.filename == "shot.png")
        AttachmentStore.purge(ownerID: owner, attachments: items, context: context, root: root)
        #expect(AttachmentStore.loadData(id: id, root: root) == nil)
        #expect(try context.fetch(FetchDescriptor<AttachmentItem>()).isEmpty)
    }
}

struct CaptureStampTests {
    @Test func staysOffUnlessEnabledAndNotSelf() {
        #expect(CaptureStamp.bundleID(enabled: false, frontmost: "com.apple.Safari", selfBundle: "com.areachain.app") == "")
        #expect(CaptureStamp.bundleID(enabled: true, frontmost: "com.apple.Safari", selfBundle: "com.areachain.app") == "com.apple.Safari")
        #expect(CaptureStamp.bundleID(enabled: true, frontmost: "com.areachain.app", selfBundle: "com.areachain.app") == "")
        #expect(CaptureStamp.bundleID(enabled: true, frontmost: nil, selfBundle: "com.areachain.app") == "")
    }
}
