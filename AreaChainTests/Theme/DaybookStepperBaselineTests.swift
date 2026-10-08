import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 保留原生对照；只能由隔离 XCTest 宿主启动。
@Suite(.serialized) @MainActor
struct DaybookStepperBaselineTests {
    typealias Native = SettingsButtonTestSupport

    @Test func nativeBoundaries() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = StepperProbe()
        let window = fixture.window(StepperBaselineView(state: state))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        for node in Native.elements(window.contentView) {
            if let role = Native.value(node, "accessibilityRole") as? String, role != "AXUnknown" {
                print("STEPPER_NODE \(type(of: node)) \(role) \(MenuButtonTestSupport.title(node))")
            }
        }
        for initial in [20, 25, 989, 990, 995, 999, 10, 1005] {
            for increase in [true, false] {
                state.integer = initial
                state.writes = 0
                try await SystemPageHost.settle(window)
                #expect(state.integer == initial && state.writes == 0)
                try await StepperNativeTestSupport.click(increase: increase, index: 0, in: window)
                print("STEPPER_INT \(initial) \(increase ? "+" : "-") -> \(state.integer) writes=\(state.writes)")
            }
        }
        for initial in [0.1, 0.35, 1.9, 1.95, 1.9999999999999998, 2.0, 0.05, 2.1] {
            for increase in [true, false] {
                state.decimal = initial
                state.writes = 0
                try await SystemPageHost.settle(window)
                #expect(state.decimal == initial && state.writes == 0)
                try await StepperNativeTestSupport.click(increase: increase, index: 1, in: window)
                print("STEPPER_DECIMAL \(initial) \(increase ? "+" : "-") -> \(state.decimal) writes=\(state.writes)")
            }
        }
        try Native.snapshot(window, name: "stepper-native-baseline")
    }

    @Test func nativeTrackingAndFocus() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = StepperProbe()
        let window = fixture.window(StepperBaselineView(state: state))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let field = try #require(Native.elements(window.contentView).compactMap { $0 as? NSTextField }.first { $0.isEditable })
        #expect(window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("unsubmitted", replacementRange: editor.selectedRange())
        try await StepperNativeTestSupport.click(increase: true, index: 0, in: window)
        print("STEPPER_FOCUS neighbor=\(field.currentEditor() === window.firstResponder)")
        let node = try #require(StepperNativeTestSupport.steppers(in: window).first)
        let rect = try Native.frame(node, in: window)
        let point = NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.75)
        state.writes = 0
        try await StepperNativeTestSupport.hold(point, in: window)
        print("STEPPER_HOLD writes=\(state.writes) value=\(state.integer)")
        let released = state.writes
        try await Task.sleep(for: .milliseconds(400))
        #expect(state.writes == released)
        try await StepperNativeTestSupport.hold(point, cancel: true, in: window)
        print("STEPPER_CANCEL writes=\(state.writes - released)")
        let cancelled = state.writes
        try await Task.sleep(for: .milliseconds(400))
        #expect(state.writes == cancelled)
        if let responder = Native.elements(window.contentView).compactMap({ $0 as? NSStepper })
            .sorted(by: { $0.convert($0.bounds, to: nil).midY > $1.convert($1.bounds, to: nil).midY }).first {
            let accepted = window.makeFirstResponder(responder)
            print("STEPPER_KEY focus=\(accepted) full=\(NSApp.isFullKeyboardAccessEnabled)")
            for (code, chars) in [(UInt16(126), "\u{F700}"), (125, "\u{F701}"), (49, " "), (123, "\u{F702}"), (124, "\u{F703}")] {
                let before = state.writes
                for phase in [NSEvent.EventType.keyDown, .keyUp] {
                    try StepperNativeTestSupport.key(phase, code: code, chars: chars, in: window)
                    print("STEPPER_KEY_PHASE code=\(code) phase=\(phase.rawValue) writes=\(state.writes - before) value=\(state.integer)")
                }
                try StepperNativeTestSupport.key(.keyDown, code: code, chars: chars, repeatKey: true, in: window)
                print("STEPPER_KEY_REPEAT code=\(code) writes=\(state.writes - before) value=\(state.integer)")
                try await SystemPageHost.settle(window)
                print("STEPPER_KEY code=\(code) writes=\(state.writes - before)")
            }
            try await StepperNativeTestSupport.click(increase: true, index: 0, in: window)
            let before = state.integer
            try StepperNativeTestSupport.key(.keyDown, code: 49, chars: " ", in: window)
            try await SystemPageHost.settle(window)
            #expect(state.integer == before + 10, "原生空格沿鼠标最后选择的方向")
        }
    }
}

@MainActor @Observable
final class StepperProbe {
    var integer = 200
    var decimal = 0.5
    var writes = 0
    var reject = false
    var disabled = false
    var trace: StepperEventTrace?
    var integerBinding: Binding<Int> {
        Binding(get: { self.integer }, set: {
            self.trace?.mark("write", value: Double($0), increase: $0 > self.integer)
            self.writes += 1
            if !self.reject { self.integer = $0 }
        })
    }
    var decimalBinding: Binding<Double> {
        Binding(get: { self.decimal }, set: {
            self.trace?.mark("write", value: $0, increase: $0 > self.decimal)
            self.writes += 1
            if !self.reject { self.decimal = $0 }
        })
    }
}

struct StepperBaselineView: View {
    @Bindable var state: StepperProbe
    @State private var text = ""
    var body: some View {
        VStack {
            TextField("Title", text: $text)
            Stepper(value: state.integerBinding, in: 20...999, step: 10) { Text("clipboard.limit \(state.integer)") }
            Stepper(value: state.decimalBinding, in: 0.1...2, step: 0.1) { Text(verbatim: String(state.decimal)) }
        }.disabled(state.disabled).padding()
    }
}

@MainActor
enum StepperNativeTestSupport {
    typealias Native = SettingsButtonTestSupport
    static func steppers(in window: NSWindow) -> [NSObject] {
        Native.elements(window.contentView).filter {
            Native.value($0, "accessibilityRole") as? String == "AXIncrementor"
        }.sorted { ((try? Native.frame($0, in: window))?.midY ?? 0) > ((try? Native.frame($1, in: window))?.midY ?? 0) }
    }

    static func point(custom: Bool, increase: Bool, in window: NSWindow) throws -> NSPoint {
        if custom {
            return try StepperTestSupport.point(StepperTestSupport.node("stepper.integer", in: window), increase: increase, in: window)
        }
        let node = try #require(steppers(in: window).first)
        let rect = try Native.frame(node, in: window)
        if let control = Native.elements(window.contentView).compactMap({ $0 as? NSStepper }).first {
            var delay: Float = 0
            var interval: Float = 0
            control.cell?.getPeriodicDelay(&delay, interval: &interval)
            print("F_NATIVE_CONFIG continuous=\(control.isContinuous) autorepeat=\(control.autorepeat) delay=\(delay) interval=\(interval) min=\(control.minValue) max=\(control.maxValue) step=\(control.increment)")
            #expect(control.isContinuous && control.autorepeat)
        }
        return NSPoint(x: rect.midX, y: rect.minY + rect.height * (increase ? 0.75 : 0.25))
    }

    static func quickClick(_ point: NSPoint, in window: NSWindow) async throws {
        NSApp.postEvent(try MenuButtonTestSupport.mouse(.leftMouseDown, at: point, in: window), atStart: false)
        try await Task.sleep(for: .milliseconds(20))
        NSApp.postEvent(try MenuButtonTestSupport.mouse(.leftMouseUp, at: point, in: window), atStart: false)
        try await Task.sleep(for: .milliseconds(20))
    }

    static func click(increase: Bool, index: Int, in window: NSWindow) async throws {
        let nodes = steppers(in: window)
        try #require(nodes.indices.contains(index))
        let rect = try Native.frame(nodes[index], in: window)
        let point = NSPoint(x: rect.midX, y: rect.minY + rect.height * (increase ? 0.75 : 0.25))
        try await quickClick(point, in: window)
        try await SystemPageHost.settle(window)
    }

    @discardableResult
    static func hold(_ point: NSPoint, cancel: Bool = false, in window: NSWindow) async throws -> StepperEventTrace {
        try await perform(point, in: window, script: StepperPointerScript(outAt: cancel ? 0.05 : nil))
    }

    /// 只投递应用内 NSEvent；不改变系统按键状态，不能据此证明原生长按重复频率。
    @discardableResult
    static func perform(_ point: NSPoint, in window: NSWindow,
                        script: StepperPointerScript = StepperPointerScript(),
                        trace suppliedTrace: StepperEventTrace? = nil) async throws -> StepperEventTrace {
        let trace = suppliedTrace ?? StepperEventTrace()
        try #require(window.isKeyWindow && NSApp.isActive)
        trace.mark("begin")
        let outside = NSPoint(x: point.x - 80, y: point.y)
        var events: [(Double, NSEvent.EventType, NSPoint, String)] = [(0, .leftMouseDown, point, "down")]
        if let time = script.outAt { events.append((time, .leftMouseDragged, outside, "out")) }
        if let time = script.reenterAt { events.append((time, .leftMouseDragged, point, "in")) }
        let releasePoint = script.outAt != nil && script.reenterAt == nil ? outside : point
        events.append((script.duration, .leftMouseUp, releasePoint, "up"))
        let monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { event in
            MainActor.assumeIsolated {
                if event.windowNumber == window.windowNumber { trace.mark("received-\(event.type.rawValue)") }
            }
            return event
        }
        var timers: [Timer] = []
        defer {
            timers.forEach { $0.invalidate() }
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
        for (index, item) in events.enumerated() {
            timers.append(schedule(after: item.0) {
                trace.mark(item.3)
                if let event = NSEvent.mouseEvent(with: item.1, location: item.2, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: index + 1, clickCount: 1, pressure: item.1 == .leftMouseUp ? 0 : 1) {
                    trace.eventTimes.append(event.timestamp)
                    NSApp.postEvent(event, atStart: false)
                }
            })
        }
        if let mutation = script.mutation {
            timers.append(schedule(after: script.mutationAt) {
                trace.mark("mutation")
                mutation()
            })
        }
        try await Task.sleep(for: .seconds(script.duration + 0.5))
        try await SystemPageHost.settle(window)
        #expect(trace.eventTimes.count == events.count)
        #expect(zip(trace.eventTimes, trace.eventTimes.dropFirst()).allSatisfy { $0 < $1 })
        #expect(trace.items.contains { $0.kind == "received-1" }, "必须实际派发 mouseDown")
        trace.mark("settled")
        return trace
    }

    private static func schedule(after delay: Double, action: @escaping @MainActor () -> Void) -> Timer {
        let timer = Timer(timeInterval: max(0.001, delay), repeats: false) { _ in
            MainActor.assumeIsolated { action() }
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .eventTracking)
        return timer
    }

    static func key(_ phase: NSEvent.EventType, code: UInt16, chars: String,
                    repeatKey: Bool = false, in window: NSWindow) throws {
        NSApp.sendEvent(try #require(NSEvent.keyEvent(with: phase, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: chars, charactersIgnoringModifiers: chars, isARepeat: repeatKey, keyCode: code)))
    }
}

struct StepperPointerScript {
    var duration = 1.2
    var outAt: Double?
    var reenterAt: Double?
    var mutationAt = 0.35
    var mutation: (@MainActor () -> Void)?
}

/// 合成数据的每次 setter 调用与投递时刻；不把观察到重复写入当成原生等价证据。
@MainActor
final class StepperEventTrace {
    struct Item {
        let time: TimeInterval
        let kind: String
        let value: Double?
        let increase: Bool?
        let eventTimestamp: TimeInterval?
    }
    private let start = ProcessInfo.processInfo.systemUptime
    var items: [Item] = []
    var eventTimes: [TimeInterval] = []
    var writes: [Item] { items.filter { $0.kind == "write" } }

    func mark(_ kind: String, value: Double? = nil, increase: Bool? = nil, eventTimestamp: TimeInterval? = nil) {
        let time = ProcessInfo.processInfo.systemUptime - start
        items.append(Item(time: time, kind: kind, value: value, increase: increase, eventTimestamp: eventTimestamp))
        print("F_TRACE t=\(time) phase=\(kind) direction=\(String(describing: increase)) value=\(String(describing: value)) mode=\(String(describing: RunLoop.current.currentMode)) event=\(NSApp.currentEvent?.type.rawValue ?? 0) timestamp=\(NSApp.currentEvent?.timestamp ?? 0)")
    }

    func assertWritesBefore(_ kind: String) throws {
        let end = try #require(items.first { $0.kind == kind }).time
        #expect(writes.allSatisfy { $0.time < end }, "\(kind) 后不得出现迟到写入")
    }

    func assertPressAndRelease(increase: Bool) throws {
        let down = try #require(items.first { $0.kind == "down" }).time
        let up = try #require(items.first { $0.kind == "up" }).time
        let first = try #require(writes.first)
        #expect(first.time >= down && first.time < up)
        // 原生 cell 配置为 500ms，公共重复实测约 480ms；100ms 仅采样首写，不是计数容差。
        #expect(writes.filter { $0.time < down + 0.1 }.count == 1)
        #expect(writes.allSatisfy { $0.increase == increase })
        try assertWritesBefore("up")
    }
}
