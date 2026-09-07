import AppKit
import Carbon

final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func start() {
        guard hotKeyRef == nil else { return }
        var hotKeyID = EventHotKeyID(signature: fourChar("ACHK"), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_A),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .openBoardWindow, object: nil)
                    NotificationCenter.default.post(name: .focusCapture, object: nil)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &handlerRef
        )
    }

    private func fourChar(_ text: String) -> OSType {
        var result: OSType = 0
        for scalar in text.unicodeScalars.prefix(4) {
            result = (result << 8) + OSType(scalar.value)
        }
        return result
    }
}
