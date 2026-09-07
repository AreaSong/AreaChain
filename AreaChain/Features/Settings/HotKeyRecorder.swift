import AppKit
import Carbon
import SwiftUI

struct HotKeyRecorder: View {
    @Environment(\.locale) private var locale
    @State private var listening = false
    @State private var label = HotKeyCenter.shared.displayName()
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text("hotkey.open")
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
            .help("hotkey.help")
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
        label = HotKeyCenter.shared.displayName(locale: locale)
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
                HotKeyCenter.shared.apply(spec)
                stopListening()
            }
            return nil
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
