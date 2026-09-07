import AppKit
import Carbon
import SwiftUI

struct HotKeyRecorder: View {
    @State private var listening = false
    @State private var label = HotKeyCenter.shared.displayName
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text("打开浮层")
            Spacer()
            Button(listening ? "按下新组合…" : label) {
                startListening()
            }
            .help("点一下，再按下新的全局热键。Esc 取消。")
        }
        .onReceive(NotificationCenter.default.publisher(for: .hotKeyDidChange)) { _ in
            label = HotKeyCenter.shared.displayName
        }
        .onDisappear(perform: stopListening)
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
