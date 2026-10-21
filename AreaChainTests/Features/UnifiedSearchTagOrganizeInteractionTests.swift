import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// 合并批 M-2 B（原生）：标签回收经共用独立确认面板（默认焦点在取消、Esc 只撤销确认）；私密标签合并在预览时拒绝；
/// 标签页取消与标签查询走页面指令面板。0 标准英文浅色、1 紧凑英文深色、2 标准中文深色、3 紧凑中文浅色。
@Suite(.serialized) @MainActor struct UnifiedSearchTagOrganizeInteractionTests {
    @Test(arguments: [0, 3]) func trashGoesThroughTheSharedConfirmationPanel(style: Int) async throws {
        let f = try UnifiedSearchSimpleFixture(organize: true)
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        try await f.begin("/tags/trash", host: host)
        try await f.chooseTargets([f.service.tags[0]], host: host)
        _ = try await f.prepareAndAccept(host, name: "m2-tag-trash-\(style)")
        try await host.clickCompositionControl("unified.simple.save")
        #expect(f.controller.simpleConfirmation != nil && f.service.count("save") == 0)
        #expect(UnifiedSearchCommandDriver.has("unified.simple.confirmation", host: host))
        try host.snapshot("m2-tag-trash-confirm-\(style)")
        // Esc 只撤销确认：草稿、预览与接受都还在，不写库。
        try await host.key(53, "\u{1b}")
        #expect(f.controller.simpleConfirmation == nil && f.controller.currentSimpleAcceptance != nil && f.service.count("save") == 0)
        try await host.clickCompositionControl("unified.simple.save")
        try await host.clickCompositionControl("unified.simple.confirm")
        let facts = try #require(f.controller.simpleUnit?.simple, "未执行：\(f.controller.simpleFailure ?? "none")")
        #expect(facts.state == .saved && f.service.count("save") == 1 && f.service.tags[0].deletedAt != nil)
        try host.snapshot("m2-tag-trash-saved-\(style)")
    }

    /// 决策 3：涉及私密标签的合并在准备时就说明原因，不写库。
    @Test(arguments: [1, 2]) func privateTagMergeIsRejectedWithReason(style: Int) async throws {
        let f = try UnifiedSearchSimpleFixture(organize: true)
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        try await f.begin("/tags/merge", host: host)
        try await f.chooseTargets([f.service.tags[2]], host: host)
        let stamp = try #require(f.controller.operations?.active?.stamp)
        let destination = CommandArgument(parameter: .destination, operation: .assign,
                                          value: .object(.init(type: .tag, id: f.service.tags[0].id)))
        try #require(f.controller.sendOperation(.edit(stamp, destination), source: f.controller.buffer) != nil)
        try await host.settle()
        try await host.clickCompositionControl("unified.simple.prepare")
        #expect(f.controller.currentSimplePreview == nil && f.controller.simpleFailure == "unified.simple.problem.protected")
        #expect(UnifiedSearchCommandDriver.has("unified.simple.issue", host: host) && f.service.count("save") == 0)
        try host.snapshot("m2-tag-merge-private-\(style)")
    }
}

/// 取消与查看只用程序化动作，放进后台轮；确认面板与拒绝原因的真实键鼠用例留在原套件。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchTagOrganizeBackgroundTests {
    /// tag.cancel：只去掉标签页那一份新建草稿；页面不切换，挂载后的新建框为空，不写库。
    @Test(arguments: [0, 3]) func cancelClearsTheTagPageDraft(style: Int) async throws {
        let f = try UnifiedSearchNavigationFixture()
        defer { f.stop() }
        _ = f.assemblePages(.tags)
        f.navigation.tagDrafts.createName = "临时新建"
        try await f.start(style: style)
        try await f.begin("tag.cancel")
        try await f.press("unified.page.prepare")
        #expect(f.controller.currentPagePreview?.before == .tagDraft(true))
        try await f.press("unified.page.apply")
        #expect(f.navigation.tagDrafts.isEmpty && f.navigation.selectedTab == .tags && f.saves == 0)
        try await f.snapshot("m2-tag-cancel-\(style)")
    }

    /// 标签查询沿标签页同一取法，在面板里列出结果；不切页、不写库。
    @Test(arguments: [1, 2]) func viewQueryListsTheTagPageResults(style: Int) async throws {
        let f = try UnifiedSearchNavigationFixture()
        defer { f.stop() }
        _ = f.assemblePages(.dashboard)
        let unused = TagItem(name: "未用标签", sortOrder: 0)
        f.context.insert(unused)
        try f.context.save()
        let saves = f.saves
        try await f.start(style: style)
        try await f.begin("tag.view")
        try await f.edit(.init(parameter: .kind, operation: .assign, value: .choice("unused")))
        try await f.press("unified.page.prepare")
        #expect(try f.label("unified.page.before").contains("未用标签"))
        try await f.press("unified.page.apply")
        #expect(f.controller.pageReceipt?.after == .results(["未用标签"], total: 1))
        #expect(f.navigation.selectedTab == .dashboard && f.saves == saves)
        try await f.snapshot("m2-tag-view-\(style)")
    }
}
