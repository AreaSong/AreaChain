import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// K 阶段只读取合成输入的布尔与长度；编号仅在本次窗口内用于比较身份。
@MainActor
final class PasswordRetryDiagnostics {
    typealias Secure = SecureInputTestSupport
    typealias Native = SettingsButtonTestSupport
    let run: String
    private var identities: [ObjectIdentifier: Int] = [:]

    init(_ run: String) { self.run = run }

    private func identity(_ object: AnyObject?) -> Int {
        guard let object else { return 0 }
        let key = ObjectIdentifier(object)
        if let number = identities[key] { return number }
        let number = identities.count + 1
        identities[key] = number
        return number
    }

    func record(_ phase: String, in window: NSWindow, probe: PasswordSheetProbe? = nil) {
        let fields = Secure.fields(window)
        for (index, field) in fields.enumerated() {
            let editor = field.currentEditor() as? NSTextView
            let fieldID = identity(field)
            let editorID = identity(editor)
            let matches = field.stringValue.utf8.elementsEqual(Secure.sample.utf8)
            let editorMatches = editor?.string.utf8.elementsEqual(Secure.sample.utf8) ?? false
            print("SecureK run=\(run) phase=\(phase) field=\(index) id=\(fieldID) editor=\(editorID) currentEditor=\(editor != nil) active=\(editor != nil && editor === window.firstResponder) marked=\(editor?.hasMarkedText() ?? false) empty=\(field.stringValue.isEmpty) length=\(field.stringValue.count) sample=\(matches) editorEmpty=\(editor?.string.isEmpty ?? true) editorLength=\(editor?.string.count ?? -1) editorSample=\(editorMatches) selectedLocation=\(editor?.selectedRange().location ?? -1) selectedLength=\(editor?.selectedRange().length ?? -1) key=\(window.isKeyWindow) appActive=\(NSApp.isActive)")
        }
        if let probe {
            let save = enabled("common.save", in: window)
            let cancel = enabled("alert.cancel", in: window)
            print("SecureK run=\(run) phase=\(phase) calls=\(probe.calls) correct=\(probe.correctInput) alternate=\(probe.alternateInput) completed=\(probe.completed) pending=\(probe.pending != nil) save=\(save) cancel=\(cancel) error=\(Secure.hasError(window)) hostStateObserved=false")
        }
    }

    func enabled(_ key: String, in window: NSWindow) -> Bool {
        guard let button = try? Native.button(key, in: window),
              let result = button.value(forKey: "accessibilityEnabled") as? Bool else {
            Issue.record("K 按钮启用状态不可读取")
            return false
        }
        return result
    }

    /// 与原 click 的鼠标事件完全相同，只在原等待前增加同步/下一轮取样。
    func submit(in window: NSWindow, probe: PasswordSheetProbe, phase: String) async throws {
        let button = try Native.button("common.save", in: window)
        try Native.assertBounds([button], in: window)
        try #require(window.isKeyWindow)
        let rect = try Native.frame(button, in: window)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: NSPoint(x: rect.midX, y: rect.midY),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            NSApp.sendEvent(event)
        }
        record("\(phase)-sync", in: window, probe: probe)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        record("\(phase)-next", in: window, probe: probe)
        try await SystemPageHost.settle(window)
        record("\(phase)-180ms", in: window, probe: probe)
        try await Task.sleep(for: .milliseconds(600))
        record("\(phase)-stable", in: window, probe: probe)
    }

    func fill(_ window: NSWindow, keyboard: Bool, text: String? = nil) async throws {
        for index in Secure.fields(window).indices {
            try await enter(text ?? Secure.sample, index: index, in: window, keyboard: keyboard)
        }
    }

    func enter(_ text: String, index: Int, in window: NSWindow, keyboard: Bool) async throws {
        let field = try #require(Secure.fields(window).dropFirst(index).first)
        let editor = try await FormInputTestSupport.editor(field, in: window)
        #expect(editor === window.firstResponder)
        record("input-\(index)-before", in: window)
        if keyboard {
            // 原生选择及逐字符应用事件，允许正常事件循环更新；不调用剪贴板或额外清空。
            try await FormInputTestSupport.key(0, text: "a", flags: .command, in: window)
            for character in text {
                try await FormInputTestSupport.key(0, text: String(character), in: window)
            }
        } else {
            editor.insertText(text, replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
        }
        record("input-\(index)-sync", in: window)
        try await SystemPageHost.settle(window)
        record("input-\(index)-stable", in: window)
        let matches = field.stringValue.utf8.elementsEqual(text.utf8)
        #expect(matches)
    }
}

/// 与生产 sheet 分离的最小绑定探针：不替换生产 State，也没有认证或提交回调。
@MainActor @Observable
final class PasswordBindingProbe {
    var first = ""
    var second = ""
    var phase = 0
    var writes = [0, 0]
    var sameWrites = 0
    var differentWrites = 0
    var emptyWrites = 0
    var clearCalls = 0
    var actionCalls = 0
    var correctActions = 0
    var pending = false
    var failures = 0
    let native: Bool

    init(native: Bool) { self.native = native }

    func binding(_ index: Int) -> Binding<String> {
        Binding(get: { index == 0 ? self.first : self.second }, set: { value in
            self.writes[index] += 1
            let previous = index == 0 ? self.first : self.second
            let same = previous.utf8.elementsEqual(value.utf8)
            let sample = value.utf8.elementsEqual(SecureInputTestSupport.sample.utf8)
            if same { self.sameWrites += 1 } else { self.differentWrites += 1 }
            if value.isEmpty { self.emptyWrites += 1 }
            print("SecureK binding native=\(self.native) phase=\(self.phase) field=\(index) writes=\(self.writes[index]) same=\(same) empty=\(value.isEmpty) length=\(value.count) sample=\(sample)")
            if index == 0 { self.first = value } else { self.second = value }
        })
    }

    /// 仅局部合成 action：清空后进入等待，失败后重试；不替代生产私有 State 证据。
    func beginAction() {
        actionCalls += 1
        if first.utf8.elementsEqual(SecureInputTestSupport.sample.utf8) { correctActions += 1 }
        clearCalls += 1
        first = ""
        pending = true
        print("SecureK localClear native=\(native) phase=\(phase) clears=\(clearCalls) calls=\(actionCalls) correct=\(correctActions) empty=\(first.isEmpty)")
    }

    func finishAction(failure: Bool) {
        pending = false
        if failure { failures += 1 }
    }

    func record() {
        let firstSample = first.utf8.elementsEqual(SecureInputTestSupport.sample.utf8)
        let secondSample = second.utf8.elementsEqual(SecureInputTestSupport.sample.utf8)
        print("SecureK bindingState native=\(native) phase=\(phase) firstEmpty=\(first.isEmpty) secondEmpty=\(second.isEmpty) firstSample=\(firstSample) secondSample=\(secondSample) writes=\(writes)")
    }
}

struct PasswordBindingContent: View {
    let probe: PasswordBindingProbe
    var singleField = false

    var body: some View {
        VStack {
            if probe.native {
                SecureField("privacy.master.label", text: probe.binding(0))
                if !singleField { SecureField("privacy.password.repeat", text: probe.binding(1)) }
            } else {
                DaybookSecureField("privacy.master.label", text: probe.binding(0))
                if !singleField { DaybookSecureField("privacy.password.repeat", text: probe.binding(1)) }
            }
        }.padding(24)
    }
}

/// 每次试验固定持有同一字段/editor；通知只计数，不读 userInfo 或额外缓存输入。
@MainActor
final class PasswordReplacementObservation {
    typealias Secure = SecureInputTestSupport
    let window: NSWindow
    let field: NSSecureTextField
    let editor: NSTextView
    let probe: PasswordBindingProbe
    let trace: PasswordRetryDiagnostics
    private var observers: [NSObjectProtocol] = []
    private var fieldNotifications = 0
    private var editorNotifications = 0
    private var samples = 0
    private var started = ProcessInfo.processInfo.systemUptime

    init(window: NSWindow, field: NSSecureTextField, editor: NSTextView,
         probe: PasswordBindingProbe, run: String) {
        self.window = window
        self.field = field
        self.editor = editor
        self.probe = probe
        trace = PasswordRetryDiagnostics(run)
        observers.append(NotificationCenter.default.addObserver(
            forName: NSControl.textDidChangeNotification, object: field, queue: nil) { [weak self] _ in
                MainActor.assumeIsolated { self?.fieldNotifications += 1 }
            })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification, object: editor, queue: nil) { [weak self] _ in
                MainActor.assumeIsolated { self?.editorNotifications += 1 }
            })
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    func continuity() throws {
        let sameField = Secure.fields(window).count == 1 && Secure.fields(window).first === field
        let sameEditor = field.currentEditor() === editor && window.firstResponder === editor
        try #require(sameField && sameEditor && field.window === window)
        try #require(window.isKeyWindow && NSApp.isActive && !editor.hasMarkedText())
    }

    func replace(_ mode: Secure.Replacement, phase: Int) throws {
        try continuity()
        probe.phase = phase
        editor.setSelectedRange(NSRange(location: 0, length: editor.string.utf16.count))
        sample("input-before")
        let began = ProcessInfo.processInfo.systemUptime
        let result = Secure.replaceSample(mode, in: editor)
        let elapsed = (ProcessInfo.processInfo.systemUptime - began) * 1_000
        print("SecureK controlInput run=\(trace.run) phase=\(phase) mode=\(mode.rawValue) calls=\(result.calls) differentIntermediates=\(result.differentIntermediates) operationMs=\(elapsed)")
        let matched = editor.string.utf8.elementsEqual(Secure.sample.utf8)
        let endpoint = editor.selectedRange() == NSRange(location: Secure.sample.utf16.count, length: 0)
        #expect(matched && endpoint)
        if mode == .inPlace { #expect(result.differentIntermediates == 0) }
        if mode == .growing { #expect(result.differentIntermediates == Secure.sample.count - 1) }
    }

    /// 不调用 settle 的强制布局，也不轮询到空；每段都只取这四个固定检查点。
    func checkpoints(_ phase: String) async throws {
        started = ProcessInfo.processInfo.systemUptime
        try continuity()
        sample("\(phase)-sync")
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        try continuity()
        sample("\(phase)-next")
        try await Task.sleep(for: .milliseconds(180))
        try continuity()
        sample("\(phase)-180ms")
        try await Task.sleep(for: .milliseconds(600))
        try continuity()
        sample("\(phase)-stable")
    }

    private func sample(_ phase: String) {
        samples += 1
        trace.record(phase, in: window)
        let elapsed = (ProcessInfo.processInfo.systemUptime - started) * 1_000
        let bindingSample = probe.first.utf8.elementsEqual(Secure.sample.utf8)
        print("SecureK controlState run=\(trace.run) phase=\(phase) stage=\(probe.phase) elapsedMs=\(elapsed) samples=\(samples) bindingEmpty=\(probe.first.isEmpty) bindingLength=\(probe.first.count) bindingSample=\(bindingSample) writes=\(probe.writes[0]) sameWrites=\(probe.sameWrites) differentWrites=\(probe.differentWrites) emptyWrites=\(probe.emptyWrites) fieldNotifications=\(fieldNotifications) editorNotifications=\(editorNotifications) clears=\(probe.clearCalls) actions=\(probe.actionCalls) correctActions=\(probe.correctActions) pending=\(probe.pending) failures=\(probe.failures)")
    }

    func filled() {
        let bindingMatches = probe.first.utf8.elementsEqual(Secure.sample.utf8)
        let nativeMatches = field.stringValue.utf8.elementsEqual(Secure.sample.utf8)
            && editor.string.utf8.elementsEqual(Secure.sample.utf8)
        #expect(bindingMatches && nativeMatches)
    }

    func outcome() throws {
        try continuity()
        let bindingEmpty = probe.first.isEmpty
        let nativeEmpty = field.stringValue.isEmpty && editor.string.isEmpty
        let actionsCorrect = probe.actionCalls == 2 && probe.correctActions == 2
            && probe.clearCalls == 2 && probe.failures == 1 && probe.pending
        print("SecureK controlOutcome run=\(trace.run) observed=true bindingEmpty=\(bindingEmpty) nativeEmpty=\(nativeEmpty) clearPassed=\(bindingEmpty && nativeEmpty) actionsCorrect=\(actionsCorrect) samples=\(samples)")
        #expect(bindingEmpty && actionsCorrect)
        // 残留依旧使清空要求失败；观测完成不借 known issue 转成通过。
        #expect(nativeEmpty, "K 同宿主安全字段/editor 清空要求")
        try SettingsButtonTestSupport.snapshot(window, name: "K-control-\(trace.run)-stable")
        sample("cache-after-outcome")
        let cacheUnchanged = nativeEmpty == (field.stringValue.isEmpty && editor.string.isEmpty)
        #expect(cacheUnchanged)
    }
}
