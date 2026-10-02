import SwiftUI

// MARK: - Modern Checkbox

/// 精确归一化的对勾矢量形状，支持从 0 到 1 的 Path 描边动画
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        // 依据标准对勾比例绘制关键节点
        path.move(to: CGPoint(x: w * 0.26, y: h * 0.52))
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.32))
        return path
    }
}

/// 完成标记只显示外部状态、派发一次动作；待沉底与保存由消费者决定。
struct ModernCheckbox: View {
    enum Presentation {
        case task
        case inlineSubtask
        case detailSubtask
    }

    var isDone: Bool
    var presentation: Presentation = .task
    var action: () -> Void

    @State private var hovering = false
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.daybookButtonReduceMotionPreview) private var previewReduceMotion
    @Environment(\.isEnabled) private var isEnabled

    private var reduceMotion: Bool { systemReduceMotion || previewReduceMotion }

    private var vectorGeometry: DaybookCompletionGeometry {
        presentation == .task ? DaybookMetrics.Completion.task : DaybookMetrics.Completion.inlineSubtask
    }

    var body: some View {
        Button(action: handleTap) { checkboxContent }
            .buttonStyle(.plain) // control: 复选框，非按钮语义
            .onHover { hovering = presentation == .task && $0 }
            .animation(presentation == .task ? DaybookMotion.snappy(reduceMotion) : nil, value: isDone)
            .animation(presentation == .task ? DaybookMotion.interactive(reduceMotion) : nil, value: hovering)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isDone ? Text("checkbox.done") : Text("checkbox.open"))
            .accessibilityAddTraits(isDone ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { handleTap() }
    }

    @ViewBuilder
    private var checkboxContent: some View {
        if presentation == .detailSubtask {
            // 详情沿用系统符号的固有布局/命中范围，不继承主任务的勾线生长或缩放。
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: DaybookMetrics.Completion.detailSubtaskSymbolSize))
                .foregroundStyle(isDone ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
        } else {
            vectorCheckboxContent
        }
    }

    private var vectorCheckboxContent: some View {
        let geometry = vectorGeometry
        return ZStack {
            Circle()
                .strokeBorder(strokeColor, lineWidth: geometry.border)
                .background(
                    Circle()
                        .fill(isDone ? DaybookPalette.accent.base : Color.clear)
                )
                .frame(width: geometry.circle, height: geometry.circle)

            CheckmarkShape()
                .trim(from: 0, to: isDone ? 1 : 0)
                .stroke(
                    DaybookPalette.checkmark,
                    style: StrokeStyle(lineWidth: geometry.check, lineCap: .round, lineJoin: .round)
                )
                .frame(width: geometry.circle, height: geometry.circle)
                .animation(DaybookMotion.checkmark(reduceMotion), value: isDone)
                .accessibilityHidden(true)
        }
        .frame(width: geometry.hit, height: geometry.hit)
        .offset(y: geometry.offset)
        .scaleEffect(presentation == .task ? (isAnimating ? 0.88 : (hovering ? 1.06 : 1.0)) : 1)
        .contentShape(Rectangle())
    }

    private var strokeColor: Color {
        if isDone {
            return DaybookPalette.accent.base
        }
        if hovering {
            return DaybookPalette.accent.base.opacity(0.8)
        }
        return presentation == .task
            ? DaybookPalette.text.primary.opacity(0.24)
            : DaybookPalette.text.secondary.opacity(0.4)
    }

    private func handleTap() {
        guard isEnabled else { return }
        if presentation != .detailSubtask { DaybookHaptics.tap() }
        if presentation == .task && !reduceMotion {
            withAnimation(DaybookMotion.snappy) {
                isAnimating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(DaybookMotion.snappy) {
                    isAnimating = false
                }
            }
        }
        action()
    }
}

// MARK: - Strikethrough Text

/// 待办完成时的删除线平滑划过与文字渐隐组件
struct ModernTaskTitle: View {
    var text: String
    var isDone: Bool
    var font: Font = DaybookType.body

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(isDone ? DaybookPalette.text.done : DaybookPalette.text.primary)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(DaybookPalette.text.done.opacity(0.85))
                        .frame(width: isDone ? proxy.size.width : 0, height: 1.2)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                .allowsHitTesting(false)
            }
            .strikethrough(reduceMotion && isDone, color: DaybookPalette.text.done.opacity(0.85))
            .animation(DaybookMotion.interactive(reduceMotion), value: isDone)
            .animation(DaybookMotion.strikethrough(reduceMotion), value: isDone)
    }
}
