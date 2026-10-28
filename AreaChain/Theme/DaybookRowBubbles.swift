import AppKit
import Observation
import SwiftUI

public extension Notification.Name {
    static let daybookStatusNoticeDidChange = Notification.Name("AreaChain.daybookStatusNoticeDidChange")
}

/// 顶部状态栏瞬态通知中心：统一承载复制、粘贴图片等轻量状态反馈（约 1.2s 自动渐隐）
@Observable
@MainActor
public final class DaybookStatusNoticeCenter {
    public enum Kind: Equatable {
        case copied
        case pastedAttachment

        public var icon: String {
            switch self {
            case .copied, .pastedAttachment:
                return "checkmark"
            }
        }

        public var titleKey: LocalizedStringKey {
            switch self {
            case .copied:
                return "diary.copied"
            case .pastedAttachment:
                return "row.attach.paste"
            }
        }
    }

    public static let shared = DaybookStatusNoticeCenter()
    public private(set) var current: Kind? = nil
    public private(set) var revision: UInt64 = 0
    private var dismissTask: Task<Void, Never>? = nil

    public init() {}

    public func show(_ kind: Kind) {
        dismissTask?.cancel()
        revision &+= 1
        withAnimation(.easeInOut(duration: 0.18)) {
            current = kind
        }
        NotificationCenter.default.post(name: .daybookStatusNoticeDidChange, object: self)
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1200))
            guard let self, !Task.isCancelled else { return }
            self.revision &+= 1
            withAnimation(.easeInOut(duration: 0.22)) {
                self.current = nil
            }
            NotificationCenter.default.post(name: .daybookStatusNoticeDidChange, object: self)
        }
    }
}

/// 顶部状态栏胶囊视图：展示复制/粘贴等瞬态提示
public struct DaybookStatusNoticePill: View {
    public let kind: DaybookStatusNoticeCenter.Kind

    public init(kind: DaybookStatusNoticeCenter.Kind) {
        self.kind = kind
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: kind.icon)
                .font(DaybookType.micro.weight(.bold))
            Text(kind.titleKey)
                .font(DaybookType.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(DaybookPalette.accent.base)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(DaybookPalette.accent.base.opacity(0.14))) // token-exempt: 与解锁胶囊同级的 14% 强调底色
        .overlay(Capsule().strokeBorder(DaybookPalette.accent.base.opacity(0.35), lineWidth: 0.8)) // token-exempt: 与解锁胶囊同级的 35% 描边
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("daybook.status.notice")
    }
}

/// 统一行标题超长截断判定逻辑（加权字符长度计算）
public enum RowTitleTruncation {
    /// 在菜单栏弹窗（~380pt 宽）的紧凑单行展示下，判定标题是否容易被尾部截断。
    /// ASCII 字符按 0.6 权重，全角/中文按 1.0 权重。
    public static func isTruncated(_ title: String, threshold: Double = 14.0) -> Bool {
        let weighted = title.reduce(0.0) { sum, char in
            sum + (char.isASCII ? 0.6 : 1.0)
        }
        return weighted > threshold
    }
}

/// 统一气泡几何位置计算器（自适应上下翻转与屏幕边缘防溢出）
public enum RowBubblePlacement {
    public static func calculate(
        globalPoint: CGPoint,
        wideHost: Bool = false,
        hostMaxX: CGFloat? = nil
    ) -> (growsUpward: Bool, bubbleShiftX: CGFloat) {
        let growsUpward = globalPoint.y > 260
        let windowSafeMaxX: CGFloat = wideHost ? 1440 : (DaybookMetrics.Window.popoverWidth - 12)
        let safeMaxX: CGFloat = min(windowSafeMaxX, hostMaxX ?? windowSafeMaxX)
        let safeMinX: CGFloat = 12
        let bubbleRight = globalPoint.x + 207.5
        let shiftX: CGFloat
        if bubbleRight > safeMaxX {
            let overflow = bubbleRight - safeMaxX
            // 气泡宽 210pt，内部箭头最多平移至 194pt，故气泡最大左移量支持到 186pt，确保指示箭头始终指向最右侧图标且气泡不贴边裁切
            let maxShift = min(186, max(0, (globalPoint.x - 2.5) - safeMinX))
            shiftX = -min(overflow, maxShift)
        } else {
            shiftX = 0
        }
        return (growsUpward, shiftX)
    }
}

/// 统一正文/标题完整预览气泡：当菜单栏单行文本截断时，悬停展示多行完整内容，支持点击一键复制
public struct RowTitleBubble: View {
    public let title: String
    public let growsUpward: Bool
    public var isExternallyCopied: Bool = false
    public var onCopy: (() -> Void)? = nil
    public var onHover: ((Bool) -> Void)? = nil

    private var windowHoverInvalidation: (() -> Void)?
    private var copyResult: (() -> Bool)?
    @State private var windowHoverLifetime = RowBubbleHoverLifetime()
    @State private var clickShieldLifetime = RowBubbleClickShieldLifetime()

    @State private var isCopied: Bool = false
    @State private var isHovered: Bool = false
    @Environment(\.locale) private var locale

    private var effectiveCopied: Bool { isCopied || isExternallyCopied }

    public init(
        title: String,
        growsUpward: Bool,
        isExternallyCopied: Bool = false,
        onCopy: (() -> Void)? = nil,
        onHover: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self.growsUpward = growsUpward
        self.isExternallyCopied = isExternallyCopied
        self.onCopy = onCopy
        self.onHover = onHover
    }

    /// 可选的写入结果；未设置时沿原 onCopy 路径，其他宿主行为不变。
    func reportingCopyResult(_ result: @escaping () -> Bool) -> Self {
        var bubble = self
        bubble.copyResult = result
        return bubble
    }

    /// 仅手记行启用；其他标题和备注保留原悬停路径。
    func observingWindowHover(onInvalidate: @escaping () -> Void) -> Self {
        var bubble = self
        bubble.windowHoverInvalidation = onInvalidate
        return bubble
    }

    public var body: some View {
        bubbleContent
            .padding(.horizontal, 8)
            .padding(.vertical, 5.5)
            .frame(maxWidth: 260, alignment: .leading)
            .daybookSurface(floating: .rowBubble(isHovered: isHovered, isCopied: effectiveCopied))
            .contentShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
            .onHover { if windowHoverInvalidation == nil { handleHover($0) } }
            .background {
                if let windowHoverInvalidation {
                    RowBubbleHoverRegion(lifetime: windowHoverLifetime, onHover: handleHover,
                                         onInvalidate: windowHoverInvalidation)
                        .accessibilityHidden(true)
                }
            }
            .background {
                RowBubbleClickShield(
                    lifetime: clickShieldLifetime,
                    isRounded: true,
                    managesHover: windowHoverInvalidation == nil,
                    onHover: handleHover,
                    onTap: handleTap
                )
                .accessibilityHidden(true)
            }
            .onAppear {
                if windowHoverInvalidation != nil { windowHoverLifetime.view?.start() }
                clickShieldLifetime.view?.start()
            }
            .onDisappear(perform: handleDisappear)
            .onTapGesture(perform: handleTap)
            .task(id: isCopied) {
                guard isCopied else { return }
                try? await Task.sleep(for: .milliseconds(1200))
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCopied = false
                }
            }
            .compositingGroup()
            .zIndex(999)
    }

    private var bubbleContent: some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "text.alignleft")
                .font(DaybookType.micro.weight(.medium))
                .foregroundStyle(effectiveCopied ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                .frame(width: 11, height: 11)
                .padding(.top, 2)

            Text(title)
                .font(DaybookType.caption.weight(.medium))
                .foregroundStyle(effectiveCopied ? DaybookPalette.accent.base : DaybookPalette.text.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(effectiveCopied ? L10n.string("diary.copied", locale: locale) : title)
        }
        .animation(.easeInOut(duration: 0.2), value: effectiveCopied)
    }

    private func handleHover(_ hovering: Bool) {
        guard hovering != isHovered else { return }
        isHovered = hovering
        onHover?(hovering)
        if hovering {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.pop()
        }
    }

    private func handleDisappear() {
        if windowHoverInvalidation != nil { windowHoverLifetime.view?.stop() }
        clickShieldLifetime.view?.stop()
        if isHovered {
            NSCursor.pop()
        }
    }

    private func handleTap() {
        clickShieldLifetime.view?.cancelPendingTap()
        if let copyResult {
            // 宿主报告写入失败时不显示已复制。
            guard copyResult() else { return }
        } else {
            guard onCopy != nil else { return }
            onCopy?()
        }
        DaybookStatusNoticeCenter.shared.show(.copied)
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }
    }
}

/// 统一备注/手记正文悬浮预览气泡：悬停在备注图标 [≡] 时弹出，展示详细内容并带指示三角，支持点击一键复制
public struct RowNoteBubble: View {
    public let note: String
    public let growsUpward: Bool
    public let bubbleShiftX: CGFloat
    public var headerTitleKey: String = "drawer.notes.title"
    public var isExternallyCopied: Bool = false
    public var onCopy: (() -> Void)? = nil
    public var onHover: ((Bool) -> Void)? = nil
    private var copyResult: (() -> Bool)?
    @State private var clickShieldLifetime = RowBubbleClickShieldLifetime()

    @State private var isCopied: Bool = false
    @State private var isHovered: Bool = false
    @Environment(\.locale) private var locale

    private var effectiveCopied: Bool { isCopied || isExternallyCopied }

    public init(
        note: String,
        growsUpward: Bool,
        bubbleShiftX: CGFloat,
        headerTitleKey: String = "drawer.notes.title",
        isExternallyCopied: Bool = false,
        onCopy: (() -> Void)? = nil,
        onHover: ((Bool) -> Void)? = nil
    ) {
        self.note = note
        self.growsUpward = growsUpward
        self.bubbleShiftX = bubbleShiftX
        self.headerTitleKey = headerTitleKey
        self.isExternallyCopied = isExternallyCopied
        self.onCopy = onCopy
        self.onHover = onHover
    }

    /// 可选的写入结果；未设置时沿原 onCopy 路径，其他宿主行为不变。
    func reportingCopyResult(_ result: @escaping () -> Bool) -> Self {
        var bubble = self
        bubble.copyResult = result
        return bubble
    }

    public var body: some View {
        let arrowPadding = max(8, min(194, 8 - bubbleShiftX))
        VStack(alignment: .leading, spacing: 0) {
            if !growsUpward {
                arrowIndicator(pointingUp: true, padding: arrowPadding)
            }

            noteCardContent

            if growsUpward {
                arrowIndicator(pointingUp: false, padding: arrowPadding)
            }
        }
        .frame(width: 210, alignment: .leading)
        .fixedSize()
        .contentShape(Rectangle())
        .background {
            RowBubbleClickShield(
                lifetime: clickShieldLifetime,
                isRounded: false,
                managesHover: true,
                onHover: handleHover,
                onTap: handleTap
            )
            .accessibilityHidden(true)
        }
        .onAppear { clickShieldLifetime.view?.start() }
        .onHover(perform: handleHover)
        .onDisappear(perform: handleDisappear)
        .onTapGesture(perform: handleTap)
        .task(id: isCopied) {
            guard isCopied else { return }
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
        .compositingGroup()
        .zIndex(999)
    }

    private func arrowIndicator(pointingUp: Bool, padding: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: padding, height: 1)
            Image(systemName: pointingUp ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 7)) // token-exempt: 小于 9pt 的气泡箭头
                .foregroundStyle(DaybookPalette.fill.page)
                .offset(y: pointingUp ? 1 : -1)
            Spacer(minLength: 0)
        }
        .frame(height: 5)
    }

    private var noteCardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            noteCardHeader

            Text(note)
                .font(DaybookType.caption.weight(.regular))
                .foregroundStyle(effectiveCopied ? DaybookPalette.accent.base : DaybookPalette.text.primary)
                .lineSpacing(2.5)
                .lineLimit(8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(width: 210, alignment: .leading)
        .daybookSurface(floating: .rowBubble(isHovered: isHovered, isCopied: effectiveCopied))
        .animation(.easeInOut(duration: 0.2), value: effectiveCopied)
    }

    private var noteCardHeader: some View {
        let titleText = L10n.string(String.LocalizationValue(stringLiteral: headerTitleKey), locale: locale)
        return HStack(spacing: 4) {
            Image(systemName: "text.alignleft")
                .font(DaybookType.micro.weight(.semibold))
                .foregroundStyle(DaybookPalette.accent.base)
                .frame(width: 11, height: 11)
            Text(titleText)
                .font(DaybookType.badge.weight(.bold))
                .foregroundStyle(effectiveCopied ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                .accessibilityLabel(effectiveCopied ? L10n.string("diary.copied", locale: locale) : titleText)
            Spacer(minLength: 0)
        }
    }

    private func handleHover(_ hovering: Bool) {
        guard hovering != isHovered else { return }
        isHovered = hovering
        onHover?(hovering)
        if hovering {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.pop()
        }
    }

    private func handleDisappear() {
        clickShieldLifetime.view?.stop()
        if isHovered {
            NSCursor.pop()
        }
    }

    private func handleTap() {
        clickShieldLifetime.view?.cancelPendingTap()
        if let copyResult {
            // 宿主报告写入失败时不显示已复制。
            guard copyResult() else { return }
        } else {
            guard onCopy != nil else { return }
            onCopy?()
        }
        DaybookStatusNoticeCenter.shared.show(.copied)
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }
    }
}
