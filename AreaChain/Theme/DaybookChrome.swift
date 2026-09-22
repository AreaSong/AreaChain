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

struct DaybookPeriodBar: View {
    var title: String
    var onPrev: () -> Void
    var onNext: () -> Void
    var onToday: (() -> Void)? = nil
    var prevLabel: LocalizedStringKey = "calendar.prev"
    var nextLabel: LocalizedStringKey = "calendar.next"

    var body: some View {
        HStack(spacing: 4) {
            DaybookIconButton(systemName: "chevron.left", label: prevLabel, action: onPrev)
            Text(title)
                .font(DaybookType.title)
                .foregroundStyle(DaybookTheme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            DaybookIconButton(systemName: "chevron.right", label: nextLabel, action: onNext)
            if let onToday {
                Button("calendar.today", action: onToday)
                    .font(DaybookType.caption.weight(.semibold))
                    .buttonStyle(DaybookButtonStyle(.prominent))
            }
        }
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
}

