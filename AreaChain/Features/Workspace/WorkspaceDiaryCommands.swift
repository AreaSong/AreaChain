import AppKit
import SwiftData

/// 手记编辑会话的保存／重载／舍弃与普通手记复制。只作用于已打开的小窗会话（DiaryWindows 的现有管理；
/// 手记页卡片的编辑会话是页面私有状态，宿主没有入口），复用 DiaryEditorSession 的保存、重载与冲突处理，
/// 不绕过会话直写仓储。受保护的会话、受保护的手记都不在这里处理：调用方改为前置小窗或打开原手记页。
extension WorkspacePageCommands {
    enum DiarySessionOutcome: Equatable {
        case saved, nothingToSave, failed, reloaded, needsConfirmation, closeRequested, protected
    }

    /// diary.save 等的目标：当前手记结果的小窗；没有打开的小窗即说明（不新建会话）。
    func diaryWindow(entry active: CommandObjectReference?) throws -> DiaryWindowController {
        guard let active, active.type == .diary else { throw CommandPageIssue.invalidTarget }
        guard let window = try requireSystem().diaryWindows.openControllers.first(where: { $0.session.entryID == active.id }) else {
            throw CommandPageIssue.nothingToCancel
        }
        return window
    }

    /// 受保护（加密、私密标记、私密标签或封存草稿）的会话只前置小窗，由用户在那里解锁后操作。
    private func protectedSession(_ window: DiaryWindowController) -> Bool {
        guard window.session.isSensitive else { return false }
        window.show(activate: false)
        return true
    }

    /// 沿小窗的“保存”：没有未保存内容只说明；失败时草稿留在会话里，不报成功。
    func saveDiarySession(_ window: DiaryWindowController) -> DiarySessionOutcome {
        if protectedSession(window) { return .protected }
        guard window.session.hasUnsavedChanges else { return .nothingToSave }
        return window.session.save() ? .saved : .failed
    }

    /// 沿冲突条的“重载”：有未保存内容时保留原有确认——前置小窗，由用户在那里确认舍弃；没有时直接重载最新版本。
    func reloadDiarySession(_ window: DiaryWindowController) -> DiarySessionOutcome {
        if protectedSession(window) { return .protected }
        guard !window.session.hasUnsavedChanges else {
            window.show(activate: false)
            return .needsConfirmation
        }
        window.session.reloadLatest()
        return window.session.issue == nil ? .reloaded : .failed
    }

    /// 舍弃沿小窗自己的关闭：有未保存内容时由 windowShouldClose 弹出原有的保存／放弃／取消确认。
    func discardDiarySession(_ window: DiaryWindowController) -> DiarySessionOutcome {
        if protectedSession(window) { return .protected }
        window.window.performClose(nil)
        return .closeRequested
    }

    /// 普通手记复制：沿卡片的复制（重查活记录、PrivateClipboard 一次发布）；普通手记不带隐私标记。
    /// 受保护手记在读取正文前抛 protectedContent，由调用方打开原手记页；写入失败不报“已复制”。
    func copyDiary(_ object: CommandObjectReference, section: DiaryCopyContent.Section) throws {
        let system = try requireSystem()
        guard object.type == .diary else { throw CommandPageIssue.invalidTarget }
        let id = object.id
        let rows = try context.fetch(FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.id == id }))
        guard rows.count == 1, rows[0].deletedAt == nil else { throw CommandPageIssue.missing }
        let entry = rows[0]
        guard DiaryWriteService.isOrdinary(entry, tags: try context.fetch(FetchDescriptor<TagItem>())) else {
            throw CommandPageIssue.protectedContent
        }
        guard let text = DiaryCopyContent.text(section, from: try DiaryContent.read(entry, vault: system.vault)) else {
            throw CommandPageIssue.nothingToCancel
        }
        guard PrivateClipboard.copy(text, sensitive: false, to: system.pasteboard) else { throw CommandPageIssue.copyFailed }
    }
}
