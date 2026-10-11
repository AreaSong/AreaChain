import AppKit
import Observation
import SwiftUI

/// 仅监听 ⌘ Command 修饰键按下/松开（不监听高频 mouseMoved，确保滚动 120fps 丝滑）。
@Observable
@MainActor
final class DashboardCommandKeyMonitor {
    static let shared = DashboardCommandKeyMonitor()

    var isCommandPressed = false
    private var flagsMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    private init() {
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            let pressed = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
            if self?.isCommandPressed != pressed {
                self?.isCommandPressed = pressed
            }
            return event
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isCommandPressed = false
            }
        }
    }
}

/// 仅当按住 ⌘ Command 且鼠标悬停在目标元素上时才挂载并弹出 HUD Popover，平时滚动零开销。
private struct DashboardCommandPopoverModifier<PopoverContent: View>: ViewModifier {
    var arrowEdge: Edge
    @ViewBuilder var popoverContent: () -> PopoverContent

    @State private var isHovering = false
    @State private var monitor = DashboardCommandKeyMonitor.shared

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if isHovering != hovering {
                    isHovering = hovering
                }
            }
            .background {
                if isHovering && monitor.isCommandPressed {
                    Color.clear
                        .popover(
                            isPresented: Binding(
                                get: { isHovering && monitor.isCommandPressed },
                                set: { if !$0 { isHovering = false } }
                            ),
                            arrowEdge: arrowEdge
                        ) {
                            popoverContent()
                                .padding(DaybookSpacing.md)
                                .frame(minWidth: 240, maxWidth: 320, alignment: .leading)
                        }
                }
            }
    }
}

extension View {
    func dashboardCommandPopover<Content: View>(
        arrowEdge: Edge = .bottom,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(DashboardCommandPopoverModifier(arrowEdge: arrowEdge, popoverContent: content))
    }
}

/// 总览页统一风格的深度透视浮窗内容组件
struct DashboardHUDCard: View {
    var icon: String
    var title: String
    var subtitle: String?
    var accent: Color = DaybookPalette.accent.base
    var items: [DashboardHUDItem] = []
    var emptyText: String

    struct DashboardHUDItem: Identifiable {
        let id = UUID()
        var symbol: String
        var symbolColor: Color
        var title: String
        var trailing: String?
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            HStack(spacing: DaybookSpacing.xs) {
                Image(systemName: icon)
                    .font(DaybookType.subtitle.weight(.semibold))
                    .foregroundStyle(accent)
                Text(verbatim: title)
                    .font(DaybookType.subtitle.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)
                Spacer(minLength: 0)
            }

            if let subtitle, !subtitle.isEmpty {
                Text(verbatim: subtitle)
                    .font(DaybookType.caption.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.secondary)
            }

            Divider()

            if items.isEmpty {
                Text(verbatim: emptyText)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.tertiary)
                    .padding(.vertical, DaybookSpacing.xs)
            } else {
                VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                    ForEach(items.prefix(8)) { item in
                        HStack(spacing: DaybookSpacing.xs) {
                            Image(systemName: item.symbol)
                                .font(DaybookType.caption)
                                .foregroundStyle(item.symbolColor)
                                .frame(width: 14)
                            Text(verbatim: item.title)
                                .font(DaybookType.caption)
                                .foregroundStyle(DaybookPalette.text.primary)
                                .lineLimit(1)
                            Spacer(minLength: DaybookSpacing.xs)
                            if let trailing = item.trailing, !trailing.isEmpty {
                                Text(verbatim: trailing)
                                    .font(DaybookType.badge.monospacedDigit())
                                    .foregroundStyle(DaybookPalette.text.tertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    if items.count > 8 {
                        Text(verbatim: "… 共 \(items.count) 项")
                            .font(DaybookType.badge)
                            .foregroundStyle(DaybookPalette.text.tertiary)
                    }
                }
            }
        }
    }
}

// MARK: - 侧边栏质感共享组件（外层温润浅灰内胆托盘 + 内层纯白微浮块 + 侧边栏同款行）

struct DashboardSidebarPanel<Content: View>: View {
    var fillsHeight: Bool = false
    private let content: Content

    init(fillsHeight: Bool = false, @ViewBuilder content: () -> Content) {
        self.fillsHeight = fillsHeight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(
            maxWidth: .infinity,
            maxHeight: fillsHeight ? .infinity : nil,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.card, style: .continuous) // control: 侧边栏同款温润浅灰内胆托盘
                .fill(DaybookPalette.sidebarFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.card, style: .continuous) // control: 侧边栏同款 1pt 内胆柔边
                .strokeBorder(DaybookPalette.sidebarBorder, lineWidth: 1)
        )
    }
}

struct DashboardSurfaceTile<Content: View>: View {
    var isSelected: Bool = false
    var fixedHeight: CGFloat?
    var action: () -> Void
    private let content: Content

    @State private var isHovered = false

    init(
        isSelected: Bool = false,
        fixedHeight: CGFloat? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.fixedHeight = fixedHeight
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: fixedHeight, maxHeight: fixedHeight, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous) // control: 浅灰托盘内的纯白微浮卡片
                        .fill(backgroundFill)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 微浮指标卡整卡点击
        .onHover { isHovered = $0 }
    }

    private var backgroundFill: Color {
        if isSelected {
            return DaybookPalette.fill.selection
        }
        if isHovered {
            return DaybookPalette.fill.hover
        }
        return DaybookPalette.fill.surface
    }
}

struct DashboardSidebarSectionHeader: View {
    var titleKey: LocalizedStringKey?
    var titleText: String?
    var badgeText: String?
    var isHighlightedBadge: Bool = false

    init(_ titleKey: LocalizedStringKey, badgeText: String? = nil, isHighlightedBadge: Bool = false) {
        self.titleKey = titleKey
        self.titleText = nil
        self.badgeText = badgeText
        self.isHighlightedBadge = isHighlightedBadge
    }

    init(verbatim titleText: String, badgeText: String? = nil, isHighlightedBadge: Bool = false) {
        self.titleKey = nil
        self.titleText = titleText
        self.badgeText = badgeText
        self.isHighlightedBadge = isHighlightedBadge
    }

    var body: some View {
        HStack(spacing: 6) {
            if let titleKey {
                Text(titleKey)
                    .lineLimit(1)
            } else if let titleText {
                Text(verbatim: titleText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let badgeText, !badgeText.isEmpty {
                Text(verbatim: badgeText)
                    .font(DaybookType.badge.monospacedDigit())
                    .foregroundStyle(isHighlightedBadge ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 分组标题右侧状态胶囊
                            .fill(isHighlightedBadge ? DaybookPalette.fill.selection : DaybookPalette.fill.hover)
                    )
            }
        }
        .frame(height: 20)
        .font(DaybookType.caption.weight(.semibold))
        .foregroundStyle(DaybookPalette.text.secondary)
        .padding(.horizontal, 4)
    }
}

struct DashboardSidebarRow: View {
    var titleKey: LocalizedStringKey?
    var titleText: String?
    var systemImage: String?
    var statusDotColor: Color?
    var secondaryText: String?
    var badgeText: String?
    var isSelected: Bool = false
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let statusDotColor {
                    DaybookStatusDot(color: statusDotColor, size: 8)
                        .frame(width: 16, alignment: .center)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(DaybookType.body)
                        .foregroundStyle(isSelected ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                        .frame(width: 16, alignment: .center)
                }

                if let titleKey {
                    Text(titleKey)
                        .lineLimit(1)
                        .truncationMode(AppPreferences.shared.contentTruncation.textTruncation)
                } else if let titleText {
                    Text(verbatim: titleText)
                        .lineLimit(1)
                        .truncationMode(AppPreferences.shared.contentTruncation.textTruncation)
                }

                Spacer(minLength: 8)

                if let secondaryText, !secondaryText.isEmpty {
                    Text(verbatim: secondaryText)
                        .font(DaybookType.caption.monospacedDigit())
                        .foregroundStyle(DaybookPalette.text.tertiary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                if let badgeText, !badgeText.isEmpty {
                    Text(verbatim: badgeText)
                        .font(DaybookType.caption.monospacedDigit())
                        .foregroundStyle(isSelected ? DaybookPalette.text.primary : DaybookPalette.text.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 侧边栏同款胶囊数字徽章
                                .fill(isSelected ? DaybookPalette.fill.surface : DaybookPalette.fill.hover)
                        )
                }
            }
            .font(DaybookType.body.weight(isSelected ? .medium : .regular))
            .foregroundStyle(isSelected ? DaybookPalette.accent.base : DaybookPalette.text.primary)
            .padding(.vertical, 4.5)
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous) // control: 侧边栏同款行圆角底衬
                    .fill(backgroundFill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 侧边栏同款导航行
        .onHover { isHovered = $0 }
    }

    private var backgroundFill: Color {
        if isSelected {
            return DaybookPalette.fill.selection
        }
        if isHovered {
            return DaybookPalette.fill.hover
        }
        return DaybookPalette.fill.surface
    }
}
