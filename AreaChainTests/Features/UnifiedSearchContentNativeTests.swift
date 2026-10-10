import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchContentNativeTests {
    @Test(arguments: [0, 1, 2, 3]) func realTagDiaryAndImageReturnChain(_ style: Int) async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.start(style: style)
        try await f.query("/tags")
        try await f.base.settle()
        let original = try f.base.handoff.state().query
        try await f.nativeOpen(.init(type: .tag, id: f.tag.id))
        #expect(f.base.router.outcome == .displayed)
        #expect(f.base.router.mounted("content." + f.tag.id.uuidString))
        try await snapshot(f, name: "tag-\(style)", style: style)
        try await f.base.click("unified.navigation.return")
        #expect(try f.base.handoff.state().query == original)
        // 同一当前目录候选供 go.tagList 使用；不按名字再找第一条。
        try await f.base.typeNative("/go/tag")
        try await f.base.key(36, "\r")
        if f.controller.returnSearch == nil { try await f.base.key(36, "\r") }
        await f.controller.navigationTask?.value
        #expect(f.content.content != nil)
        try await f.base.key(53, "\u{1b}")
        #expect(f.base.navigation.isSearching)
        try await f.query("/diaries")
        let query = try f.base.handoff.state().query
        let version = try f.session.presentation().pagination.snapshot.version
        try await f.nativeOpen(.init(type: .diary, id: f.diary.id))
        guard case .diary(let diary) = f.content.content else { Issue.record("实际手记未显示"); return }
        #expect(diary.text == UnifiedSearchContentFixture.text)
        #expect(f.base.router.mounted("content." + f.diary.id.uuidString))
        try await snapshot(f, name: "diary-\(style)", style: style)
        try await f.base.click("unified.navigation.return")
        #expect(try f.session.presentation().pagination.snapshot.version == version)
        #expect(try f.base.handoff.state().query == query && f.content.content == nil)
        try await f.query("/images")
        try await f.nativeOpen(.init(type: .image, id: f.image.id))
        guard case .image(let image, _, _, _) = f.content.content else { Issue.record("实际图片未显示"); return }
        #expect(image.size == NSSize(width: 320, height: 200))
        #expect(f.base.router.mounted("content." + f.image.id.uuidString))
        try await snapshot(f, name: "image-\(style)", style: style)
        try await f.base.click("unified.navigation.return")
        #expect(f.base.navigation.isSearching && f.content.content == nil)
        try f.assertNoWrites()
    }

    @Test func expiredContentReturnAndRealLockClearOldRequests() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.start()
        try await f.query("/diaries")
        try await f.open(.init(type: .diary, id: f.diary.id))
        let ticket = try #require(f.controller.returnSearch)
        let reads = f.reads
        f.diary.deletedAt = .now
        #expect(f.content.content == nil)
        try await f.base.settle()
        try await snapshot(f, name: "deleted-target", style: 0)
        try await f.base.back()
        #expect(f.reads > reads && f.controller.navigationMessage == "unified.navigation.missing")
        f.diary.deletedAt = nil
        try await f.query("/diaries")
        try await f.open(.init(type: .diary, id: f.diary.id))
        f.base.vault.lock()
        #expect(f.content.content == nil && f.controller.returnSearch == nil)
        #expect(f.controller.buffer.text.isEmpty)
        await f.controller.returnToSearch(ticket.id)
        #expect(f.controller.returnSearch == nil && f.controller.buffer.text.isEmpty)
    }

    @Test(arguments: [0, 1]) func nativeFileErrorsHaveAccurateFeedback(_ mode: Int) async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        if mode == 0 { f.image.storageID = UUID() }
        else { try Data("合成损坏图片".utf8).write(to: f.store.fileURL(id: f.image.id)) }
        try await f.start()
        try await f.query("/images")
        try await f.open(.init(type: .image, id: f.image.id))
        #expect(f.content.failure == (mode == 0 ? .missingFile : .invalidImage))
        #expect(f.content.content == nil && f.controller.returnSearch != nil)
        try await snapshot(f, name: "image-error-\(mode)", style: 0)
        try await f.base.click("unified.navigation.return")
        #expect(f.base.navigation.isSearching)
    }

    private func snapshot(_ f: UnifiedSearchContentFixture, name: String, style: Int) async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-NM2-QA")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try cache(try #require(f.base.window?.contentView), path: root.appending(path: name + "-workspace.png"))
        let object: CommandObjectReference
        guard case .content(let current) = f.base.router.destination else { return }
        object = current
        let host = WorkspaceReadOnlyContentView(session: f.content, object: object, controller: f.controller)
            .modelContainer(f.base.data.container).environment(\.modelContext, f.context).environment(f.base.prefs)
            .environment(\.workspaceHostContext, f.base.hostContext).environment(\.workspaceEmbedded, true)
            .environment(\.locale, Locale(identifier: style < 2 ? "en" : "zh-Hans"))
            .preferredColorScheme(style % 2 == 1 ? .dark : .light)
        let window = NSWindow(contentViewController: NSHostingController(rootView: host))
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: style < 2 ? 680 : 480, height: style < 2 ? 640 : 380))
        window.orderFront(nil)
        try await SystemPageHost.settle(window)
        let view = try #require(window.contentView)
        let hasImage: Bool
        if case .image = f.content.content { hasImage = true } else { hasImage = false }
        try cache(view, path: root.appending(path: name + "-content.png"), expectsImage: hasImage)
        if case .diary = f.content.content {
            let scrolls = SettingsButtonTestSupport.elements(view).compactMap { $0 as? NSScrollView }
            let scroll = try #require(scrolls.first { ($0.documentView?.bounds.height ?? 0) > $0.bounds.height + 100 })
            let text = try #require(scroll.documentView as? SearchReadOnlyEditor)
            #expect(!text.isEditable && text.isSelectable && text.string == UnifiedSearchContentFixture.text)
            text.setSelectedRange(NSRange(location: 0, length: 10))
            #expect(text.selectedRange().length == 10)
            let before = scroll.contentView.bounds.origin.y
            let event = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -300, wheel2: 0, wheel3: 0))
            scroll.scrollWheel(with: try #require(NSEvent(cgEvent: event)))
            try await SystemPageHost.settle(window)
            #expect(scroll.contentView.bounds.origin.y > before)
            scroll.contentView.scroll(to: NSPoint(x: 0, y: (scroll.documentView?.bounds.height ?? 0) - scroll.contentView.bounds.height))
            scroll.reflectScrolledClipView(scroll.contentView)
            try await SystemPageHost.settle(window)
            #expect(scroll.contentView.bounds.origin.y > before + 100)
            try cache(view, path: root.appending(path: name + "-scrolled.png"))
        }
        window.orderOut(nil); window.contentViewController = nil
        f.base.window?.makeKeyAndOrderFront(nil)
        try await NativeSyntaxUI.prepareFocus(in: try #require(f.base.window))
        print("NM2_SCREENSHOT " + root.appending(path: name + "-content.png").path)
    }

    private func cache(_ view: NSView, path: URL, expectsImage: Bool = false) throws {
        view.layoutSubtreeIfNeeded()
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        if expectsImage {
            var colored = 0
            for y in stride(from: 0, to: rep.pixelsHigh, by: 20) {
                for x in stride(from: 0, to: rep.pixelsWide, by: 20) {
                    if let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                       color.greenComponent - color.redComponent > 0.2 { colored += 1 }
                }
            }
            #expect(colored > 100, "实际图像不能是文件名、空容器或透明像素")
        }
        try #require(rep.representation(using: .png, properties: [:])).write(to: path)
    }
}
