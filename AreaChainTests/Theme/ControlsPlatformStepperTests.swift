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
        session.close()
        let rows = try ControlsPlatformTestSupport.rows(session)
        let recorded = rows.first { $0["phase"] as? String == "observed-up" }
        #expect(recorded?["eventTimestamp"] as? Double == release.timestamp)
    }
}
