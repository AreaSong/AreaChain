import AppKit
import SwiftUI

enum DaybookMotion {
    static let snappy: Animation = .spring(response: 0.22, dampingFraction: 0.72)
    static let interactive: Animation = .spring(response: 0.28, dampingFraction: 0.80)
    static let smooth: Animation = .spring(response: 0.34, dampingFraction: 0.85)
    static let strike: Animation = .easeInOut(duration: 0.20)
    static let quick: Animation = snappy
    static let checkmark: Animation = .spring(response: 0.24, dampingFraction: 0.68)
    static let strikethrough: Animation = .easeInOut(duration: 0.24)
    static let collapse: Animation = .spring(response: 0.34, dampingFraction: 0.82)
    static let fade: Animation = .easeInOut(duration: 0.15)

    static func snappy(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : snappy
    }

    static func interactive(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : interactive
    }

    static func smooth(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : smooth
    }

    static func animation(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : quick
    }

    static func checkmark(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : checkmark
    }

    static func strikethrough(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : strikethrough
    }

    static func collapse(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : collapse
    }

    static func fade(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : fade
    }
}

/// macOS 触控板微触感反馈
enum DaybookHaptics {
    @MainActor
    static func tap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }

    @MainActor
    static func celebrate() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }
}

struct DaybookQuietButtonStyle: ButtonStyle {
    var prominent: Bool = false
    var destructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        DaybookQuietButton(
            configuration: configuration,
            prominent: prominent,
            destructive: destructive
        )
    }
}

private struct DaybookQuietButton: View {
    let configuration: ButtonStyle.Configuration
    var prominent: Bool
    var destructive: Bool
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.daybookViewStyle) private var style

    var body: some View {
        let ringOpacity: CGFloat = hovering && isEnabled ? 0.35 : 0
        return configuration.label
            .foregroundStyle(ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .stroke(DaybookTheme.focusRing.opacity(ringOpacity), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed && !style.isWorkspace ? 0.97 : 1.0)
            .onHover { hovering = $0 }
            .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
            .animation(DaybookMotion.snappy(reduceMotion), value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.45)
    }

    private var ink: Color {
        if !isEnabled { return DaybookTheme.muted }
        if destructive { return DaybookTheme.destructive }
        if prominent { return DaybookTheme.stamp }
        return DaybookTheme.ink
    }

    private var fill: Color {
        if configuration.isPressed { return DaybookTheme.pressFill }
        if hovering && isEnabled { return style.hoverFill }
        return .clear
    }
}

struct DaybookEmptyState: View {
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var systemImage: String = "square.and.pencil"
    var compact: Bool = false
    var alignment: HorizontalAlignment = .center
    var centerVertically: Bool = false

    var body: some View {
        VStack(alignment: alignment, spacing: compact ? 4 : 6) {
            if !compact {
                Image(systemName: systemImage)
                    .font(.system(size: alignment == .center ? 28 : 16, weight: .light))
                    .foregroundStyle(DaybookTheme.stamp.opacity(0.85))
                    .padding(.bottom, alignment == .center ? 4 : 0)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(compact ? DaybookType.caption : (alignment == .center ? .system(size: 13, weight: .medium) : DaybookType.body))
                .foregroundStyle(DaybookTheme.ink.opacity(0.88))
                .multilineTextAlignment(alignment == .center ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(DaybookTheme.muted)
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, compact ? 2 : (alignment == .center ? (centerVertically ? 12 : 28) : DaybookTheme.space))
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        .modifier(EmptyStateCenterModifier(centerVertically: centerVertically && !compact))
    }
}

private struct EmptyStateCenterModifier: ViewModifier {
    var centerVertically: Bool

    func body(content: Content) -> some View {
        if centerVertically {
            content
                .containerRelativeFrame(.vertical, alignment: .center) { length, _ in
                    max(length - 16, 120)
                }
        } else {
            content
        }
    }
}

struct DaybookNavButton: View {
    var systemName: String
    var label: LocalizedStringKey
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(DaybookType.subtitle.weight(.semibold))
                .frame(width: DaybookTheme.hit, height: DaybookTheme.hit)
                .contentShape(Rectangle())
        }
        .buttonStyle(DaybookQuietButtonStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
        .help(label)
    }
}

struct DaybookPeriodBar: View {
    var title: String
    var onPrev: () -> Void
    var onNext: () -> Void
    var onToday: (() -> Void)? = nil
    var prevLabel: LocalizedStringKey = "calendar.prev"
    var nextLabel: LocalizedStringKey = "calendar.next"

    var body: some View {
        HStack(spacing: 4) {
            DaybookNavButton(systemName: "chevron.left", label: prevLabel, action: onPrev)
            Text(title)
                .font(DaybookType.title)
                .foregroundStyle(DaybookTheme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            DaybookNavButton(systemName: "chevron.right", label: nextLabel, action: onNext)
            if let onToday {
                Button("calendar.today", action: onToday)
                    .font(DaybookType.caption.weight(.semibold))
                    .buttonStyle(DaybookQuietButtonStyle(prominent: true))
            }
        }
    }
}

struct DaybookField<Content: View>: View {
    var focused: Bool = false
    var content: Content

    init(focused: Bool = false, @ViewBuilder content: () -> Content) {
        self.focused = focused
        self.content = content()
    }

    var body: some View {
        content
            .daybookInputChrome(focused: focused, kind: .search)
    }
}

extension View {
    func daybookPanel(minWidth: CGFloat, minHeight: CGFloat) -> some View {
        padding(DaybookSpacing.page)
            .frame(minWidth: minWidth, maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
            .background(DaybookTheme.paper.opacity(0.94))
    }

    func daybookHoverReveal(visible: Bool, reduceMotion: Bool) -> some View {
        opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
            .animation(DaybookMotion.animation(reduceMotion), value: visible)
    }

    func daybookCardStyle(
        isHoverable: Bool = true,
        padding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    ) -> some View {
        modifier(DaybookCardModifier(isHoverable: isHoverable, padding: padding))
    }
}

/// 现代生产力微质感卡片修饰器（Linear / Raycast 风格）：
/// 规范微圆角（6~8pt）、精密细边框、半透明卡片底色与微弱悬浮态高亮。
struct DaybookCardModifier: ViewModifier {
    @Environment(\.daybookViewStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isHoverable: Bool
    var padding: EdgeInsets
    @State private var isHovered = false

    init(isHoverable: Bool = true, padding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)) {
        self.isHoverable = isHoverable
        self.padding = padding
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .stroke(borderStroke, lineWidth: 0.5)
            )
            .shadow(color: isHovered && isHoverable ? DaybookElevation.raised.color : DaybookElevation.raised.color, radius: isHovered && isHoverable ? 2 : 0.5, y: 0.5)
            .onHover { isHovered = $0 }
            .animation(DaybookMotion.interactive(reduceMotion), value: isHovered)
    }

    private var backgroundFill: Color {
        if isHovered && isHoverable {
            return style.isWorkspace ? WorkspaceStyle.surface : DaybookTheme.cardSurfaceHover
        }
        return style.cardSurface
    }

    private var borderStroke: Color {
        if isHovered && isHoverable {
            return style.isWorkspace ? WorkspaceStyle.border.opacity(0.85) : DaybookTheme.cardBorderHover
        }
        return style.cardBorder
    }
}

