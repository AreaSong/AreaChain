import AppKit
import Foundation
import Testing
@testable import AreaChain

/// 合并批 M-2 D 的隔离剪贴板：临时目录里的历史、私有命名剪贴板（不碰系统通用剪贴板）、fake 辅助功能门与按键、
/// fake 小窗（只计数，不建窗口）。
@MainActor final class ClipboardCommandFixture {
    /// 门与按键的计数：先于会话创建，闭包只捕获它。
    final class Probe {
        var trusted = false
        var prompts = 0
        var keystrokes = 0
    }

    let root = FileManager.default.temporaryDirectory.appending(path: "areachain-m2-clipboard-\(UUID().uuidString)")
    let pasteboard = NSPasteboard(name: .init("AreaChain.M2.\(UUID().uuidString)"))
    let probe = Probe()
    var windowVisible = false
    var toggles = 0
    var closes = 0
    let session: ClipboardHistorySession
    let records: [ClipboardHistoryRecord]

    init(records: [ClipboardHistoryRecord] = ClipboardCommandFixture.sample) throws {
        let defaults = try #require(UserDefaults(suiteName: "AreaChain.M2.clipboard." + UUID().uuidString))
        self.records = records
        try ClipboardHistoryStore(root: root).save(records)
        let probe = probe
        session = ClipboardHistorySession(store: ClipboardHistoryStore(root: root), defaults: defaults, pasteboard: pasteboard,
            gate: .init(isTrusted: { probe.trusted }, prompt: { probe.prompts += 1 }, sendCommandV: { probe.keystrokes += 1 }))
    }

    deinit {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
        try? FileManager.default.removeItem(at: root)
    }

    /// 让历史目录只读：之后的保存会失败（读到的历史不变）。
    func breakSaving() throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: root.path)
    }

    static let sample: [ClipboardHistoryRecord] = [
        record("第一条 alpha", copiedAt: 30), record("第二条 beta", copiedAt: 20, pinned: "b"), record("第三条 Alpha", copiedAt: 10),
    ]

    static func record(_ text: String, copiedAt: Double, pinned: String? = nil) -> ClipboardHistoryRecord {
        .init(id: UUID(), copiedAt: Date(timeIntervalSince1970: copiedAt), pinnedAt: pinned.map { _ in Date(timeIntervalSince1970: 1) },
              pinKey: pinned, sourceBundleID: "qa.synthetic", plainText: text, html: nil, rtf: nil, imageFile: nil,
              contentHash: "hash-" + text)
    }

    /// 只经注入的门与按键：不申请、不触发真实辅助功能权限，也不送真实 ⌘V。
    var actions: ClipboardHistoryActions {
        var actions = ClipboardHistoryActions(session: session, window: .init(
            isVisible: { [unowned self] in windowVisible },
            toggle: { [unowned self] in toggles += 1; windowVisible.toggle() },
            close: { [unowned self] in closes += 1; windowVisible = false },
            setStaysOnTop: { [unowned self] in session.setPanelStaysOnTop($0) }))
        actions.resignFirstResponder = {}
        actions.schedulePaste = { $0() }
        return actions
    }

    func written() -> String? { pasteboard.string(forType: .string) }
}
