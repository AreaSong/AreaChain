import AppKit
import SwiftUI
@testable import AreaChain

/// 裸 NSStepper 的 target/action 原样驱动合成 Binding；不合成持续按压或设置重复节奏。
struct ControlsNativeStepper: NSViewRepresentable {
    let state: StepperProbe

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    func makeNSView(context: Context) -> NSStepper {
        let view = ControlsTrackingStepper()
        view.trace = state.trace
        view.minValue = 20
        view.maxValue = 999
        view.increment = 10
        view.doubleValue = Double(state.integer)
        view.target = context.coordinator
        view.action = #selector(Coordinator.changed(_:))
        view.setAccessibilityLabel("QA Native Stepper")
        var delay: Float = 0
        var interval: Float = 0
        view.cell?.getPeriodicDelay(&delay, interval: &interval)
        print("P_NATIVE_CONFIG continuous=\(view.isContinuous) autorepeat=\(view.autorepeat) delay=\(delay) interval=\(interval) range=20...999 step=10")
        return view
    }

    func updateNSView(_ view: NSStepper, context: Context) { view.integerValue = state.integer }

    @MainActor final class Coordinator: NSObject {
        let state: StepperProbe
        init(state: StepperProbe) { self.state = state }
        @objc func changed(_ sender: NSStepper) {
            state.trace?.mark("native-action", value: sender.doubleValue)
            state.integerBinding.wrappedValue = sender.integerValue
        }
    }
}

private final class ControlsTrackingStepper: NSStepper {
    var trace: StepperEventTrace?
    override func mouseDown(with event: NSEvent) {
        trace?.mark("native-mouseDown")
        super.mouseDown(with: event)
        // tracking 返回只是一层证据；若没有真实 mouseUp 回执，不能声称精确释放时序已取得。
        trace?.mark("native-trackingReturned")
    }
}

/// 仅用控件界内的按下开始一次观测；窗口内其他按钮不会伪造 Stepper 释放。
@MainActor
enum ControlsStepperHit {
    static func contains(_ point: NSPoint, in window: NSWindow, native: Bool) -> Bool {
        let nodes = SettingsButtonTestSupport.elements(window.contentView)
        let node = nodes.first {
            native ? $0 is NSStepper
                : SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == "stepper.integer"
        }
        guard let node, let rect = try? SettingsButtonTestSupport.frame(node, in: window) else { return false }
        return rect.contains(point)
    }
}
