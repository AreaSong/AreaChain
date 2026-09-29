import Foundation

/// Carbon 虚拟键码与修饰位。数值必须与系统热键注册使用的常量一致，旧的浮层热键才能继续读出来。
enum ShortcutModifier {
    static let command: UInt32 = 1 << 8
    static let shift: UInt32 = 1 << 9
    static let option: UInt32 = 1 << 11
    static let control: UInt32 = 1 << 12
    static let required: UInt32 = command | option | control

    static func mask(command: Bool, shift: Bool, option: Bool, control: Bool) -> UInt32 {
        var mask: UInt32 = 0
        if command { mask |= self.command }
        if shift { mask |= self.shift }
        if option { mask |= self.option }
        if control { mask |= self.control }
        return mask
    }
}

enum ShortcutKey {
    static let a: UInt32 = 0x00
    static let s: UInt32 = 0x01
    static let c: UInt32 = 0x08
    static let f: UInt32 = 0x03
    static let o: UInt32 = 0x1F
    static let q: UInt32 = 0x0C
    static let v: UInt32 = 0x09
    static let zero: UInt32 = 0x1D
    static let returnKey: UInt32 = 0x24
    static let tab: UInt32 = 0x30
    static let space: UInt32 = 0x31
    static let delete: UInt32 = 0x33
    static let escape: UInt32 = 0x35
    static let comma: UInt32 = 0x2B
    static let slash: UInt32 = 0x2C

    static func isRecognized(_ keyCode: UInt32) -> Bool {
        symbol(for: keyCode) != nil || keyCode == returnKey || keyCode == space || keyCode == tab
    }

    static func symbol(for keyCode: UInt32) -> String? {
        symbols[keyCode]
    }

    private static let symbols: [UInt32: String] = [
        0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E", 0x03: "F",
        0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J", 0x28: "K", 0x25: "L",
        0x2E: "M", 0x2D: "N", 0x1F: "O", 0x23: "P", 0x0C: "Q", 0x0F: "R",
        0x01: "S", 0x11: "T", 0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X",
        0x10: "Y", 0x06: "Z",
        0x1D: "0", 0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4",
        0x17: "5", 0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9",
        0x2B: ",", 0x2C: "/", 0x33: "⌫"
    ]
}

struct ShortcutChord: Equatable, Hashable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32

    /// 不会出现在真实按键里，用来表示这项快捷键当前不响应。
    static let unmatched = ShortcutChord(keyCode: .max, modifiers: ShortcutModifier.command)

    var isUsable: Bool {
        keyCode != ShortcutKey.escape && (modifiers & ShortcutModifier.required) != 0
    }

    /// 能在菜单快捷键和清单监听里同时生效的组合。不认识的功能键只显示编号，不能拿来重设。
    var isBindable: Bool {
        isUsable && ShortcutKey.isRecognized(keyCode)
    }

    func matches(keyCode: UInt16, command: Bool, shift: Bool, option: Bool, control: Bool) -> Bool {
        self.keyCode == UInt32(keyCode)
            && modifiers == ShortcutModifier.mask(command: command, shift: shift, option: option, control: control)
    }
}

struct ShortcutBinding: Equatable, Sendable {
    var chord: ShortcutChord
    var isArmed: Bool
}

enum ShortcutGroup: CaseIterable, Sendable {
    case global
    case navigation
    case diary
    case list

    var titleKey: String {
        switch self {
        case .global: return "shortcut.group.global"
        case .navigation: return "shortcut.group.navigation"
        case .diary: return "shortcut.group.diary"
        case .list: return "shortcut.group.list"
        }
    }

    var actions: [ShortcutAction] {
        ShortcutAction.allCases.filter { $0.group == self }
    }
}

enum ShortcutAction: String, CaseIterable, Identifiable, Sendable {
    case toggleOverlay
    case pasteToday
    case search
    case openFilter
    case openWorkspace
    case syntaxHelp
    case openSettings
    case quit
    case commitDiary
    case saveDiary
    case openDiary
    case copyDiary
    case selectAll
    case trashDiary

    var id: String { rawValue }

    var group: ShortcutGroup {
        switch self {
        case .toggleOverlay, .pasteToday: return .global
        case .search, .openFilter, .openWorkspace, .syntaxHelp, .openSettings, .quit: return .navigation
        case .commitDiary, .saveDiary, .openDiary, .copyDiary, .trashDiary: return .diary
        case .selectAll: return .list
        }
    }

    var titleKey: String {
        switch self {
        case .toggleOverlay: return "hotkey.open"
        case .pasteToday: return "hotkey.paste"
        case .search: return "shortcut.search"
        case .openFilter: return "shortcut.filter"
        case .openWorkspace: return "shortcut.workspace"
        case .syntaxHelp: return "shortcut.syntax"
        case .openSettings: return "shortcut.settings"
        case .quit: return "shortcut.quit"
        case .commitDiary: return "shortcut.commitDiary"
        case .saveDiary: return "shortcut.saveDiary"
        case .openDiary: return "shortcut.openDiary"
        case .copyDiary: return "shortcut.copyDiary"
        case .selectAll: return "shortcut.selectAll"
        case .trashDiary: return "shortcut.trashDiary"
        }
    }

    var helpKey: String {
        switch self {
        case .toggleOverlay: return "hotkey.help"
        case .pasteToday: return "hotkey.paste.help"
        case .search: return "shortcut.search.help"
        case .openFilter: return "shortcut.filter.help"
        case .openWorkspace: return "shortcut.workspace.help"
        case .syntaxHelp: return "shortcut.syntax.help"
        case .openSettings: return "shortcut.settings.help"
        case .quit: return "shortcut.quit.help"
        case .commitDiary: return "shortcut.commitDiary.help"
        case .saveDiary: return "shortcut.saveDiary.help"
        case .openDiary: return "shortcut.openDiary.help"
        case .copyDiary: return "shortcut.copyDiary.help"
        case .selectAll: return "shortcut.selectAll.help"
        case .trashDiary: return "shortcut.trashDiary.help"
        }
    }

    var defaultChord: ShortcutChord {
        switch self {
        case .toggleOverlay:
            return ShortcutChord(keyCode: ShortcutKey.a, modifiers: ShortcutModifier.command | ShortcutModifier.shift)
        case .pasteToday:
            return ShortcutChord(keyCode: ShortcutKey.v, modifiers: ShortcutModifier.command | ShortcutModifier.shift)
        case .search:
            return ShortcutChord(keyCode: ShortcutKey.f, modifiers: ShortcutModifier.command)
        case .openFilter:
            return ShortcutChord(keyCode: ShortcutKey.f, modifiers: ShortcutModifier.command | ShortcutModifier.shift)
        case .openWorkspace:
            return ShortcutChord(keyCode: ShortcutKey.zero, modifiers: ShortcutModifier.command)
        case .syntaxHelp:
            return ShortcutChord(keyCode: ShortcutKey.slash, modifiers: ShortcutModifier.command)
        case .openSettings:
            return ShortcutChord(keyCode: ShortcutKey.comma, modifiers: ShortcutModifier.command)
        case .quit:
            return ShortcutChord(keyCode: ShortcutKey.q, modifiers: ShortcutModifier.command)
        case .commitDiary:
            return ShortcutChord(keyCode: ShortcutKey.returnKey, modifiers: ShortcutModifier.command)
        case .saveDiary:
            return ShortcutChord(keyCode: ShortcutKey.s, modifiers: ShortcutModifier.command)
        case .openDiary:
            return ShortcutChord(keyCode: ShortcutKey.o, modifiers: ShortcutModifier.command)
        case .copyDiary:
            return ShortcutChord(keyCode: ShortcutKey.c, modifiers: ShortcutModifier.command)
        case .selectAll:
            return ShortcutChord(keyCode: ShortcutKey.a, modifiers: ShortcutModifier.command)
        case .trashDiary:
            return ShortcutChord(keyCode: ShortcutKey.delete, modifiers: ShortcutModifier.command)
        }
    }

    /// 浮层和剪贴板沿用原来的 UserDefaults 键，已经改过的组合不会丢。
    var usesLegacyHotKeyDefaults: Bool {
        self == .toggleOverlay || self == .pasteToday
    }
}

enum ShortcutCatalog {
    /// 没有“刚录下的那一项”时按目录顺序占住组合：打开浮层优先于剪贴板，和旧的停用规则一致。
    /// 用户刚录下的一项放在最前，它留下，原先占用同一组合的那一项停用。
    static func resolve(
        stored: [ShortcutAction: ShortcutChord],
        preferred: ShortcutAction? = nil
    ) -> [ShortcutAction: ShortcutBinding] {
        var chords: [ShortcutAction: ShortcutChord] = [:]
        for action in ShortcutAction.allCases {
            let candidate = stored[action] ?? action.defaultChord
            chords[action] = candidate.isBindable ? candidate : action.defaultChord
        }
        var order = Array(ShortcutAction.allCases)
        if let preferred, let index = order.firstIndex(of: preferred) {
            order.remove(at: index)
            order.insert(preferred, at: 0)
        }
        var claimed = Set<ShortcutChord>()
        var armed: [ShortcutAction: Bool] = [:]
        for action in order {
            let chord = chords[action] ?? action.defaultChord
            armed[action] = claimed.insert(chord).inserted
        }
        return Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { action in
            (action, ShortcutBinding(chord: chords[action] ?? action.defaultChord, isArmed: armed[action] ?? false))
        })
    }
}
