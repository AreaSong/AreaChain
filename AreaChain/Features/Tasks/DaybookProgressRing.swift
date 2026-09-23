import SwiftUI

struct DaybookProgressRing: View {
    var progress: Double // 0.0 ... 1.0
    var lineWidth: CGFloat = 4.5
    var size: CGFloat = 42

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(DaybookPalette.border.default.opacity(0.35), lineWidth: lineWidth) // token-exempt: 35% 分隔线没有对应令牌
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            DaybookPalette.accent.base.opacity(0.75), // token-exempt: 75% 印章色没有对应令牌
                            DaybookPalette.accent.base
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(DaybookMotion.smooth(reduceMotion), value: progress)

            Text("\(Int(round(progress * 100)))%")
                .font(.system(size: 10, weight: .bold, design: .rounded)) // token-exempt: 进度环数字用圆体
                .foregroundStyle(DaybookPalette.text.primary)
        }
        .frame(width: size, height: size)
    }
}
