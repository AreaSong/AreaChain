import SwiftUI

struct DaybookProgressRing: View {
    var progress: Double // 0.0 ... 1.0
    var lineWidth: CGFloat = 4.5
    var size: CGFloat = 42

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(DaybookTheme.rule.opacity(0.35), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            DaybookTheme.stamp.opacity(0.75),
                            DaybookTheme.stamp
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(ModernMotion.smooth(reduceMotion), value: progress)

            Text("\(Int(round(progress * 100)))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(DaybookTheme.ink)
        }
        .frame(width: size, height: size)
    }
}
