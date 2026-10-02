import SwiftUI

/// 只负责步进与呈现；每次操作回读 Binding，拒绝写入不产生乐观镜像值。
struct DaybookStepper<Label: View>: View {
    private let label: Label
    private let currentValue: () -> Text
    private let canStep: (Bool) -> Bool
    private let stepValue: (Bool) -> Void
    @Environment(\.isEnabled) private var isEnabled
    @State private var focused = false
    @State private var lastDirection = true
    @State private var attachment = DaybookStepperAttachment()

    init(value: Binding<Int>, in bounds: ClosedRange<Int>, step: Int, @ViewBuilder label: () -> Label) {
        self.label = label()
        currentValue = { Text(value.wrappedValue, format: .number) }
        canStep = { DaybookStepping.next(value.wrappedValue, in: bounds, step: step, increase: $0) != nil }
        stepValue = {
            if let next = DaybookStepping.next(value.wrappedValue, in: bounds, step: step, increase: $0) {
                value.wrappedValue = next
            }
        }
    }

    init(value: Binding<Double>, in bounds: ClosedRange<Double>, step: Double, @ViewBuilder label: () -> Label) {
        self.label = label()
        // 显示格式不反向参与数值运算，也不改变消费者保存的精度。
        currentValue = { Text(value.wrappedValue, format: .number) }
        canStep = { DaybookStepping.next(value.wrappedValue, in: bounds, step: step, increase: $0) != nil }
        stepValue = {
            if let next = DaybookStepping.next(value.wrappedValue, in: bounds, step: step, increase: $0) {
                value.wrappedValue = next
            }
        }
    }

    var body: some View {
        HStack(spacing: DaybookMetrics.Stepper.labelSpacing) {
            label
                .font(DaybookType.body)
                .foregroundStyle(isEnabled ? DaybookPalette.text.primary : DaybookPalette.text.disabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack(spacing: DaybookMetrics.Stepper.buttonSpacing) {
                button(increase: false)
                button(increase: true)
            }
            .fixedSize()
            .background {
                DaybookStepperKeyboard(attachment: attachment, isEnabled: isEnabled, canStep: canStep, adjust: adjust,
                                       lastDirection: { lastDirection }) { focused = $0 }
                    .allowsHitTesting(false)
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(currentValue())
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjust(true)
            case .decrement: adjust(false)
            @unknown default: break
            }
        }
    }

    private func button(increase: Bool) -> some View {
        DaybookStepButton(increase: increase, focused: focused) { adjust(increase) }
        .disabled(!isEnabled || !attachment.buttonEnabled || !canStep(increase))
        .help(increase ? "stepper.increase" : "stepper.decrease")
    }

    private func adjust(_ increase: Bool) {
        // NSHostingView 拆离窗口不保证 SwiftUI onDisappear 先于平台重复回调。
        guard isEnabled && attachment.isAttached else { return }
        lastDirection = increase
        stepValue(increase)
    }
}

/// 原生 Stepper 在按下时写入，即使随后拖出也不撤回；Button 的首次触发则可能在释放时。
/// 先消费按下，再忽略平台的首次触发，后续长按重复仍由 Button 的重复机制驱动。
private struct DaybookStepButton: View {
    let increase: Bool
    let focused: Bool
    let action: () -> Void
    @State private var tracking = false
    @State private var consumesInitialTrigger = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button {
            if consumesInitialTrigger { consumesInitialTrigger = false } else { action() }
        } label: {
            Image(systemName: increase ? "plus" : "minus").font(DaybookButtonSize.regular.iconFont)
        }
        .buttonStyle(DaybookButtonStyle(.icon, isFocused: focused))
        .buttonRepeatBehavior(.enabled)
        .focusable(false)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !tracking else { return }
                tracking = true
                consumesInitialTrigger = true
                action()
            }
            .onEnded { _ in tracking = false })
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { tracking = false; consumesInitialTrigger = false }
        }
        .onDisappear { tracking = false; consumesInitialTrigger = false }
    }
}

/// 原生 Stepper 先限制操作基值，再将最后一步截到端点；挂载时不回写。
enum DaybookStepping {
    static func next(_ value: Int, in bounds: ClosedRange<Int>, step: Int, increase: Bool) -> Int? {
        guard step > 0 else { return nil }
        let base = min(bounds.upperBound, max(bounds.lowerBound, value))
        let result = increase ? base.addingReportingOverflow(step) : base.subtractingReportingOverflow(step)
        let endpoint = increase ? bounds.upperBound : bounds.lowerBound
        let next = result.overflow ? endpoint : min(bounds.upperBound, max(bounds.lowerBound, result.partialValue))
        return next == value ? nil : next
    }

    static func next(_ value: Double, in bounds: ClosedRange<Double>, step: Double, increase: Bool) -> Double? {
        guard value.isFinite, step.isFinite, step > 0, bounds.lowerBound.isFinite, bounds.upperBound.isFinite else { return nil }
        let base = min(bounds.upperBound, max(bounds.lowerBound, value))
        let result = base + (increase ? step : -step)
        let endpoint = increase ? bounds.upperBound : bounds.lowerBound
        var next = min(bounds.upperBound, max(bounds.lowerBound, result))
        // 只消除本次运算在目标端点的舍入尾差；不将合法初值或中间小数对齐到步长。
        let tolerance = max(base.ulp, step.ulp, endpoint.ulp) * 8
        if abs(result - endpoint) <= tolerance { next = endpoint }
        return next == value ? nil : next
    }
}
