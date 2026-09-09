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

struct TodayProgressCard: View {
    var completedCount: Int
    var totalCount: Int
    var streakDays: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progressRatio: Double {
        guard totalCount > 0 else { return completedCount > 0 ? 1.0 : 0.0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        HStack(spacing: 12) {
            DaybookProgressRing(progress: progressRatio)

            VStack(alignment: .leading, spacing: 3.5) {
                HStack(spacing: 6) {
                    Text(completedCount >= totalCount && totalCount > 0 ? "今日要事已全部达成" : "今日专注进度")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(DaybookTheme.ink)
                    Text("\(completedCount)/\(totalCount)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DaybookTheme.stamp)
                }

                HStack(spacing: 4) {
                    if streakDays > 0 {
                        PillBadge(
                            title: "已连续打卡 \(streakDays) 天",
                            icon: "flame.fill",
                            color: .orange,
                            isSelected: true
                        )
                    } else {
                        Text("✨ 坚持记录与打卡，开启新连击")
                            .font(.system(size: 11))
                            .foregroundStyle(DaybookTheme.muted)
                    }
                }
            }

            Spacer()
        }
        .padding(11)
        .modernCard(cornerRadius: DaybookRadius.card)
        .animation(ModernMotion.interactive(reduceMotion), value: completedCount)
        .animation(ModernMotion.interactive(reduceMotion), value: totalCount)
    }
}
