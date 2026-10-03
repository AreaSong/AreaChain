import AppKit
import SwiftUI

/// 公开字段只读展开；独立 NSTextView 支持选择，不提供保存、撤销写入或文件能力。
struct DaybookSearchReadOnlyText: NSViewRepresentable {
    let text: String
    let identifier: String
    let collapse: () -> Void
    var onFocus: (Bool) -> Void = { _ in }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let editor = SearchReadOnlyEditor()
        editor.isEditable = false
        editor.isSelectable = true
        editor.drawsBackground = false
        editor.textContainerInset = NSSize(width: 8, height: 8)
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        scroll.documentView = editor
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.verticalScroller = DaybookScroller()
        return scroll
    }

    func updateNSView(_ view: NSScrollView, context: Context) {
        guard let editor = view.documentView as? SearchReadOnlyEditor else { return }
        if editor.string != text { editor.string = text }
        editor.font = NSFont.systemFont(ofSize: DaybookType.bodySize)
        editor.textColor = NSColor(DaybookPalette.text.primary)
        editor.setAccessibilityIdentifier(identifier)
        editor.collapse = collapse
        editor.onFocus = onFocus
    }

    static func dismantleNSView(_ view: NSScrollView, coordinator: ()) {
        guard let editor = view.documentView as? SearchReadOnlyEditor else { return }
        editor.string = ""
        editor.collapse = nil
        editor.onFocus = nil
    }
}

final class SearchReadOnlyEditor: NSTextView {
    var collapse: (() -> Void)?
    var onFocus: ((Bool) -> Void)?
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { onFocus?(true) }
        return result
    }
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result { onFocus?(false) }
        return result
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { collapse?(); return }
        if event.keyCode == 48 {
            if event.modifierFlags.contains(.shift) { window?.selectPreviousKeyView(self) }
            else { window?.selectNextKeyView(self) }
            return
        }
        super.keyDown(with: event)
    }
}
