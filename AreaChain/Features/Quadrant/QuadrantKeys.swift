import AppKit
import SwiftUI

/// 四象限卡片键盘：上下移动，空格完成，回车打开检查器。输入框聚焦时不接管。
struct QuadrantKeys: ViewModifier {
    @WorkspaceNavigationContext private var navigation
    var ids: [UUID]
    @Binding var focusedID: UUID?
    var onToggle: () -> Void
    var onInspect: () -> Void
    @State private var token: Any?
    @State private var hostWindow: NSWindow?
    @State private var sink = QuadrantKeySink()

    func body(content: Content) -> some View {
        sink.ids = ids
        sink.focusedID = $focusedID
        sink.onToggle = onToggle
        sink.onInspect = onInspect
        sink.escapeClearsFocus = !navigation.isInspectorPresented
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
            sink.escapeClearsFocus = !navigation.isInspectorPresented
            return sink.handle(event)
        }
    }
}

private final class QuadrantKeySink {
    var ids: [UUID] = []
    var focusedID: Binding<UUID?> = .constant(nil)
    var onToggle: () -> Void = {}
    var onInspect: () -> Void = {}
    var escapeClearsFocus = true
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
        case ItemsListKey.space:
            guard focusedID.wrappedValue != nil else { return event }
            onToggle()
        case ItemsListKey.returnKey:
            guard focusedID.wrappedValue != nil else { return event }
            onInspect()
        case ItemsListKey.escape:
            guard focusedID.wrappedValue != nil, escapeClearsFocus else { return event }
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
    func quadrantKeys(
        ids: [UUID],
        focusedID: Binding<UUID?>,
        onToggle: @escaping () -> Void,
        onInspect: @escaping () -> Void
    ) -> some View {
        modifier(QuadrantKeys(ids: ids, focusedID: focusedID, onToggle: onToggle, onInspect: onInspect))
    }
}
