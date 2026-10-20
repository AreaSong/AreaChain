import AppKit
import SwiftUI

/// 合并批 M-3 B、C：窗口与面板、总览统计、退出与立即锁定的执行。只沿现有入口（AppWindows、DiaryWindows、
/// 今日页面板请求、DashboardStatsReader、AppDelegate 的退出确认、PrivacyVault.lock），不建草稿、不写业务数据。
extension UnifiedSearchController {
    var systemAction: CommandSystemAction? {
        let parsed = CommandPathParser().parse(.init(text: buffer.text))
        guard let command = parsed.command, CommandSystemAction.commands.contains(command.id.rawValue) else { return nil }
        return try? CommandSystemAction(command: command.id, arguments: parsed.arguments)
    }

    /// 有未完成的指令草稿或待执行列表时，关闭工作台会丢掉它们；先要求在搜索里完成或放弃。
    var hasUnsavedCommandWork: Bool { operations?.active != nil || plan?.items.isEmpty == false }

    func executeSystemAction(_ command: CommandDescriptor, parsed: CommandPathResult, source: UnifiedSearchBuffer) {
        do {
            guard let pages = pageCommands else { throw CommandPageIssue.unassembled }
            let system = try pages.requireSystem()
            let action = try CommandSystemAction(command: command.id, arguments: parsed.arguments)
            switch action {
            case .workspaceOpen:
                // 同 AppWindows.openWorkspace 的“默认总览”，但页面沿 N-M1 导航显示，保留返回搜索的票据。
                AppWindows.revealWorkspace(opening: system.opening)
                navigate(.page(.dashboard), source: source)
            case .workspaceReveal:
                AppWindows.revealWorkspace(opening: system.opening)
                navigationMessage = "unified.system.workspace.revealed"
            case .workspaceClose:
                guard !hasUnsavedCommandWork else { throw CommandPageIssue.stale }
                system.closeWorkspace()
                navigationMessage = "unified.system.workspace.closed"
            case .overlayToggle:
                system.toggleOverlay()
                navigationMessage = "unified.system.overlay.toggled"
            case .overlayMode(let mode):
                guard let switchMode = system.overlayMode else { navigationMessage = "unified.system.overlay.modeUnavailable"; return }
                switchMode(mode == "tasks" ? .tasks : .diary)
                navigationMessage = "unified.system.overlay.toggled"
            case .routineAddPanel, .routineManagePanel:
                navigate(.page(.today), source: source) { [weak self, pages] _ in
                    if action == .routineAddPanel { pages.navigation.wantsRecurringEditor = true }
                    else { pages.navigation.wantsRecurringList = true }
                    self?.navigationMessage = "unified.system.routine.opened"
                }
            case .diaryOpen:
                guard let active = try? session.presentation().pagination.browse.active else {
                    navigationMessage = "unified.navigation.chooseObject"; return
                }
                try pages.openDiaryWindow(active)
                navigationMessage = "unified.system.diary.opened"
            case .diaryDraft:
                try pages.detachDiaryDraft()
                navigationMessage = "unified.system.diary.detached"
            case .diaryPinned(let value):
                let window = try pages.diaryWindow(for: try? session.presentation().pagination.browse.active)
                window.setPinned(value ?? !window.session.isWindowPinned)
                navigationMessage = window.session.isWindowPinned ? "unified.system.diary.pinned" : "unified.system.diary.unpinned"
            case .diaryClose:
                // 沿小窗自己的关闭：有未保存内容时由 windowShouldClose 弹出原有的保存／放弃／取消确认。
                let window = try pages.diaryWindow(for: try? session.presentation().pagination.browse.active)
                window.window.performClose(nil)
                navigationMessage = "unified.system.diary.closeRequested"
            case .stats:
                navigationMessage = "unified.stats.shown"
            case .statsOpenDay(let day):
                navigate(.day(day), source: source)
            case .statsOpenActivity:
                navigationMessage = "unified.stats.chooseActivity"
            case .quit:
                guard system.requestTermination() == .terminateNow else {
                    navigationMessage = "unified.system.quit.cancelled"; return
                }
                system.terminate()
                navigationMessage = "unified.system.quit.confirmed"
            case .privacyLock:
                navigationMessage = "unified.navigation.unsupported"
            }
        } catch {
            let issue = error as? CommandPageIssue ?? .stale
            navigationMessage = Self.systemMessage(issue, command: command)
        }
    }

    /// 总览活动行的打开沿总览页 DashboardNavigation 的路由，但页面一律经 N-M1 导航（保留返回票据）；
    /// 对象再经 objects.resolve 的存活与隐私检查，手记沿小窗的受保护拒绝。
    func openStatsActivity(_ activity: DashboardActivity, source: UnifiedSearchBuffer) {
        guard validates(source), let router = navigationRouter, let pages = pageCommands else {
            navigationMessage = "unified.navigation.unassembled"; return
        }
        do {
            switch activity.route {
            case .inspectItem(let id, let dayKey, let kind):
                let open = kind == .routine
                    ? ContentQueryBrowseOpen(object: .init(type: .routineOccurrence, id: id, dayKey: dayKey),
                                             parent: .init(type: .routine, id: id), viewingTrash: false)
                    : ContentQueryBrowseOpen(object: .init(type: .todo, id: id), parent: nil, viewingTrash: false)
                navigate(.object(try router.objects.resolve(open)), source: source)
            case .openDiary(let id):
                try pages.openDiaryWindow(.init(type: .diary, id: id))
                navigationMessage = "unified.system.diary.opened"
            case .focusTrash(let id):
                navigate(.page(.trash), source: source) { [weak router] _ in router?.navigation.focusedTrashID = id }
            case nil: navigationMessage = "unified.navigation.unsupported"
            }
        } catch let failure as WorkspaceOpenFailure {
            navigationMessage = navigationFailure(failure)
        } catch {
            navigationMessage = Self.systemMessage(error as? CommandPageIssue ?? .stale, command: nil)
        }
    }

    static func systemMessage(_ issue: CommandPageIssue, command: CommandDescriptor?) -> String {
        switch (issue, command?.id.rawValue) {
        case (.stale, "workspace.close"): "unified.system.workspace.closeBlocked"
        case (.protectedContent, "diaryWindow.draft"): "unified.system.diary.draftProtected"
        case (.protectedContent, _): "unified.system.diary.protected"
        case (.nothingToCancel, _): "unified.system.diary.noWindow"
        case (.invalidTarget, "diaryWindow.pinned"), (.invalidTarget, "diaryWindow.close"): "unified.system.diary.chooseWindow"
        default: UnifiedSearchPageCopy.key(issue)
        }
    }
}
