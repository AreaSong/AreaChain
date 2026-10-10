#if AREACHAIN_QA
import AppKit
import Testing
@testable import AreaChain

/// 仅合成原型观察，不读取 layoutManager 来探测 TK2，避免检查本身触发兼容回退。
@MainActor final class CommandTextPrototypeObservation {
    private var observers: [NSObjectProtocol] = []
    private(set) var switches = 0
    let engine: CommandTextPrototype
    let editor: CommandProtectedTextView

    init(_ editor: CommandProtectedTextView, engine: CommandTextPrototype) {
        self.editor = editor
        self.engine = engine
        for name in [NSTextView.willSwitchToNSLayoutManagerNotification, NSTextView.didSwitchToNSLayoutManagerNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: editor, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.switches += 1 }
            })
        }
    }

    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }

    func check() throws {
        try #require(switches == 0)
        try #require((editor.textLayoutManager != nil) == (engine == .textKit2))
    }

    var metadata: [String: Any] {
        ["engine": engine.rawValue, "fallbackNotifications": switches,
         "layoutObject": editor.textLayoutManager.map { String(describing: type(of: $0)) } ?? "NSLayoutManager",
         "contentObject": editor.textContentStorage.map { String(describing: type(of: $0)) } ?? "NSTextStorage"]
    }
}

@MainActor enum CommandTextPrototypeChecks {
    static func current(_ editor: CommandProtectedTextView, service: CommandDraftContentSession, vault: PrivacyVault) throws -> CommandDraftEditingState {
        let access = try #require(editor.access)
        let state = try service.nativeState(access, owner: editor)
        try state.validate()
        try #require((editor.string as NSString).isEqual(to: state.spelling))
        try #require(editor.selectedRange() == state.selection)
        try #require(editor.hasMarkedText() == (state.composition != nil && !state.composition!.pendingConfirmation))
        if access.isProtected {
            let point = try service.nativeRecoveryPoint(access, owner: editor)
            let opened = try point.open(keys: vault.keys)
            if let stored = opened.editing.first(where: { $0.parameter == state.parameter }) {
                try #require(stored == state)
            }
            try #require(opened.arguments.first(where: { $0.parameter == editor.parameter })?.value == .longText(state.confirmedText))
        }
        return state
    }

    static func anchor(_ editor: CommandProtectedTextView, range: NSRange) throws -> [String: Any] {
        var actual = NSRange()
        let start = ContinuousClock.now
        let rect = editor.firstRect(forCharacterRange: range, actualRange: &actual)
        let elapsed = milliseconds(start)
        let window = try #require(editor.window)
        let visible = window.convertToScreen(editor.convert(editor.visibleRect, to: nil))
        if rect.height <= 0 || actual.location == NSNotFound {
            let diagnostic: [String: Any] = ["rect": NSStringFromRect(rect), "actualRange": NSStringFromRange(actual),
                "requestedRange": NSStringFromRange(range), "frame": NSStringFromRect(editor.frame),
                "visibleRect": NSStringFromRect(editor.visibleRect), "key": window.isKeyWindow,
                "textKit2": editor.textLayoutManager != nil]
            Attachment.record(try JSONSerialization.data(withJSONObject: diagnostic), named: "CM2-anchor-failure.json")
            try snapshot(window, name: "CM2-anchor-failure")
        }
        try #require(rect.height > 0 && rect.width >= 0 && actual.location != NSNotFound)
        try #require(actual.location <= range.location && NSMaxRange(actual) >= range.location)
        try #require(visible.insetBy(dx: -1, dy: -1).contains(rect.origin))
        // 用同一原生字符映射反查锚点，不仅检查非空矩形。
        let hit = editor.characterIndex(for: NSPoint(x: rect.minX + 0.5, y: rect.midY))
        try #require(hit >= actual.location && hit <= max(NSMaxRange(actual), range.location + 1))
        return ["anchorMS": elapsed, "height": rect.height, "x": rect.minX, "y": rect.minY,
                "requestedLocation": range.location, "actualLocation": actual.location, "hitLocation": hit,
                "visibleY": editor.visibleRect.minY]
    }

    static func milliseconds(_ start: ContinuousClock.Instant) -> Double {
        let value = start.duration(to: .now).components
        return Double(value.seconds) * 1_000 + Double(value.attoseconds) / 1e15
    }

    static func snapshot(_ window: NSWindow, name: String) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        Attachment.record(try #require(bitmap.representation(using: .png, properties: [:])), named: name + ".png")
    }
}
#endif
