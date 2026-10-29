import AppKit
import Foundation

/// 剪贴板历史“复制 / 粘贴 / 纯文本粘贴”的唯一实现（从 ClipboardHistoryKeys.commit 抽出，原小窗与历史页转调）。
/// 复制先经原 stage 写剪贴板并登记自身回写；直接粘贴再经原 gate 请求辅助功能并发送 ⌘V——只能说明按键已发送，
/// 目标应用是否收下没有回执。小窗、前台交还与按键发送都可注入，隔离环境全部用 fake，不触发真实辅助功能权限。
@MainActor struct ClipboardHistoryActions {
    /// 小窗的现有窗口管理；只有一个窗口，打开时已开就不再新建。
    struct Window {
        var isVisible: () -> Bool
        var toggle: () -> Void
        var close: () -> Void
        var setStaysOnTop: (Bool) -> Void
    }

    let session: ClipboardHistorySession
    var window: Window
    /// 写剪贴板；默认就是会话原有的 stage（写入并登记自身回写）。隔离测试可注入写入失败。
    var stage: ((UUID, Bool) -> ClipboardPasteResult)?
    var resignFirstResponder: () -> Void = { NSApp.keyWindow?.makeFirstResponder(nil) }
    /// 先交还前台，再送 ⌘V，避免按键落进历史浮窗或搜索框（原 0.08 秒延迟）。
    var schedulePaste: (@escaping @MainActor () -> Void) -> Void = { work in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { MainActor.assumeIsolated { work() } }
    }

    /// 返回实际发生的事：empty 表示写剪贴板失败（不报“已复制”）；pasted 只表示粘贴按键已安排发送。
    @discardableResult
    func commit(id: UUID, plain: Bool, paste: Bool, inPanel: Bool) -> ClipboardPasteResult {
        let staged = stage?(id, plain) ?? session.stage(id, plainOnly: plain)
        guard staged == .copied else { return .empty }
        guard paste else {
            if inPanel { window.close() }
            return .copied
        }
        guard session.allowKeystroke(prompt: true) else {
            session.noticeKey = "clipboard.paste.needsAccess"
            if inPanel { window.close() }
            return .needsAccessibility
        }
        if inPanel { window.close() } else { resignFirstResponder() }
        let session = session
        schedulePaste { session.sendPasteKeystroke() }
        return .pasted
    }
}
