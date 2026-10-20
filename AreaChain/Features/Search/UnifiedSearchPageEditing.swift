import Foundation

/// 合并批 M-1 C：任务页交互与查询指令沿 todo.copy 的“只读当前操作草稿”模式——不入列、不建 Run、不写库。
/// 状态类直接写页面自己的那一份状态；选择类先沿 N-M1 显示当前页面（不切页），再按页面投影选择。
extension UnifiedSearchController {
    var showsPage: Bool { operations?.active.map { routesPage($0.commandID) } == true }

    func routesPage(_ command: CommandID) -> Bool { pageCommands?.supports(command) == true }

    /// 预览随页面状态失效：页面上的改动会让旧预览不再显示，需要重新预览（不会拿旧条件覆盖页面）。
    var currentPagePreview: WorkspacePagePreview? {
        guard operationVisible, let preview = pagePreview, let draft = operations?.active, let pageCommands,
              (try? pageCommands.validate(preview, draft: draft)) != nil else { return nil }
        return preview
    }

    func revokePage() {
        pagePreview = nil
        pageReceipt = nil
    }

    private func pageAction(_ source: UnifiedSearchBuffer, _ work: (WorkspacePageCommands, CommandDraft) throws -> Void) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            guard let pageCommands else { throw CommandPageIssue.unassembled }
            guard editingParameter == nil, tagSelection == nil, objectSelectionLocation == nil, !objectSelectionLoading,
                  settingExecution == nil, plan?.items.isEmpty == true, let draft = operations?.active,
                  draft.stamp == source.operation else { throw CommandPageIssue.stale }
            try session.validateDisplayHost(expecting: source.lease)
            try work(pageCommands, draft)
            pageFailure = nil
        } catch {
            pageReceipt = nil
            pageFailure = error as? CommandPageIssue ?? .stale
        }
    }

    func preparePage(_ source: UnifiedSearchBuffer) {
        pageAction(source) { pages, draft in
            revokePage()
            pagePreview = try pages.prepare(draft)
        }
    }

    func submitPage(_ source: UnifiedSearchBuffer) {
        pageAction(source) { pages, draft in
            pageReceipt = nil
            guard let preview = currentPagePreview else { throw CommandPageIssue.stale }
            if case .transfer(let transfer) = preview.action {
                try pages.validate(preview, draft: draft)
                try transferOperation(transfer, from: draft, source: source)
                return
            }
            guard preview.revealsPage else {
                pageReceipt = try pages.apply(preview, draft: draft)
                return
            }
            try pages.validate(preview, draft: draft)
            guard let page = preview.page else { throw CommandPageIssue.stale }
            navigate(.page(page), source: source) { [weak self, pages] _ in
                guard let self else { return }
                do {
                    self.pageReceipt = try pages.applySelection(preview)
                    self.navigationMessage = "unified.page.selected"
                } catch {
                    let issue = error as? CommandPageIssue ?? .stale
                    self.pageFailure = issue
                    self.navigationMessage = UnifiedSearchPageCopy.key(issue)
                }
            }
        }
    }
}

/// 页面指令的文案：状态按当前语言显示，复用页面筛选条与全部事项页已有的名称。
@MainActor enum UnifiedSearchPageCopy {
    static func key(_ issue: CommandPageIssue) -> String {
        switch issue {
        case .unassembled: "unified.page.unassembled"
        case .unsupported: "unified.page.unsupported"
        case .invalidArguments: "unified.page.invalidArguments"
        case .invalidTarget: "unified.page.invalidTarget"
        case .oneTag: "unified.page.oneTag"
        case .wrongPage: "unified.page.wrongPage"
        case .pageUnavailable: "unified.page.unavailable"
        case .nothingToCancel: "unified.page.nothingToCancel"
        case .notInList: "unified.page.notInList"
        case .missing: "unified.page.missing"
        case .stale: "unified.page.stale"
        case .todaySectionFixed: "unified.page.todaySectionFixed"
        case .notesUnsupported: "unified.page.notesUnsupported"
        }
    }

    static func message(_ issue: CommandPageIssue, locale: Locale) -> String {
        guard case .wrongPage(let pages) = issue else { return L10n.string(.init(stringLiteral: key(issue)), locale: locale) }
        let names = pages.split(separator: ",").map { pageName(String($0), locale: locale) }
        return L10n.format("unified.page.wrongPage", locale: locale, names.joined(separator: " / "))
    }

    static func pageName(_ raw: String, locale: Locale) -> String {
        L10n.string(.init(stringLiteral: "tab." + raw), locale: locale)
    }

    static func lines(_ snapshot: WorkspacePageSnapshot, tags: [UUID: String], locale: Locale) -> [String] {
        switch snapshot {
        case .filter(let filter): return filterLines(filter, tags: tags, locale: locale)
        case .listing(let kind, let todo, let routine):
            return [kind.titleKey, todo.titleKey, routine.titleKey].map { L10n.string(.init(stringLiteral: $0), locale: locale) }
        case .sections(let sections):
            let state = { (open: Bool) in L10n.string(open ? "unified.page.expanded" : "unified.page.collapsed", locale: locale) }
            return [L10n.format("unified.page.sections", locale: locale, state(sections.yesterday), state(sections.upcoming))]
        case .selection(let ids): return [L10n.format("unified.page.selection", locale: locale, ids.count)]
        case .titleDraft(let kept): return [L10n.string(kept ? "unified.page.titleDraft.on" : "unified.page.titleDraft.off", locale: locale)]
        case .pending(let pending): return [L10n.string(pending ? "unified.page.pending.on" : "unified.page.pending.off", locale: locale)]
        case .streak(let current, let best):
            return [L10n.format("unified.page.streak.current", locale: locale, current),
                    L10n.format("unified.page.streak.best", locale: locale, best)]
        case .calendarSpan(let raw): return [L10n.string(.init(stringLiteral: "calendar.span." + raw), locale: locale)]
        case .transfer(let transfer):
            let name = L10n.string(.init(stringLiteral: "command." + transfer.command.rawValue + ".name"), locale: locale)
            return [L10n.format("unified.board.transfer", locale: locale, name)]
        }
    }

    private static func filterLines(_ filter: BoardFilter, tags: [UUID: String], locale: Locale) -> [String] {
        guard filter.isActive else { return [L10n.string("unified.page.filter.none", locale: locale)] }
        var result: [String] = []
        if let tag = filter.tagID {
            result.append(filter.isNoTag ? L10n.string("filter.tag.none", locale: locale) : "#" + (tags[tag] ?? tag.uuidString))
        }
        if filter.priorityScope != .all { result.append(filter.priorityTitle(locale: locale)) }
        if filter.dateScope != .all { result.append(filter.dateScope.title(locale: locale)) }
        if filter.reminderScope != .all { result.append(filter.reminderScope.title(locale: locale)) }
        if let bundle = filter.bundleID { result.append(BundleDisplay.name(for: bundle)) }
        return result
    }
}
