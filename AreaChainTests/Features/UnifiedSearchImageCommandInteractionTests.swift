import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 原生：image.browse 在面板里列出附件中心可见的图片；image.preview 沿普通图片查阅打开，
/// 不另开查看器、不写库。0 标准英文浅色、3 最小中文深色。
@Suite(.serialized) @MainActor struct UnifiedSearchImageCommandInteractionTests {
    private func fixture() throws -> UnifiedSearchContentFixture {
        let f = try UnifiedSearchContentFixture()
        f.controller.pageCommands = WorkspacePageCommands(router: f.base.router, host: f.base.hostContext, context: f.context)
        return f
    }

    @Test(arguments: [0, 3]) func previewOpensTheOrdinaryImageThroughNM2(style: Int) async throws {
        let f = try fixture()
        defer { f.stop() }
        try await f.start(style: style)
        try await f.query("/images")
        let image = CommandObjectReference(type: .image, id: f.image.id)
        try #require(try f.session.presentation().pagination.snapshot.visible.contains(image))
        try await f.base.begin("image.preview")
        try await f.base.target([image])
        try await f.base.press("unified.page.prepare")
        #expect(try f.base.label("unified.page.before").contains("合成山景.png"))
        try await f.base.press("unified.page.apply")
        // 查阅先重读结果再沿普通图片查阅打开，两段都是异步任务：等到两者都结束且内容会话不再加载（有上限，不靠运气）。
        for _ in 0..<150 {
            await f.controller.contentCommandTask?.value
            await f.controller.navigationTask?.value
            if f.controller.contentCommandTask == nil, f.controller.navigationTask == nil, !f.content.loading,
               f.content.content != nil || f.controller.pageFailure != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        try await f.base.settle()
        guard case .image(_, let filename, let owner, _)? = f.content.content else {
            Issue.record("应沿 N-M2 打开图片：\(String(describing: f.content.failure)) page=\(String(describing: f.controller.pageFailure))"); return
        }
        #expect(filename == "合成山景.png" && owner == .init(type: .todo, id: f.base.todo.id))
        try f.assertNoWrites()
        try await f.base.snapshot("m2-image-preview-\(style)")
    }

    @Test func browseListsTheImagesInThePanel() async throws {
        let f = try fixture()
        defer { f.stop() }
        try await f.start(style: 1)
        try await f.base.begin("image.browse")
        try await f.base.edit(.init(parameter: .kind, operation: .assign, value: .choice("todo")))
        try await f.base.press("unified.page.prepare")
        try await f.base.press("unified.page.apply")
        #expect(f.controller.pageReceipt?.after == .results(["合成山景.png"], total: 1))
        try f.assertNoWrites()
        try await f.base.snapshot("m2-image-browse")
    }
}
