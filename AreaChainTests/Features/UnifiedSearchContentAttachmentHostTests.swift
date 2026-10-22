import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// M-5F（N-M2 整改）：隔离宿主没有显式附件存储时，附件页与回收站不得退回共享附件目录；
/// 只用内存库与临时目录。不装配统一搜索控制器，让工作台直接渲染目标页；纯程序化渲染，不发键鼠事件，走后台轮。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchContentAttachmentHostTests {
    private func nodes(_ window: NSWindow?) -> [NSObject] { SettingsButtonTestSupport.elements(window?.contentView) }

    private func identifiers(_ window: NSWindow?) -> Set<String> {
        Set(nodes(window).compactMap { SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String })
    }

    private func texts(_ window: NSWindow?) -> [String] {
        nodes(window).flatMap { node in
            ["accessibilityLabel", "accessibilityTitle", "accessibilityValue", "stringValue"]
                .compactMap { SettingsButtonTestSupport.value(node, $0) as? String }
        }
    }

    private func headerEnabled(_ id: String, in window: NSWindow?) throws -> Bool? {
        let node = try #require(nodes(window).first {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == "workspace.header.action." + id
        })
        return (node.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue
    }

    @Test func storageResolutionHasOneRulePerHost() throws {
        let production = try #require(WorkspaceAttachmentStorage.resolve(nil))
        #expect(production.store === AttachmentStore.shared && production.root == nil && !production.ordinaryOnly)
        let f = try UnifiedSearchNavigationFixture(); defer { f.stop() }
        #expect(WorkspaceAttachmentStorage.resolve(f.hostContext) == nil)
        let root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-M5F-" + UUID().uuidString)
        var host = f.hostContext
        host.attachments = AttachmentStore(keys: VaultKeyAccess(), root: root)
        let isolated = try #require(WorkspaceAttachmentStorage.resolve(host))
        #expect(isolated.store === host.attachments && isolated.root == root && isolated.ordinaryOnly)
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test func browserWithoutHostStoreShowsNoAttachmentsAndDisablesWrites() async throws {
        let f = try UnifiedSearchNavigationFixture(); defer { f.stop() }
        let live = AttachmentItem(ownerKind: "todo", ownerID: f.todo.id, filename: "M5F 不应呈现.png")
        f.context.insert(live)
        try f.context.save()
        try await f.start(unified: false)
        f.navigation.revealTab(.attachments)
        try await f.settle()
        #expect(!identifiers(f.window).contains("attachments.preview." + live.id.uuidString))
        #expect(!texts(f.window).contains { $0.contains("M5F 不应呈现") })
        for action in ["attachments.upload", "attachments.paste"] {
            #expect(try headerEnabled(action, in: f.window) == false)
        }
    }

    @Test func trashWithoutHostStoreHidesAttachmentRows() async throws {
        let f = try UnifiedSearchNavigationFixture(); defer { f.stop() }
        let deleted = AttachmentItem(ownerKind: "todo", ownerID: f.todo.id, filename: "M5F 回收站附件.png")
        deleted.deletedAt = .now
        let todo = TodoItem(title: "M5F 回收站任务", dayKey: f.day)
        todo.deletedAt = .now
        f.context.insert(deleted); f.context.insert(todo)
        try f.context.save()
        try await f.start(unified: false)
        f.navigation.revealTab(.trash)
        try await f.settle()
        let shown = texts(f.window)
        // 非附件行照常呈现，证明页面已渲染；附件行没有宿主存储就不出现。
        #expect(shown.contains { $0.contains("M5F 回收站任务") })
        #expect(!shown.contains { $0.contains("M5F 回收站附件") })
    }

    @Test func browserWithHostStoreReadsOnlyThatStore() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        let names = try FileManager.default.contentsOfDirectory(atPath: f.root.path)
        try await f.base.start(unified: false, attachments: f.store)
        f.base.navigation.revealTab(.attachments)
        try await f.base.settle()
        #expect(identifiers(f.base.window).contains("attachments.preview." + f.image.id.uuidString))
        for action in ["attachments.upload", "attachments.paste"] {
            #expect(try headerEnabled(action, in: f.base.window) != false)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.root.path) == names)
        try f.assertNoWrites()
    }

    /// 检查器附件缩略图同样只读宿主存储：图片只写在宿主临时目录，读到才会出现 56pt 高的位图（占位是矩形加小图标）。
    @Test func inspectorThumbnailReadsHostStore() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.base.start(unified: false, attachments: f.store)
        f.base.navigation.revealTab(.allItems, inspecting: f.base.todo.id, dayKey: f.base.day)
        try await f.base.settle()
        #expect(f.base.navigation.selectedTaskID == f.base.todo.id && f.base.navigation.isInspectorPresented)
        // 附件分区在检查器折叠线以下，先滚到底让它进入无障碍树。
        for scroll in nodes(f.base.window).compactMap({ $0 as? NSScrollView }) {
            guard let document = scroll.documentView else { continue }
            scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, document.frame.height - scroll.contentView.bounds.height)))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        try await f.base.settle()
        let pick = L10n.string("drawer.attachments.pick", locale: Locale(identifier: "en"))
        #expect(texts(f.base.window).contains(pick))
        let thumbnails = nodes(f.base.window).filter { node in
            guard SettingsButtonTestSupport.value(node, "accessibilityRole") as? String == "AXImage",
                  let frame = node.value(forKey: "accessibilityFrame") as? NSRect else { return false }
            // scaledToFill 的无障碍框按原图比例展开，高度才是缩略图格子的 56pt。
            return abs(frame.height - 56) < 1 && frame.width >= 55
        }
        #expect(thumbnails.count == 1)
        try f.assertNoWrites()
    }
}
