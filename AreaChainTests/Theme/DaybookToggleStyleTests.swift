import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookToggleStyleTests {
    typealias Native = SettingsButtonTestSupport
    typealias Presentation = DaybookToggleStyle.Presentation
    static let variants: [(Bool, Presentation)] = [
        (false, .switchControl), (true, .switchControl), (false, .checkbox), (true, .checkbox)
    ]

    @Test(arguments: variants, ["en", "zh-Hans"])
    func bindingAndSemantics(variant: (Bool, Presentation), locale: String) async throws {
        let (hidden, presentation) = variant
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = ToggleProbe()
        let window = fixture.window(ToggleProbeView(state: state, hidden: hidden, presentation: presentation), locale: locale)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        var node = try toggle(in: window)
        #expect(Native.value(node, "accessibilityRole") as? String == "AXCheckBox")
        #expect(Native.value(node, "accessibilityLabel") as? String ==
                L10n.string("residents.enabled", locale: Locale(identifier: locale)))
        try assertValue(false, in: window)
        let frame = try Native.frame(node, in: window)
        #expect(frame.height >= 28)
        #expect(hidden ? frame.width == (presentation == .checkbox ? 18 : 34) : frame.width > 34)
        try await Native.click(node, in: window)
        #expect(state.value && state.writes == 1)
        try assertValue(true, in: window)
        try await Native.click(try toggle(in: window), in: window)
        #expect(!state.value && state.writes == 2)
        state.value = true
        try await SystemPageHost.settle(window)
        try assertValue(true, in: window)
        #expect(state.writes == 2)
        state.reject = true
        try await Native.click(try toggle(in: window), in: window)
        #expect(state.value && state.writes == 3)
        try assertValue(true, in: window)
        state.reject = false
        node = try toggle(in: window)
        try press(node)
        try await SystemPageHost.settle(window)
        #expect(!state.value && state.writes == 4)
        try assertValue(false, in: window)
    }

    @Test(arguments: Presentation.allCases)
    func disabledRejectsMouseAndAccessibility(presentation: Presentation) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = ToggleProbe()
        let window = fixture.window(ToggleProbeView(state: state, hidden: true, presentation: presentation))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        state.disabled = true
        try await SystemPageHost.settle(window)
        let node = try toggle(in: window)
        #expect((node.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == false)
        try await Native.click(node, in: window)
        try press(node)
        try await SystemPageHost.settle(window)
        #expect(!state.value && state.writes == 0)
        try assertValue(false, in: window)
    }

    @Test(arguments: Presentation.allCases, [("en", false), ("en", true), ("zh-Hans", false), ("zh-Hans", true)])
    func longLabelLayouts(presentation: Presentation, environment: (String, Bool)) async throws {
        let (locale, dark) = environment
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = ToggleProbe()
        let content = VStack(spacing: DaybookSpacing.md) {
            Toggle(isOn: state.binding) {
                Label("dev.controls.toggle.longLabel", systemImage: "lock")
            }
                .toggleStyle(DaybookToggleStyle(presentation)).accessibilityIdentifier("toggle.probe")
            Toggle("residents.enabled", isOn: .constant(true))
                .toggleStyle(DaybookToggleStyle(presentation)).disabled(true)
            Toggle("residents.enabled", isOn: .constant(false))
                .toggleStyle(DaybookToggleStyle(presentation, hiddenLabel: "residents.enabled")).labelsHidden().disabled(true)
        }.padding(DaybookSpacing.page).background(DaybookPalette.fill.page)
        let window = fixture.window(content, locale: locale, scheme: dark ? .dark : .light,
                                    size: NSSize(width: 320, height: 220))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let node = try toggle(in: window)
        try Native.assertBounds([node], in: window)
        #expect(try Native.frame(node, in: window).height > 28)
        #expect(Native.value(node, "accessibilityLabel") as? String ==
                L10n.string("dev.controls.toggle.longLabel", locale: Locale(identifier: locale)))
        try Native.snapshot(window, name: "toggle-\(presentation)-\(locale)-\(dark)")
    }

    @Test func thumbFollowsExternalAndRejectedBinding() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = ToggleProbe()
        let window = fixture.window(ToggleProbeView(state: state, hidden: true))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try assertThumb(false, in: window)
        state.value = true
        try await SystemPageHost.settle(window)
        try assertThumb(true, in: window)
        state.reject = true
        try await Native.click(toggle(in: window), in: window)
        try assertThumb(true, in: window)
        #expect(state.writes == 1)
        try Native.snapshot(window, name: "toggle-rejected-binding")
    }

    @Test func checkboxGraphicAndLabelShareOneAction() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = ToggleProbe()
        let window = fixture.window(ToggleProbeView(state: state, hidden: false, presentation: .checkbox))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let rect = try Native.frame(toggle(in: window), in: window)
        for x in [rect.minX + 9, rect.maxX - 4] {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                NSApp.sendEvent(try MenuButtonTestSupport.mouse(type, at: NSPoint(x: x, y: rect.midY), in: window))
            }
            try await SystemPageHost.settle(window)
        }
        #expect(!state.value && state.writes == 2)
        let before = try checkboxPixels(window)
        state.value = true
        try await SystemPageHost.settle(window)
        let selected = try checkboxPixels(window)
        #expect(before != selected, "外部更新必须改变方框的实际像素，而不只是 AX 值")
        state.reject = true
        try await Native.click(toggle(in: window), in: window)
        #expect(try checkboxPixels(window) == selected)
        #expect(state.value && state.writes == 3)
    }

    private func checkboxPixels(_ window: NSWindow) throws -> [UInt32] {
        let view = try #require(window.contentView)
        let rect = try Native.frame(toggle(in: window), in: window)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return try (4..<14).map { x in
            let point = view.convert(NSPoint(x: rect.minX + CGFloat(x), y: rect.midY), from: nil)
            let y = view.isFlipped ? point.y : view.bounds.height - point.y
            let color = try #require(bitmap.colorAt(
                x: Int(point.x * CGFloat(bitmap.pixelsWide) / view.bounds.width),
                y: Int(y * CGFloat(bitmap.pixelsHigh) / view.bounds.height))?.usingColorSpace(.deviceRGB))
            return UInt32(color.redComponent * 255) << 16 | UInt32(color.greenComponent * 255) << 8 | UInt32(color.blueComponent * 255)
        }
    }

    private func assertThumb(_ isOn: Bool, in window: NSWindow) throws {
        let view = try #require(window.contentView)
        let frame = try Native.frame(toggle(in: window), in: window)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        func red(at x: CGFloat) throws -> CGFloat {
            let point = view.convert(NSPoint(x: x, y: frame.midY), from: nil)
            let y = view.isFlipped ? point.y : view.bounds.height - point.y
            let color = try #require(bitmap.colorAt(
                x: Int(point.x * CGFloat(bitmap.pixelsWide) / view.bounds.width),
                y: Int(y * CGFloat(bitmap.pixelsHigh) / view.bounds.height))?.usingColorSpace(.deviceRGB))
            return color.redComponent
        }
        let left = try red(at: frame.minX + 10)
        let right = try red(at: frame.maxX - 10)
        // 独立抽样实际滑块像素，避免只验证 AX 状态而漏掉外观滞留。
        #expect(isOn ? right > left + 0.02 : left > right + 0.02)
    }

    @Test(arguments: Presentation.allCases)
    func keyboardRespectsNativeActivationPolicy(presentation: Presentation) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = ToggleProbe()
        let window = fixture.window(ToggleKeyboardProbe(state: state, presentation: presentation))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let node = try toggle(in: window)
        // activate 遵守 macOS 键盘导航策略；不能改成 edit 来抢走相邻标题焦点。
        let acceptsKeyboard = NSApp.isFullKeyboardAccessEnabled
        print("TOGGLE_KEYBOARD_ACTIVATION enabled=\(acceptsKeyboard)")
        #expect((node.value(forKey: "accessibilityFocused") as? NSNumber)?.boolValue == acceptsKeyboard)
        try key(.keyDown, in: window)
        try key(.keyDown, in: window, repeatKey: true)
        try await SystemPageHost.settle(window)
        #expect(!state.value && state.writes == 0)
        try Native.snapshot(window, name: "toggle-key-policy-\(acceptsKeyboard)")
        try key(.keyUp, in: window)
        try await SystemPageHost.settle(window)
        #expect(state.value == acceptsKeyboard && state.writes == (acceptsKeyboard ? 1 : 0))
        try key(.keyDown, in: window)
        state.disabled = true
        try await SystemPageHost.settle(window)
        try await space(in: window)
        #expect(state.value == acceptsKeyboard && state.writes == (acceptsKeyboard ? 1 : 0))
        try assertValue(acceptsKeyboard, in: window)
    }

    @Test(arguments: Presentation.allCases)
    func mouseKeepsNativeNeighborFocusContract(presentation: Presentation) async throws {
        let native = try await neighborFocus(custom: false, presentation: presentation)
        let daybook = try await neighborFocus(custom: true, presentation: presentation)
        #expect(native == daybook, "启用开关不能改变相邻标题的失焦提交时机")
    }

    private func neighborFocus(custom: Bool, presentation: Presentation) async throws -> Bool {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let window = fixture.window(ToggleNeighborProbe(custom: custom, presentation: presentation))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let field = try #require(Native.elements(window.contentView).compactMap { $0 as? NSTextField }.first { $0.isEditable })
        #expect(window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("Uncommitted title", replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(window)
        let frame = try Native.frame(toggle(in: window), in: window)
        let point = NSPoint(x: frame.midX, y: frame.midY)
        // NSSwitch 的 mouseDown 同步追踪必须先排入 mouseUp，不能串行 send 两个事件。
        NSApp.postEvent(try MenuButtonTestSupport.mouse(.leftMouseUp, at: point, in: window), atStart: false)
        NSApp.sendEvent(try MenuButtonTestSupport.mouse(.leftMouseDown, at: point, in: window))
        try await SystemPageHost.settle(window)
        return field.currentEditor() != nil && window.firstResponder === field.currentEditor()
    }

    private func space(in window: NSWindow) async throws {
        try key(.keyDown, in: window)
        try key(.keyUp, in: window)
        try await SystemPageHost.settle(window)
    }

    private func key(_ type: NSEvent.EventType, in window: NSWindow, repeatKey: Bool = false) throws {
        let event = try #require(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: " ", charactersIgnoringModifiers: " ", isARepeat: repeatKey, keyCode: 49))
        NSApp.sendEvent(event)
    }

    private func press(_ node: NSObject) throws {
        let selector = NSSelectorFromString("accessibilityPerformPress")
        try #require(node.responds(to: selector))
        _ = node.perform(selector)
    }

    private func toggle(in window: NSWindow) throws -> NSObject {
        try #require(Native.elements(window.contentView).first {
            Native.value($0, "accessibilityIdentifier") as? String == "toggle.probe"
        })
    }

    private func assertValue(_ expected: Bool, in window: NSWindow) throws {
        let value = Native.value(try toggle(in: window), "accessibilityValue") as? NSNumber
        #expect(value?.boolValue == expected)
    }
}

@MainActor @Observable
private final class ToggleProbe {
    var value = false
    var writes = 0
    var reject = false
    var disabled = false
    var binding: Binding<Bool> {
        Binding(get: { self.value }, set: {
            self.writes += 1
            if !self.reject { self.value = $0 }
        })
    }
}

@MainActor
private struct ToggleProbeView: View {
    @Bindable var state: ToggleProbe
    let hidden: Bool
    var presentation: DaybookToggleStyle.Presentation = .switchControl

    var body: some View {
        Toggle("residents.enabled", isOn: state.binding)
            .toggleStyle(DaybookToggleStyle(presentation, hiddenLabel: hidden ? "residents.enabled" : nil))
            .accessibilityIdentifier("toggle.probe")
            .disabled(state.disabled)
            // 自定义 setter 的测试宿主显式订阅外部模型，模拟生产 State/Query 的重绘生命周期。
            .onChange(of: state.value) { _, _ in }
            .padding().background(DaybookPalette.fill.page)
    }
}

@MainActor
private struct ToggleKeyboardProbe: View {
    @Bindable var state: ToggleProbe
    let presentation: DaybookToggleStyle.Presentation
    @FocusState private var focused: Bool

    var body: some View {
        Toggle("residents.enabled", isOn: state.binding)
            .toggleStyle(DaybookToggleStyle(presentation))
            .focused($focused)
            .accessibilityIdentifier("toggle.probe")
            .disabled(state.disabled)
            // 自定义 setter 的测试宿主显式订阅外部模型，模拟生产 State/Query 的重绘生命周期。
            .onChange(of: state.value) { _, _ in }
            .onAppear { focused = true }
            .padding().background(DaybookPalette.fill.page)
    }
}

@MainActor
private struct ToggleNeighborProbe: View {
    let custom: Bool
    let presentation: DaybookToggleStyle.Presentation
    @State private var text = ""
    @State private var focused = false
    @State private var enabled = true

    var body: some View {
        HStack {
            SyntaxTextField(text: $text, placeholder: "Title", focused: $focused, onSubmit: {})
            Group {
                if custom {
                    Toggle("residents.enabled", isOn: $enabled)
                        .toggleStyle(DaybookToggleStyle(presentation, hiddenLabel: "residents.enabled"))
                } else if presentation == .checkbox {
                    Toggle("residents.enabled", isOn: $enabled).toggleStyle(.checkbox)
                } else {
                    Toggle("residents.enabled", isOn: $enabled).toggleStyle(.switch)
                }
            }
            .labelsHidden()
            .accessibilityIdentifier("toggle.probe")
        }.padding()
    }
}
