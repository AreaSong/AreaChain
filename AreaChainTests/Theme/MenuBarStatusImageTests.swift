import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct MenuBarStatusImageTests {
    private var states: [MenuBarStatus?] {
        [nil, .empty, .remaining(1), .remaining(9), .remaining(10), .remaining(99), .remaining(100), .completed]
    }

    @Test func nativeStatusItemNeverChangesSizeOrRecentersItsImage() throws {
        let item = NSStatusBar.system.statusItem(withLength: MenuBarStatusImage.itemWidth)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try #require(item.button)
        let initialFrame = button.frame
        #expect(initialFrame.width == MenuBarStatusImage.itemWidth)
        #expect(initialFrame.height > 0)
        var imageFrame: NSRect?
        for state in states + [.remaining(Int.max)] {
            MenuBarStatusImage.apply(to: button, status: state, locale: Locale(identifier: "zh-Hans"))
            button.layoutSubtreeIfNeeded()
            #expect(item.length == 53)
            #expect(button.frame == initialFrame)
            #expect(button.title.isEmpty)
            #expect(button.imageScaling == .scaleNone)
            let image = try #require(button.image)
            #expect(image.isTemplate)
            #expect(image.size == NSSize(width: 45, height: 18))
            let frame = try #require(button.cell).imageRect(forBounds: button.bounds)
            #expect(frame.size == MenuBarStatusImage.imageSize)
            #expect(button.bounds.contains(frame))
            if let imageFrame { #expect(frame == imageFrame) }
            else { imageFrame = frame }
        }
        #expect(button.toolTip == MenuBarStatus.remaining(Int.max).accessibilityLabel(locale: Locale(identifier: "zh-Hans")))
        #expect(button.accessibilityLabel() == button.toolTip)
    }

    @Test func everyGlyphFitsTheFixedSlotWithoutFontScaling() {
        #expect(MenuBarStatusImage.font.pointSize == 13)
        for text in states.map({ $0?.text ?? "—" }) {
            let bounds = MenuBarStatusImage.textBounds(for: text)
            #expect(MenuBarStatusImage.statusBounds.contains(bounds))
            #expect(abs(bounds.midX - MenuBarStatusImage.statusBounds.midX) < 0.001)
            #expect(abs(bounds.midY - MenuBarStatusImage.statusBounds.midY) < 0.001)
        }
        #expect(MenuBarStatusImage.textBounds(for: "1").width == MenuBarStatusImage.textBounds(for: "9").width)
    }

    @Test func iconPixelsAreIdenticalForAllCountsAtOneAndTwoTimesScale() throws {
        for scale in [1, 2] {
            var reference: [CGFloat]?
            for state in states {
                let bitmap = try raster(MenuBarStatusImage.make(status: state), scale: scale)
                let iconPixels = (0..<bitmap.pixelsHigh).flatMap { y in
                    (0..<(17 * scale)).map { x in bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0 }
                }
                #expect(iconPixels.contains { $0 > 0 })
                if let reference { #expect(iconPixels == reference) }
                else { reference = iconPixels }
            }
        }
    }

    @Test func renderLightAndDarkStatusStrip() throws {
        let width: CGFloat = 600
        let canvas = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 104))
        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = NSColor(white: 0.94, alpha: 1).cgColor
        let appearances: [NSAppearance.Name] = [.aqua, .darkAqua]
        let rows = appearances.enumerated().map { index, appearance in
            let row = NSView(frame: NSRect(x: 0, y: index == 0 ? 46 : 4, width: width, height: 36))
            row.wantsLayer = true
            row.layer?.backgroundColor = (appearance == .aqua ? NSColor.white : NSColor(white: 0.12, alpha: 1)).cgColor
            row.appearance = NSAppearance(named: appearance)
            canvas.addSubview(row)
            return row
        }
        let labels = ["未读取", "未安排", "1", "9", "10", "99", "100+", "已处理"]
        for (index, state) in states.enumerated() {
            let x = 12 + CGFloat(index) * 72
            let label = NSTextField(labelWithString: labels[index])
            label.font = NSFont.systemFont(ofSize: 10)
            label.alignment = .center
            label.frame = NSRect(x: x, y: 86, width: 53, height: 14)
            canvas.addSubview(label)
            for row in rows {
                let button = NSButton(frame: NSRect(x: x, y: 6, width: 53, height: 24))
                button.isBordered = false
                button.contentTintColor = .labelColor
                MenuBarStatusImage.apply(to: button, status: state, locale: Locale(identifier: "zh-Hans"))
                row.addSubview(button)
            }
        }
        canvas.appearance = NSAppearance(named: .aqua)
        canvas.layoutSubtreeIfNeeded()
        let bitmap = try #require(canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds))
        canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-UI-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: directory.appendingPathComponent("menubar-fixed-status.png"), options: .atomic)
    }

    private func raster(_ image: NSImage, scale: Int) throws -> NSBitmapImageRep {
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(image.size.width) * scale, pixelsHigh: Int(image.size.height) * scale,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
        context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        image.draw(in: NSRect(origin: .zero, size: image.size))
        context.flushGraphics()
        return bitmap
    }
}
