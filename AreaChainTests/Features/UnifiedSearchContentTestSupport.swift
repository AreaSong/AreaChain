import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@MainActor final class UnifiedSearchContentFixture {
    let base: UnifiedSearchNavigationFixture
    let tag: TagItem
    let diary: DiaryEntry
    let image: AttachmentItem
    let root: URL
    let store: AttachmentStore
    let session: ContentQueryReadSession
    let content: WorkspaceContentSession
    var controller: UnifiedSearchController!
    let bodyProbe = BodyReadProbe()
    var reads = 0
    var context: ModelContext { base.context }
    var imagePause: (() async throws -> Void)?
    static let text = (0..<90).map { "合成查阅段落 \($0) — ordinary text / # ! 保持原文，不是应用命令。" }.joined(separator: "\n\n")

    init(handoff: HandoffFixture? = nil, multiPlan: MultiPlanCommandAdapter? = nil) throws {
        base = try UnifiedSearchNavigationFixture(handoff: handoff)
        root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-NM2-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = AttachmentStore(keys: VaultKeyAccess(), root: root)
        tag = TagItem(name: "NM2 真实关联", sortOrder: 0)
        diary = DiaryEntry(text: Self.text, dayKey: base.day)
        image = AttachmentItem(ownerKind: "todo", ownerID: base.todo.id, filename: "合成山景.png")
        base.context.insert(tag); base.context.insert(diary); base.context.insert(image)
        base.todo.tagIDs = tag.id.uuidString; base.routine.tagIDs = tag.id.uuidString
        base.child.tagIDs = tag.id.uuidString; diary.tagIDs = tag.id.uuidString
        try Self.png().write(to: store.fileURL(id: image.id))
        try base.context.save()
        base.saves = 0; base.publications = 0
        var bodies = ContentQueryBodyReads(context: base.context, ordinaryOnly: true)
        bodies.observeContent = bodyProbe.observe
        session = try ContentQueryReadSession(vault: base.vault,
            imageReads: .init(context: base.context, bodies: bodies), coordinator: base.handoff.coordinator,
            ownership: base.handoff.owned().lease.ownership,
            notifications: .init(privacy: base.privacy, model: base.model, focus: NotificationCenter(),
                focusLost: .init("NM2.focus"), focusObject: NSObject()))
        session.install()
        content = WorkspaceContentSession(reader: .init(bodies: bodies, vault: base.vault,
            attachments: store, attachmentRoot: root, navigation: base.router.objects))
        base.router.contents = content
        controller = UnifiedSearchController(session: session, coordinator: base.handoff.coordinator,
            buffer: .init(lease: try base.handoff.owned().lease, version: 0, text: "needle"),
            read: { [weak self] in
                guard let self else { throw WorkspaceContentFailure.stale }
                return try await self.read()
            }, recordOpen: { _ in Issue.record("不得进入旧意图回调") }, multiPlan: multiPlan)
        controller.navigationRouter = base.router
    }

    func read() async throws -> ContentQueryReadEffect {
        reads += 1
        let query = try base.handoff.state().query
        let handle: ContentQueryReadHandle
        if query.typeAnalysis.possibleTypes.contains(.image) {
            handle = try session.prepareImages(observation: RoutineContentQueryFixture.observation(base.day))
        } else {
            handle = try session.prepare { query in
                TaskFamilyContentQueryReader(context: context, diaryMode: .metadataOnly)
                    .read(session: query, requestID: UUID(), observation: RoutineContentQueryFixture.observation(base.day)).batch
            }
        }
        try session.evaluate(handle)
        return try await session.publish(handle)
    }

    func query(_ text: String) async throws {
        let previous = try? session.presentation().pagination.snapshot.version
        _ = controller.edit(.init(source: controller.buffer, text: text, selection: .init(location: text.utf16.count, length: 0)))
        for _ in 0..<150 {
            if let publication = try? session.presentation(), publication.pagination.snapshot.version != previous { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        _ = try session.presentation()
    }

    func start(style: Int = 0) async throws {
        try await base.start(style: style, controller: controller, attachments: store)
    }

    func open(_ object: CommandObjectReference) async throws {
        let page = try session.presentation().pagination
        try #require(page.snapshot.visible.contains(object))
        controller.browse(.init(version: page.snapshot.version, action: .activate(object)), source: controller.buffer)
        controller.browse(.init(version: page.snapshot.version, action: .open(inputEditing: false)), source: controller.buffer)
        await controller.navigationTask?.value
        try await base.settle()
    }

    func nativeOpen(_ object: CommandObjectReference) async throws {
        try await base.settle()
        // 当前查询是直接装配的合法查询；Esc 沿原输入契约先关闭仍展开的目录候选。
        if controller.inputReset.state?.suggestions.isActive == true { try await base.key(53, "\u{1b}") }
        try await base.click("unified.hit." + object.searchIdentifier)
        #expect(try session.presentation().pagination.browse.active == object)
        try await base.key(36, "\r")
        await controller.navigationTask?.value
        try await base.settle()
    }

    func serviceOpen(_ object: CommandObjectReference, parent: CommandObjectReference? = nil,
                     using other: WorkspaceContentSession? = nil) async throws {
        let target = other ?? content
        let publication = try session.presentation()
        if other != nil { try target.bindSource(target.captureSource(), publication: publication) }
        await target.open(.init(object: object, parent: parent, viewingTrash: false), session: session,
            lease: controller.buffer.lease, version: publication.pagination.snapshot.version)
    }

    func assertNoWrites() throws {
        #expect(base.saves == 0 && base.publications == 0)
        #expect(!context.hasChanges)
        #expect(try context.fetch(FetchDescriptor<RoutineCheck>()).isEmpty)
    }

    func stop() {
        content.clear(); controller.detach(); session.detach(); base.stop()
    }

    static func png() throws -> Data {
        let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 320, pixelsHigh: 200,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        let bytes = try #require(rep.bitmapData)
        for y in 0..<200 {
            for x in 0..<320 {
                let mountain = y < 110 - abs(x - 160) / 3
                let offset = y * rep.bytesPerRow + x * 4
                bytes[offset] = mountain ? 36 : 80
                bytes[offset + 1] = mountain ? 122 : 190
                bytes[offset + 2] = mountain ? 64 : 230
                bytes[offset + 3] = 255
            }
        }
        #expect(try #require(rep.colorAt(x: 160, y: 20)).alphaComponent == 1)
        return try #require(rep.representation(using: .png, properties: [:]))
    }
}
