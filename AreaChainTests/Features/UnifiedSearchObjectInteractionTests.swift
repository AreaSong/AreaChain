import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchObjectInteractionTests {
    @Test func lockClearsNativeCandidateTextWithoutDeletingFixedDraft() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        try fixture.startOperation("todo.completion")
        try await fixture.acceptObjects([.object(0)])
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickResult("unified.objects.choose.target")
        await fixture.controller.objectSelectionTask?.value
        try await host.settle()
        let old = try #require(fixture.controller.objectSelection?.stamp)
        let before = try fixture.draft
        let panel = try #require(SettingsButtonTestSupport.elements(host.window.contentView)
            .compactMap { $0 as? UnifiedSearchOperationBoundary }.first)
        let labels = SettingsButtonTestSupport.elements(panel).compactMap { $0 as? SearchFragmentLabel }
        #expect(labels.contains { !$0.stringValue.isEmpty })
        NotificationCenter.default.post(name: .privacyWillLock, object: fixture.vault)
        #expect(panel.subviews.isEmpty && labels.allSatisfy { $0.stringValue.isEmpty })
        #expect(fixture.controller.objectSelection == nil)
        #expect(try fixture.draft == before)
        #expect(!fixture.controller.acceptObjects(old))
        try host.snapshot("objects-locked")
    }

    @Test func parentReturnAndEscapePreserveOuterQueryAndInputFocus() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        try fixture.startOperation("subtask.create")
        try fixture.typeParameter(.title, text: "合成子任务")
        let query = try fixture.handoff.state().query
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        let responder = host.window.firstResponder
        _ = try await fixture.chooseObjects(.parameter(.parent))
        try await host.settle()
        #expect(host.window.firstResponder === responder)
        try await host.key(125, "\u{F701}")
        try await host.key(36, "\r")
        await fixture.controller.objectSelectionTask?.value
        try await host.settle()
        #expect(try fixture.draft.targets == .none)
        #expect(try fixture.draft.arguments.contains { $0.parameter == .parent && $0.value == .object(.object(0)) })
        #expect(try fixture.handoff.state().query == query)
        try host.snapshot("objects-parent-parameter")
        let before = try fixture.draft
        try await host.clickResult("unified.objects.choose.parent")
        await fixture.controller.objectSelectionTask?.value
        try await host.settle()
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(53, "\u{1b}")
        #expect(fixture.controller.objectSelection == nil)
        #expect(try fixture.draft == before)
    }

    @Test func nativeInputCandidateConfirmationCoordinatorAndPreview() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        editor.insertText("/tasks/completion", replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(53, "\u{1b}")
        try await host.key(36, "\r")
        #expect(try fixture.draft.commandID.rawValue == "todo.completion")
        try await host.clickResult("unified.objects.choose.target")
        await fixture.controller.objectSelectionTask?.value
        try await host.settle()
        #expect(fixture.controller.objectSelection != nil)
        #expect(try fixture.draft.targets == .none)
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        #expect(try !host.state.suggestions.isActive)
        try await host.key(125, "\u{F701}")
        try await host.key(49, " ")
        try await host.key(125, "\u{F701}")
        try await host.key(49, " ")
        #expect(fixture.controller.objectSelection?.objects.count == 2)
        try host.snapshot("objects-keyboard-temporary")
        try await host.key(48, "\t")
        await fixture.controller.objectSelectionTask?.value
        try await host.settle()
        #expect(fixture.controller.objectSelection == nil)
        #expect(try fixture.draft.targets.objects.count == 2)
        let objects = try fixture.draft.targets.objects
        #expect(objects.allSatisfy { fixture.controller.objectPreview($0) != nil })
        try host.snapshot("objects-keyboard-fixed")
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.operationMessage == "unified.operation.submitBlocked")
        #expect(try fixture.handoff.state().plan.items.isEmpty && fixture.handoff.state().execution == nil)
        #expect(fixture.opens.isEmpty)
    }

    @Test func cancelReturnsFocusAndNativeRemovalPreservesOtherParameters() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        try fixture.startOperation("todo.title")
        try fixture.typeParameter(.title, text: "新的合成标题")
        try await fixture.acceptObjects([.object(0)])
        let host = UnifiedSearchTestHost(layout: .compact, width: 304, locale: "zh-Hans", dark: true,
                                         results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        let before = try fixture.draft
        try await host.clickResult("unified.objects.choose.target")
        await fixture.controller.objectSelectionTask?.value
        try await host.settle()
        try await host.clickResult("unified.objects.cancel")
        #expect(try fixture.draft == before)
        #expect(fixture.controller.objectReturnRevision > 0)
        let choose = try host.resultNode("unified.objects.choose.target")
        // SwiftUI 辅助节点未声明完整 NSAccessibilityProtocol；按 SDK 的 BOOL getter 读取，不能用对象 perform。
        let focusGetter = NSSelectorFromString("isAccessibilityFocused")
        try #require(choose.responds(to: focusGetter))
        let readFocus = unsafeBitCast(choose.method(for: focusGetter),
            to: (@convention(c) (AnyObject, Selector) -> Bool).self)
        #expect(readFocus(choose, focusGetter))
        try await host.key(49, " ")
        let release = try #require(NSEvent.keyEvent(with: .keyUp, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: host.window.windowNumber,
            context: nil, characters: " ", charactersIgnoringModifiers: " ", isARepeat: false, keyCode: 49))
        NSApp.sendEvent(release)
        try await host.settle()
        await fixture.controller.objectSelectionTask?.value
        #expect(fixture.controller.objectSelection != nil, "焦点返回发起按钮后，空格可重新打开选择器")
        try await host.settle()
        try await host.clickResult("unified.objects.cancel")
        // 固定目标与下方搜索结果复用行标识；必须操作原参数面板里的移除按钮。
        let panel = try #require(SettingsButtonTestSupport.elements(host.window.contentView)
            .compactMap { $0 as? UnifiedSearchOperationBoundary }.first)
        let remove = try #require(SettingsButtonTestSupport.elements(panel).first {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String
                == "unified.select." + CommandObjectReference.object(0).searchIdentifier
        })
        try await SettingsButtonTestSupport.reveal(remove, in: host.window)
        #expect(try panel.convert(panel.bounds, to: nil).contains(SettingsButtonTestSupport.frame(remove, in: host.window)))
        try #require(remove.responds(to: focusGetter))
        let removeFocused = unsafeBitCast(remove.method(for: focusGetter),
            to: (@convention(c) (AnyObject, Selector) -> Bool).self)
        for _ in 0..<8 {
            if removeFocused(remove, focusGetter) { break }
            try await host.key(48, "\t")
        }
        try #require(removeFocused(remove, focusGetter), "Tab 可到达固定目标的移除按钮")
        try await host.key(49, " ")
        NSApp.sendEvent(release)
        try await host.settle()
        #expect(try fixture.draft.targets == .none)
        #expect(try fixture.draft.arguments.first?.value == .shortText("新的合成标题"))
        try host.snapshot("objects-removed-keeps-title")
    }

    @Test func realWindowBlurSynchronouslyRemovesSelectionAndTargetDetails() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        try fixture.startOperation("todo.completion")
        try await fixture.acceptObjects([.object(0)])
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickResult("unified.objects.choose.target")
        await fixture.controller.objectSelectionTask?.value
        try await host.settle()
        let old = try #require(fixture.controller.objectSelection?.stamp)
        let before = try fixture.draft
        let panel = try #require(SettingsButtonTestSupport.elements(host.window.contentView)
            .compactMap { $0 as? UnifiedSearchOperationBoundary }.first)
        let other = NSWindow(contentRect: .init(x: 20, y: 20, width: 100, height: 100),
                             styleMask: [.titled], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        defer { SystemPageHost.release(other) }
        other.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(other)
        #expect(panel.subviews.isEmpty)
        #expect(fixture.controller.objectSelection == nil)
        #expect(!fixture.controller.acceptObjects(old))
        #expect(try fixture.draft == before)
        try host.snapshot("objects-blurred")
    }
}
