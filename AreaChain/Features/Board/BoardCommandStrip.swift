import AppKit
import SwiftUI

/// 任务行和手记行共用的 ⌘ 命令条外壳。动作清单由调用方填入。
struct BoardCommandStrip<Actions: View, Destructive: View>: View {
    var hoveredTip: String?
    var destructiveTitle: String
    @ViewBuilder var actions: () -> Actions
    @ViewBuilder var destructive: () -> Destructive

    var body: some View {
        HStack(spacing: 3) {
            HStack(spacing: 2.5) {
                actions()
            }
            .fixedSize(horizontal: true, vertical: true)

            if let hoveredTip {
                BoardCommandStripTip(tip: hoveredTip, destructiveTitle: destructiveTitle)
            }

            Spacer(minLength: 2)
            destructive()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 24)
        .animation(.easeInOut(duration: 0.12), value: hoveredTip)
    }
}

struct BoardCommandStripTip: View {
    var tip: String
    var destructiveTitle: String

    private var isDestructive: Bool { tip == destructiveTitle }

    var body: some View {
        Text(tip)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(isDestructive ? Color.red : DaybookTheme.ink.opacity(0.85))
            .lineLimit(1)
            .padding(.horizontal, 5)
            .frame(height: 18)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(isDestructive ? Color.red.opacity(0.08) : DaybookTheme.ink.opacity(0.06))
            )
            .fixedSize(horizontal: true, vertical: true)
            .transition(.opacity)
    }
}

struct BoardCommandStripButton: View {
    var icon: String
    var labelKey: String
    var isActive = false
    var isDestructive = false
    @Binding var hoveredTip: String?
    var action: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            BoardCommandStripIcon(
                icon: icon,
                isButtonHovered: hoveredTip == localizedText,
                isActive: isActive,
                isDestructive: isDestructive
            )
        }
        .buttonStyle(.plain)
        .frame(width: 22, height: 22)
        .fixedSize()
        .accessibilityLabel(LocalizedStringKey(labelKey))
        .help(LocalizedStringKey(labelKey))
        .onHover { updateTip($0) }
        .background(BoardCommandHoverArea { updateTip($0) })
    }

    private var localizedText: String {
        L10n.string(String.LocalizationValue(stringLiteral: labelKey), locale: locale)
    }

    private func updateTip(_ hovering: Bool) {
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            if hovering {
                hoveredTip = localizedText
            } else if hoveredTip == localizedText {
                hoveredTip = nil
            }
        }
    }
}

struct BoardCommandStripMenu<Content: View>: View {
    var icon: String
    var labelKey: String
    var isActive = false
    @Binding var hoveredTip: String?
    @ViewBuilder var content: () -> Content

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Menu {
            content()
        } label: {
            BoardCommandStripIcon(
                icon: icon,
                isButtonHovered: hoveredTip == localizedText,
                isActive: isActive
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 22, height: 22)
        .fixedSize()
        .help(LocalizedStringKey(labelKey))
        .onHover { updateTip($0) }
        .background(BoardCommandHoverArea { updateTip($0) })
    }

    private var localizedText: String {
        L10n.string(String.LocalizationValue(stringLiteral: labelKey), locale: locale)
    }

    private func updateTip(_ hovering: Bool) {
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            if hovering {
                hoveredTip = localizedText
            } else if hoveredTip == localizedText {
                hoveredTip = nil
            }
        }
    }
}

struct BoardCommandStripIcon: View {
    var icon: String
    var isButtonHovered: Bool
    var isActive = false
    var isDestructive = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 11.5, weight: .medium))
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 4.0, style: .continuous)
                    .fill(
                        isDestructive
                            ? (isButtonHovered ? Color.red.opacity(0.18) : Color.red.opacity(0.08))
                            : (isActive
                                ? DaybookTheme.stamp.opacity(isButtonHovered ? 0.22 : 0.14)
                                : (isButtonHovered ? DaybookTheme.ink.opacity(0.12) : Color.clear))
                    )
            )
            .foregroundStyle(
                isDestructive
                    ? Color.red
                    : (isActive ? DaybookTheme.stamp : DaybookTheme.ink.opacity(isButtonHovered ? 0.95 : 0.72))
            )
            .contentShape(Rectangle())
    }
}

struct BoardCommandHoverArea: NSViewRepresentable {
    var onHover: (Bool) -> Void

    func makeNSView(context: Context) -> HoverTrackingNSView {
        let view = HoverTrackingNSView()
        view.onHover = onHover
        return view
    }

    func updateNSView(_ nsView: HoverTrackingNSView, context: Context) {
        nsView.onHover = onHover
    }
}

final class HoverTrackingNSView: NSView {
    var onHover: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHover?(false)
    }
}
