import SwiftUI

enum DaybookTheme {
    static let ink = Color(red: 0.91, green: 0.89, blue: 0.84)
    static let muted = Color(red: 0.55, green: 0.52, blue: 0.47)
    static let rule = Color(red: 0.27, green: 0.24, blue: 0.20)
    static let stamp = Color(red: 0.88, green: 0.63, blue: 0.29)
    static let paper = Color(red: 0.10, green: 0.09, blue: 0.08)
    static let done = Color(red: 0.45, green: 0.43, blue: 0.39)

    static let popoverSize = CGSize(width: 320, height: 420)
}

struct RuledPaper: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 28
            var y: CGFloat = 36
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 16, y: y))
                path.addLine(to: CGPoint(x: size.width - 16, y: y))
                context.stroke(path, with: .color(DaybookTheme.rule.opacity(0.45)), lineWidth: 0.6)
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

struct InkCheckbox: View {
    var isDone: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(isDone ? DaybookTheme.done : DaybookTheme.ink.opacity(0.85), lineWidth: 1.4)
                    .frame(width: 14, height: 14)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DaybookTheme.stamp)
                }
            }
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDone ? "已完成" : "未完成")
    }
}

struct SectionStamp: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(2.4)
            .foregroundStyle(DaybookTheme.muted)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }
}
