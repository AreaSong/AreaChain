import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// F 只冻结原装饰；正文、事件、反馈与箭头均直接挂生产气泡。
struct OriginalRowBubbleSurface: ViewModifier {
    var hovered = false
    var copied = false

    func body(content: Content) -> some View {
        let color = copied ? DaybookPalette.accent.base.opacity(0.7)
            : (hovered ? DaybookPalette.cardBorderHover : DaybookPalette.border.default.opacity(0.9))
        content.background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.fill.page).daybookElevation(.floating)
        ).overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .stroke(color, lineWidth: 0.8)
        )
    }
}

@Observable @MainActor
final class RowBubbleProbe {
    var mounted = true
    var copies = 0
    var hovers: [Bool] = []
    var appearances = 0
}

struct RowBubbleSample: View {
    let probe: RowBubbleProbe
    var note = false
    var callback = true
    var upward = false
    var shift: CGFloat = 0
    var text = "Synthetic 合成正文"
    var header = "drawer.notes.title"

    var body: some View {
        ZStack {
            if probe.mounted {
                bubble.background(SyntaxViewAnchor("syntax.bubble.sample"))
                    .onAppear { probe.appearances += 1 }
            }
        }.frame(width: 340, height: 340)
    }

    @ViewBuilder private var bubble: some View {
        if note {
            RowNoteBubble(note: text, growsUpward: upward, bubbleShiftX: shift, headerTitleKey: header,
                          onCopy: callback ? { probe.copies += 1 } : nil,
                          onHover: { probe.hovers.append($0) })
        } else {
            RowTitleBubble(title: text, growsUpward: upward,
                           onCopy: callback ? { probe.copies += 1 } : nil,
                           onHover: { probe.hovers.append($0) })
        }
    }
}

@MainActor
enum RowBubbleTestSupport {
    static func warp(_ point: NSPoint) {
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        #expect(CGWarpMouseCursorPosition(CGPoint(x: point.x, y: top - point.y)) == .success)
    }

    static func move(_ point: NSPoint, in window: NSWindow) async throws {
        warp(window.convertPoint(toScreen: point))
        window.acceptsMouseMovedEvents = true
        let event = try #require(NSEvent.mouseEvent(with: .mouseMoved, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 0, pressure: 0))
        NSApp.sendEvent(event)
        try await Task.sleep(for: .milliseconds(80))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    static func record(_ window: NSWindow, name: String, probe: RowBubbleProbe) throws {
        let phase = ProcessInfo.processInfo.environment["AREACHAIN_BUBBLE_PHASE"] ?? "current"
        let directory = FileManager.default.temporaryDirectory.appending(path: "AreaChainSurfaceQA")
        try OverlaySurfaceTestSupport.record(window, name: "f-\(phase)-\(name)")
        let frame = try NativeSyntaxUI.frame("syntax.bubble.sample", in: window)
        let record: [String: Any] = ["frame": NSStringFromRect(frame), "copies": probe.copies,
                                   "hovers": probe.hovers, "appearances": probe.appearances,
                                   "strings": SurfaceConsumerUI.strings(window).sorted()]
        try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys, .prettyPrinted])
            .write(to: directory.appending(path: "f-\(phase)-\(name)-evidence.json"))
        print("ROW_BUBBLE \(phase) \(name) frame=\(frame) copies=\(probe.copies) hovers=\(probe.hovers)")
    }

    static func copied(_ window: NSWindow, locale: String = "en") -> Bool {
        SurfaceConsumerUI.strings(window).contains(L10n.string("diary.copied", locale: Locale(identifier: locale)))
    }

    static func bytes(_ bitmap: NSBitmapImageRep) -> Data {
        guard let data = bitmap.bitmapData else { return Data() }
        return Data(bytes: data, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
    }
}
