import SwiftUI

struct DaybookProgressRing: View {
    var progress: Double // 0.0 ... 1.0
    var lineWidth: CGFloat = 4.5
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            Circle()
                .stroke(DaybookTheme.rule.opacity(0.35), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            DaybookTheme.stamp.opacity(0.8),
                            DaybookTheme.stamp
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)

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

    private var progressRatio: Double {
        guard totalCount > 0 else { return completedCount > 0 ? 1.0 : 0.0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        HStack(spacing: 12) {
            DaybookProgressRing(progress: progressRatio)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(completedCount >= totalCount && totalCount > 0 ? "今日要事已全部达成" : "今日专注进度")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DaybookTheme.ink)
                    Text("\(completedCount)/\(totalCount)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DaybookTheme.stamp)
                }

                HStack(spacing: 4) {
                    if streakDays > 0 {
                        Text("🔥")
                            .font(.system(size: 11))
                        Text("已连续打卡 \(streakDays) 天")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DaybookTheme.muted)
                    } else {
                        Text("✨ 坚持记录与打卡，开启新连击")
                            .font(.system(size: 11))
                            .foregroundStyle(DaybookTheme.muted)
                    }
                }
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DaybookTheme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(DaybookTheme.rule.opacity(0.3), lineWidth: 0.8)
                )
        )
    }
}
