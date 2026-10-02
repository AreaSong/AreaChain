import AppKit
import SwiftUI

/// NSStepper 在关闭全键盘导航时仍可接受焦点；SwiftUI edit 焦点会改变相邻文本的失焦时机。
/// 这里仅承接原生键盘响应，鼠标命中继续交给可见 Daybook 按钮。
struct DaybookStepperKeyboard: NSViewRepresentable {
    let attachment: DaybookStepperAttachment
    let isEnabled: Bool
    let canStep: (Bool) -> Bool
    let adjust: (Bool) -> Void
    let lastDirection: () -> Bool
    let focusChanged: (Bool) -> Void

    func makeNSView(context: Context) -> DaybookStepperKeyView {
        let view = DaybookStepperKeyView()
        view.attachment = attachment
        view.target = view
        view.action = #selector(DaybookStepperKeyView.step)
        view.valueWraps = false
        view.increment = 1
        view.focusRingType = .none
        return view
    }

    func updateNSView(_ view: DaybookStepperKeyView, context: Context) {
        view.isEnabled = isEnabled
        view.canStep = canStep
        view.adjust = adjust
        view.lastDirection = lastDirection
        view.focusChanged = focusChanged
        view.resetDirection()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: DaybookStepperKeyView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? DaybookMetrics.Hit.regular, height: DaybookMetrics.Hit.regular)
    }

    static func dismantleNSView(_ view: DaybookStepperKeyView, coordinator: ()) {
        view.attachment?.setAttached(false)
        view.attachment = nil
        view.adjust = { _ in }
        view.canStep = { _ in false }
        view.lastDirection = { true }
        view.focusChanged = { _ in }
    }
}

/// 只反映原生窗口的接入状态，不持有业务值或 setter。
@MainActor @Observable
final class DaybookStepperAttachment {
    @ObservationIgnored private(set) var isAttached = false
    private(set) var buttonEnabled = false

    func setAttached(_ attached: Bool) {
        // 事件防线同步生效；SwiftUI 的禁用刷新推迟到本次 AppKit 更新结束。
        isAttached = attached
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.buttonEnabled = self.isAttached
        }
    }
}

final class DaybookStepperKeyView: NSStepper {
    var attachment: DaybookStepperAttachment?
    var canStep: (Bool) -> Bool = { _ in false }
    var adjust: (Bool) -> Void = { _ in }
    var lastDirection: () -> Bool = { true }
    var focusChanged: (Bool) -> Void = { _ in }

    override func draw(_ dirtyRect: NSRect) {}
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { attachment?.setAttached(false) }
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachment?.setAttached(window != nil)
    }

    override func keyDown(with event: NSEvent) {
        // 空格沿用最近一次鼠标/键盘的方向，释放不再写入。
        if event.keyCode == 49 && event.modifierFlags.isDisjoint(with: .deviceIndependentFlagsMask) {
            if isEnabled { adjust(lastDirection()) }
        } else {
            super.keyDown(with: event)
        }
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { focusChanged(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { focusChanged(false) }
        return accepted
    }

    @objc func step() {
        let direction = doubleValue
        if isEnabled && direction != 0 { adjust(direction > 0) }
        resetDirection()
    }

    func resetDirection() {
        minValue = canStep(false) ? -1 : 0
        maxValue = canStep(true) ? 1 : 0
        // 这是一次按键的方向信号，不保存或缓存业务数值。
        doubleValue = 0
    }
}
