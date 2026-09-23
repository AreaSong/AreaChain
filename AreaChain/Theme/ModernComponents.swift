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

/// 现代物理微弹性复选框：支持弹性回弹、Path 对勾描边动画、微触感与无障碍特性
struct ModernCheckbox: View {
    var isDone: Bool
    var action: () -> Void

    @State private var hovering = false
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: handleTap) { checkboxContent }
            .buttonStyle(.plain) // control: 复选框，非按钮语义
            .onHover { hovering = $0 }
            .animation(DaybookMotion.snappy(reduceMotion), value: isDone)
            .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isDone ? Text("checkbox.done") : Text("checkbox.open"))
            .accessibilityAddTraits(isDone ? [.isButton, .isSelected] : .isButton)
    }

    private var checkboxContent: some View {
        ZStack {
            Circle()
                .strokeBorder(strokeColor, lineWidth: 1.5)
                .background(
                    Circle()
                        .fill(isDone ? DaybookTheme.stamp : Color.clear)
                )
                .frame(width: 17, height: 17)

            CheckmarkShape()
                .trim(from: 0, to: isDone ? 1 : 0)
                .stroke(
                    DaybookTheme.checkmark,
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 17, height: 17)
                .animation(DaybookMotion.checkmark(reduceMotion), value: isDone)
                .accessibilityHidden(true)
        }
        .frame(width: 20, height: 20)
        .offset(y: 0.5)
        .scaleEffect(isAnimating ? 0.88 : (hovering ? 1.06 : 1.0))
        .contentShape(Rectangle())
    }

    private var strokeColor: Color {
        if isDone {
            return DaybookTheme.stamp
        }
        if hovering {
            return DaybookTheme.stamp.opacity(0.8)
        }
        return DaybookTheme.ink.opacity(0.24)
    }

    private func handleTap() {
        DaybookHaptics.tap()
        if !reduceMotion {
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

extension View {
    /// 现代柔光焦点环
    func modernFocusRing(isFocused: Bool) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .stroke(DaybookTheme.focusRing, lineWidth: isFocused ? 1.5 : 0)
                .padding(-1.5)
                .opacity(isFocused ? 0.9 : 0)
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
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
            .foregroundStyle(isDone ? DaybookTheme.done : DaybookTheme.ink)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(DaybookTheme.done.opacity(0.85))
                        .frame(width: isDone ? proxy.size.width : 0, height: 1.2)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                .allowsHitTesting(false)
            }
            .strikethrough(reduceMotion && isDone, color: DaybookTheme.done.opacity(0.85))
            .animation(DaybookMotion.interactive(reduceMotion), value: isDone)
            .animation(DaybookMotion.strikethrough(reduceMotion), value: isDone)
    }
}
