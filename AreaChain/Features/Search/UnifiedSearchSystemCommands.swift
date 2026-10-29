import AppKit
import SwiftUI

/// 窗口与面板、总览统计、退出与立即锁定的执行。只沿现有入口（AppWindows、DiaryWindows、
/// 今日页面板请求、DashboardStatsReader、AppDelegate 的退出确认、PrivacyVault.lock），不建草稿、不写业务数据。
extension UnifiedSearchController {
    var systemAction: CommandSystemAction? {
        let parsed = CommandPathParser().parse(.init(text: buffer.text))
        guard let command = parsed.command, CommandSystemAction.commands.contains(command.id.rawValue) else { return nil }
        return try? CommandSystemAction(command: command.id, arguments: parsed.arguments)
    }

    /// 有未完成的指令草稿或待执行列表时，关闭工作台会丢掉它们；先要求在搜索里完成或放弃。
    var hasUnsavedCommandWork: Bool { operations?.active != nil || plan?.items.isEmpty == false }

    /// 不读搜索结果的系统动作输入期间，结果区让位给面板，避免看起来像要作用于这些结果。
    var hidesResultsForCommand: Bool { systemAction.map { !$0.readsSearchResults } ?? false }

    /// 关闭工作台在有未完成指令工作时不可执行；面板常驻说明原因，执行按钮随之禁用。
    var systemActionBlocked: Bool { systemAction == .workspaceClose && hasUnsavedCommandWork }

    static let closeRefusedKey = "unified.system.workspace.closeRefused"

    /// 拒绝反馈只在仍被挡时显示：放弃或完成草稿后不再留着“没有关闭”这句。
    var showsNavigationMessage: Bool {
        navigationMessage != "unified.navigation.hint" && (navigationMessage != Self.closeRefusedKey || systemActionBlocked)
    }

    func executeSystemAction(_ command: CommandDescriptor, parsed: CommandPathResult, source: UnifiedSearchBuffer) {
        do {
            guard let pages = pageCommands else { throw CommandPageIssue.unassembled }
            let system = try pages.requireSystem()
            let action = try CommandSystemAction(command: command.id, arguments: parsed.arguments)
            switch action {
            case .workspaceOpen:
                // 同 AppWindows.openWorkspace 的“默认总览”，但页面经导航显示，保留返回搜索的票据。
                AppWindows.revealWorkspace(opening: system.opening)
                navigate(.page(.dashboard), source: source)
            case .workspaceReveal:
                AppWindows.revealWorkspace(opening: system.opening)
                navigationMessage = "unified.system.workspace.revealed"
            case .workspaceClose:
                // 面板已常驻说明原因；Return 仍要有一句明确反馈，不能看起来像没反应。
                guard !hasUnsavedCommandWork else { navigationMessage = Self.closeRefusedKey; return }
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
            case .diarySave, .diaryReload, .diaryDiscard, .diaryCopy:
                try executeDiaryAction(action, pages: pages, source: source)
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
                lockPrivacy(system.vault)
            }
        } catch {
            let issue = error as? CommandPageIssue ?? .stale
            navigationMessage = Self.systemMessage(issue, command: command)
        }
    }

    /// 手记会话的保存／重载／舍弃（只作用于已打开的小窗）与普通手记复制。
    private func executeDiaryAction(_ action: CommandSystemAction, pages: WorkspacePageCommands,
                                    source: UnifiedSearchBuffer) throws {
        switch action {
        case .diarySave(let isWindow):
            let active = try? session.presentation().pagination.browse.active
            let window = isWindow ? try pages.diaryWindow(for: active) : try pages.diaryWindow(entry: active)
            navigationMessage = Self.diaryMessage(pages.saveDiarySession(window))
        case .diaryReload:
            let window = try pages.diaryWindow(entry: try? session.presentation().pagination.browse.active)
            navigationMessage = Self.diaryMessage(pages.reloadDiarySession(window))
        case .diaryDiscard:
            let window = try pages.diaryWindow(entry: try? session.presentation().pagination.browse.active)
            navigationMessage = Self.diaryMessage(pages.discardDiarySession(window))
        case .diaryCopy(let section):
            guard let active = try? session.presentation().pagination.browse.active else {
                navigationMessage = "unified.navigation.chooseObject"; return
            }
            do {
                try pages.copyDiary(active, section: section)
                navigationMessage = "unified.system.diary.copied." + section.rawValue
            } catch CommandPageIssue.protectedContent {
                // 受保护手记不在指令里读取或复制，改为打开原手记页（沿“打开原页面”的手记目的地）。
                navigate(.page(.diary), source: source) { [weak self] _ in
                    self?.navigationMessage = "unified.system.diary.copyProtected"
                }
            }
        default: navigationMessage = "unified.navigation.unsupported"
        }
    }

    /// privacy.lock：沿页头与隐私设置页的“立即锁定”（vault.lock）。锁定事件让结果展示、返回票据、查阅内容、
    /// 长文托管与受保护预览按长文编辑与受控借用的现有规则全部撤销；未启用或已锁定时只说明原因。
    func lockPrivacy(_ vault: PrivacyVault) {
        guard vault.isConfigured else { navigationMessage = "unified.privacy.lock.unconfigured"; return }
        guard vault.isUnlocked else { navigationMessage = "unified.privacy.lock.already"; return }
        vault.lock()
        navigationMessage = "unified.privacy.lock.done"
    }

    /// 总览活动行的打开沿总览页 DashboardNavigation 的路由，但页面一律经导航（保留返回票据）；
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

    static func diaryMessage(_ outcome: WorkspacePageCommands.DiarySessionOutcome) -> String {
        switch outcome {
        case .saved: "unified.system.diary.saved"
        case .nothingToSave: "unified.system.diary.nothingToSave"
        case .failed: "unified.system.diary.saveFailed"
        case .reloaded: "unified.system.diary.reloaded"
        case .needsConfirmation: "unified.system.diary.reloadConfirm"
        case .closeRequested: "unified.system.diary.closeRequested"
        case .protected: "unified.system.diary.protectedWindow"
        }
    }

    static func systemMessage(_ issue: CommandPageIssue, command: CommandDescriptor?) -> String {
        switch (issue, command?.id.rawValue) {
        case (.nothingToCancel, "diary.copy"): "unified.system.diary.nothingToCopy"
        case (.copyFailed, "diary.copy"): "unified.system.diary.copyFailed"
        case (.invalidTarget, "diary.save"), (.invalidTarget, "diary.reload"), (.invalidTarget, "diary.discard"),
             (.invalidTarget, "diaryWindow.save"): "unified.system.diary.chooseWindow"
        case (.protectedContent, "diaryWindow.draft"): "unified.system.diary.draftProtected"
        case (.protectedContent, _): "unified.system.diary.protected"
        case (.nothingToCancel, _): "unified.system.diary.noWindow"
        case (.invalidTarget, "diaryWindow.pinned"), (.invalidTarget, "diaryWindow.close"): "unified.system.diary.chooseWindow"
        default: UnifiedSearchPageCopy.key(issue)
        }
    }
}
