import AppKit
import SwiftData

/// 合并批 M-3 B、C 的宿主依赖。窗口沿 AppWindows（WorkspaceOpening）与 DiaryWindows 的现有管理，只复用已有窗口；
/// 激活、显示、关闭、浮层、退出全部可注入，隔离环境里是 fake，绝不真的退出测试宿主。默认不装配，生产没有构造点。
@MainActor struct WorkspaceSystemCommands {
    /// N-M1 的工作台打开依赖：收起浮层、激活、显示同一个工作台窗口。
    var opening: AppWindows.WorkspaceOpening
    var closeWorkspace: () -> Void
    var toggleOverlay: () -> Void
    /// 浮层的任务／手记页是浮层自己的状态，没有外部切换入口；nil 时只说明原因。
    var overlayMode: ((BoardTab) -> Void)?
    var diaryWindows: DiaryWindows
    /// 退出沿 AppDelegate.applicationShouldTerminate 的原有确认（含未保存手记）；同意后才调用 terminate。
    var requestTermination: () -> NSApplication.TerminateReply
    var terminate: () -> Void
    var vault: PrivacyVault
    var today: () -> String = { DayClock.shared.todayKey }
}

extension WorkspacePageCommands {
    func requireSystem() throws -> WorkspaceSystemCommands {
        guard let system else { throw CommandPageIssue.unassembled }
        return system
    }

    /// 只读：与总览页同一投影；日期缺省为今天。
    func statsSnapshot(day: String?) throws -> DashboardSnapshot {
        let system = try requireSystem()
        return try DashboardStatsReader.read(context: context, todayKey: day ?? system.today(), calendar: calendar)
    }

    /// 打开已有手记小窗：目标须是当前可读的活手记；受保护手记（私密、挂私密标签或加密正文）拒绝，
    /// 沿 N-M2 普通手记的口径，不借小窗绕过解锁。同一手记只有一个窗口（DiaryWindows.open 复用）。
    func openDiaryWindow(_ object: CommandObjectReference) throws {
        let system = try requireSystem()
        guard object.type == .diary else { throw CommandPageIssue.invalidTarget }
        let entry = try liveDiary(object.id)
        try refuseProtected(entry)
        system.diaryWindows.open(entry: entry, context: context, activate: false)
    }

    /// 工作台手记页的草稿转小窗：窗口先持有草稿再清空来源，不写入；受保护（需封存）的草稿留给原页面处理。
    func detachDiaryDraft() throws {
        let system = try requireSystem()
        let draft = navigation.diaryDraft
        guard draft.sealed == nil, !draft.needsProtection else { throw CommandPageIssue.protectedContent }
        if draft.hasContent {
            system.diaryWindows.openDraft(draft, dayKey: system.today(), context: context, activate: false) { [navigation] in
                navigation.diaryDraft = BoardComposerDraft()
            }
        } else {
            system.diaryWindows.openDraft(BoardComposerDraft(), dayKey: system.today(), context: context, activate: false)
        }
    }

    /// 置顶／关闭只作用于已打开的小窗：优先当前焦点手记的窗口，否则只有一个窗口时用它，多个时拒绝。
    func diaryWindow(for active: CommandObjectReference?) throws -> DiaryWindowController {
        let open = try requireSystem().diaryWindows.openControllers
        if let active, active.type == .diary, let match = open.first(where: { $0.session.entryID == active.id }) { return match }
        guard open.count == 1 else { throw open.isEmpty ? CommandPageIssue.nothingToCancel : CommandPageIssue.invalidTarget }
        return open[0]
    }

    private func liveDiary(_ id: UUID) throws -> DiaryEntry {
        let rows = try context.fetch(FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.id == id }))
        guard rows.count == 1, rows[0].deletedAt == nil else { throw CommandPageIssue.missing }
        return rows[0]
    }

    private func refuseProtected(_ entry: DiaryEntry) throws {
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        guard !entry.hasProtectedContent, !DiaryPrivacy.isSensitive(entry.snapshot, tags: tags) else {
            throw CommandPageIssue.protectedContent
        }
    }
}
