import AppKit
import SwiftUI

/// 任务与手记共用同一颗快捷操作按钮；快捷键由宿主按输入上下文注册。
struct CommandReturnButton: View {
    var enabled: Bool
    var label: LocalizedStringKey
    var help: LocalizedStringKey? = nil
    var action: () -> Void

    @State private var isCommandPressed = false
    @State private var eventMonitor: Any?

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2.5) {
                Image(systemName: "command")
                Image(systemName: "return")
            }
            .font(DaybookType.badge.weight(.semibold))
        }
        .buttonStyle(DaybookButtonStyle(enabled && isCommandPressed ? .iconActive : .icon, size: .compact))
        .focusable(false)
        .disabled(!enabled)
        .fixedSize()
        .accessibilityLabel(label)
        .help(help ?? label)
        .background(SyntaxViewAnchor("syntax.commandReturn.button"))
        .onAppear(perform: startObservingModifiers)
        .onDisappear(perform: stopObservingModifiers)
    }

    private func startObservingModifiers() {
        guard eventMonitor == nil else { return }
        isCommandPressed = NSEvent.modifierFlags.contains(.command)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            isCommandPressed = event.modifierFlags.contains(.command)
            return event
        }
    }

    private func stopObservingModifiers() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
    }
}
