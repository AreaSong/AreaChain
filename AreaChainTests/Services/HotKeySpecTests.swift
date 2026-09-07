import Carbon
import Foundation
import Testing
@testable import AreaChain

struct HotKeySpecTests {
    @Test func fallbackDisplaysCommandShiftA() {
        #expect(HotKeySpec.fallback.displayName == "⌘⇧A")
        #expect(HotKeySpec.fallback.isUsable)
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
}
