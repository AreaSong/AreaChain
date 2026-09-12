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
            #expect(item.length == 24)
            #expect(button.frame == initialFrame)
            #expect(button.title.isEmpty)
            #expect(button.imageScaling == .scaleNone)
            let image = try #require(button.image)
            #expect(image.isTemplate)
            #expect(image.size == NSSize(width: 18, height: 18))
            let frame = try #require(button.cell).imageRect(forBounds: button.bounds)
            #expect(frame.size == MenuBarStatusImage.imageSize)
            #expect(button.bounds.contains(frame))
            if let imageFrame { #expect(frame == imageFrame) }
            else { imageFrame = frame }
        }
        #expect(button.toolTip == MenuBarStatus.remaining(Int.max).accessibilityLabel(locale: Locale(identifier: "zh-Hans")))
        #expect(button.accessibilityLabel() == button.toolTip)
    }

    @Test func statusMarksStayInsideTheIconAndEmptyStatesHaveNoMark() throws {
        #expect(MenuBarStatusImage.markerPath(for: nil) == nil)
        #expect(MenuBarStatusImage.markerPath(for: .empty) == nil)
        #expect(MenuBarStatusImage.markerPath(for: .remaining(0)) == nil)
        for state in [MenuBarStatus.remaining(1), .remaining(Int.max), .completed] {
            let path = try #require(MenuBarStatusImage.markerPath(for: state))
            #expect(MenuBarStatusImage.markerBounds.contains(path.boundingBoxOfPath))
            #expect(MenuBarStatusImage.iconBounds.contains(path.boundingBoxOfPath))
        }
    }

    @Test func allPositiveCountsUseTheSameIconAtOneAndTwoTimesScale() throws {
        for scale in [1, 2] {
            let reference = try alphaPixels(status: .remaining(1), scale: scale)
            #expect(reference.contains { $0 > 0 })
            for count in [9, 10, 99, 100, 1_000_000, Int.max] {
                #expect(try alphaPixels(status: .remaining(count), scale: scale) == reference)
            }
            let empty = try alphaPixels(status: .empty, scale: scale)
            let completed = try alphaPixels(status: .completed, scale: scale)
            #expect(reference != empty)
            #expect(completed != empty && completed != reference)
            #expect(try alphaPixels(status: nil, scale: scale) == empty)
        }
    }

    @Test func stateChangesPreserveTheOuterBookShape() throws {
        for scale in [1, 2] {
            let base = try raster(MenuBarStatusImage.make(status: .empty), scale: scale)
            for state in [MenuBarStatus.remaining(1), .completed] {
                let marked = try raster(MenuBarStatusImage.make(status: state), scale: scale)
                for y in 0..<base.pixelsHigh {
                    for x in 0..<base.pixelsWide where x < 6 * scale || x >= 15 * scale || y < 3 * scale || y >= 15 * scale {
                        #expect(marked.colorAt(x: x, y: y)?.alphaComponent == base.colorAt(x: x, y: y)?.alphaComponent)
                    }
                }
            }
        }
    }

    @Test func renderLightAndDarkStatusStrip() throws {
        let width: CGFloat = 440
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
            let x = 12 + CGFloat(index) * 52
            let label = NSTextField(labelWithString: labels[index])
            label.font = NSFont.systemFont(ofSize: 10)
            label.alignment = .center
            label.frame = NSRect(x: x, y: 86, width: 52, height: 14)
            canvas.addSubview(label)
            for row in rows {
                let button = NSButton(frame: NSRect(x: x + 14, y: 6, width: MenuBarStatusImage.itemWidth, height: 24))
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
        try png.write(to: directory.appendingPathComponent("menubar-single-icon.png"), options: .atomic)
    }

    private func alphaPixels(status: MenuBarStatus?, scale: Int) throws -> [CGFloat] {
        let bitmap = try raster(MenuBarStatusImage.make(status: status), scale: scale)
        return (0..<bitmap.pixelsHigh).flatMap { y in
            (0..<bitmap.pixelsWide).map { x in bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0 }
        }
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
