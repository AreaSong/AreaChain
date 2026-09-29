import AppKit
import Carbon
import Foundation

struct HotKeyRegistration {
    var register: (HotKeySpec, UInt32) -> Bool
    var unregister: (UInt32) -> Void
}

final class HotKeyCenter {
    static let shared = HotKeyCenter()
    static let toggleID: UInt32 = 1
    static let pasteID: UInt32 = 2
    static let workspaceID: UInt32 = 3
    static let historyID: UInt32 = 4

    private(set) var spec: HotKeySpec = .fallback
    private(set) var pasteSpec: HotKeySpec = .pasteFallback
    private(set) var workspaceSpec: HotKeySpec = .unset
    private(set) var historySpec: HotKeySpec = .unset
    private(set) var pasteIsArmed = false
    private(set) var toggleIsArmed = false
    private(set) var workspaceIsArmed = false
    private(set) var historyIsArmed = false
    private var toggleRef: EventHotKeyRef?
    private var pasteRef: EventHotKeyRef?
    private var workspaceRef: EventHotKeyRef?
    private var historyRef: EventHotKeyRef?
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

    /// 快捷键页已经决定哪一项生效。这里只按给定状态注册或卸下，不再互相覆盖。
    func applyResolved(
        toggle: ShortcutChord,
        armToggle: Bool,
        paste: ShortcutChord,
        armPaste: Bool,
        workspace: ShortcutChord,
        armWorkspace: Bool,
        history: ShortcutChord = .unset,
        armHistory: Bool = false
    ) {
        installHandlerIfNeeded()
        spec = toggle
        pasteSpec = paste
        workspaceSpec = workspace
        historySpec = history
        unregister(id: Self.toggleID, ref: &toggleRef)
        unregister(id: Self.pasteID, ref: &pasteRef)
        unregister(id: Self.workspaceID, ref: &workspaceRef)
        unregister(id: Self.historyID, ref: &historyRef)
        if armToggle, toggle.isBindable {
            _ = register(toggle, id: Self.toggleID, ref: &toggleRef)
        }
        if armPaste, paste.isBindable, !(armToggle && paste == toggle) {
            _ = register(paste, id: Self.pasteID, ref: &pasteRef)
        }
        if armWorkspace, workspace.isBindable,
           !(armToggle && workspace == toggle),
           !(armPaste && workspace == paste) {
            _ = register(workspace, id: Self.workspaceID, ref: &workspaceRef)
        }
        if armHistory, history.isBindable,
           !(armToggle && history == toggle),
           !(armPaste && history == paste),
           !(armWorkspace && history == workspace) {
            _ = register(history, id: Self.historyID, ref: &historyRef)
        }
        toggleIsArmed = armedIDs.contains(Self.toggleID)
        pasteIsArmed = armedIDs.contains(Self.pasteID)
        workspaceIsArmed = armedIDs.contains(Self.workspaceID)
        historyIsArmed = armedIDs.contains(Self.historyID)
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
        } else if id == Self.workspaceID, workspaceIsArmed {
            NotificationCenter.default.post(name: .revealWorkspace, object: nil)
        } else if id == Self.historyID, historyIsArmed {
            NotificationCenter.default.post(name: .showClipboardHistory, object: nil)
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
