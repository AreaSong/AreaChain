import SwiftUI

extension ShortcutChord {
    var keyEquivalent: KeyEquivalent? {
        switch keyCode {
        case ShortcutKey.returnKey: return .return
        case ShortcutKey.delete: return .delete
        case ShortcutKey.space: return .space
        case ShortcutKey.tab: return .tab
        default:
            guard let symbol = ShortcutKey.symbol(for: keyCode), symbol.count == 1, let first = symbol.first else {
                return nil
            }
            return KeyEquivalent(Character(String(first).lowercased()))
        }
    }

    var eventModifiers: EventModifiers {
        var modifiers: EventModifiers = []
        if self.modifiers & ShortcutModifier.command != 0 { modifiers.insert(.command) }
        if self.modifiers & ShortcutModifier.shift != 0 { modifiers.insert(.shift) }
        if self.modifiers & ShortcutModifier.option != 0 { modifiers.insert(.option) }
        if self.modifiers & ShortcutModifier.control != 0 { modifiers.insert(.control) }
        return modifiers
    }
}

extension ShortcutStore {
    func keyboardShortcut(for action: ShortcutAction) -> KeyboardShortcut? {
        let binding = binding(for: action)
        guard binding.isArmed, binding.chord.isBindable, let key = binding.chord.keyEquivalent else { return nil }
        return KeyboardShortcut(key, modifiers: binding.chord.eventModifiers)
    }
}

private struct AppShortcutModifier: ViewModifier {
    var action: ShortcutAction
    var isEnabled: Bool
    @Bindable private var shortcuts = ShortcutStore.shared

    func body(content: Content) -> some View {
        content.keyboardShortcut(isEnabled ? shortcuts.keyboardShortcut(for: action) : nil)
    }
}

extension View {
    func appShortcut(_ action: ShortcutAction, enabled: Bool = true) -> some View {
        modifier(AppShortcutModifier(action: action, isEnabled: enabled))
    }
}
