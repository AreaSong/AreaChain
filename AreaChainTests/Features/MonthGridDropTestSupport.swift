import AppKit
import Testing
@testable import AreaChain

/// XCTest 挂载生产目的地，原生电脑控制工具只负责真实鼠标拖动；断言仍留在测试中。
@MainActor
enum MonthGridDropTestSupport {
    nonisolated static var enabled: Bool { ProcessInfo.processInfo.environment["AREACHAIN_MONTH_GRID_DRAG_QA"] == "1" }

    static func drop(_ values: [String], onto node: NSObject, in window: NSWindow,
                     snapshot: String? = nil) async throws {
        let native = SettingsButtonTestSupport.self
        try #require(window.isKeyWindow)
        let frame = try native.frame(node, in: window)
        let content = try #require(window.contentView)
        let source = MonthGridDragSource(frame: CGRect(x: 12, y: content.bounds.height - 28, width: 92, height: 22))
        source.values = values
        content.addSubview(source)
        defer { source.removeFromSuperview() }
        window.title = "MonthGridB Drag QA"
        let start = window.convertPoint(toScreen: source.convert(NSPoint(x: 46, y: 11), to: nil))
        let target = window.convertPoint(toScreen: NSPoint(x: frame.midX, y: frame.midY))
        let request: [String: Any] = ["pid": ProcessInfo.processInfo.processIdentifier,
            "request": UUID().uuidString, "window": window.windowNumber,
            "source": [start.x, start.y], "target": [target.x, target.y],
            "day": native.value(node, "accessibilityIdentifier") as? String ?? "",
            "items": values.count]
        let file = FileManager.default.temporaryDirectory.appending(path: "AreaChainMonthGridDragQA.json")
        try JSONSerialization.data(withJSONObject: request, options: .sortedKeys).write(to: file, options: .atomic)
        defer { try? FileManager.default.removeItem(at: file) }
        // 等待系统拖动本身结束，不能用 callback 的出现作为无效拖放完成条件。
        for _ in 0..<600 {
            if source.ended { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        try #require(source.started && source.ended, "必须由原生拖动完成此验收步骤")
        try await SystemPageHost.settle(window)
        if let snapshot { try native.snapshot(window, name: snapshot) }
    }
}

@MainActor
private final class MonthGridDragSource: NSView, NSDraggingSource {
    var values: [String] = []
    var started = false
    var ended = false

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlAccentColor.setFill()
        bounds.fill()
        ("QA Drag" as NSString).draw(at: NSPoint(x: 14, y: 3), withAttributes: [.foregroundColor: NSColor.white])
    }

    override func mouseDown(with event: NSEvent) {
        let items = values.map { value in
            let item = NSDraggingItem(pasteboardWriter: value as NSString)
            item.setDraggingFrame(bounds, contents: NSImage(size: bounds.size))
            return item
        }
        started = true
        beginDraggingSession(with: items, event: event, source: self).animatesToStartingPositionsOnCancelOrFail = false
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        ended = true
    }
}
