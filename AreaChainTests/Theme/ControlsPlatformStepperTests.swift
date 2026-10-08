import AppKit
import Testing
@testable import AreaChain

/// 合成事件只核验记录器路由和缺失释放处理，不构造真实持续按压证据。
@Suite(.serialized) @MainActor
struct ControlsPlatformStepperTests {
    @Test(arguments: [ControlsPlatformAcceptance.Scene.nativeStepper, .daybookStepper])
    func releaseObservationRequiresCurrentPressAndActualEvent(scene: ControlsPlatformAcceptance.Scene) async throws {
        var now = ProcessInfo.processInfo.systemUptime
        let session = ControlsPlatformAcceptance(now: { now })
        defer { session.close() }
        session.start(gallery: ControlsPlatformTestSupport.gallery())
        session.selection = scene
        session.openSelected()
        let window = try #require(session.auxiliary)
        try await SystemPageHost.settle(window)
        let state = try #require(session.stepper)
        let trace = try #require(state.trace)
        if scene == .nativeStepper {
            state.integerBinding.wrappedValue = 510
            try await SystemPageHost.settle(window)
            #expect(FormInputTestSupport.labels(in: window).contains("NSStepper · 510"))
            let reset = try SettingsButtonTestSupport.button("设为 / Set 500", in: window)
            try await SecureInputTestSupport.ready(window)
            try await SettingsButtonTestSupport.click(reset, in: window)
            #expect(FormInputTestSupport.labels(in: window).contains("NSStepper · 500"))
            let native = SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSStepper }.first
            #expect(native?.integerValue == 500)
            trace.items.removeAll()
            state.writes = 0
        }
        let point = try StepperNativeTestSupport.point(custom: scene == .daybookStepper, increase: true, in: window)
        let up = try MenuButtonTestSupport.mouse(.leftMouseUp, at: point, in: window)
        session.observe(up)
        #expect(trace.items.isEmpty)
        let down = try MenuButtonTestSupport.mouse(.leftMouseDown, at: point, in: window)
        session.observe(down)
        #expect(trace.items.map(\.kind) == ["observed-down"])
        now += 3
        session.tick()
        #expect(!trace.items.contains { $0.kind == "release-observation" })
        let release = try MenuButtonTestSupport.mouse(.leftMouseUp, at: point, in: window)
        session.observe(release)
        now += 3
        session.tick()
        #expect(trace.items.map(\.kind) == ["observed-down", "observed-up", "release-observation"])
        #expect(trace.items[1].eventTimestamp == release.timestamp && state.writes == 0)
        session.observe(try MenuButtonTestSupport.mouse(.leftMouseDown, at: point, in: window))
        trace.mark("native-trackingReturned")
        session.observe(try MenuButtonTestSupport.mouse(.leftMouseDown, at: .zero, in: window))
        session.observe(try MenuButtonTestSupport.mouse(.leftMouseUp, at: .zero, in: window))
        #expect(trace.items.filter { $0.kind == "observed-up" }.count == 1)
        session.close()
        let rows = try ControlsPlatformTestSupport.rows(session)
        let recorded = rows.first { $0["phase"] as? String == "observed-up" }
        #expect(recorded?["eventTimestamp"] as? Double == release.timestamp)
    }
}
