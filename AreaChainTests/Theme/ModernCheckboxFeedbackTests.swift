import AppKit
import ObjectiveC
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ModernCheckboxFeedbackTests {
    @Test(arguments: [false, true])
    func detailRowDoesNotRequestHaptics(disabled: Bool) async throws {
        let fixture = try DetailCompletionFixture()
        defer { fixture.native.cleanup() }
        let spy = CompletionHapticSpy()
        defer { spy.restore() }
        let window = fixture.native.window(fixture.row(disabled: disabled), size: NSSize(width: 320, height: 80))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let button = try #require(DetailCompletionFixture.completionButtons(in: window).first)
        try await SettingsButtonTestSupport.click(button, in: window)
        _ = button.perform(NSSelectorFromString("accessibilityPerformPress"))
        try await SystemPageHost.settle(window)
        #expect(fixture.toggles.count == (disabled ? 0 : 2))
        #expect(spy.patterns.isEmpty, "详情不调用触感；关闭动画不能代替此断言")
    }

    @Test(arguments: [ModernCheckbox.Presentation.task, .inlineSubtask], [false, true])
    func existingPresentationsRequestOneHapticPerAction(presentation: ModernCheckbox.Presentation, reduced: Bool) async throws {
        let native = try SettingsButtonTestSupport()
        defer { native.cleanup() }
        let spy = CompletionHapticSpy()
        defer { spy.restore() }
        var calls = 0
        let window = native.window(ModernCheckbox(isDone: false, presentation: presentation) { calls += 1 }
            .environment(\.daybookButtonReduceMotionPreview, reduced)
            .transaction { $0.disablesAnimations = false })
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let button = try SettingsButtonTestSupport.button("checkbox.open", in: window)
        try await SettingsButtonTestSupport.click(button, in: window)
        _ = button.perform(NSSelectorFromString("accessibilityPerformPress"))
        try await Task.sleep(for: .milliseconds(600))
        #expect(calls == 2)
        #expect(spy.patterns == [.alignment, .alignment])
    }
}

/// 仅在串行 XCTest 临时替换系统 performer，记录真实调用，不修改生产反馈 API。
@MainActor
private final class CompletionHapticSpy: NSObject, @preconcurrency NSHapticFeedbackPerformer {
    var patterns: [NSHapticFeedbackManager.FeedbackPattern] = []
    private let method: Method
    private let original: IMP
    private let replacement: IMP

    override init() {
        method = class_getClassMethod(NSHapticFeedbackManager.self, NSSelectorFromString("defaultPerformer"))!
        original = method_getImplementation(method)
        var performer: CompletionHapticSpy?
        let block: @convention(block) (AnyObject) -> AnyObject = { _ in performer! }
        replacement = imp_implementationWithBlock(block)
        super.init()
        performer = self
        method_setImplementation(method, replacement)
    }

    func perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern, performanceTime: NSHapticFeedbackManager.PerformanceTime) {
        patterns.append(pattern)
    }

    func restore() {
        method_setImplementation(method, original)
        imp_removeBlock(replacement)
    }
}
