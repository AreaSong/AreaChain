import AppKit

/// 状态嵌在书本内部；数量只留在提示里，所有状态都占同一个单图标位置。
@MainActor
enum MenuBarStatusImage {
    static let itemWidth: CGFloat = 24
    static let imageSize = NSSize(width: 18, height: 18)
    static let iconBounds = NSRect(x: 1, y: 1, width: 16, height: 16)
    static let markerBounds = NSRect(x: 6.5, y: 7, width: 7.5, height: 7)

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
        let icon = NSImage(systemSymbolName: "book.closed.fill", accessibilityDescription: nil)
        let iconFrame = fittedIconBounds(size: icon?.size ?? iconBounds.size)
        let marker = markerPath(for: status)
        let image = NSImage(size: imageSize, flipped: false) { _ in
            icon?.draw(in: iconFrame, from: .zero, operation: .sourceOver, fraction: 1)
            if let marker, let context = NSGraphicsContext.current?.cgContext {
                // 镂空标记随模板图标一起适配明暗背景，不依赖固定白色或额外角标。
                context.saveGState()
                context.setBlendMode(.destinationOut)
                context.setFillColor(NSColor.black.cgColor)
                context.addPath(marker)
                context.fillPath()
                context.restoreGState()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    static func markerPath(for status: MenuBarStatus?) -> CGPath? {
        switch status {
        case .remaining(let count) where count > 0:
            return CGPath(ellipseIn: CGRect(x: 9, y: 9.5, width: 3, height: 3), transform: nil)
        case .completed:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 7.5, y: 10))
            path.addLine(to: CGPoint(x: 9.5, y: 8))
            path.addLine(to: CGPoint(x: 13, y: 13))
            return path.copy(strokingWithWidth: 1.5, lineCap: .round, lineJoin: .round, miterLimit: 1)
        default:
            return nil
        }
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
