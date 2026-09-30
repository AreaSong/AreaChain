import AppKit
import SwiftUI

/// 回收站键盘只移动和恢复。彻底删除仍走按钮确认。
struct TrashKeys: ViewModifier {
    var items: [TrashRow]
    @Binding var focusedID: UUID?
    var onRestore: () -> Void
    @State private var token: Any?
    @State private var hostWindow: NSWindow?
    @State private var sink = TrashKeySink()

    func body(content: Content) -> some View {
        sink.ids = items.map(\.id)
        sink.focusedID = $focusedID
        sink.onRestore = onRestore
        sink.hostWindow = hostWindow
        return content
            .background(KeyWindowHost { hostWindow = $0 })
            .onAppear(perform: install)
            .onDisappear {
                BoardKeyMonitor.remove(token)
                token = nil
            }
    }

    private func install() {
        guard token == nil else { return }
        token = BoardKeyMonitor.install(existing: nil) { event in
            sink.handle(event)
        }
    }
}

private final class TrashKeySink {
    var ids: [UUID] = []
    var focusedID: Binding<UUID?> = .constant(nil)
    var onRestore: () -> Void = {}
    weak var hostWindow: NSWindow?

    func handle(_ event: NSEvent) -> NSEvent? {
        guard hostWindow == nil || event.window === hostWindow else { return event }
        if NSApp.keyWindow?.firstResponder is NSTextView { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
        guard flags.isEmpty else { return event }
        switch event.keyCode {
        case ItemsListKey.arrowDown:
            move(1)
        case ItemsListKey.arrowUp:
            move(-1)
        case ItemsListKey.returnKey:
            guard focusedID.wrappedValue != nil else { return event }
            onRestore()
        case ItemsListKey.escape:
            guard focusedID.wrappedValue != nil else { return event }
            focusedID.wrappedValue = nil
        default:
            return event
        }
        return nil
    }

    private func move(_ delta: Int) {
        guard !ids.isEmpty else {
            focusedID.wrappedValue = nil
            return
        }
        guard let current = focusedID.wrappedValue, let index = ids.firstIndex(of: current) else {
            focusedID.wrappedValue = delta < 0 ? ids.last : ids.first
            return
        }
        let next = min(max(index + delta, 0), ids.count - 1)
        focusedID.wrappedValue = ids[next]
    }
}

extension View {
    func trashKeys(
        items: [TrashRow],
        focusedID: Binding<UUID?>,
        onRestore: @escaping () -> Void
    ) -> some View {
        modifier(TrashKeys(items: items, focusedID: focusedID, onRestore: onRestore))
    }
}
