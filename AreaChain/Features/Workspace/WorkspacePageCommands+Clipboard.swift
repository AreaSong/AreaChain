import Foundation

/// 剪贴板历史的页面指令。数据就是宿主那一份 ClipboardHistorySession；复制与粘贴只经
/// ClipboardHistoryActions（与历史页、小窗同一入口），置顶只经会话原有的 togglePin，保存成功才报告。
/// 默认未装配：`clipboard` 为 nil 时一律拒绝；生产没有构造点。
extension WorkspacePageCommands {
    func clipboardSnapshot(_ action: CommandClipboardAction) throws -> WorkspacePageSnapshot {
        guard let clipboard else { throw CommandPageIssue.unassembled }
        let items = clipboard.session.items
        switch action {
        case .browse: return results(ClipboardHistoryRules.filtered(items, query: "", mode: .mixed))
        case .search(let needle, let mode): return results(ClipboardHistoryRules.filtered(items, query: needle, mode: mode))
        case .copy(let id), .paste(let id, _): return .results([Self.line(try record(id, in: items))], total: 1)
        case .copyLetter(let letter): return .results([Self.line(try pinned(letter, in: items))], total: 1)
        case .pin(let id, _): return .clipboardPin(try record(id, in: items).isPinned)
        case .pinWindow: return .windowPinned(clipboard.session.panelStaysOnTop)
        }
    }

    func clipboardExpected(_ action: CommandClipboardAction) -> WorkspacePageSnapshot? {
        switch action {
        case .pin(_, let enabled): return .clipboardPin(enabled)
        case .pinWindow(let enabled): return .windowPinned(enabled)
        default: return nil
        }
    }

    /// 执行并给出回执状态。写剪贴板失败抛 copyFailed（不报“已复制”）；粘贴只说明按键已安排发送。
    func applyClipboard(_ action: CommandClipboardAction) throws -> WorkspacePageSnapshot {
        guard let clipboard else { throw CommandPageIssue.unassembled }
        let items = clipboard.session.items
        switch action {
        case .browse, .search: return try clipboardSnapshot(action)
        case .copy(let id): return try result(clipboard.commit(id: record(id, in: items).id, plain: false, paste: false, inPanel: false))
        case .paste(let id, let plain):
            return try result(clipboard.commit(id: record(id, in: items).id, plain: plain, paste: true, inPanel: false))
        case .copyLetter(let letter):
            // 同小窗空查询时的字母快捷复制：默认纯文本偏好、不粘贴；指令不在小窗里，不关窗。
            let entry = try pinned(letter, in: items)
            return try result(clipboard.commit(id: entry.id, plain: clipboard.session.plainByDefault, paste: false, inPanel: false))
        case .pin(let id, let enabled):
            if try record(id, in: items).isPinned != enabled {
                guard clipboard.session.togglePin(id) else { throw CommandPageIssue.saveFailed }
            }
            return .clipboardPin(try record(id, in: clipboard.session.items).isPinned)
        case .pinWindow(let enabled):
            clipboard.window.setStaysOnTop(enabled)
            return .windowPinned(clipboard.session.panelStaysOnTop)
        }
    }

    /// 小窗导航（不建草稿）：只有一个窗口，已开就不再打开、不新建；没开就无可关。返回执行后是否可见。
    @discardableResult
    func applyClipboardWindow(_ action: CommandClipboardWindow) throws -> Bool {
        guard let clipboard else { throw CommandPageIssue.unassembled }
        do { try hostAvailable() } catch { throw CommandPageIssue.pageUnavailable }
        let window = clipboard.window
        switch action {
        case .open: if !window.isVisible() { window.toggle() }
        case .close:
            guard window.isVisible() else { throw CommandPageIssue.nothingToCancel }
            window.close()
        case .workspace: if window.isVisible() { window.close() }
        }
        return window.isVisible()
    }

    private func record(_ id: UUID, in items: [ClipboardHistoryRecord]) throws -> ClipboardHistoryRecord {
        let matches = items.filter { $0.id == id }
        guard matches.count == 1 else { throw CommandPageIssue.missing }
        return matches[0]
    }

    private func pinned(_ letter: String, in items: [ClipboardHistoryRecord]) throws -> ClipboardHistoryRecord {
        guard let entry = items.first(where: { $0.pinKey == letter }) else { throw CommandPageIssue.notInList }
        return entry
    }

    private func result(_ value: ClipboardPasteResult) throws -> WorkspacePageSnapshot {
        switch value {
        case .copied: return .clipboardResult("copied")
        case .pasted: return .clipboardResult("pasted")
        case .needsAccessibility: return .clipboardResult("needsAccessibility")
        case .empty, .saveFailed: throw CommandPageIssue.copyFailed
        }
    }

    private func results(_ records: [ClipboardHistoryRecord]) -> WorkspacePageSnapshot {
        .results(records.prefix(Self.resultSample).map(Self.line), total: records.count)
    }

    /// 结果行：沿历史页的 preview（压成一行），再截到面板宽度可读的长度。
    static func line(_ record: ClipboardHistoryRecord) -> String {
        let prefix = record.pinKey.map { "[\($0)] " } ?? ""
        return prefix + String(record.preview.prefix(60))
    }
}
