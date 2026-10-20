import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 合并批 M-2 B（服务层）：tag.cancel 只去掉标签页那一份草稿；三个查询沿标签页同一取法（TagListQuery），不写库。
@Suite(.serialized) @MainActor struct TagPageCommandTests {
    typealias Fixture = WorkspacePageCommandTests.Fixture

    private func results(_ f: Fixture, _ command: String, _ arguments: [CommandArgument] = []) throws -> WorkspacePageSnapshot {
        let draft = f.draft(command, arguments)
        let preview = try f.pages.prepare(draft)
        #expect(preview.page == nil && preview.after == nil)
        return try f.pages.apply(preview, draft: draft).after
    }

    @Test func cancelDiscardsTheTagPageDraftsOnly() throws {
        let f = try Fixture(page: .tags)
        let draft = f.draft("tag.cancel")
        #expect(throws: CommandPageIssue.nothingToCancel) { try f.pages.prepare(draft) }
        f.navigation.tagDrafts = .init(createName: "临时标签", renamingID: f.tag.id, renameName: "改名中")
        let preview = try f.pages.prepare(draft)
        #expect(preview.page == .tags && preview.before == .tagDraft(true) && preview.after == .tagDraft(false))
        #expect(try f.pages.apply(preview, draft: draft).after == .tagDraft(false))
        #expect(f.navigation.tagDrafts.isEmpty && f.navigation.tagDrafts.cancelRevision == 1)
        #expect(f.tag.name == "页面标签" && !f.context.hasChanges)
        let wrong = try Fixture(page: .today)
        wrong.navigation.tagDrafts.createName = "临时标签"
        #expect(throws: CommandPageIssue.wrongPage("tags")) { try wrong.pages.prepare(wrong.draft("tag.cancel")) }
        #expect(wrong.navigation.tagDrafts.createName == "临时标签")
    }

    /// 与标签页同一取法：视图沿 TagUsage，搜索按名字包含，已删除按删除时间倒序。
    @Test func queriesFollowTheTagPageListing() throws {
        let f = try Fixture(page: .dashboard)
        f.todo.tagIDs = TagIDList.encode([f.tag.id])
        try f.context.save()
        let kind = { (value: String) in CommandArgument(parameter: .kind, operation: .assign, value: .choice(value)) }
        // 常用按使用次数排全部活标签，最近只列用过的（同 TagUsage.filteredValues）。
        #expect(try results(f, "tag.view", [kind("frequent")]) == .results(["页面标签", "另一标签"], total: 2))
        #expect(try results(f, "tag.view", [kind("recent")]) == .results(["页面标签"], total: 1))
        #expect(try results(f, "tag.view", [kind("unused")]) == .results(["另一标签"], total: 1))
        #expect(try results(f, "tag.view", [kind("all")]) == .results(["页面标签", "另一标签"], total: 2))
        let query = CommandArgument(parameter: .query, operation: .assign, value: .shortText("另一"))
        #expect(try results(f, "tag.search", [query]) == .results(["另一标签"], total: 1))
        f.other.deletedAt = Date(timeIntervalSince1970: 10)
        f.tag.deletedAt = Date(timeIntervalSince1970: 20)
        try f.context.save()
        #expect(try results(f, "tag.deleted") == .results(["页面标签", "另一标签"], total: 2))
        let tags = try f.context.fetch(FetchDescriptor<TagItem>(sortBy: [SortDescriptor(\.sortOrder)]))
        let usage = TagListQuery.usage(todos: [f.todo], routines: [f.routine], diaries: [])
        #expect(TagListQuery.displayed(tags, filter: .all, showsDeleted: true, query: "", usage: usage).map(\.name) == ["页面标签", "另一标签"])
        #expect(!f.context.hasChanges)
        let empty = CommandArgument(parameter: .query, operation: .assign, value: .shortText("  "))
        #expect(throws: CommandPageIssue.invalidArguments) { try f.pages.prepare(f.draft("tag.search", [empty])) }
    }

    /// 结果在预览后变了，旧预览失效；不会拿旧结果冒充当前。
    @Test func queryPreviewGoesStaleWhenTagsChange() throws {
        let f = try Fixture(page: .dashboard)
        let draft = f.draft("tag.view", [.init(parameter: .kind, operation: .assign, value: .choice("unused"))])
        let preview = try f.pages.prepare(draft)
        f.todo.tagIDs = TagIDList.encode([f.other.id])
        try f.context.save()
        #expect(throws: CommandPageIssue.stale) { try f.pages.apply(preview, draft: draft) }
    }
}
