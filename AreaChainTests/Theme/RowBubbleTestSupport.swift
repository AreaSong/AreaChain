import AppKit
import SwiftUI
import Testing
import Vision
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

/// M 只读取公开辅助语义、原生几何和注入 chrome；不设置生产悬停状态。
@MainActor
enum DiaryDiagnostic {
    static func performCopy(in window: NSWindow, locale: String = "en") throws -> Bool {
        let name = L10n.string("diary.copy", locale: Locale(identifier: locale))
        let card = try #require(SettingsButtonTestSupport.elements(window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String == "diary.preview.card"
        })
        let actions = SettingsButtonTestSupport.value(card, "accessibilityCustomActions") as? [NSAccessibilityCustomAction]
        let action = try #require(actions?.first { $0.name == name }, "合并节点必须公开命名 Copy 动作")
        // NSAccessibilityCustomAction.handler 是公开辅助动作入口；不读取或直接调用 onCopy。
        let handler = try #require(action.handler, "当前工具只执行已公开的 block 动作，不猜 selector")
        return handler()
    }

    static func recognizedStrings(_ bitmap: NSBitmapImageRep, locale: String = "en") throws -> [String] {
        let request = VNRecognizeTextRequest()
        // Vision 按语言顺序识别；英文优先会漏掉小字号中文反馈，不能据此判定没有绘制。
        request.recognitionLanguages = locale == "zh-Hans" ? ["zh-Hans", "en-US"] : ["en-US", "zh-Hans"]
        try VNImageRequestHandler(cgImage: #require(bitmap.cgImage)).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }

    static func renderedTitles(_ window: NSWindow) throws -> [CGRect] {
        let bitmap = try OverlaySurfaceTestSupport.bitmap(window)
        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = ["en-US", "zh-Hans"]
        try VNImageRequestHandler(cgImage: #require(bitmap.cgImage)).perform([request])
        let view = try #require(window.contentView)
        return (request.results ?? []).filter {
            $0.topCandidates(1).first?.string.contains("Synthetic") == true
        }.map { observation in
            let box = observation.boundingBox
            let rect = CGRect(x: box.minX * view.bounds.width,
                y: (view.isFlipped ? 1 - box.maxY : box.minY) * view.bounds.height,
                width: box.width * view.bounds.width, height: box.height * view.bounds.height)
            return view.convert(rect, to: nil)
        }
    }

    static func state(_ chrome: BoardRowChrome, phase: String) {
        print("DIARY_M \(phase) uptime=\(ProcessInfo.processInfo.systemUptime) "
            + "row=\(chrome.isRowHovered) title=\(chrome.isTitleTextHovered) "
            + "bubble=\(chrome.isTitleBubbleHovered) command=\(chrome.isCommandPressed)")
    }

    static func sample(_ chrome: BoardRowChrome, window: NSWindow, phase: String) async throws {
        var previous = ""
        for index in 0..<100 {
            let current = "\(chrome.isRowHovered),\(chrome.isTitleTextHovered),\(chrome.isTitleBubbleHovered)"
            if current != previous { state(chrome, phase: "\(phase)-\(index)"); previous = current }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(window.isKeyWindow)
    }

    static func record(_ window: NSWindow, phase: String) throws {
        try OverlaySurfaceTestSupport.record(window, name: "m-\(phase)")
        let nodes = SettingsButtonTestSupport.elements(window.contentView).map { node -> [String: Any] in
            var result: [String: Any] = ["type": String(describing: type(of: node))]
            for key in ["accessibilityRole", "accessibilityLabel", "accessibilityValue", "accessibilityTitle",
                        "accessibilityIdentifier", "accessibilityActionNames"] {
                if let value = SettingsButtonTestSupport.value(node, key) { result[key] = String(describing: value) }
            }
            if node.responds(to: NSSelectorFromString("accessibilityFrame")),
               let frame = node.value(forKey: "accessibilityFrame") as? NSValue {
                result["screenFrame"] = NSStringFromRect(frame.rectValue)
                result["windowFrame"] = NSStringFromRect(window.convertFromScreen(frame.rectValue))
            }
            if let actions = SettingsButtonTestSupport.value(node, "accessibilityCustomActions") as? [NSAccessibilityCustomAction] {
                result["customActions"] = actions.map(\.name)
            }
            if let accessible = node as? NSAccessibilityProtocol {
                result["screenFrame"] = NSStringFromRect(accessible.accessibilityFrame())
                result["windowFrame"] = NSStringFromRect(window.convertFromScreen(accessible.accessibilityFrame()))
                result["customActions"] = accessible.accessibilityCustomActions()?.map(\.name) ?? []
            }
            if let view = node as? NSView {
                result["viewFrame"] = NSStringFromRect(view.convert(view.bounds, to: nil))
                result["tracking"] = view.trackingAreas.map { area in
                    ["rect": NSStringFromRect(view.convert(area.rect, to: nil)),
                     "options": String(area.options.rawValue), "owner": String(describing: type(of: area.owner))]
                }
            }
            return result
        }
        let output: [String: Any] = ["window": window.windowNumber, "frame": NSStringFromRect(window.frame),
                                     "key": window.isKeyWindow, "nodes": nodes]
        let directory = FileManager.default.temporaryDirectory.appending(path: "AreaChainSurfaceQA")
        try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appending(path: "m-\(phase)-ax.json"))
        print("DIARY_M \(phase) window=\(window.windowNumber) output=\(directory.path)")
    }
}
