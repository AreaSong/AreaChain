import SwiftUI

/// 任务捕获和手记快速输入共用的单行外壳。正文、提交和尾部动作由调用方填入。
struct BoardCaptureRow<Leading: View, Field: View, Trailing: View>: View {
    var focused: Bool
    var fill: Color
    var stroke: Color
    var locksHeight = false
    var showsFocusShadow = false
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var field: () -> Field
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            leading()
            field()
            trailing()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .frame(height: locksHeight ? 34 : nil)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fill)
                .shadow(color: focused && showsFocusShadow ? DaybookShadow.cardSubtle : .clear, radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(stroke, lineWidth: focused ? 0.9 : 0.6)
        )
    }
}
