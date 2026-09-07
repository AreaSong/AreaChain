import SwiftUI

enum DaybookMotion {
    static let quick: Animation = .easeOut(duration: 0.15)

    static func animation(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : quick
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

    var body: some View {
        configuration.label
            .foregroundStyle(ink)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(DaybookTheme.focusRing.opacity(hovering && isEnabled ? 0.35 : 0), lineWidth: 1)
            )
            .onHover { hovering = $0 }
            .animation(DaybookMotion.animation(reduceMotion), value: hovering)
            .animation(DaybookMotion.animation(reduceMotion), value: configuration.isPressed)
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
        if hovering && isEnabled { return DaybookTheme.hoverFill }
        return .clear
    }
}

struct DaybookEmptyState: View {
    var title: LocalizedStringKey
    var systemImage: String = "square.and.pencil"
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : DaybookTheme.space) {
            if !compact {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DaybookTheme.stamp)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.system(size: compact ? 11 : 13))
                .foregroundStyle(DaybookTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, compact ? 2 : DaybookTheme.space)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .font(.system(size: 12, weight: .semibold))
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
                .font(.system(size: 16, weight: .regular, design: .serif).italic())
                .foregroundStyle(DaybookTheme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            DaybookNavButton(systemName: "chevron.right", label: nextLabel, action: onNext)
            if let onToday {
                Button("calendar.today", action: onToday)
                    .font(.system(size: 11, weight: .semibold))
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DaybookTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                focused ? DaybookTheme.focusRing : DaybookTheme.rule,
                                lineWidth: focused ? 1.6 : 1
                            )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension View {
    func daybookPanel(minWidth: CGFloat, minHeight: CGFloat) -> some View {
        padding(16)
            .frame(minWidth: minWidth, minHeight: minHeight)
            .background(DaybookTheme.paper.opacity(0.94))
    }

    func daybookHoverReveal(visible: Bool, reduceMotion: Bool) -> some View {
        opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
            .animation(DaybookMotion.animation(reduceMotion), value: visible)
    }
}
