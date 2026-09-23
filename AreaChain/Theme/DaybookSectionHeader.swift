import SwiftUI

/// 列表分节：图标、标题、计数。外观与改名前相同。
struct DaybookSectionHeader: View {
    var title: LocalizedStringKey
    var icon: String? = nil
    var count: Int? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(DaybookType.badge.weight(.semibold))
                    .foregroundStyle(DaybookTheme.stamp)
            }
            Text(title)
                .font(DaybookType.section)
                .tracking(0.5)
                .foregroundStyle(DaybookTheme.muted)
            if let count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded)) // token-exempt: 分节计数用圆体
                    .foregroundStyle(DaybookTheme.muted)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

/// 布局用的淡分隔线。菜单里的 Divider 不要换成这个。
struct DaybookDivider: View {
    var opacity: Double = 0.4

    var body: some View {
        Divider().overlay(DaybookTheme.rule.opacity(opacity))
    }
}
