import Foundation
import SwiftData

/// 标签、附件、剪贴板的页面指令。取消类只写页面自己的那一份草稿；查询类只读，
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
        case .image(.browse(let owner)): return try imageResults(owner)
        case .image(.preview(let image)):
            let id = image.id
            let rows = try context.fetch(FetchDescriptor<AttachmentItem>(predicate: #Predicate { $0.id == id }))
            guard rows.count == 1 else { throw CommandPageIssue.missing }
            // 同普通图片查阅与附件中心：只打开普通图片；加密、敏感手记或拥有者已删的都不打开。
            guard try AttachmentTrashService.eligibility(rows[0], in: context) == .eligible else {
                throw CommandPageIssue.protectedContent
            }
            return .results([rows[0].filename], total: 1)
        default: throw CommandPageIssue.stale
        }
    }

    /// 图片的拥有者引用（同结果行的 parent），查阅时随打开请求一起给出。
    func imageOwner(_ image: CommandObjectReference) throws -> CommandObjectReference {
        let id = image.id
        let rows = try context.fetch(FetchDescriptor<AttachmentItem>(predicate: #Predicate { $0.id == id }))
        guard rows.count == 1, let owner = rows[0].ownerKey else { throw CommandPageIssue.missing }
        let types: [AttachmentOwner: CommandObjectType] = [.todo: .todo, .routine: .routine, .diary: .diary]
        guard let type = types[owner.kind] else { throw CommandPageIssue.missing }
        return .init(type: type, id: owner.id)
    }

    /// 图片口径：已挂在对象上、附件中心可见（AttachmentAccess.canBrowse）的图片，按所属类型分组，新的在前。
    private func imageResults(_ owner: AttachmentOwner?) throws -> WorkspacePageSnapshot {
        let rows = try context.fetch(FetchDescriptor<AttachmentItem>(predicate: #Predicate { $0.deletedAt == nil }))
        let owners = AttachmentAccess.ownerIndex(todos: try context.fetch(FetchDescriptor<TodoItem>()),
                                                 routines: try context.fetch(FetchDescriptor<DailyRoutine>()),
                                                 diaries: try context.fetch(FetchDescriptor<DiaryEntry>()))
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        let visible = rows.filter { row in
            AttachmentAccess.canBrowse(row, owners: owners, tags: tags) && (owner == nil || row.ownerKey?.kind == owner)
        }.sorted { ($0.createdAt, $0.filename) > ($1.createdAt, $1.filename) }
        return .results(visible.prefix(Self.resultSample).map(\.filename), total: visible.count)
    }

    func contentExpected(_ action: CommandPageAction) -> WorkspacePageSnapshot? {
        if case .tagCancel = action { return .tagDraft(false) }
        return nil
    }

    func applyContent(_ action: CommandPageAction) {
        if case .tagCancel = action {
            navigation.tagDrafts = WorkspaceTagPageDrafts(cancelRevision: navigation.tagDrafts.cancelRevision &+ 1)
        }
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
