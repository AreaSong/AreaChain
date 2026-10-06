import AppKit
import ObjectiveC
import Testing
@testable import AreaChain

/// 串行诊断时包裹原 IMP，只记录进入/返回；不改 delegate、通知或文本，退出时恢复。
@MainActor
final class SearchMultilineTrace {
    struct Event {
        let name: String
        let query: String
        let editor: String
        let marked: Bool
    }
    private var originals: [(Method, IMP, IMP)] = []
    private(set) var events: [Event] = []
    let field: NSTextField
    let coordinator: DaybookTextField.Coordinator

    init(_ field: NSTextField) throws {
        self.field = field
        coordinator = try #require(field.delegate as? DaybookTextField.Coordinator)
        do {
            for name in ["controlTextDidChange:", "editorDidChangeText:"] { try hook(name) }
            try hookCommand()
        } catch {
            restore()
            throw error
        }
    }

    func restore() {
        for (method, original, replacement) in originals.reversed() {
            method_setImplementation(method, original)
            imp_removeBlock(replacement)
        }
        originals.removeAll()
    }

    func reset() { events.removeAll() }

    func record(_ name: String) {
        let editor = field.currentEditor() as? NSTextView
        events.append(Event(name: name, query: coordinator.parent.text,
                            editor: editor?.string ?? field.stringValue, marked: editor?.hasMarkedText() == true))
        print("SEARCH_I \(name) field=\(field.stringValue.debugDescription) editor=\((editor?.string ?? "<none>").debugDescription) query=\(coordinator.parent.text.debugDescription) selection=\(String(describing: editor?.selectedRange())) marked=\(editor?.hasMarkedText() == true) undo=\(editor?.undoManager?.canUndo == true)")
    }

    private func hook(_ name: String) throws {
        let selector = NSSelectorFromString(name)
        let method = try #require(class_getInstanceMethod(DaybookTextField.Coordinator.self, selector))
        let original = method_getImplementation(method)
        typealias Callback = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
        let callback = unsafeBitCast(original, to: Callback.self)
        let block: @convention(block) (AnyObject, AnyObject?) -> Void = { [weak self] receiver, value in
            MainActor.assumeIsolated {
                let matches = receiver === self?.coordinator
                if matches { self?.record("enter.\(name)") }
                callback(receiver, selector, value)
                if matches { self?.record("exit.\(name)") }
            }
        }
        let replacement = imp_implementationWithBlock(block)
        method_setImplementation(method, replacement)
        originals.append((method, original, replacement))
    }

    private func hookCommand() throws {
        let selector = NSSelectorFromString("control:textView:doCommandBySelector:")
        let method = try #require(class_getInstanceMethod(DaybookTextField.Coordinator.self, selector))
        let original = method_getImplementation(method)
        typealias Callback = @convention(c) (AnyObject, Selector, NSControl, NSTextView, Selector) -> Bool
        let callback = unsafeBitCast(original, to: Callback.self)
        let block: @convention(block) (AnyObject, NSControl, NSTextView, Selector) -> Bool = { [weak self] receiver, control, editor, command in
            MainActor.assumeIsolated {
                let matches = receiver === self?.coordinator
                if matches { self?.record("enter.command.\(NSStringFromSelector(command))") }
                let handled = callback(receiver, selector, control, editor, command)
                if matches { self?.record("exit.command.\(NSStringFromSelector(command)).\(handled)") }
                return handled
            }
        }
        let replacement = imp_implementationWithBlock(block)
        method_setImplementation(method, replacement)
        originals.append((method, original, replacement))
    }
}
