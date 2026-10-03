import AppKit
import ObjectiveC
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookSegmentedMotionTests {
    /// 仅拦截测试进程的系统读取，不修改系统偏好；单独验证 SwiftUI 环境实际命中。
    @Test(arguments: [false, true])
    func systemReadFeedsMotionAndUnmountDoesNotWrite(reduced: Bool) async throws {
        let method = try #require(class_getInstanceMethod(NSWorkspace.self,
            #selector(getter: NSWorkspace.accessibilityDisplayShouldReduceMotion)))
        let block: @convention(block) (AnyObject) -> Bool = { _ in reduced }
        let replacement = imp_implementationWithBlock(block)
        let original = method_setImplementation(method, replacement)
        defer {
            method_setImplementation(method, original)
            imp_removeBlock(replacement)
            NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                                                       object: NSWorkspace.shared)
        }
        #expect(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion == reduced)
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        let probe = SegmentMotionProbe()
        let window = fixture.window(SegmentMotionView(probe: probe))
        defer { SystemPageHost.release(window) }
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                                                   object: NSWorkspace.shared)
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try #require(probe.reduceMotion == reduced, "必须观察系统读取到 SwiftUI 环境的真实路径")
        let tests = DaybookSegmentedControlTests()
        try tests.press(tests.nodes(window)[1])
        try await Task.sleep(for: .milliseconds(30))
        try tests.press(tests.nodes(window)[0])
        try await Task.sleep(for: .milliseconds(30))
        #expect(probe.writes == [2, 1])
        SystemPageHost.release(window)
        try await Task.sleep(for: .milliseconds(600))
        #expect(probe.writes == [2, 1])
    }
}

@MainActor @Observable
private final class SegmentMotionProbe {
    var value = 1
    var writes: [Int] = []
    var reduceMotion: Bool?
}

private struct SegmentMotionView: View {
    @Bindable var probe: SegmentMotionProbe
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        DaybookSegmentedControl(selection: Binding(get: { probe.value }, set: {
            probe.writes.append($0); probe.value = $0
        }), options: [.init(1, "tab.tasks"), .init(2, "tab.diary")])
            .onAppear { probe.reduceMotion = reduceMotion }
            .onChange(of: reduceMotion) { _, value in probe.reduceMotion = value }
            .transaction { $0.disablesAnimations = false }
    }
}
