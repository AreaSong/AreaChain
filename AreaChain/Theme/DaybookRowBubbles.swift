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
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: isCopied ? "checkmark" : "text.alignleft")
                .font(.system(size: 9.5, weight: isCopied ? .bold : .medium))
                .foregroundStyle(isCopied ? DaybookTheme.stamp : DaybookTheme.muted)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                if isCopied {
                    Text(L10n.string("diary.copied", locale: locale))
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(DaybookTheme.stamp)
                        .transition(.opacity)
                }

                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(DaybookTheme.ink)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5.5)
        .frame(maxWidth: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(DaybookTheme.paper)
                .daybookElevation(.floating)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isCopied ? DaybookTheme.stamp.opacity(0.7) : (isHovered ? DaybookTheme.cardBorderHover : DaybookTheme.rule.opacity(0.9)), lineWidth: 0.8)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
            onHover?(hovering)
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onDisappear {
            if isHovered {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            guard onCopy != nil else { return }
            onCopy?()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isCopied = true
            }
        }
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
                HStack {
                    Spacer().frame(width: arrowPadding)
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(DaybookTheme.paper)
                        .offset(y: 1)
                    Spacer()
                }
                .frame(height: 5)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: isCopied ? "checkmark" : "text.alignleft")
                        .font(.system(size: 9.5, weight: isCopied ? .bold : .semibold))
                        .foregroundStyle(DaybookTheme.stamp)
                    Text(isCopied ? L10n.string("diary.copied", locale: locale) : L10n.string(String.LocalizationValue(stringLiteral: headerTitleKey), locale: locale))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isCopied ? DaybookTheme.stamp : DaybookTheme.muted)
                    Spacer(minLength: 0)
                }

                Text(note)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(DaybookTheme.ink)
                    .lineSpacing(2.5)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(width: 210, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(DaybookTheme.paper)
                    .daybookElevation(.floating)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isCopied ? DaybookTheme.stamp.opacity(0.7) : (isHovered ? DaybookTheme.cardBorderHover : DaybookTheme.rule.opacity(0.9)), lineWidth: 0.8)
            )

            if growsUpward {
                HStack {
                    Spacer().frame(width: arrowPadding)
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(DaybookTheme.paper)
                        .offset(y: -1)
                    Spacer()
                }
                .frame(height: 5)
            }
        }
        .frame(width: 210, alignment: .leading)
        .fixedSize()
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            onHover?(hovering)
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onDisappear {
            if isHovered {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            guard onCopy != nil else { return }
            onCopy?()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isCopied = true
            }
        }
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
}
