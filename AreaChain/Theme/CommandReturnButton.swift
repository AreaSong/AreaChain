import AppKit
import SwiftUI

/// 任务与手记共用同一颗快捷操作按钮；快捷键由宿主按输入上下文注册。
struct CommandReturnButton: View {
    var enabled: Bool
    var label: LocalizedStringKey
    var help: LocalizedStringKey? = nil
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCommandPressed = false
    @State private var isHovered = false
    @State private var eventMonitor: Any?

    private var isActive: Bool { enabled && (isCommandPressed || isHovered) }
    private var animation: Animation? {
        reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.75)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2.5) {
                Image(systemName: "command")
                    .font(.system(size: 10.5, weight: isActive ? .bold : .semibold))
                Image(systemName: "return")
                    .font(.system(size: 10, weight: isActive ? .bold : .semibold))
            }
            .foregroundStyle(isActive ? DaybookTheme.stamp : DaybookTheme.muted.opacity(enabled ? 0.6 : 0.25))
            .padding(.horizontal, 5)
            .padding(.vertical, 3.5)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isActive ? DaybookTheme.stamp.opacity(0.12) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!enabled)
        .fixedSize()
        .accessibilityLabel(label)
        .help(help ?? label)
        .background(SyntaxViewAnchor("syntax.commandReturn.button"))
        .onHover { isHovered = $0 }
        .animation(animation, value: isActive)
        .animation(animation, value: enabled)
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
