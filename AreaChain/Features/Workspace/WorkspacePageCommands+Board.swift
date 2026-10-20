import Foundation

/// 合并批 M-2 A：看板三页的页面指令。状态都写页面自己的那一份——日期在共享 BoardSelection，
/// 日历月／周、安排页月份与选择在显式宿主的 `boardPages`——不另存副本；页面不对时拒绝而不切页。
extension WorkspacePageCommands {
    func supportsBoardNavigation(_ command: CommandID) -> Bool {
        CommandBoardNavigation.commands.contains(command.rawValue)
    }

    /// 导航类（不建草稿）：核对页面、只写一次页面状态；显示由调用方沿 N-M1 navigate(.page) 完成。
    /// 检查器两条只核对焦点项在页面投影里，再沿页面自己的 inspect 写法打开（同 QuadrantPage／GanttPage）。
    func applyBoardNavigation(_ action: CommandBoardNavigation, inspecting target: CommandObjectReference?) throws -> WorkspaceTab {
        let page = try requireBoardPage(action.page)
        switch action {
        case .quadrantInspect, .ganttInspect:
            guard let target, [.todo, .routineOccurrence].contains(target.type) else { throw CommandPageIssue.invalidTarget }
            guard navigation.inspectorTargetIDs.contains(target.id) else { throw CommandPageIssue.notInList }
            if action == .ganttInspect, let day = target.dayKey ?? todoDay(target.id) {
                navigation.boardSelection.inspectBoard(day)
            } else if action == .quadrantInspect {
                navigation.boardSelection.inspectBoard(navigation.boardSelection.inspectingDayKey)
            }
            navigation.inspectTask(target.id)
        case .ganttStep, .ganttCurrentMonth:
            let current = navigation.boardPages.ganttMonth ?? today()
            guard let next = action.nextDay(from: current, today: today(), calendar: calendar) else { throw CommandPageIssue.stale }
            navigation.boardPages.ganttMonth = next
        default:
            let current = navigation.boardSelection.inspectingDayKey
            let span: CommandBoardSpan = navigation.boardPages.calendarSpan == .week ? .week : .month
            guard let next = action.nextDay(from: current, today: today(), span: span, calendar: calendar) else {
                throw CommandPageIssue.stale
            }
            navigation.boardSelection.inspectingDayKey = next
        }
        return page
    }

    /// 进入该日清单：页面显示后递增一次请求，由日历页按 Return 键同一入口执行。
    func requestCalendarDayList() { navigation.boardPages.calendarListRequest &+= 1 }

    // MARK: - 交互类（预览 → 执行）

    func boardPage(for action: CommandPageAction) throws -> WorkspaceTab? {
        switch action {
        case .calendarMode: return try requireBoardPage("calendar")
        case .ganttSelect: return try requireBoardPage("gantt")
        // 转交不绑页面：参数都已显式给出，由目标指令自己的适配器核对。
        case .transfer:
            do { try hostAvailable() } catch { throw CommandPageIssue.pageUnavailable }
            return nil
        default: return nil
        }
    }

    func boardSnapshot(_ action: CommandPageAction) -> WorkspacePageSnapshot? {
        switch action {
        case .calendarMode: return .calendarSpan(navigation.boardPages.calendarSpan.rawValue)
        case .ganttSelect: return .selection(navigation.boardPages.ganttSelection.ids)
        case .transfer(let transfer): return .transfer(transfer)
        default: return nil
        }
    }

    func boardExpected(_ action: CommandPageAction) -> WorkspacePageSnapshot? {
        switch action {
        case .calendarMode(let span): return .calendarSpan(span.rawValue)
        case .ganttSelect(let mode, let objects) where mode != .range: return .selection(Set(objects.map(\.id)))
        case .transfer(let transfer): return .transfer(transfer)
        default: return nil
        }
    }

    func applyCalendarMode(_ span: CommandBoardSpan) {
        navigation.boardPages.calendarSpan = span == .week ? .week : .month
    }

    /// 沿页面已有的 TaskSelection 规则：单选同点按，多选同 ⌘ 点按逐个加入，范围同 ⇧ 点按（以第一项为锚点）。
    /// 只在页面已登记的色块顺序里选择；不在当月清单里的目标拒绝，不换成别的行。
    func applyGanttSelection(_ preview: WorkspacePagePreview) throws -> WorkspacePageReceipt {
        guard try requirePage(for: preview.action) == preview.page,
              case .ganttSelect(let mode, let objects) = preview.action else { throw CommandPageIssue.stale }
        let order = navigation.boardPages.ganttOrder
        let ids = objects.map(\.id)
        guard !ids.isEmpty, Set(ids).isSubset(of: Set(order)) else { throw CommandPageIssue.notInList }
        var selection = TaskSelection()
        switch mode {
        case .single: selection.select(ids[0], in: order)
        case .multiple: for id in ids { selection.select(id, in: order, modifiers: .command) }
        case .range:
            selection.select(ids[0], in: order)
            selection.select(ids[1], in: order, modifiers: .shift)
        }
        navigation.boardPages.ganttSelection = selection
        return .init(action: preview.action, after: .selection(selection.ids))
    }

    // MARK: - 页面与日期

    /// 看板指令绑定的页面；和任务页同一规则：标签清单与外壳预览一律拒绝。导航前的核对也走这里，不写状态。
    func requireBoardPage(_ raw: String) throws -> WorkspaceTab {
        do { try hostAvailable() } catch { throw CommandPageIssue.pageUnavailable }
        guard let tab = WorkspaceTab(rawValue: raw), navigation.selectedTagID == nil, !navigation.isShowingShellPreview,
              navigation.selectedTab == tab else { throw CommandPageIssue.wrongPage(raw) }
        return tab
    }

    private func todoDay(_ id: UUID) -> String? {
        (try? context.fetch(.init(predicate: #Predicate<TodoItem> { $0.id == id })))?.first?.dayKey
    }
}
