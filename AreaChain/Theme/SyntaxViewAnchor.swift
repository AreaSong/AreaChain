import AppKit
import SwiftUI

/// 混合 SwiftUI/AppKit 界面的原生几何标识，不参与鼠标命中或无障碍朗读。
struct SyntaxViewAnchor: NSViewRepresentable {
    let identifier: String

    init(_ identifier: String) { self.identifier = identifier }

    func makeNSView(context: Context) -> NSView {
        let view = AnchorView()
        view.identifier = NSUserInterfaceItemIdentifier(identifier)
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        view.identifier = NSUserInterfaceItemIdentifier(identifier)
    }

    private final class AnchorView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
