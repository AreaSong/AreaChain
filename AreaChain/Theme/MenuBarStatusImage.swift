import AppKit

/// 固定尺寸的模板图像由系统着色，图标与数字不会被 NSButton 按文字长度重新排位。
@MainActor
enum MenuBarStatusImage {
    static let itemWidth: CGFloat = 53
    static let imageSize = NSSize(width: 45, height: 18)
    static let iconBounds = NSRect(x: 0, y: 1, width: 16, height: 16)
    static let statusBounds = NSRect(x: 19, y: 0, width: 26, height: 18)
    static let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)

    static func apply(to button: NSButton, status: MenuBarStatus?, locale: Locale) {
        let label = status?.accessibilityLabel(locale: locale)
            ?? L10n.string("menubar.status.unavailable", locale: locale)
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.image = make(status: status)
        button.toolTip = label
        button.setAccessibilityLabel(label)
    }

    static func make(status: MenuBarStatus?) -> NSImage {
        let text = status?.text ?? "—"
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let textFrame = textBounds(for: text)
        let icon = NSImage(systemSymbolName: "book.closed.fill", accessibilityDescription: nil)
        let iconFrame = fittedIconBounds(size: icon?.size ?? iconBounds.size)
        let image = NSImage(size: imageSize, flipped: false) { _ in
            icon?.draw(in: iconFrame, from: .zero, operation: .sourceOver, fraction: 1)
            (text as NSString).draw(in: textFrame, withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        return image
    }

    static func textBounds(for text: String) -> NSRect {
        let size = (text as NSString).size(withAttributes: [.font: font])
        return NSRect(
            x: statusBounds.midX - size.width / 2,
            y: statusBounds.midY - size.height / 2,
            width: size.width, height: size.height
        )
    }

    private static func fittedIconBounds(size: NSSize) -> NSRect {
        let scale = min(iconBounds.width / size.width, iconBounds.height / size.height)
        let fitted = NSSize(width: size.width * scale, height: size.height * scale)
        return NSRect(
            x: iconBounds.midX - fitted.width / 2, y: iconBounds.midY - fitted.height / 2,
            width: fitted.width, height: fitted.height
        )
    }
}
