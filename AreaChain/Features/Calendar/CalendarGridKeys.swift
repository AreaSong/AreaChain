import AppKit
import SwiftUI

/// 月格或周格获得焦点时，方向键换日，回车进入当日清单。
struct CalendarGridKeys: ViewModifier {
    var enabled: Bool
    var selectedKey: String
    var onSelect: (String) -> Void
    var onEnterList: () -> Void
    @Environment(\.calendar) private var calendar
    @State private var token: Any?
    @State private var hostWindow: NSWindow?
    @State private var sink = CalendarGridKeySink()

    func body(content: Content) -> some View {
        sink.enabled = enabled
        sink.selectedKey = selectedKey
        sink.onSelect = onSelect
        sink.onEnterList = onEnterList
        sink.calendar = calendar
        sink.hostWindow = hostWindow
        return content
            .background(KeyWindowHost { hostWindow = $0 })
            .onAppear(perform: install)
            .onDisappear {
                BoardKeyMonitor.remove(token)
                token = nil
            }
            .onChange(of: enabled) { _, _ in install() }
    }

    private func install() {
        BoardKeyMonitor.remove(token)
        token = nil
        guard enabled else { return }
        token = BoardKeyMonitor.install(existing: nil) { event in
            sink.handle(event)
        }
    }
}

private final class CalendarGridKeySink {
    var enabled = false
    var selectedKey = ""
    var onSelect: (String) -> Void = { _ in }
    var onEnterList: () -> Void = {}
    var calendar: Calendar = .current
    weak var hostWindow: NSWindow?

    func handle(_ event: NSEvent) -> NSEvent? {
        guard enabled else { return event }
        guard hostWindow == nil || event.window === hostWindow else { return event }
        if NSApp.keyWindow?.firstResponder is NSTextView { return event }
        if let step = CalendarGridStep.from(keyCode: event.keyCode) {
            onSelect(step.apply(to: selectedKey, calendar: calendar))
            return nil
        }
        if event.keyCode == ItemsListKey.returnKey {
            onEnterList()
            return nil
        }
        return event
    }
}

extension View {
    func calendarGridKeys(
        enabled: Bool,
        selectedKey: String,
        onSelect: @escaping (String) -> Void,
        onEnterList: @escaping () -> Void
    ) -> some View {
        modifier(CalendarGridKeys(
            enabled: enabled,
            selectedKey: selectedKey,
            onSelect: onSelect,
            onEnterList: onEnterList
        ))
    }
}
