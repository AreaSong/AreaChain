import SwiftUI

/// 只统一启用开关的外观；原生 Toggle 持有操作语义，Binding 始终属于消费者。
struct DaybookToggleStyle: ToggleStyle {
    // button ToggleStyle 不读取 labelsHidden；隐藏布局时要求名称，避免生成无名开关。
    var hiddenLabel: LocalizedStringKey?
    init(hiddenLabel: LocalizedStringKey? = nil) {
        self.hiddenLabel = hiddenLabel
    }

    func makeBody(configuration: Configuration) -> some View {
        DaybookToggleBody(configuration: configuration, hiddenLabel: hiddenLabel)
    }
}

private struct DaybookToggleBody: View {
    let configuration: ToggleStyleConfiguration
    let hiddenLabel: LocalizedStringKey?
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var focused: Bool
    @State private var keyPressed = false

    var body: some View {
        namedToggle
            // activate 跟随系统键盘导航；edit 会在点击时抢走标题焦点、提前提交草稿。
            .focusable(isEnabled, interactions: .activate)
            .focused($focused)
            .focusEffectDisabled()
            .onKeyPress(.space, phases: [.down, .repeat, .up], action: space)
            .onChange(of: focused) { _, value in if !value { keyPressed = false } }
            .onChange(of: isEnabled) { _, value in if !value { keyPressed = false } }
    }

    private var namedToggle: some View {
        let toggle = Toggle(configuration)
            .toggleStyle(.button)
            .buttonStyle(DaybookToggleButtonStyle(
                isOn: configuration.isOn, showsLabel: hiddenLabel == nil,
                keyPressed: keyPressed, focused: focused
            ))
        return Group {
            if let hiddenLabel { toggle.accessibilityLabel(hiddenLabel) } else { toggle }
        }
    }

    private func space(_ press: KeyPress) -> KeyPress.Result {
        guard isEnabled, press.modifiers.isEmpty else {
            keyPressed = false
            return .ignored
        }
        // 显式焦点容器消费空格，避免与内层原生 Toggle 重复写入；按住重复不提交。
        if press.phase == .down { keyPressed = true }
        if press.phase == .up {
            if keyPressed { configuration.isOn.toggle() }
            keyPressed = false
        }
        return .handled
    }
}

private struct DaybookToggleButtonStyle: ButtonStyle {
    let isOn: Bool
    let showsLabel: Bool
    let keyPressed: Bool
    let focused: Bool

    func makeBody(configuration: Configuration) -> some View {
        DaybookToggleChrome(label: configuration.label, isOn: isOn, showsLabel: showsLabel,
                            isPressed: configuration.isPressed || keyPressed, focused: focused)
    }
}

private struct DaybookToggleChrome<Label: View>: View {
    let label: Label
    let isOn: Bool
    let showsLabel: Bool
    let isPressed: Bool
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    let focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: showsLabel ? DaybookSpacing.sm : 0) {
            if showsLabel {
                label
                .font(DaybookType.body)
                .foregroundStyle(isEnabled ? DaybookPalette.text.primary : DaybookPalette.text.disabled)
                .fixedSize(horizontal: false, vertical: true)
            }
            track
        }
        .frame(minHeight: DaybookMetrics.Hit.regular)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
        .animation(DaybookMotion.snappy(reduceMotion), value: isPressed)
        .animation(DaybookMotion.snappy(reduceMotion), value: isOn)
    }

    private var track: some View {
        Capsule()
            .fill(isOn ? DaybookPalette.accent.base : DaybookPalette.fill.press)
            .overlay(Capsule().fill(feedback))
            .overlay(Capsule().strokeBorder(DaybookPalette.border.strong, lineWidth: DaybookMetrics.Stroke.regular))
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(DaybookPalette.text.onAccent)
                    .overlay(Circle().strokeBorder(DaybookPalette.border.strong, lineWidth: DaybookMetrics.Stroke.regular))
                    .frame(width: DaybookMetrics.Toggle.thumb, height: DaybookMetrics.Toggle.thumb)
                    .padding(DaybookMetrics.Toggle.inset)
            }
            .frame(width: DaybookMetrics.Toggle.width, height: DaybookMetrics.Toggle.height)
            .overlay {
                Capsule().strokeBorder(focused && isEnabled ? DaybookPalette.border.focus : .clear,
                                       lineWidth: DaybookMetrics.Stroke.emphasis)
                    .padding(-DaybookSpacing.xxs)
            }
            .opacity(isEnabled ? 1 : 0.45)
            .accessibilityHidden(true)
    }

    private var feedback: Color {
        guard isEnabled else { return .clear }
        return isPressed ? DaybookPalette.fill.press : (hovering ? DaybookPalette.fill.hover : .clear)
    }
}
