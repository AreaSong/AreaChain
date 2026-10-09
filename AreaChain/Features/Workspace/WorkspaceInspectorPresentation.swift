import AppKit
import SwiftUI

struct WorkspaceColumnWidths: Equatable {
    var main: CGFloat?
    var inspector: CGFloat?
}

struct WorkspaceColumnWidthsKey: PreferenceKey {
    static let defaultValue = WorkspaceColumnWidths()

    static func reduce(value: inout WorkspaceColumnWidths, nextValue: () -> WorkspaceColumnWidths) {
        let next = nextValue()
        if let main = next.main { value.main = main }
        if let inspector = next.inspector { value.inspector = inspector }
    }
}

/// 只退出即将卸载的详情编辑器；搜索及主内容的 first responder 不受收起影响。
@MainActor
final class WorkspaceInspectorFocus {
    weak var marker: NSView?
    private(set) var retainsMarkedDraft = false

    func beginPresentation() { retainsMarkedDraft = false }

    func attach(_ view: NSView) {
        // inspector 会建立离屏测量视图；它不能替换已挂载窗口里的归属标记。
        guard view.window != nil, marker !== view else { return }
        marker = view
        retainsMarkedDraft = false
    }

    @discardableResult
    func releaseFocus() -> Bool {
        guard let marker, let window = marker.window,
              let editor = window.firstResponder as? NSTextView else { return false }
        let bounds = marker.convert(marker.bounds, to: nil)
        // 字段编辑器由 AppKit 临时承载，归属应使用其真实字段的坐标。
        let input: NSView = (editor.delegate as? NSTextField) ?? editor
        let frame = input.convert(input.bounds, to: nil)
        guard bounds.contains(NSPoint(x: frame.midX, y: frame.midY)) else { return false }
        // AppKit 失焦可能结束 marked text；先记录收起原因，供原草稿所有者阻止隐式提交。
        retainsMarkedDraft = editor.hasMarkedText()
        // marked text 的原生缓冲可能尚未通知 Binding；卸载前经原委托保留最新草稿。
        if retainsMarkedDraft {
            editor.didChangeText()
            // 保留字符后结束即将隐藏的原生组合会话；不触发产品提交，避免输入上下文重新取得焦点。
            editor.unmarkText()
        }
        // 系统收起时结束编辑通知可能迟到；同步撤掉该控件的聚焦请求，防止队列把焦点送回隐藏字段。
        if let field = editor.delegate as? NSTextField,
           let coordinator = field.delegate as? DaybookTextField.Coordinator {
            coordinator.parent.focus.wrappedValue = false
        } else if let coordinator = editor.delegate as? DaybookTextEditor.Coordinator {
            coordinator.parent.focused = false
        }
        return window.makeFirstResponder(nil)
    }
}

struct WorkspaceInspectorFocusMarker: NSViewRepresentable {
    let owner: WorkspaceInspectorFocus

    func makeNSView(context: Context) -> NSView {
        let view = Marker()
        view.owner = owner
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? Marker)?.owner = owner
        owner.attach(nsView)
    }

    private final class Marker: NSView {
        weak var owner: WorkspaceInspectorFocus?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            owner?.attach(self)
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil, owner?.marker === self {
                owner?.releaseFocus()
                owner?.marker = nil
            }
            super.viewWillMove(toWindow: newWindow)
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

private struct WorkspaceInspectorFocusKey: EnvironmentKey {
    static let defaultValue: WorkspaceInspectorFocus? = nil
}

extension EnvironmentValues {
    var workspaceInspectorFocus: WorkspaceInspectorFocus? {
        get { self[WorkspaceInspectorFocusKey.self] }
        set { self[WorkspaceInspectorFocusKey.self] = newValue }
    }
}
