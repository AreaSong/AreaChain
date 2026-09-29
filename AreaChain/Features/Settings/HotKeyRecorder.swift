import AppKit
import SwiftUI

struct ShortcutRecorder: View {
    var action: ShortcutAction
    @Bindable var store: ShortcutStore

    @Environment(\.locale) private var locale
    @State private var listening = false
    @State private var monitor: Any?

    var body: some View {
        let binding = store.binding(for: action)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(action.titleKey))
                    Text(LocalizedStringKey(action.helpKey))
                        .font(DaybookType.subtitle)
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if binding.chord != action.defaultChord || !binding.isArmed {
                    Button("shortcut.reset") { store.reset(action) }
                }
                Button {
                    startListening()
                } label: {
                    if listening {
                        Text("hotkey.listen")
                    } else {
                        Text(verbatim: label(for: binding))
                    }
                }
                .help(LocalizedStringKey(action.helpKey))
                .accessibilityIdentifier("shortcut.record.\(action.rawValue)")
            }
            if !binding.isArmed {
                Text("hotkey.registration.failed")
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onDisappear(perform: stopListening)
    }

    private func label(for binding: ShortcutBinding) -> String {
        let name = binding.chord.displayName(locale: locale)
        return binding.isArmed ? name : L10n.format("hotkey.paste.disabled", locale: locale, name)
    }

    private func startListening() {
        guard !listening else { return }
        listening = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(ShortcutKey.escape) {
                stopListening()
                return nil
            }
            if let chord = ShortcutChord.captured(from: event) {
                store.assign(chord, to: action)
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
