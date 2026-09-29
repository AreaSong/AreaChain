import AppKit
import Foundation

typealias HotKeySpec = ShortcutChord

extension ShortcutChord {
    /// 旧的 `HotKeyCenter.load` 在缺键或非法值时仍回到这两个历史组合。
    /// 产品里的全局热键默认是未设置，由 `ShortcutStore` 决定，不从这里取。
    static let fallback = ShortcutChord(
        keyCode: ShortcutKey.a,
        modifiers: ShortcutModifier.command | ShortcutModifier.shift
    )
    static let pasteFallback = ShortcutChord(
        keyCode: ShortcutKey.v,
        modifiers: ShortcutModifier.command | ShortcutModifier.shift
    )
    static let workspaceKeyCodeDefaultsKey = "areachain.hotkey.workspace.keyCode"
    static let workspaceModifiersDefaultsKey = "areachain.hotkey.workspace.modifiers"

    static let keyCodeDefaultsKey = "areachain.hotkey.keyCode"
    static let modifiersDefaultsKey = "areachain.hotkey.modifiers"
    static let pasteKeyCodeDefaultsKey = "areachain.hotkey.paste.keyCode"
    static let pasteModifiersDefaultsKey = "areachain.hotkey.paste.modifiers"

    var displayName: String { displayName(locale: .current) }

    func displayName(locale: Locale = .current) -> String {
        var parts: [String] = []
        if modifiers & ShortcutModifier.control != 0 { parts.append("⌃") }
        if modifiers & ShortcutModifier.option != 0 { parts.append("⌥") }
        if modifiers & ShortcutModifier.command != 0 { parts.append("⌘") }
        if modifiers & ShortcutModifier.shift != 0 { parts.append("⇧") }
        parts.append(Self.glyph(for: keyCode, locale: locale))
        return parts.joined()
    }

    static func load(from defaults: UserDefaults = .standard) -> ShortcutChord {
        load(
            from: defaults,
            keyCodeKey: keyCodeDefaultsKey,
            modifiersKey: modifiersDefaultsKey,
            fallback: .fallback
        )
    }

    static func loadPaste(from defaults: UserDefaults = .standard) -> ShortcutChord {
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

    static func parse(event: NSEvent) -> ShortcutChord? {
        let chord = captured(from: event)
        return chord?.isUsable == true ? chord : nil
    }

    static func captured(from event: NSEvent) -> ShortcutChord? {
        if event.keyCode == UInt16(ShortcutKey.escape) { return nil }
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let chord = ShortcutChord(
            keyCode: UInt32(event.keyCode),
            modifiers: ShortcutModifier.mask(
                command: flags.contains(.command),
                shift: flags.contains(.shift),
                option: flags.contains(.option),
                control: flags.contains(.control)
            )
        )
        return chord.isBindable ? chord : nil
    }

    func matches(_ event: NSEvent) -> Bool {
        guard !isUnset else { return false }
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        return matches(
            keyCode: event.keyCode,
            command: flags.contains(.command),
            shift: flags.contains(.shift),
            option: flags.contains(.option),
            control: flags.contains(.control)
        )
    }

    static func glyph(for keyCode: UInt32, locale: Locale = .current) -> String {
        if let symbol = ShortcutKey.symbol(for: keyCode) { return symbol }
        switch keyCode {
        case ShortcutKey.space: return L10n.string("hotkey.space", locale: locale)
        case ShortcutKey.returnKey: return L10n.string("hotkey.return", locale: locale)
        case ShortcutKey.tab: return L10n.string("hotkey.tab", locale: locale)
        default: return L10n.string("hotkey.unknown \(Int(keyCode))", locale: locale)
        }
    }

    private static func load(
        from defaults: UserDefaults,
        keyCodeKey: String,
        modifiersKey: String,
        fallback: ShortcutChord
    ) -> ShortcutChord {
        guard defaults.object(forKey: keyCodeKey) != nil else { return fallback }
        let spec = ShortcutChord(
            keyCode: UInt32(bitPattern: Int32(truncatingIfNeeded: defaults.integer(forKey: keyCodeKey))),
            modifiers: UInt32(bitPattern: Int32(truncatingIfNeeded: defaults.integer(forKey: modifiersKey)))
        )
        return spec.isUsable ? spec : fallback
    }

    private func save(to defaults: UserDefaults, keyCodeKey: String, modifiersKey: String) {
        defaults.set(Int(keyCode), forKey: keyCodeKey)
        defaults.set(Int(modifiers), forKey: modifiersKey)
    }
}

extension ShortcutBinding {
    func matches(_ event: NSEvent) -> Bool {
        isArmed && chord.matches(event)
    }
}

enum ShortcutChordMatching {
    static func accepts(_ event: NSEvent, chord: ShortcutChord?) -> Bool {
        if let chord { return chord.matches(event) }
        return isLegacyCommandReturn(event)
    }

    static func isLegacyCommandReturn(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        return flags == .command
            && (event.keyCode == UInt16(ShortcutKey.returnKey)
                || event.charactersIgnoringModifiers == "\r"
                || event.charactersIgnoringModifiers == "\n")
    }
}
