import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookStepperTests {
    typealias Native = SettingsButtonTestSupport

    @Test func observedNativeBoundariesAndRoundTrips() {
        let integers = [(20, 30, 20), (25, 35, 20), (989, 999, 979), (990, 999, 980),
                        (995, 999, 985), (999, 999, 989), (10, 30, 20), (1005, 999, 989)]
        for (value, plus, minus) in integers {
            #expect(DaybookStepping.next(value, in: 20...999, step: 10, increase: true) == (plus == value ? nil : plus))
            #expect(DaybookStepping.next(value, in: 20...999, step: 10, increase: false) == (minus == value ? nil : minus))
        }
        let decimals = [(0.1, 0.2, 0.1), (0.35, 0.44999999999999996, 0.24999999999999997),
                        (1.9, 2.0, 1.7999999999999998), (1.95, 2.0, 1.8499999999999999),
                        (2.0.nextDown, 2.0, 1.8999999999999997), (2.0, 2.0, 1.9),
                        (0.05, 0.2, 0.1), (2.1, 2.0, 1.9)]
        for (value, plus, minus) in decimals {
            #expect(DaybookStepping.next(value, in: 0.1...2, step: 0.1, increase: true) == (plus == value ? nil : plus))
            #expect(DaybookStepping.next(value, in: 0.1...2, step: 0.1, increase: false) == (minus == value ? nil : minus))
        }
        var decimal = 0.1
        for _ in 0..<19 { decimal = DaybookStepping.next(decimal, in: 0.1...2, step: 0.1, increase: true)! }
        #expect(decimal == 2)
        for _ in 0..<19 { decimal = DaybookStepping.next(decimal, in: 0.1...2, step: 0.1, increase: false)! }
        #expect(decimal == 0.1)
        #expect(DaybookStepping.next(decimal, in: 0.1...2, step: 0.1, increase: false) == nil)
        decimal = 1
        for _ in 0..<9 { decimal = DaybookStepping.next(decimal, in: 0.1...2, step: 0.1, increase: false)! }
        #expect(decimal == 0.1, "端点尾差不能要求额外一次无可见变化的操作")
        var integer = 25
        for direction in [true, false] { integer = DaybookStepping.next(integer, in: 20...999, step: 10, increase: direction)! }
        #expect(integer == 25)
        #expect(DaybookStepping.next(0.35, in: 0.1...2, step: 0, increase: true) == nil)
        #expect(DaybookStepping.next(Double.nan, in: 0.1...2, step: 0.1, increase: true) == nil)
    }

    @Test(arguments: ["en", "zh-Hans"])
    func bindingAndAccessibility(locale: String) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = StepperProbe()
        state.integer = 25
        state.decimal = 0.35
        let window = fixture.window(DaybookStepperProbeView(state: state), locale: locale)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        #expect(state.integer == 25 && state.decimal == 0.35 && state.writes == 0)
        try await StepperTestSupport.click("stepper.integer", increase: true, in: window)
        #expect(state.integer == 35 && state.writes == 1)
        try await StepperTestSupport.click("stepper.integer", increase: false, in: window)
        #expect(state.integer == 25 && state.writes == 2)
        state.integer = 995
        try await SystemPageHost.settle(window)
        try StepperTestSupport.assertValue("995", id: "stepper.integer", in: window)
        state.reject = true
        try await StepperTestSupport.click("stepper.integer", increase: true, in: window)
        #expect(state.integer == 995 && state.writes == 3)
        try StepperTestSupport.assertValue("995", id: "stepper.integer", in: window)
        state.reject = false
        try StepperTestSupport.adjust("stepper.integer", increase: true, in: window)
        try await SystemPageHost.settle(window)
        #expect(state.integer == 999 && state.writes == 4)
        try await StepperTestSupport.click("stepper.integer", increase: true, in: window)
        try StepperTestSupport.adjust("stepper.integer", increase: true, in: window)
        #expect(state.integer == 999 && state.writes == 4)
        try StepperTestSupport.adjust("stepper.decimal", increase: true, in: window)
        try await SystemPageHost.settle(window)
        #expect(state.decimal == 0.44999999999999996 && state.writes == 5)
        let node = try StepperTestSupport.node("stepper.integer", in: window)
        let expected = L10n.format("clipboard.limit %lld", locale: Locale(identifier: locale), 999)
        #expect(MenuButtonTestSupport.title(node) == expected)
        state.disabled = true
        try await SystemPageHost.settle(window)
        #expect((try StepperTestSupport.node("stepper.integer", in: window).value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == false)
        try await StepperTestSupport.click("stepper.integer", increase: false, in: window)
        try StepperTestSupport.adjust("stepper.integer", increase: false, in: window)
        #expect(state.writes == 5)
        try Native.snapshot(window, name: "stepper-binding-\(locale)")
    }

    @Test func boundaryClicksHaveExactWriteCounts() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = StepperProbe()
        let window = fixture.window(DaybookStepperProbeView(state: state))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        for (initial, increase, expected) in [(20, false, 20), (25, false, 20), (989, true, 999),
                                             (990, true, 999), (995, true, 999), (999, true, 999), (999, false, 989)] {
            state.integer = initial
            state.writes = 0
            try await SystemPageHost.settle(window)
            #expect(state.integer == initial && state.writes == 0)
            try await StepperTestSupport.click("stepper.integer", increase: increase, in: window)
            #expect(state.integer == expected, "initial=\(initial), increase=\(increase)")
            #expect(state.writes == (initial == expected ? 0 : 1), "initial=\(initial), increase=\(increase)")
        }
        for (initial, increase, expected) in [(0.1, false, 0.1), (0.35, true, 0.44999999999999996),
                                             (1.95, true, 2.0), (2.0.nextDown, true, 2.0), (2.0, true, 2.0)] {
            state.decimal = initial
            state.writes = 0
            try await SystemPageHost.settle(window)
            #expect(state.decimal == initial && state.writes == 0)
            try await StepperTestSupport.click("stepper.decimal", increase: increase, in: window)
            #expect(state.decimal == expected, "initial=\(initial), increase=\(increase)")
            #expect(state.writes == (initial == expected ? 0 : 1))
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func longLabelsAndPreview(locale: String, dark: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = StepperProbe()
        let window = fixture.window(DaybookStepperProbeView(state: state, longLabel: true), locale: locale,
                                    scheme: dark ? .dark : .light, size: NSSize(width: 320, height: 220))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let node = try StepperTestSupport.node("stepper.integer", in: window)
        try Native.assertBounds([node], in: window)
        #expect(try Native.frame(node, in: window).height > 28)
        #expect(MenuButtonTestSupport.title(node) == L10n.string("dev.controls.stepper.longLabel", locale: Locale(identifier: locale)))
        try Native.snapshot(window, name: "stepper-long-\(locale)-\(dark)")
        let preview = fixture.window(DaybookControlsPreview(localeID: locale, dark: dark, longLabels: true),
                                     locale: locale, scheme: dark ? .dark : .light, size: NSSize(width: 600, height: 800))
        defer { SystemPageHost.release(preview) }
        try await SystemPageHost.settle(preview)
        try Native.snapshot(preview, name: "stepper-preview-\(locale)-\(dark)")
    }
}

struct DaybookStepperProbeView: View {
    @Bindable var state: StepperProbe
    var longLabel = false
    @State private var text = ""
    var body: some View {
        VStack {
            TextField("Title", text: $text)
            DaybookStepper(value: state.integerBinding, in: 20...999, step: 10) {
                if longLabel { Text("dev.controls.stepper.longLabel") } else { Text("clipboard.limit \(state.integer)") }
            }.accessibilityIdentifier("stepper.integer")
            DaybookStepper(value: state.decimalBinding, in: 0.1...2, step: 0.1) { Text(verbatim: String(state.decimal)) }
                .accessibilityIdentifier("stepper.decimal")
        }.disabled(state.disabled).padding().background(DaybookPalette.fill.page)
    }
}

@MainActor
enum StepperTestSupport {
    typealias Native = SettingsButtonTestSupport
    static func node(_ id: String, in window: NSWindow) throws -> NSObject {
        try #require(Native.elements(window.contentView).first { Native.value($0, "accessibilityIdentifier") as? String == id })
    }
    static func point(_ node: NSObject, increase: Bool, in window: NSWindow) throws -> NSPoint {
        let rect = try Native.frame(node, in: window)
        return NSPoint(x: rect.maxX - 14 - (increase ? 0 : 28 + DaybookMetrics.Stepper.buttonSpacing), y: rect.midY)
    }
    static func click(_ id: String, increase: Bool, in window: NSWindow) async throws {
        let target = try node(id, in: window)
        try Native.assertBounds([target], in: window)
        let point = try point(target, increase: increase, in: window)
        try await StepperNativeTestSupport.quickClick(point, in: window)
        try await SystemPageHost.settle(window)
    }
    static func adjust(_ id: String, increase: Bool, in window: NSWindow) throws {
        let target = try node(id, in: window)
        let selector = NSSelectorFromString(increase ? "accessibilityPerformIncrement" : "accessibilityPerformDecrement")
        try #require(target.responds(to: selector))
        _ = target.perform(selector)
    }
    static func assertValue(_ value: String, id: String, in window: NSWindow) throws {
        #expect(Native.value(try node(id, in: window), "accessibilityValue") as? String == value)
    }
}
