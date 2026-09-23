import SwiftUI

// MARK: - 圆角令牌（xxs / regular 为新增，吸收 Features 里 2–3 与 7–8 的字面圆角）

enum DaybookRadius {
    static let xxs: CGFloat = 2.5
    static let xs: CGFloat = 4
    static let small: CGFloat = 6
    static let regular: CGFloat = 8
    static let medium: CGFloat = 10
    static let card: CGFloat = 12
    static let large: CGFloat = 16
    static let full: CGFloat = 999
}

// MARK: - 间距令牌

enum DaybookSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let page: CGFloat = 16
}

// MARK: - 字号令牌（kbd / micro / bodyLarge / display 为新增，吸收 8.5 / 9 / 14 / 26 的字面字号）

enum DaybookType {
    static let titleSize: CGFloat = 16
    static let subtitleSize: CGFloat = 12
    static let bodySize: CGFloat = 13
    static let captionSize: CGFloat = 11
    static let title: Font = .system(size: titleSize, weight: .semibold)
    static let subtitle: Font = .system(size: subtitleSize)
    static let body: Font = .system(size: bodySize)
    static let caption: Font = .system(size: captionSize, weight: .medium)
    static let badge: Font = .system(size: 10, weight: .medium)
    static let label: Font = .system(size: 10, weight: .semibold)
    static let entity: Font = .system(size: 17, weight: .medium)
    static let headline: Font = title
    static let section: Font = .system(size: 11, weight: .semibold)
    static let kbd: Font = .system(size: 8.5, weight: .semibold, design: .monospaced)
    static let micro: Font = .system(size: 9, weight: .medium)
    static let counter: Font = .system(size: 10, weight: .bold, design: .rounded)
    static let bodyLarge: Font = .system(size: 14)
    static let display: Font = .system(size: 26, weight: .light)
}
