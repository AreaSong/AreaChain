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

    static let pasteFallback = HotKeySpec(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    static let keyCodeDefaultsKey = "areachain.hotkey.keyCode"
    static let modifiersDefaultsKey = "areachain.hotkey.modifiers"
    static let pasteKeyCodeDefaultsKey = "areachain.hotkey.paste.keyCode"
    static let pasteModifiersDefaultsKey = "areachain.hotkey.paste.modifiers"

    var isUsable: Bool {
        keyCode != UInt32(kVK_Escape) && (modifiers & UInt32(cmdKey | optionKey | controlKey)) != 0
    }

    var displayName: String { displayName(locale: .current) }

    func displayName(locale: Locale = .current) -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        parts.append(Self.glyph(for: keyCode, locale: locale))
        return parts.joined()
    }

    static func load(from defaults: UserDefaults = .standard) -> HotKeySpec {
        load(
            from: defaults,
            keyCodeKey: keyCodeDefaultsKey,
            modifiersKey: modifiersDefaultsKey,
            fallback: .fallback
        )
    }

    static func loadPaste(from defaults: UserDefaults = .standard) -> HotKeySpec {
        load(
            from: defaults,
            keyCodeKey: pasteKeyCodeDefaultsKey,
            modifiersKey: pasteModifiersDefaultsKey,
            fallback: .pasteFallback
        )
    }

    func save(to defaults: UserDefaults = .standard) {
        save(to: defaults, keyCodeKey: Self.keyCodeDefaultsKey, modifiersKey: Self.modifiersDefaultsKey)
    }

    func savePaste(to defaults: UserDefaults = .standard) {
        save(to: defaults, keyCodeKey: Self.pasteKeyCodeDefaultsKey, modifiersKey: Self.pasteModifiersDefaultsKey)
    }

    private static func load(
        from defaults: UserDefaults,
        keyCodeKey: String,
        modifiersKey: String,
        fallback: HotKeySpec
    ) -> HotKeySpec {
        guard defaults.object(forKey: keyCodeKey) != nil else { return fallback }
        let spec = HotKeySpec(
            keyCode: UInt32(bitPattern: Int32(truncatingIfNeeded: defaults.integer(forKey: keyCodeKey))),
            modifiers: UInt32(bitPattern: Int32(truncatingIfNeeded: defaults.integer(forKey: modifiersKey)))
        )
        return spec.isUsable ? spec : fallback
    }

    private func save(to defaults: UserDefaults, keyCodeKey: String, modifiersKey: String) {
        defaults.set(Int(keyCode), forKey: keyCodeKey)
        defaults.set(Int(modifiers), forKey: modifiersKey)
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

    static func glyph(for keyCode: UInt32, locale: Locale = .current) -> String {
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
            UInt32(kVK_Space): L10n.string("hotkey.space", locale: locale),
            UInt32(kVK_Return): L10n.string("hotkey.return", locale: locale),
            UInt32(kVK_Tab): L10n.string("hotkey.tab", locale: locale)
        ]
        if let glyph = letters[keyCode] { return glyph }
        return L10n.string("hotkey.unknown \(Int(keyCode))", locale: locale)
    }
}

struct HotKeyRegistration {
    var register: (HotKeySpec, UInt32) -> Bool
    var unregister: (UInt32) -> Void
}

final class HotKeyCenter {
    static let shared = HotKeyCenter()
    static let toggleID: UInt32 = 1
    static let pasteID: UInt32 = 2

    private(set) var spec: HotKeySpec = .fallback
    private(set) var pasteSpec: HotKeySpec = .pasteFallback
    private(set) var pasteIsArmed = false
    private(set) var toggleIsArmed = false
    private var toggleRef: EventHotKeyRef?
    private var pasteRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var handlerInstalled = false
    private var armedIDs: Set<UInt32> = []
    private let defaults: UserDefaults
    private let registration: HotKeyRegistration?

    init(defaults: UserDefaults = .standard, registration: HotKeyRegistration? = nil) {
        self.defaults = defaults
        self.registration = registration
    }

    var displayName: String { spec.displayName() }

    func displayName(locale: Locale = .current) -> String {
        spec.displayName(locale: locale)
    }

    func pasteDisplayName(locale: Locale = .current) -> String {
        pasteSpec.displayName(locale: locale)
    }

    func start() {
        guard !handlerInstalled else { return }
        apply(HotKeySpec.load(from: defaults), persist: false)
        applyPaste(HotKeySpec.loadPaste(from: defaults), persist: false)
    }

    @discardableResult
    func apply(_ next: HotKeySpec, persist: Bool = true) -> HotKeySpec {
        installHandlerIfNeeded()
        let resolved = next.isUsable ? next : .fallback
        if resolved == pasteSpec {
            unregister(id: Self.pasteID, ref: &pasteRef)
            pasteIsArmed = false
        }
        unregister(id: Self.toggleID, ref: &toggleRef)
        if register(resolved, id: Self.toggleID, ref: &toggleRef) {
            spec = resolved
        } else if resolved != .fallback, register(.fallback, id: Self.toggleID, ref: &toggleRef) {
            spec = .fallback
        } else {
            spec = resolved
        }
        if persist {
            spec.save(to: defaults)
        }
        toggleIsArmed = armedIDs.contains(Self.toggleID)
        armPasteIfCompatible()
        NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
        return spec
    }

    @discardableResult
    func applyPaste(_ next: HotKeySpec, persist: Bool = true) -> HotKeySpec {
        installHandlerIfNeeded()
        let resolved = next.isUsable ? next : .pasteFallback
        if resolved == spec {
            unregister(id: Self.pasteID, ref: &pasteRef)
            pasteSpec = resolved
            pasteIsArmed = false
            if persist { pasteSpec.savePaste(to: defaults) }
            NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
            return pasteSpec
        }
        unregister(id: Self.pasteID, ref: &pasteRef)
        if register(resolved, id: Self.pasteID, ref: &pasteRef) {
            pasteSpec = resolved
        } else if resolved != .pasteFallback, resolved != spec,
                  register(.pasteFallback, id: Self.pasteID, ref: &pasteRef) {
            pasteSpec = .pasteFallback
        } else {
            pasteSpec = resolved
        }
        if persist {
            pasteSpec.savePaste(to: defaults)
        }
        pasteIsArmed = armedIDs.contains(Self.pasteID)
        NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
        return pasteSpec
    }

    private func armPasteIfCompatible() {
        if pasteSpec == spec {
            unregister(id: Self.pasteID, ref: &pasteRef)
            pasteIsArmed = false
            return
        }
        pasteIsArmed = register(pasteSpec, id: Self.pasteID, ref: &pasteRef)
    }

    private func register(_ spec: HotKeySpec, id: UInt32, ref: inout EventHotKeyRef?) -> Bool {
        unregister(id: id, ref: &ref)
        guard handlerInstalled else { return false }
        if let registration {
            let registered = registration.register(spec, id)
            if registered { armedIDs.insert(id) }
            return registered
        }
        let hotKeyID = EventHotKeyID(signature: fourChar("ACHK"), id: id)
        let status = RegisterEventHotKey(
            spec.keyCode,
            spec.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr { armedIDs.insert(id) }
        return status == noErr
    }

    private func unregister(id: UInt32, ref: inout EventHotKeyRef?) {
        registration?.unregister(id)
        armedIDs.remove(id)
        if let hotKey = ref {
            UnregisterEventHotKey(hotKey)
            ref = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        if registration != nil { handlerInstalled = true; return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                var hotKeyID = EventHotKeyID()
                if let event {
                    GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotKeyID
                    )
                }
                let id = hotKeyID.id
                DispatchQueue.main.async {
                    HotKeyCenter.shared.dispatchHotKey(id)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &handlerRef
        )
        handlerInstalled = status == noErr
    }

    func dispatchHotKey(_ id: UInt32) {
        if id == Self.pasteID, pasteIsArmed {
            NotificationCenter.default.post(name: .pasteClipboardCapture, object: nil)
        } else if id == Self.toggleID, toggleIsArmed {
            NotificationCenter.default.post(name: .toggleBoardPopover, object: nil)
        }
    }

    private func fourChar(_ text: String) -> OSType {
        var result: OSType = 0
        for scalar in text.unicodeScalars.prefix(4) {
            result = (result << 8) + OSType(scalar.value)
        }
        return result
    }
}
