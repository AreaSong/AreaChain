import AppKit
import Carbon
import Foundation

struct HotKeySpec: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let fallback = HotKeySpec(
        keyCode: UInt32(kVK_ANSI_A),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    static let keyCodeDefaultsKey = "areachain.hotkey.keyCode"
    static let modifiersDefaultsKey = "areachain.hotkey.modifiers"

    var isUsable: Bool {
        keyCode != UInt32(kVK_Escape) && (modifiers & UInt32(cmdKey | optionKey | controlKey)) != 0
    }

    var displayName: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        parts.append(Self.glyph(for: keyCode))
        return parts.joined()
    }

    static func load(from defaults: UserDefaults = .standard) -> HotKeySpec {
        guard defaults.object(forKey: keyCodeDefaultsKey) != nil else { return fallback }
        let spec = HotKeySpec(
            keyCode: UInt32(bitPattern: Int32(truncatingIfNeeded: defaults.integer(forKey: keyCodeDefaultsKey))),
            modifiers: UInt32(bitPattern: Int32(truncatingIfNeeded: defaults.integer(forKey: modifiersDefaultsKey)))
        )
        return spec.isUsable ? spec : fallback
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(Int(keyCode), forKey: Self.keyCodeDefaultsKey)
        defaults.set(Int(modifiers), forKey: Self.modifiersDefaultsKey)
    }

    static func parse(event: NSEvent) -> HotKeySpec? {
        if event.keyCode == UInt16(kVK_Escape) { return nil }
        var modifiers: UInt32 = 0
        if event.modifierFlags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.option) { modifiers |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { modifiers |= UInt32(controlKey) }
        let spec = HotKeySpec(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        return spec.isUsable ? spec : nil
    }

    static func glyph(for keyCode: UInt32) -> String {
        let letters: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
            UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
            UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
            UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
            UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
            UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
            UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
            UInt32(kVK_ANSI_9): "9",
            UInt32(kVK_Space): "空格",
            UInt32(kVK_Return): "回车",
            UInt32(kVK_Tab): "Tab"
        ]
        return letters[keyCode] ?? "键\(keyCode)"
    }
}

final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private(set) var spec: HotKeySpec = .fallback
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    var displayName: String { spec.displayName }

    func start() {
        guard hotKeyRef == nil else { return }
        apply(HotKeySpec.load(), persist: false)
    }

    @discardableResult
    func apply(_ next: HotKeySpec, persist: Bool = true) -> HotKeySpec {
        let resolved = next.isUsable ? next : .fallback
        unregisterKey()
        installHandlerIfNeeded()
        if register(resolved) {
            spec = resolved
        } else if resolved != .fallback, register(.fallback) {
            spec = .fallback
        } else {
            spec = resolved
        }
        if persist {
            spec.save()
        }
        NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
        return spec
    }

    private func register(_ spec: HotKeySpec) -> Bool {
        var hotKeyID = EventHotKeyID(signature: fourChar("ACHK"), id: 1)
        let status = RegisterEventHotKey(
            spec.keyCode,
            spec.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        return status == noErr
    }

    private func unregisterKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .toggleBoardPopover, object: nil)
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
