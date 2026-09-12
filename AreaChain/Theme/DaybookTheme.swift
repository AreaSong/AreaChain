import AppKit
import SwiftUI

extension Color {
    /// 必须具名：`NSColor(name: nil)` 的动态色在 SwiftUI Button 拷贝时会 SIGSEGV。
    static func daybook(name: String, light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name(name), dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }))
    }

    static func daybook(
        name: String,
        swatch: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        .daybook(name: name, light: NSColor.daybook(swatch), dark: NSColor.daybook(dark))
    }
}

enum DaybookSwatch {
    static let inkLight = (0.12, 0.12, 0.14)
    static let inkDark = (0.96, 0.96, 0.98)
    static let mutedLight = (0.40, 0.41, 0.45)
    static let mutedDark = (0.70, 0.71, 0.75)
    static let ruleLight = (0.86, 0.88, 0.92)
    static let ruleDark = (0.24, 0.25, 0.28)
    static let stampLight = (0.08, 0.35, 0.76)
    static let stampDark = (0.38, 0.68, 1.0)
    static let paperLight = (0.98, 0.98, 0.99)
    static let paperDark = (0.12, 0.12, 0.13)
    static let doneLight = (0.40, 0.42, 0.45)
    static let doneDark = (0.68, 0.70, 0.74)
    static let destructiveLight = (0.78, 0.16, 0.14)
    static let destructiveDark = (0.98, 0.52, 0.48)
    static let checkmarkLight = (1.0, 1.0, 1.0)
    static let checkmarkDark = (0.08, 0.08, 0.10)
}

enum ContrastMath {
    static func relativeLuminance(r: Double, g: Double, b: Double) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    static func ratio(
        _ a: (Double, Double, Double),
        _ b: (Double, Double, Double)
    ) -> Double {
        let first = relativeLuminance(r: a.0, g: a.1, b: a.2)
        let second = relativeLuminance(r: b.0, g: b.1, b: b.2)
        let high = max(first, second)
        let low = min(first, second)
        return (high + 0.05) / (low + 0.05)
    }
}

enum DaybookTheme {
    static let ink = Color.daybook(name: "daybook.ink", swatch: DaybookSwatch.inkLight, dark: DaybookSwatch.inkDark)
    static let muted = Color.daybook(name: "daybook.muted", swatch: DaybookSwatch.mutedLight, dark: DaybookSwatch.mutedDark)
    static let rule = Color.daybook(name: "daybook.rule", swatch: DaybookSwatch.ruleLight, dark: DaybookSwatch.ruleDark)
    static let stamp = Color.daybook(name: "daybook.stamp", swatch: DaybookSwatch.stampLight, dark: DaybookSwatch.stampDark)
    static let paper = Color.daybook(name: "daybook.paper", swatch: DaybookSwatch.paperLight, dark: DaybookSwatch.paperDark)
    static let done = Color.daybook(name: "daybook.done", swatch: DaybookSwatch.doneLight, dark: DaybookSwatch.doneDark)
    static let destructive = Color.daybook(name: "daybook.destructive", swatch: DaybookSwatch.destructiveLight, dark: DaybookSwatch.destructiveDark)
    static let checkmark = Color.daybook(name: "daybook.checkmark", swatch: DaybookSwatch.checkmarkLight, dark: DaybookSwatch.checkmarkDark)
    static let hoverFill = Color.daybook(name: "daybook.hoverFill", light: NSColor.black.withAlphaComponent(0.04), dark: NSColor.white.withAlphaComponent(0.08))
    static let pressFill = Color.daybook(name: "daybook.pressFill", light: NSColor.black.withAlphaComponent(0.08), dark: NSColor.white.withAlphaComponent(0.14))
    static let surface = Color.daybook(name: "daybook.surface", light: NSColor.white.withAlphaComponent(0.65), dark: NSColor(white: 0.18, alpha: 0.55))
    static let cardSurface = Color.daybook(name: "daybook.cardSurface", light: NSColor.white.withAlphaComponent(0.55), dark: NSColor(white: 0.18, alpha: 0.55))
    static let cardSurfaceHover = Color.daybook(name: "daybook.cardSurfaceHover", light: NSColor.white.withAlphaComponent(0.85), dark: NSColor(white: 0.24, alpha: 0.75))
    static let cardSelectionFill = Color.daybook(
        name: "daybook.cardSelectionFill",
        light: NSColor.daybook(DaybookSwatch.stampLight).withAlphaComponent(0.08),
        dark: NSColor.daybook(DaybookSwatch.stampDark).withAlphaComponent(0.14)
    )
    static let cardSelectionStroke = Color.daybook(
        name: "daybook.cardSelectionStroke",
        light: NSColor.daybook(DaybookSwatch.stampLight).withAlphaComponent(0.35),
        dark: NSColor.daybook(DaybookSwatch.stampDark).withAlphaComponent(0.40)
    )
    static let cardBorder = Color.daybook(
        name: "daybook.cardBorder",
        light: NSColor.black.withAlphaComponent(0.06),
        dark: NSColor.white.withAlphaComponent(0.08)
    )
    static let cardBorderHover = Color.daybook(
        name: "daybook.cardBorderHover",
        light: NSColor.black.withAlphaComponent(0.12),
        dark: NSColor.white.withAlphaComponent(0.16)
    )
    static let focusRing = stamp
    static let popoverWidth: CGFloat = 380
    static let popoverMinHeight: CGFloat = 280
    static let popoverMaxHeight: CGFloat = 490
    static let popoverHeight: CGFloat = 490
    static let popoverSize = CGSize(width: popoverWidth, height: popoverHeight)
    static let workspaceSize = CGSize(width: 960, height: 640)
    static let workspaceMinSize = CGSize(width: 780, height: 500)
    static let hit: CGFloat = 28
    static let space: CGFloat = 8
}

// MARK: - Layout tokens

enum DaybookRadius {
    static let xs: CGFloat = 4
    static let small: CGFloat = 6
    static let medium: CGFloat = 10
    static let card: CGFloat = 12
    static let large: CGFloat = 16
    static let full: CGFloat = 999
}

enum DaybookSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let page: CGFloat = 16
}

enum DaybookType {
    static let title: Font = .system(size: 16, weight: .semibold)
    static let subtitle: Font = .system(size: 12)
    static let body: Font = .system(size: 13)
    static let caption: Font = .system(size: 11, weight: .medium)
    static let badge: Font = .system(size: 10, weight: .medium)
    static let label: Font = .system(size: 10, weight: .semibold)
    static let entity: Font = .system(size: 17, weight: .medium)
    static let headline: Font = .system(size: 16, weight: .semibold)
    static let section: Font = .system(size: 11, weight: .semibold)
}

enum DaybookShadow {
    static let cardSubtle = Color.black.opacity(0.04)
    static let cardHover = Color.black.opacity(0.08)
    static let popover = Color.black.opacity(0.15)
}

extension NSColor {
    static func daybook(_ rgb: (Double, Double, Double)) -> NSColor {
        NSColor(calibratedRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    }
}

struct SectionStamp: View {
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
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(DaybookTheme.muted)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

struct RowIconButton: View {
    var systemName: String
    var label: LocalizedStringKey
    var role: ButtonRole? = nil
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(DaybookType.subtitle.weight(.semibold))
                .frame(width: DaybookTheme.hit, height: DaybookTheme.hit)
                .contentShape(Rectangle())
        }
        .buttonStyle(DaybookQuietButtonStyle(destructive: role == .destructive))
        .accessibilityLabel(label)
        .help(label)
    }
}

struct ComposerAddButton: View {
    var title: LocalizedStringKey = "row.add"
    var enabled: Bool
    var emphasized: Bool = true
    var action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(DaybookType.subtitle.weight(.semibold))
            .buttonStyle(DaybookQuietButtonStyle(prominent: emphasized && enabled))
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.45)
    }
}

extension View {
    func daybookScroll() -> some View {
        scrollIndicators(.automatic)
    }

    @ViewBuilder
    func daybookHideInputChrome() -> some View {
        if #available(macOS 15.4, *) {
            self
                .writingToolsBehavior(.disabled)
                .writingToolsAffordanceVisibility(.hidden)
        } else if #available(macOS 15.0, *) {
            self.writingToolsBehavior(.disabled)
        } else {
            self
        }
    }
}
