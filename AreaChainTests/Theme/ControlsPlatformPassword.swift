import AppKit
import SwiftUI
@testable import AreaChain

/// 人工 K 只控制假 action 的完成时刻；不写原生字段，也不读取生产私有 State。
@MainActor @Observable
final class ControlsPlatformPassword {
    static let sample = "24682468"
    let probe = PasswordSheetProbe(0, expectedInput: sample)
    let replacement: Bool
    let locale: String
    weak var host: NSWindow?
    var record: ((String, [String: Any]) -> Void)?
    private(set) var stage = "先填两个字段，再提交 / Fill both fields, then submit"
    private(set) var remaining = 0
    private(set) var closed = false
    private var finishAt: TimeInterval?
    private var sampleAt: TimeInterval?
    private var sampledSheet: NSWindow?
    private var fieldIDs: [ObjectIdentifier: Int] = [:]
    private var lastDismissals = 0

    init(replacement: Bool, locale: String) {
        self.replacement = replacement
        self.locale = locale
        probe.observeAction = { [weak self] in self?.submitted() }
    }

    private func submitted() {
        guard !closed else { return }
        let first = probe.calls % 2 == 1
        remaining = first ? 30 : 12
        finishAt = ProcessInfo.processInfo.systemUptime + Double(remaining)
        sampleAt = ProcessInfo.processInfo.systemUptime + 1
        stage = first
            ? "等待30秒合成失败：在两个字段重新填同值 / Refill both while waiting"
            : "观察12秒：不要按键、点击或切换焦点 / Observe without further input"
        sample("action-entered")
    }

    func tick(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard !closed else { return }
        if let sheet = host?.attachedSheet, sheet !== sampledSheet {
            sampledSheet = sheet
            probe.window = sheet
            sample("sheet-open")
        }
        if probe.dismissals != lastDismissals {
            lastDismissals = probe.dismissals
            record?("password-dismissed", ["dismissals": lastDismissals, "calls": probe.calls,
                                          "hostKey": host?.isKeyWindow ?? false])
            sampledSheet = nil
            probe.window = nil
            sampleAt = nil
            stage = "已取消：可重开核对空字段 / Cancelled; reopen to check empty fields"
        }
        if let sampleAt, now >= sampleAt {
            self.sampleAt = nil
            sample("settled")
        }
        guard let finishAt else { return }
        remaining = max(0, Int(ceil(finishAt - now)))
        if now >= finishAt { finishFailure() }
    }

    func finishFailure() {
        guard !closed, probe.pending != nil else { return }
        sample("before-failure")
        finishAt = nil
        probe.finish(failure: true)
        sampleAt = ProcessInfo.processInfo.systemUptime + 1
        stage = probe.calls % 2 == 1
            ? "已返回合成失败：按本场景方式重填，再提交 / Refill and retry"
            : "观察完毕：记住遮蔽现象，再取消、重开 / Note masking, then cancel and reopen"
    }

    func sample(_ phase: String) {
        guard !closed, let sheet = probe.window else { return }
        let fields = SecureInputTestSupport.fields(sheet)
        let lengths: [[String: Any]] = fields.map { field in
            let identity = ObjectIdentifier(field)
            if fieldIDs[identity] == nil { fieldIDs[identity] = fieldIDs.count + 1 }
            let editor = field.currentEditor() as? NSTextView
            return ["fieldID": fieldIDs[identity] ?? 0, "utf16Length": field.stringValue.utf16.count,
                    "editorUTF16Length": editor?.string.utf16.count ?? -1,
                    "editorActive": editor != nil && sheet.firstResponder === editor]
        }
        var values: [String: Any] = ["phase": phase, "calls": probe.calls,
            "inputEqual": probe.correctInput, "inputEqualAfterWait": probe.correctAfterWait,
            "pending": probe.pending != nil, "completed": probe.completed, "fields": lengths,
            "sheetNumber": sheet.windowNumber, "sheetKey": sheet.isKeyWindow,
            "hostStateObserved": false, "replacementPath": replacement]
        for key in ["common.save", "alert.cancel"] {
            let button = try? SettingsButtonTestSupport.button(key, locale: locale, in: sheet)
            values[key] = (button?.value(forKey: "accessibilityEnabled") as? Bool) as Any? ?? NSNull()
        }
        record?("password-sample", values)
    }

    func close() {
        guard !closed else { return }
        sample("closing")
        closed = true
        finishAt = nil
        sampleAt = nil
        probe.observeAction = nil
        probe.finish(failure: true)
        if let sheet = host?.attachedSheet { host?.endSheet(sheet); SystemPageHost.release(sheet) }
        probe.presented = false
        probe.window = nil
        sampledSheet = nil
        record = nil
    }

    var content: some View { ControlsPlatformPasswordView(support: self) }
}

/// 让反馈在 SwiftUI body 内读取 Observation；一次性构造的 Text 不会随 Probe 更新。
private struct ControlsPlatformPasswordView: View {
    @Bindable var support: ControlsPlatformPassword
    private var probe: PasswordSheetProbe { support.probe }

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                Text("K 合成密码验收 / Synthetic password QA")
                Text("取消后可重开；这不能代替原字段自然清空。 / Reopening is a separate check.")
                Button("重开密码窗 / Reopen password sheet") { self.probe.presented = true }
                    .disabled(probe.presented || support.closed)
            }
            PrivacyButtonSheetHost(content: AnyView(sheetContent), onDismiss: { self.probe.dismissals += 1 },
                presentation: Binding(get: { self.probe.presented }, set: { self.probe.presented = $0 }))
        }
    }

    private var sheetContent: some View {
        VStack(spacing: 0) {
            probe.content
            VStack(alignment: .leading, spacing: 6) {
                Text("仅合成材料 / Synthetic only: \(ControlsPlatformPassword.sample)").accessibilityHidden(true)
                Text(support.replacement
                     ? "同值覆盖：全选后由用户粘贴合成材料；代理不读取或改写剪贴板。 / Select all and paste voluntarily."
                     : "逐字路径：全选后逐字键入合成材料。 / Select all and type each digit.")
                Text(support.stage)
                Text("action: \(probe.calls) · 等待 / remaining: \(support.remaining)s")
            }.font(DaybookType.caption).padding(16).frame(width: 440, alignment: .leading)
        }
    }
}
