import Carbon
import Foundation
import Testing
@testable import AreaChain

struct HotKeySpecTests {
    @Test func fallbackDisplaysCommandShiftA() {
        #expect(HotKeySpec.fallback.displayName == "⌘⇧A")
        #expect(HotKeySpec.fallback.isUsable)
        #expect(HotKeySpec.pasteFallback.displayName == "⌘⇧V")
        #expect(HotKeySpec.pasteFallback.isUsable)
        #expect(HotKeySpec.fallback != HotKeySpec.pasteFallback)
    }

    @Test func loadMissingDefaultsUsesFallback() {
        let defaults = UserDefaults(suiteName: "areachain.hotkey.tests.missing")!
        defaults.removePersistentDomain(forName: "areachain.hotkey.tests.missing")
        #expect(HotKeySpec.load(from: defaults) == .fallback)
    }

    @Test func loadRejectsShiftOnlyAndReturnsFallback() {
        let name = "areachain.hotkey.tests.shift"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaults.set(Int(kVK_ANSI_A), forKey: HotKeySpec.keyCodeDefaultsKey)
        defaults.set(Int(shiftKey), forKey: HotKeySpec.modifiersDefaultsKey)
        #expect(HotKeySpec.load(from: defaults) == .fallback)
    }

    @Test func loadKeepsCommandOptionCombo() {
        let name = "areachain.hotkey.tests.keep"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let spec = HotKeySpec(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | optionKey))
        spec.save(to: defaults)
        #expect(HotKeySpec.load(from: defaults) == spec)
        #expect(spec.displayName == "⌥⌘K")
    }

    @Test func tabGlyphIsLocalizedKey() {
        #expect(HotKeySpec.glyph(for: UInt32(kVK_Tab), locale: Locale(identifier: "en")) == "Tab")
    }

    @Test func loadPasteMissingDefaultsUsesPasteFallback() {
        let name = "areachain.hotkey.tests.paste.missing"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        #expect(HotKeySpec.loadPaste(from: defaults) == .pasteFallback)
    }

    @Test func savePasteRoundTrip() {
        let name = "areachain.hotkey.tests.paste.keep"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let spec = HotKeySpec(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(cmdKey | optionKey))
        spec.savePaste(to: defaults)
        #expect(HotKeySpec.loadPaste(from: defaults) == spec)
    }
}
