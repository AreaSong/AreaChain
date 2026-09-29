import Foundation

/// 全部可重设快捷键的唯一状态。全局热键交给 `HotKeyCenter` 注册，应用内组合由界面读取同一份绑定。
@MainActor
@Observable
final class ShortcutStore {
    static let shared = ShortcutStore()

    private let defaults: UserDefaults
    private let center: HotKeyCenter
    private(set) var bindings: [ShortcutAction: ShortcutBinding]

    init(defaults: UserDefaults = .standard, center: HotKeyCenter? = nil) {
        self.defaults = defaults
        self.center = center ?? .shared
        bindings = ShortcutCatalog.resolve(stored: [:])
    }

    func binding(for action: ShortcutAction) -> ShortcutBinding {
        bindings[action] ?? ShortcutBinding(chord: action.defaultChord, isArmed: true)
    }

    /// 停用时返回一个不会命中的组合，避免输入框继续响应旧的 ⌘Return。
    func armedChord(for action: ShortcutAction) -> ShortcutChord {
        let binding = binding(for: action)
        return binding.isArmed ? binding.chord : .unmatched
    }

    func start() {
        bindings = ShortcutCatalog.resolve(stored: loadStored())
        syncGlobals()
        NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
    }

    func assign(_ chord: ShortcutChord, to action: ShortcutAction) {
        guard chord.isBindable else { return }
        var stored = chords
        stored[action] = chord
        bindings = ShortcutCatalog.resolve(stored: stored, preferred: action)
        persistAll()
        syncGlobals()
        NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
    }

    func reset(_ action: ShortcutAction) {
        var stored = chords
        stored[action] = action.defaultChord
        bindings = ShortcutCatalog.resolve(stored: stored, preferred: action)
        persistAll()
        syncGlobals()
        NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
    }

    func resetAll() {
        bindings = ShortcutCatalog.resolve(stored: [:])
        persistAll()
        syncGlobals()
        NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
    }

    private var chords: [ShortcutAction: ShortcutChord] {
        Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { ($0, binding(for: $0).chord) })
    }

    private func syncGlobals() {
        let toggle = binding(for: .toggleOverlay)
        let paste = binding(for: .pasteToday)
        let workspace = binding(for: .openWorkspaceHotKey)
        let history = binding(for: .clipboardHistory)
        center.applyResolved(
            toggle: toggle.chord,
            armToggle: toggle.isArmed && toggle.chord.isBindable,
            paste: paste.chord,
            armPaste: paste.isArmed && paste.chord.isBindable,
            workspace: workspace.chord,
            armWorkspace: workspace.isArmed && workspace.chord.isBindable,
            history: history.chord,
            armHistory: history.isArmed && history.chord.isBindable
        )
        var next = bindings
        if var toggleBinding = next[.toggleOverlay] {
            toggleBinding.isArmed = center.toggleIsArmed
            next[.toggleOverlay] = toggleBinding
        }
        if var pasteBinding = next[.pasteToday] {
            pasteBinding.isArmed = center.pasteIsArmed
            next[.pasteToday] = pasteBinding
        }
        if var workspaceBinding = next[.openWorkspaceHotKey] {
            workspaceBinding.isArmed = center.workspaceIsArmed
            next[.openWorkspaceHotKey] = workspaceBinding
        }
        if var historyBinding = next[.clipboardHistory] {
            historyBinding.isArmed = center.historyIsArmed
            next[.clipboardHistory] = historyBinding
        }
        bindings = next
    }

    private func loadStored() -> [ShortcutAction: ShortcutChord] {
        var stored: [ShortcutAction: ShortcutChord] = [:]
        for action in ShortcutAction.allCases {
            let keyCodeKey = keyCodeDefaultsKey(action)
            guard defaults.object(forKey: keyCodeKey) != nil else { continue }
            stored[action] = ShortcutChord(
                keyCode: UInt32(bitPattern: Int32(truncatingIfNeeded: defaults.integer(forKey: keyCodeKey))),
                modifiers: UInt32(bitPattern: Int32(truncatingIfNeeded: defaults.integer(forKey: modifiersDefaultsKey(action))))
            )
        }
        return stored
    }

    private func persistAll() {
        for action in ShortcutAction.allCases {
            let chord = binding(for: action).chord
            let keyCodeKey = keyCodeDefaultsKey(action)
            let modifiersKey = modifiersDefaultsKey(action)
            if chord.isUnset {
                defaults.removeObject(forKey: keyCodeKey)
                defaults.removeObject(forKey: modifiersKey)
            } else {
                defaults.set(Int(chord.keyCode), forKey: keyCodeKey)
                defaults.set(Int(chord.modifiers), forKey: modifiersKey)
            }
        }
    }

    private func keyCodeDefaultsKey(_ action: ShortcutAction) -> String {
        switch action {
        case .toggleOverlay: return ShortcutChord.keyCodeDefaultsKey
        case .pasteToday: return ShortcutChord.pasteKeyCodeDefaultsKey
        case .openWorkspaceHotKey: return ShortcutChord.workspaceKeyCodeDefaultsKey
        default: return "areachain.shortcut.\(action.rawValue).keyCode"
        }
    }

    private func modifiersDefaultsKey(_ action: ShortcutAction) -> String {
        switch action {
        case .toggleOverlay: return ShortcutChord.modifiersDefaultsKey
        case .pasteToday: return ShortcutChord.pasteModifiersDefaultsKey
        case .openWorkspaceHotKey: return ShortcutChord.workspaceModifiersDefaultsKey
        default: return "areachain.shortcut.\(action.rawValue).modifiers"
        }
    }
}
