import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookStepperInteractionTests {
    typealias Native = SettingsButtonTestSupport

    @Test func neighborFocusAndTracking() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = StepperProbe()
        let window = fixture.window(DaybookStepperProbeView(state: state))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let field = try #require(Native.elements(window.contentView).compactMap { $0 as? NSTextField }.first { $0.isEditable })
        #expect(window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("Unsubmitted", replacementRange: editor.selectedRange())
        try await StepperTestSupport.click("stepper.integer", increase: true, in: window)
        #expect(state.integer == 210 && state.writes == 1)
        #expect(field.currentEditor() === window.firstResponder, "原生 Stepper 鼠标操作保留相邻输入焦点")
        #expect(field.stringValue == "Unsubmitted")
    }

    @Test func tabNavigationMatchesNative() async throws {
        let original = try await tabTarget(custom: false)
        let daybook = try await tabTarget(custom: true)
        #expect(original == daybook)
    }

    @Test(arguments: [true, false])
    func disablingDuringHoldStopsWritesAndAllowsNextPress(increase: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = StepperProbe()
        let window = fixture.window(DaybookStepperProbeView(state: state))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let trace = StepperEventTrace()
        state.trace = trace
        let point = try StepperTestSupport.point(StepperTestSupport.node("stepper.integer", in: window), increase: increase, in: window)
        try await StepperNativeTestSupport.perform(point, in: window,
            script: StepperPointerScript(mutation: { state.disabled = true }), trace: trace)
        let count = state.writes
        #expect(state.disabled && count == 1, "禁用发生在已观察到的重复延迟之前")
        try trace.assertPressAndRelease(increase: increase)
        try trace.assertWritesBefore("mutation")
        state.disabled = false
        state.integer = 40
        try await SystemPageHost.settle(window)
        try await StepperTestSupport.click("stepper.integer", increase: increase, in: window)
        #expect(state.integer == (increase ? 50 : 30) && state.writes == count + 1)
    }

    @Test(arguments: [true, false])
    func syntheticHoldComparison(increase: Bool) async throws {
        var traces: [StepperEventTrace] = []
        for custom in [false, true] {
            let fixture = try Native()
            defer { fixture.cleanup() }
            let state = StepperProbe()
            state.integer = 500
            let trace = StepperEventTrace()
            state.trace = trace
            let view = custom ? AnyView(DaybookStepperProbeView(state: state)) : AnyView(StepperBaselineView(state: state))
            let window = fixture.window(view)
            defer { SystemPageHost.release(window) }
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await SystemPageHost.settle(window)
            let point = try StepperNativeTestSupport.point(custom: custom, increase: increase, in: window)
            print("F_HOLD custom=\(custom) increase=\(increase) initial=500 range=20...999 key=\(window.isKeyWindow) point=\(point) physical=\(window.mouseLocationOutsideOfEventStream) buttons=\(NSEvent.pressedMouseButtons)")
            try await StepperNativeTestSupport.perform(point, in: window, trace: trace)
            try trace.assertPressAndRelease(increase: increase)
            for (index, write) in trace.writes.enumerated() {
                #expect(write.value == Double(500 + (increase ? 10 : -10) * (index + 1)))
            }
            traces.append(trace)
        }
        // 不将应用内队列的不同重复次数包装为通过；原生有效系统长按输入仍需单独取得。
        print("F_REPEAT_UNRESOLVED increase=\(increase) native=\(traces[0].writes.count) daybook=\(traces[1].writes.count)")
    }

    @Test(arguments: [true, false])
    func cancellationBoundariesAndRemoval(increase: Bool) async throws {
        for scenario in ["cancel", "reenter", "bound", "reject", "remove"] {
            let fixture = try Native()
            defer { fixture.cleanup() }
            let state = StepperProbe()
            state.integer = scenario == "bound" ? (increase ? 989 : 30) : 500
            state.reject = scenario == "reject"
            let trace = StepperEventTrace()
            state.trace = trace
            let window = fixture.window(DaybookStepperProbeView(state: state))
            defer { SystemPageHost.release(window) }
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await SystemPageHost.settle(window)
            let point = try StepperNativeTestSupport.point(custom: true, increase: increase, in: window)
            var script = StepperPointerScript()
            if scenario == "cancel" || scenario == "reenter" { script.outAt = 0.05 }
            if scenario == "reenter" { script.reenterAt = 0.65 }
            if scenario == "remove" { script.mutation = { window.contentView = NSView() } }
            print("F_SCENARIO \(scenario) increase=\(increase)")
            try await StepperNativeTestSupport.perform(point, in: window, script: script, trace: trace)
            try trace.assertPressAndRelease(increase: increase)
            if ["cancel", "bound", "remove"].contains(scenario) { #expect(state.writes == 1) }
            if scenario == "cancel" { try trace.assertWritesBefore("out") }
            if scenario == "remove" { try trace.assertWritesBefore("mutation") }
            if scenario == "bound" { #expect(state.integer == (increase ? 999 : 20)) }
            if scenario == "reject" {
                #expect(state.integer == 500)
                #expect(trace.writes.allSatisfy { $0.value == Double(increase ? 510 : 490) })
            }
            if scenario == "reenter" {
                let outside = try #require(trace.items.first { $0.kind == "out" }).time
                let inside = try #require(trace.items.first { $0.kind == "in" }).time
                #expect(!trace.writes.contains { $0.time > outside && $0.time < inside })
            }
            if scenario == "remove" {
                state.trace = nil
                let replacement = fixture.window(DaybookStepperProbeView(state: state))
                defer { SystemPageHost.release(replacement) }
                try await NativeSyntaxUI.prepareFocus(in: replacement)
                try await SystemPageHost.settle(replacement)
                let count = state.writes
                try await StepperTestSupport.click("stepper.integer", increase: !increase, in: replacement)
                try await Task.sleep(for: .milliseconds(400))
                #expect(state.writes == count + 1 && state.integer == 500, "旧宿主不能向重建后的同一 Binding 继续写入")
            } else {
                state.reject = false
                state.integer = 500
                state.trace = nil
                try await SystemPageHost.settle(window)
                let count = state.writes
                try await StepperTestSupport.click("stepper.integer", increase: !increase, in: window)
                #expect(state.writes == count + 1 && state.integer == (increase ? 490 : 510))
            }
        }
    }

    @Test func rapidClicksMatchNative() async throws {
        for custom in [false, true] {
            let fixture = try Native()
            defer { fixture.cleanup() }
            let state = StepperProbe()
            let view = custom ? AnyView(DaybookStepperProbeView(state: state)) : AnyView(StepperBaselineView(state: state))
            let window = fixture.window(view)
            defer { SystemPageHost.release(window) }
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await SystemPageHost.settle(window)
            let plus = try StepperNativeTestSupport.point(custom: custom, increase: true, in: window)
            let minus = try StepperNativeTestSupport.point(custom: custom, increase: false, in: window)
            // 无 settle 的连续点击，交替方向可检出前次消费标志串到后次。
            for index in 0..<10 {
                let point = index.isMultiple(of: 2) ? plus : minus
                try await StepperNativeTestSupport.quickClick(point, in: window)
                #expect(state.writes == index + 1)
                #expect(state.integer == (index.isMultiple(of: 2) ? 210 : 200))
            }
            try await SystemPageHost.settle(window)
            #expect(state.writes == 10 && state.integer == 200)
        }
    }

    private func tabTarget(custom: Bool) async throws -> Bool {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = StepperProbe()
        let view = custom ? AnyView(DaybookStepperProbeView(state: state)) : AnyView(StepperBaselineView(state: state))
        let window = fixture.window(view)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let field = try #require(Native.elements(window.contentView).compactMap { $0 as? NSTextField }.first { $0.isEditable })
        #expect(window.makeFirstResponder(field))
        try StepperNativeTestSupport.key(.keyDown, code: 48, chars: "\t", in: window)
        try await SystemPageHost.settle(window)
        print("STEPPER_TAB custom=\(custom) responder=\(String(describing: window.firstResponder))")
        return window.firstResponder is NSStepper
    }

    @Test func keyboardSingleRepeatReleaseAndDisabled() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = StepperProbe()
        let window = fixture.window(DaybookStepperProbeView(state: state))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let keyView = try #require(Native.elements(window.contentView).compactMap { $0 as? DaybookStepperKeyView }
            .sorted { $0.convert($0.bounds, to: nil).midY > $1.convert($1.bounds, to: nil).midY }.first)
        #expect(window.makeFirstResponder(keyView))
        #expect(window.firstResponder === keyView)
        for (code, chars, expected) in [(UInt16(126), "\u{F700}", 220), (125, "\u{F701}", 200), (49, " ", 180)] {
            let before = state.writes
            try StepperNativeTestSupport.key(.keyDown, code: code, chars: chars, in: window)
            try StepperNativeTestSupport.key(.keyDown, code: code, chars: chars, repeatKey: true, in: window)
            try await SystemPageHost.settle(window)
            print("DAYBOOK_STEPPER_KEY code=\(code) value=\(state.integer) writes=\(state.writes - before)")
            #expect(state.integer == expected)
            #expect(state.writes == before + 2)
            try StepperNativeTestSupport.key(.keyUp, code: code, chars: chars, in: window)
            try await SystemPageHost.settle(window)
            #expect(state.writes == before + 2)
        }
        try Native.snapshot(window, name: "stepper-keyboard-focused")
        try await StepperTestSupport.click("stepper.integer", increase: true, in: window)
        let clicked = state.integer
        let clickWrites = state.writes
        try StepperNativeTestSupport.key(.keyDown, code: 49, chars: " ", in: window)
        try await SystemPageHost.settle(window)
        #expect(state.integer == clicked + 10 && state.writes == clickWrites + 1)
        for increase in [false, true] {
            try await StepperTestSupport.click("stepper.integer", increase: increase, in: window)
            let value = state.integer
            let writes = state.writes
            for repeatKey in [false, true] {
                try StepperNativeTestSupport.key(.keyDown, code: 49, chars: " ", repeatKey: repeatKey, in: window)
            }
            try StepperNativeTestSupport.key(.keyUp, code: 49, chars: " ", in: window)
            #expect(state.integer == value + (increase ? 20 : -20) && state.writes == writes + 2)
        }
        state.disabled = true
        try await SystemPageHost.settle(window)
        let before = state.writes
        try StepperNativeTestSupport.key(.keyDown, code: 126, chars: "\u{F700}", repeatKey: true, in: window)
        try await SystemPageHost.settle(window)
        #expect(state.writes == before)
        try Native.snapshot(window, name: "stepper-keyboard-disabled")
    }
}
