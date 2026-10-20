import Foundation
import SwiftData

/// 合并批 M-2 B～D：标签、附件、剪贴板的页面指令。取消类只写页面自己的那一份草稿；查询类只读，
/// 取法与原页面同一个入口（TagListQuery 等），结果只在面板里列出，不写库、不建 Run。
extension WorkspacePageCommands {
    /// 面板只列前若干条结果，其余以总数说明。
    static let resultSample = 20

    func contentPage(for action: CommandPageAction) throws -> WorkspaceTab? {
        do { try hostAvailable() } catch { throw CommandPageIssue.pageUnavailable }
        switch action {
        case .tagCancel:
            guard navigation.selectedTagID == nil, !navigation.isShowingShellPreview, navigation.selectedTab == .tags else {
                throw CommandPageIssue.wrongPage(WorkspaceTab.tags.rawValue)
            }
            return .tags
        default: return nil
        }
    }

    func contentSnapshot(_ action: CommandPageAction) throws -> WorkspacePageSnapshot {
        switch action {
        case .tagCancel:
            guard !navigation.tagDrafts.isEmpty else { throw CommandPageIssue.nothingToCancel }
            return .tagDraft(true)
        case .tagQuery(let query): return try tagResults(query)
        default: throw CommandPageIssue.stale
        }
    }

    func contentExpected(_ action: CommandPageAction) -> WorkspacePageSnapshot? {
        if case .tagCancel = action { return .tagDraft(false) }
        return nil
    }

    func applyContent(_ action: CommandPageAction) {
        if case .tagCancel = action { navigation.tagDrafts = WorkspaceTagPageDrafts() }
    }

    /// 与标签页同一输入：按 sortOrder 排的全部标签，以及待办、习惯、手记（含已删除，TagUsage 自己只计未删除）。
    private func tagResults(_ query: CommandTagQuery) throws -> WorkspacePageSnapshot {
        let tags = try context.fetch(FetchDescriptor<TagItem>(sortBy: [SortDescriptor(\.sortOrder)]))
        let usage = TagListQuery.usage(todos: try context.fetch(FetchDescriptor<TodoItem>()),
                                       routines: try context.fetch(FetchDescriptor<DailyRoutine>()),
                                       diaries: try context.fetch(FetchDescriptor<DiaryEntry>()))
        let page = query.page
        let rows = TagListQuery.displayed(tags, filter: page.filter, showsDeleted: page.showsDeleted, query: page.query, usage: usage)
        return .results(rows.prefix(Self.resultSample).map(\.name), total: rows.count)
    }
}
