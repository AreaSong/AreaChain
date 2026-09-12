import AppKit
import Carbon
import SwiftUI

enum HotKeySlot {
    case toggle
    case paste
}

struct HotKeyRecorder: View {
    var slot: HotKeySlot = .toggle
    var title: LocalizedStringKey = "hotkey.open"
    var help: LocalizedStringKey = "hotkey.help"

    @Environment(\.locale) private var locale
    @State private var listening = false
    @State private var label = ""
    @State private var pasteArmed = true
    @State private var toggleArmed = true
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Button {
                    startListening()
                } label: {
                    if listening {
                        Text("hotkey.listen")
                    } else {
                        Text(label)
                    }
                }
                .help(help)
            }
            if slot == .paste, !pasteArmed {
                Text("hotkey.registration.failed")
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
            }
            if slot == .toggle, !toggleArmed {
                Text("hotkey.registration.failed")
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
            }
        }
        .onAppear { refreshLabel() }
        .onChange(of: locale.identifier) { _, _ in refreshLabel() }
        .onReceive(NotificationCenter.default.publisher(for: .hotKeyDidChange)) { _ in
            refreshLabel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appPreferencesDidChange)) { _ in
            refreshLabel()
        }
        .onDisappear(perform: stopListening)
    }

    private func refreshLabel() {
        switch slot {
        case .toggle:
            toggleArmed = HotKeyCenter.shared.toggleIsArmed
            let name = HotKeyCenter.shared.displayName(locale: locale)
            label = toggleArmed ? name : L10n.format("hotkey.paste.disabled", locale: locale, name)
        case .paste:
            pasteArmed = HotKeyCenter.shared.pasteIsArmed
            let name = HotKeyCenter.shared.pasteDisplayName(locale: locale)
            label = pasteArmed ? name : L10n.format("hotkey.paste.disabled", locale: locale, name)
        }
    }

    private func startListening() {
        guard !listening else { return }
        listening = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopListening()
                return nil
            }
            if let spec = HotKeySpec.parse(event: event) {
                apply(spec)
                stopListening()
            }
            return nil
        }
    }

    private func apply(_ spec: HotKeySpec) {
        switch slot {
        case .toggle:
            HotKeyCenter.shared.apply(spec)
        case .paste:
            HotKeyCenter.shared.applyPaste(spec)
        }
    }

    private func stopListening() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        listening = false
    }
}
