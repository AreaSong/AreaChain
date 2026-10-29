import Foundation
import SwiftData

/// 任务页交互与查询指令的页面宿主。只操作显式装配的工作台——WorkspaceSearchRouter 的同一
/// navigation、筛选会话与草稿——并直接读写页面自己的那一份状态，不另存可编辑副本，也就不会循环回写。
/// 页面不对时拒绝并说明需要哪一页，不替用户切页。默认不装配：控制器的 pageCommands 为 nil，生产没有构造点。
@MainActor final class WorkspacePageCommands {
    let router: WorkspaceSearchRouter
    let filters: BoardFilterSession
    let drafts: EditDrafts
    let pending: PendingCompletionManager
    let context: ModelContext
    /// 宿主窗口可用性（沿导航的 validateHost）；服务层测试可注入。
    var hostAvailable: () throws -> Void
    /// 看板“回今天／本月”的今天与日期推算；与页面同源，测试可注入。
    var today: () -> String = { DayClock.shared.todayKey }
    var calendar: Calendar = .current
    /// 剪贴板历史的复制／粘贴与小窗；默认 nil（未装配），由隔离夹具显式注入 fake 窗口与按键。
    var clipboard: ClipboardHistoryActions?
    /// 窗口、面板、小窗、统计、退出与立即锁定；默认 nil（未装配），隔离夹具注入 fake 系统动作。
    var system: WorkspaceSystemCommands?
    var navigation: WorkspaceNavigation { router.navigation }

    init(router: WorkspaceSearchRouter, filters: BoardFilterSession, drafts: EditDrafts, context: ModelContext,
         pending: PendingCompletionManager = .shared) {
        self.router = router
        self.filters = filters
        self.drafts = drafts
        self.pending = pending
        self.context = context
        hostAvailable = { [unowned router] in try router.validateHost() }
    }

    /// 与工作台同一宿主：筛选会话与草稿取自 WorkspaceHostContext，navigation 取自 router。
    convenience init(router: WorkspaceSearchRouter, host: WorkspaceHostContext, context: ModelContext) {
        self.init(router: router, filters: host.filters, drafts: host.drafts, context: context)
    }

    func supports(_ command: CommandID) -> Bool { CommandPageAction.commands.contains(command.rawValue) }

    /// 只读：解析草稿、核对页面，读出当前状态与执行后状态。
    func prepare(_ draft: CommandDraft) throws -> WorkspacePagePreview {
        let action = try CommandPageAction(draft)
        let page = try requirePage(for: action)
        let before = try snapshot(action)
        return .init(draft: draft.stamp, action: action, page: page, before: before, after: try expected(action, from: before))
    }

    /// 重新解析并核对页面；页面状态在预览后被改（包括用户在页面上改）即 stale，要求重新预览。
    @discardableResult
    func validate(_ preview: WorkspacePagePreview, draft: CommandDraft) throws -> CommandPageAction {
        guard draft.stamp == preview.draft, try CommandPageAction(draft) == preview.action,
              try requirePage(for: preview.action) == preview.page,
              try snapshot(preview.action) == preview.before else { throw CommandPageIssue.stale }
        return preview.action
    }

    /// 状态类与取消类立即执行；选择类须先显示页面（见 applySelection）。
    func apply(_ preview: WorkspacePagePreview, draft: CommandDraft) throws -> WorkspacePageReceipt {
        let action = try validate(preview, draft: draft)
        guard !preview.revealsPage else { throw CommandPageIssue.stale }
        if case .clipboard(let clipboard) = action { return .init(action: action, after: try applyClipboard(clipboard)) }
        switch action {
        case .cancelTitle(let object):
            drafts.titles.removeValue(forKey: Self.titleKey(object))
        case .cancelCompletion(let id):
            pending.cancelPending(id)
        case .clearSelection:
            navigation.clearSelection()
        case .sections(let section, let expanded):
            if section == .yesterday { navigation.todaySections.yesterday = expanded }
            else { navigation.todaySections.upcoming = expanded }
        case .filter, .clearFilter:
            guard let next = preview.after, case .filter(let filter) = next else { throw CommandPageIssue.stale }
            writeFilter(filter, page: preview.page)
        case .kind(let kind):
            navigation.allItemsQuery.kind = kind
        case .status(let todo, let routine):
            if let todo { navigation.allItemsQuery.todoStatus = todo }
            if let routine { navigation.allItemsQuery.routineStatus = routine }
        case .calendarMode(let span):
            applyCalendarMode(span)
        case .tagCancel:
            applyContent(action)
        case .streak, .select, .selectAll, .ganttSelect, .transfer, .tagQuery, .image, .clipboard:
            break
        }
        // 取消类执行后已无可读的草稿／驻留，回执用预期状态；其余重读页面状态，证明确实写到了页面那一份。
        guard let after = (try? snapshot(action)) ?? preview.after else { throw CommandPageIssue.stale }
        return .init(action: action, after: after)
    }

    /// 页面实际挂载并登记了当前投影（inspectorTargetIDs）之后才选择；不在投影里的目标拒绝，不换成别的行。
    func applySelection(_ preview: WorkspacePagePreview) throws -> WorkspacePageReceipt {
        if case .ganttSelect = preview.action { return try applyGanttSelection(preview) }
        guard try requirePage(for: preview.action) == preview.page else { throw CommandPageIssue.stale }
        let visible = navigation.inspectorTargetIDs
        let ids: Set<UUID>
        switch preview.action {
        case .select(let objects): ids = Set(objects.map(\.id))
        case .selectAll: ids = visible
        default: throw CommandPageIssue.stale
        }
        guard !ids.isEmpty, ids.isSubset(of: visible) else { throw CommandPageIssue.notInList }
        navigation.clearSelection()
        navigation.selectedTaskIDs = ids
        return .init(action: preview.action, after: .selection(ids))
    }

    /// 只给预览显示筛选条件里的标签名。
    func tagNames() -> [UUID: String] {
        let tags = (try? context.fetch(FetchDescriptor<TagItem>())) ?? []
        return Dictionary(tags.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    func tagCandidates(evidence: CommandTaskTagCatalog.Evidence?) throws -> CommandTaskTagCandidates {
        let reader = TaskCreateTagCatalogReader(context: context, invalidation: .catalogFacts)
        return try CommandTaskTagCandidates(catalog: evidence.map(reader.validate) ?? reader.current())
    }

    // MARK: - 页面与状态

    /// 返回指令绑定的页面；不需要页面的（取消、连击）为 nil，但仍要求宿主可用。
    func requirePage(for action: CommandPageAction) throws -> WorkspaceTab? {
        do { try hostAvailable() } catch { throw CommandPageIssue.pageUnavailable }
        let allowed: [WorkspaceTab]
        switch action {
        case .calendarMode, .ganttSelect, .transfer: return try boardPage(for: action)
        case .tagCancel, .tagQuery, .image, .clipboard: return try contentPage(for: action)
        case .cancelTitle, .cancelCompletion, .streak: return nil
        case .filter, .clearFilter: allowed = [.today, .pending, .allItems]
        case .kind, .status: allowed = [.allItems]
        case .sections: allowed = [.today]
        case .select, .selectAll, .clearSelection: allowed = [.pending, .allItems]
        }
        guard navigation.selectedTagID == nil, !navigation.isShowingShellPreview,
              allowed.contains(navigation.selectedTab) else {
            throw CommandPageIssue.wrongPage(allowed.map(\.rawValue).joined(separator: ","))
        }
        return navigation.selectedTab
    }

    private func snapshot(_ action: CommandPageAction) throws -> WorkspacePageSnapshot {
        switch action {
        case .cancelTitle(let object):
            guard drafts.titles[Self.titleKey(object)] != nil else { throw CommandPageIssue.nothingToCancel }
            return .titleDraft(true)
        case .cancelCompletion(let id):
            guard pending.pendingDoneIDs.contains(id) else { throw CommandPageIssue.nothingToCancel }
            return .pending(true)
        case .select, .selectAll, .clearSelection: return .selection(navigation.selectedTaskIDs)
        case .sections(let section, _):
            if section == .today { throw CommandPageIssue.todaySectionFixed }
            return .sections(navigation.todaySections)
        case .filter, .clearFilter: return .filter(currentFilter())
        case .kind, .status:
            let query = navigation.allItemsQuery
            return .listing(kind: query.kind, todo: query.todoStatus, routine: query.routineStatus)
        case .streak(let id, _, let day): return try streak(id, day: day)
        case .calendarMode, .ganttSelect, .transfer:
            guard let snapshot = boardSnapshot(action) else { throw CommandPageIssue.stale }
            return snapshot
        case .tagCancel, .tagQuery, .image: return try contentSnapshot(action)
        case .clipboard(let clipboard): return try clipboardSnapshot(clipboard)
        }
    }

    private func expected(_ action: CommandPageAction, from before: WorkspacePageSnapshot) throws -> WorkspacePageSnapshot? {
        switch (action, before) {
        case (.cancelTitle, _): return .titleDraft(false)
        case (.cancelCompletion, _): return .pending(false)
        case (.clearSelection, _): return .selection([])
        case (.select(let objects), _): return .selection(Set(objects.map(\.id)))
        case (.selectAll, _), (.streak, _): return nil
        case (.calendarMode, _), (.ganttSelect, _), (.transfer, _): return boardExpected(action)
        case (.tagCancel, _), (.tagQuery, _), (.image, _): return contentExpected(action)
        case (.clipboard(let clipboard), _): return clipboardExpected(clipboard)
        case (.sections(let section, let expanded), .sections(var sections)):
            if section == .yesterday { sections.yesterday = expanded } else { sections.upcoming = expanded }
            return .sections(sections)
        case (.filter(let input), .filter(let filter)):
            if let tag = input.tag, let id = tag { try requireFilterTag(id) }
            return .filter(input.applied(to: filter))
        case (.clearFilter, _): return .filter(BoardFilter())
        case (.kind(let kind), .listing(_, let todo, let routine)): return .listing(kind: kind, todo: todo, routine: routine)
        case (.status(let todo, let routine), .listing(let kind, let oldTodo, let oldRoutine)):
            return .listing(kind: kind, todo: todo ?? oldTodo, routine: routine ?? oldRoutine)
        default: throw CommandPageIssue.stale
        }
    }

    private func currentFilter() -> BoardFilter {
        switch navigation.selectedTab {
        case .today: filters.filters.tasks
        case .pending: navigation.pendingFilter
        default: navigation.allItemsQuery.filter
        }
    }

    /// 与各页面自己的写法一致：今日页经共享筛选会话（同 WorkspaceTodayView.writeTaskFilter），另两页写 navigation。
    private func writeFilter(_ filter: BoardFilter, page: WorkspaceTab?) {
        switch page {
        case .today:
            var next = filters.filters
            next.write(filter, for: .tasks)
            filters.filters = next
        case .pending: navigation.pendingFilter = filter
        default: navigation.allItemsQuery.filter = filter
        }
    }

    /// 页面筛选的标签必须是现存的活标签（同标签目录）；不新建、不恢复。
    private func requireFilterTag(_ id: UUID) throws {
        let rows = try context.fetch(FetchDescriptor<TagItem>(predicate: #Predicate { $0.id == id }))
        guard rows.count == 1, rows[0].deletedAt == nil else { throw CommandPageIssue.invalidArguments }
    }

    /// 连击沿 HabitStreakLogic，与详情抽屉同一算法与输入（定义快照 + 该习惯的打卡快照）。
    private func streak(_ id: UUID, day: String) throws -> WorkspacePageSnapshot {
        let rows = try context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.id == id }))
        guard rows.count == 1, rows[0].deletedAt == nil else { throw CommandPageIssue.missing }
        let result = HabitStreakLogic.calculate(routine: rows[0].snapshot, checks: rows[0].checks.compactMap(\.snapshot),
                                                todayKey: day)
        return .streak(current: result.currentStreak, best: result.bestStreak)
    }

    static func titleKey(_ object: CommandObjectReference) -> String {
        object.type == .subtask ? EditDrafts.key(subtask: object.id) : EditDrafts.key(todo: object.id)
    }
}

/// 预览与回执里的页面状态：就是页面自己的状态值，界面按当前语言显示。
enum WorkspacePageSnapshot: Equatable {
    case filter(BoardFilter)
    case listing(kind: ItemKindScope, todo: TodoStatusScope, routine: RoutineStatusScope)
    case sections(TasksPageSections)
    case selection(Set<UUID>)
    case titleDraft(Bool)
    case pending(Bool)
    case streak(current: Int, best: Int)
    /// 日历月／周（CalendarSpan 的 rawValue）与看板修改转交的目标指令。
    case calendarSpan(String)
    case transfer(CommandBoardTransfer)
    /// 标签页草稿是否还在；只读查询的结果（前若干条的原文与总数）。
    case tagDraft(Bool)
    case results([String], total: Int)
    /// 剪贴板条目是否置顶、小窗是否置顶、复制／粘贴实际发生了什么（copied／pasted／needsAccessibility）。
    case clipboardPin(Bool), windowPinned(Bool), clipboardResult(String)
}

struct WorkspacePagePreview: Equatable {
    let draft: CommandDraftStamp
    let action: CommandPageAction
    let page: WorkspaceTab?
    let before: WorkspacePageSnapshot
    /// 选择全部与连击在执行前无法给出确定结果，为 nil。
    let after: WorkspacePageSnapshot?
    var revealsPage: Bool {
        switch action {
        case .select, .selectAll, .ganttSelect: return true
        default: return false
        }
    }
}

struct WorkspacePageReceipt: Equatable {
    let action: CommandPageAction
    let after: WorkspacePageSnapshot
}
