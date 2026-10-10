import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct CommandTextGeometryTests {
    @Test func nativeGeometryBeforeAndAfterWindowAttachment() async throws {
        let f = try ProtectedDraftFixture(configured: false)
        try f.start()
        let editor = CommandProtectedTextView(session: f.service)
        var rows: [[String: Any]] = []
        func record(_ name: String) {
            var actual = NSRange()
            let rect = editor.firstRect(forCharacterRange: editor.selectedRange(), actualRange: &actual)
            rows.append(["step": name, "frame": NSStringFromRect(editor.frame), "bounds": NSStringFromRect(editor.bounds),
                         "container": NSStringFromSize(editor.textContainer!.containerSize), "max": NSStringFromSize(editor.maxSize),
                         "min": NSStringFromSize(editor.minSize), "verticallyResizable": editor.isVerticallyResizable,
                         "font": editor.font?.pointSize ?? -1, "typingFont": (editor.typingAttributes[.font] as? NSFont)?.pointSize ?? -1,
                         "firstRect": NSStringFromRect(rect), "selectedLocation": editor.selectedRange().location,
                         "markedLocation": editor.markedRange().location, "window": editor.window?.windowNumber ?? -1])
        }
        record("initial")
        try editor.begin(using: f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease))
        record("restored")
        let scroll = NSScrollView(frame: .init(x: 0, y: 0, width: 400, height: 200))
        scroll.documentView = editor
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = scroll
        defer { editor.end(); window.close() }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(window)
        try await NativeSyntaxUI.prepareFocus(in: window)
        try #require(window.makeFirstResponder(editor))
        record("window")
        editor.insertText(String(repeating: "中a🙂", count: 128), replacementRange: .init(location: 0, length: editor.string.utf16.count))
        record("inserted")
        editor.setMarkedText("z", selectedRange: .init(location: 1, length: 0), replacementRange: .init(location: NSNotFound, length: 0))
        record("marked")
        editor.font = .systemFont(ofSize: DaybookType.bodySize)
        record("configured-font")
        editor.sizeToFit()
        record("sizeToFit")
        Attachment.record(try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys]), named: "CM1R-geometry.json")
    }
}
