import AppKit
import SwiftUI

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
    public static func calculate(globalPoint: CGPoint, wideHost: Bool = false) -> (growsUpward: Bool, bubbleShiftX: CGFloat) {
        let growsUpward = globalPoint.y > 260
        let safeMaxX: CGFloat = wideHost ? 700 : 356
        let safeMinX: CGFloat = 12
        let bubbleRight = globalPoint.x + 202
        let shiftX: CGFloat
        if bubbleRight > safeMaxX {
            let overflow = bubbleRight - safeMaxX
            let maxShift = max(0, (globalPoint.x - 8) - safeMinX)
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
    public var onCopy: (() -> Void)? = nil
    public var onHover: ((Bool) -> Void)? = nil

    @State private var isCopied: Bool = false
    @State private var isHovered: Bool = false
    @Environment(\.locale) private var locale

    public init(
        title: String,
        growsUpward: Bool,
        onCopy: (() -> Void)? = nil,
        onHover: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self.growsUpward = growsUpward
        self.onCopy = onCopy
        self.onHover = onHover
    }

    public var body: some View {
        bubbleContent
            .padding(.horizontal, 8)
            .padding(.vertical, 5.5)
            .frame(maxWidth: 260, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(DaybookPalette.fill.page)
                    .daybookElevation(.floating)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .stroke(borderStrokeColor, lineWidth: 0.8) // token-exempt: 70% 印章色和 90% 分隔线没有对应令牌
            )
            .contentShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
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

    private var bubbleContent: some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: isCopied ? "checkmark" : "text.alignleft")
                .font(DaybookType.micro.weight(isCopied ? .bold : .medium))
                .foregroundStyle(isCopied ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                if isCopied {
                    Text(L10n.string("diary.copied", locale: locale))
                        .font(DaybookType.micro.weight(.bold))
                        .foregroundStyle(DaybookPalette.accent.base)
                        .transition(.opacity)
                }

                Text(title)
                    .font(DaybookType.caption.weight(.medium))
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var borderStrokeColor: Color {
        if isCopied {
            return DaybookPalette.accent.base.opacity(0.7)
        }
        return isHovered ? DaybookPalette.cardBorderHover : DaybookPalette.border.default.opacity(0.9)
    }

    private func handleHover(_ hovering: Bool) {
        isHovered = hovering
        onHover?(hovering)
        if hovering {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.pop()
        }
    }

    private func handleDisappear() {
        if isHovered {
            NSCursor.pop()
        }
    }

    private func handleTap() {
        guard onCopy != nil else { return }
        onCopy?()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
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
    public var onCopy: (() -> Void)? = nil
    public var onHover: ((Bool) -> Void)? = nil

    @State private var isCopied: Bool = false
    @State private var isHovered: Bool = false
    @Environment(\.locale) private var locale

    public init(
        note: String,
        growsUpward: Bool,
        bubbleShiftX: CGFloat,
        headerTitleKey: String = "drawer.notes.title",
        onCopy: (() -> Void)? = nil,
        onHover: ((Bool) -> Void)? = nil
    ) {
        self.note = note
        self.growsUpward = growsUpward
        self.bubbleShiftX = bubbleShiftX
        self.headerTitleKey = headerTitleKey
        self.onCopy = onCopy
        self.onHover = onHover
    }

    public var body: some View {
        let arrowPadding = max(8, min(186, 8 - bubbleShiftX))
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
        HStack {
            Spacer().frame(width: padding)
            Image(systemName: pointingUp ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 7)) // token-exempt: 小于 9pt 的气泡箭头
                .foregroundStyle(DaybookPalette.fill.page)
                .offset(y: pointingUp ? 1 : -1)
            Spacer()
        }
        .frame(height: 5)
    }

    private var noteCardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            noteCardHeader

            Text(note)
                .font(DaybookType.caption.weight(.regular))
                .foregroundStyle(DaybookPalette.text.primary)
                .lineSpacing(2.5)
                .lineLimit(8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(width: 210, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.fill.page)
                .daybookElevation(.floating)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .stroke(borderStrokeColor, lineWidth: 0.8) // token-exempt: 70% 印章色和 90% 分隔线没有对应令牌
        )
    }

    private var noteCardHeader: some View {
        HStack(spacing: 4) {
            Image(systemName: isCopied ? "checkmark" : "text.alignleft")
                .font(DaybookType.micro.weight(isCopied ? .bold : .semibold))
                .foregroundStyle(DaybookPalette.accent.base)
            Text(isCopied ? L10n.string("diary.copied", locale: locale) : L10n.string(String.LocalizationValue(stringLiteral: headerTitleKey), locale: locale))
                .font(DaybookType.badge.weight(.bold))
                .foregroundStyle(isCopied ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
            Spacer(minLength: 0)
        }
    }

    private var borderStrokeColor: Color {
        if isCopied {
            return DaybookPalette.accent.base.opacity(0.7)
        }
        return isHovered ? DaybookPalette.cardBorderHover : DaybookPalette.border.default.opacity(0.9)
    }

    private func handleHover(_ hovering: Bool) {
        isHovered = hovering
        onHover?(hovering)
        if hovering {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.pop()
        }
    }

    private func handleDisappear() {
        if isHovered {
            NSCursor.pop()
        }
    }

    private func handleTap() {
        guard onCopy != nil else { return }
        onCopy?()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            isCopied = true
        }
    }
}
