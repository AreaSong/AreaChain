import AppKit
import CoreFoundation

/// 对象身份加场景代次；窗口号只是日志中的系统元数据，不能作为路由键。
@MainActor
final class ControlsPlatformEvents {
    struct WindowStamp: Equatable {
        let id = UUID().uuidString
        let generation: Int
        let scene: String
        let number: Int
        let openedUptime = ProcessInfo.processInfo.systemUptime
        var fields: [String: Any] {
            ["windowID": id, "generation": generation, "scene": scene, "windowNumber": number,
             "windowOpenedUptime": openedUptime]
        }
    }
    private final class Observed {
        weak var event: NSEvent?
        let sequence: Int
        let stamp: WindowStamp
        init(_ event: NSEvent, sequence: Int, stamp: WindowStamp) {
            self.event = event; self.sequence = sequence; self.stamp = stamp
        }
    }
    let evidence: ControlsPlatformEvidence
    private var observed: [Observed] = []
    private var presses: [String: Int] = [:]
    private var shortcuts: [String: String] = [:]
    private var dispatches: [(stamp: WindowStamp, sequence: Int, callbacks: Int, eligible: Bool)] = []
    private var runLoopObserver: CFRunLoopObserver?
    private(set) var callbackCount = 0
    var listenerReleased: Bool { runLoopObserver == nil }

    init(_ evidence: ControlsPlatformEvidence) { self.evidence = evidence }

    func start() {
        guard runLoopObserver == nil else { return }
        runLoopObserver = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.entry.rawValue, true, 0) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.invalidateScopes() }
        }
        if let runLoopObserver {
            for mode in [CFRunLoopMode.commonModes, CFRunLoopMode(rawValue: RunLoop.Mode.eventTracking.rawValue as CFString),
                         CFRunLoopMode(rawValue: RunLoop.Mode.modalPanel.rawValue as CFString)] {
                CFRunLoopAddObserver(CFRunLoopGetMain(), runLoopObserver, mode)
            }
        }
    }

    func stop() {
        if let runLoopObserver { CFRunLoopObserverInvalidate(runLoopObserver) }
        runLoopObserver = nil
        invalidateScopes()
        observed.removeAll()
        presses.removeAll()
        shortcuts.removeAll()
    }

    private func invalidateScopes() {
        // tracking/modal 的嵌套循环可能运行任意异步工作；外层栈尚在并不证明因果。
        for index in dispatches.indices { dispatches[index].eligible = false }
    }

    @discardableResult
    func observe(_ event: NSEvent, stamp: WindowStamp, editor: NSTextView?) -> Int? {
        // 系统可能复用窗口号；在本次绑定前生成的排队事件不能归到新窗口。
        guard event.timestamp >= stamp.openedUptime, relevant(event, stamp: stamp) else { return nil }
        // 同一 native 事件经过 monitor 与 window 时只观察一次，不丢弃重复 keyDown。
        observed.removeAll { $0.event == nil }
        if let existing = observed.first(where: { $0.event === event && $0.stamp == stamp }) { return existing.sequence }
        var row = stamp.fields
        row["eventType"] = eventName(event.type)
        row["eventTimestamp"] = event.timestamp
        row["observationUptime"] = ProcessInfo.processInfo.systemUptime
        row["modifiers"] = event.modifierFlags.rawValue
        row["editorExists"] = editor != nil
        row["marked"] = editor.map { $0.hasMarkedText() ? "true" : "false" } ?? "unknown"
        row["phase"] = "before-dispatch"
        let sequence = evidence.sequence + 1
        if event.type == .keyDown || event.type == .keyUp {
            let key = "\(stamp.id):\(event.keyCode)"
            let semantic = shortcut(event) ?? (event.type == .keyUp ? shortcuts[key] : nil)
            row["controlKey"] = semantic ?? controlKey(event.keyCode)
            row["isARepeat"] = event.isARepeat
            if event.type == .keyDown {
                row["previousDownSequence"] = presses[key] as Any? ?? NSNull()
                if !event.isARepeat { presses[key] = sequence; shortcuts[key] = semantic }
            }
            row["pressSequence"] = presses[key] as Any? ?? NSNull()
            if event.type == .keyUp { presses.removeValue(forKey: key); shortcuts.removeValue(forKey: key) }
        }
        evidence.record("event", row)
        observed.append(Observed(event, sequence: sequence, stamp: stamp))
        return sequence
    }

    func withDispatch<T>(_ event: NSEvent, stamp: WindowStamp, editor: NSTextView?, action: () -> T) -> T {
        guard let sequence = observe(event, stamp: stamp, editor: editor) else {
            invalidateScopes()
            let previous = dispatches
            dispatches = []
            defer { dispatches = previous }
            return action()
        }
        // sendEvent 内嵌 performKeyEquivalent 属于同一栈帧；不重新派发、不改返回值。
        if dispatches.last?.sequence == sequence { return action() }
        dispatches.append((stamp, sequence, 0, runLoopObserver != nil))
        defer {
            let finished = dispatches.removeLast()
            var row = stamp.fields
            row["eventSequence"] = sequence
            row["synchronousCallbacks"] = finished.callbacks
            row["associationScopeIntact"] = finished.eligible
            row["scope"] = "window-dispatch-returned; asynchronous-outcome-unknown"
            evidence.record("dispatch-end", row)
        }
        return action()
    }

    func submitted(_ submission: SearchMultilineDraft.Submission, stamp: WindowStamp) -> String {
        callbackCount += 1
        var row = stamp.fields
        row["callbackType"] = submission.kind
        row["callbackUptime"] = submission.uptime
        row["callbackWallTime"] = submission.wallTime
        row["countBefore"] = submission.before
        row["countAfter"] = submission.after
        row["callbackSequence"] = callbackCount
        let matched = dispatches.last?.stamp == stamp && dispatches.last?.eligible == true
        if matched, let sequence = dispatches.last?.sequence { row["eventSequence"] = sequence }
        else { row["eventSequence"] = NSNull() }
        row["association"] = matched ? "synchronous-window-dispatch" : "unassociated"
        if matched { dispatches[dispatches.count - 1].callbacks += 1 }
        evidence.record("callback", row)
        return "\(submission.kind) \(submission.before) → \(submission.after) · \(matched ? "同步派发 / synchronous" : "未关联 / unassociated")"
    }

    func detach(_ stamp: WindowStamp) {
        observed.removeAll { $0.stamp == stamp }
        presses = presses.filter { !$0.key.hasPrefix(stamp.id + ":") }
        shortcuts = shortcuts.filter { !$0.key.hasPrefix(stamp.id + ":") }
    }

    func relevant(_ event: NSEvent, stamp: WindowStamp) -> Bool {
        if event.type == .leftMouseDown || event.type == .leftMouseUp { return true }
        guard event.type == .keyDown || event.type == .keyUp else { return false }
        return controlKey(event.keyCode) != nil || shortcut(event) != nil ||
            (event.type == .keyUp && shortcuts["\(stamp.id):\(event.keyCode)"] != nil)
    }

    private func shortcut(_ event: NSEvent) -> String? {
        let flags = event.modifierFlags.intersection([.command, .shift, .control, .option])
        if event.keyCode == 6 && flags == .command { return "Undo" }
        if event.keyCode == 6 && flags == [.command, .shift] { return "Redo" }
        if event.keyCode == 9 && flags == .command { return "Paste" }
        return nil
    }

    private func eventName(_ type: NSEvent.EventType) -> String {
        switch type {
        case .keyDown: "keyDown"
        case .keyUp: "keyUp"
        case .leftMouseDown: "leftMouseDown"
        case .leftMouseUp: "leftMouseUp"
        default: "other"
        }
    }

    private func controlKey(_ code: UInt16) -> String? {
        switch code {
        case 36: "Return"
        case 76: "Enter"
        case 48: "Tab"
        case 53: "Escape"
        default: nil
        }
    }
}

/// 只用于显式 P 合成输入夹具。主菜单先消费的快捷键可能没有窗口派发范围，应保持未关联。
@MainActor
final class ControlsEvidenceWindow: NSWindow {
    weak var platform: ControlsPlatformAcceptance?
    init() {
        super.init(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
    }
    override func sendEvent(_ event: NSEvent) {
        guard let platform else { super.sendEvent(event); return }
        platform.withDispatch(event, in: self) { super.sendEvent(event) }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let platform else { return super.performKeyEquivalent(with: event) }
        return platform.withDispatch(event, in: self) { super.performKeyEquivalent(with: event) }
    }
}
