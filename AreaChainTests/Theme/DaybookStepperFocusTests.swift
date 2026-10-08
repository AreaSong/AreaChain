import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookStepperFocusTests {
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: [false, true])
    func disablingWithOrWithoutFocus(releaseFirst: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = StepperProbe()
        let window = fixture.window(DaybookStepperProbeView(state: state))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let keys = Native.elements(window.contentView).compactMap { $0 as? DaybookStepperKeyView }
        let key = try #require(keys.first)
        #expect(window.makeFirstResponder(key))
        #expect(window.firstResponder === key)
        if releaseFirst { #expect(window.makeFirstResponder(nil)) }
        print("STEPPER_FOCUS disable releaseFirst=\(releaseFirst)")
        state.disabled = true
        try await SystemPageHost.settle(window)
        #expect(window.firstResponder !== key && !key.isEnabled)
        key.doubleValue = 1
        key.step()
        #expect(state.writes == 0)
        state.disabled = false
        try await SystemPageHost.settle(window)
        #expect(key.isEnabled && window.makeFirstResponder(key))
        key.doubleValue = 1
        key.step()
        #expect(state.writes == 1)
        #expect(window.makeFirstResponder(nil))
        try await SystemPageHost.settle(window)
        #expect(state.writes == 1)
    }

    @Test func focusFeedbackUsesLatestAttachmentAndCancelsOnDismantle() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let attachment = DaybookStepperAttachment()
        var feedback: [Bool] = []
        var writes = 0
        let bridge = DaybookStepperKeyboard(attachment: attachment, isEnabled: true,
            canStep: { _ in true }, adjust: { _ in writes += 1 }, lastDirection: { true },
            focusChanged: { feedback.append($0) })
        let window = fixture.window(bridge)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let host = try #require(window.contentView)
        let key = try #require(Native.elements(host).compactMap { $0 as? DaybookStepperKeyView }.first)
        feedback.removeAll()
        #expect(window.makeFirstResponder(key))
        #expect(feedback.isEmpty, "仅呈现反馈延后，原生焦点已经同步取得")
        #expect(window.firstResponder === key)
        #expect(window.makeFirstResponder(nil))
        try await SystemPageHost.settle(window)
        #expect(feedback == [false], "同一轮旧的取得焦点通知不得迟到恢复描边")
        feedback.removeAll()
        #expect(window.makeFirstResponder(key))
        window.contentView = NSView()
        #expect(!attachment.isAttached)
        try await SystemPageHost.settle(window)
        #expect(feedback == [false] && !attachment.buttonEnabled)
        window.contentView = host
        try await SystemPageHost.settle(window)
        #expect(attachment.isAttached && attachment.buttonEnabled && feedback.allSatisfy { !$0 })
        #expect(window.makeFirstResponder(key))
        try await SystemPageHost.settle(window)
        #expect(feedback.last == true)
        feedback.removeAll()
        #expect(window.makeFirstResponder(nil))
        DaybookStepperKeyboard.dismantleNSView(key, coordinator: ())
        try await SystemPageHost.settle(window)
        #expect(feedback.isEmpty && !attachment.isAttached && !attachment.buttonEnabled)
        key.doubleValue = 1
        key.step()
        #expect(writes == 0 && !key.canStep(true) && !key.canStep(false))
    }

    @Test func movingFocusBetweenInstancesKeepsBindingsIndependent() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = StepperProbe()
        let window = fixture.window(DaybookStepperProbeView(state: state))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let keys = Native.elements(window.contentView).compactMap { $0 as? DaybookStepperKeyView }
            .sorted { $0.convert($0.bounds, to: nil).midY > $1.convert($1.bounds, to: nil).midY }
        try #require(keys.count == 2)
        #expect(window.makeFirstResponder(keys[0]))
        try StepperNativeTestSupport.key(.keyDown, code: 126, chars: "\u{F700}", in: window)
        #expect(state.integer == 210 && state.decimal == 0.5 && state.writes == 1)
        #expect(window.makeFirstResponder(keys[1]))
        try StepperNativeTestSupport.key(.keyDown, code: 125, chars: "\u{F701}", in: window)
        #expect(state.integer == 210 && state.decimal == 0.4 && state.writes == 2)
        try await SystemPageHost.settle(window)
        #expect(window.firstResponder === keys[1])
        try StepperNativeTestSupport.key(.keyDown, code: 123, chars: "\u{F702}", in: window)
        try StepperNativeTestSupport.key(.keyDown, code: 124, chars: "\u{F703}", in: window)
        #expect(state.writes == 2)
        #expect(window.makeFirstResponder(keys[0]))
        try StepperNativeTestSupport.key(.keyDown, code: 49, chars: " ", in: window)
        #expect(state.integer == 220 && state.decimal == 0.4 && state.writes == 3)
    }

}
