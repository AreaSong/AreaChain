import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ModernCheckboxTests {
    private typealias Native = SettingsButtonTestSupport

    /// 重构前后运行同一真实控件场景，AX 框及缓存图只证明几何/绘制，不代表真人辅助操作。
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func completionBaseline(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let todo = TodoItem(title: "合成父项", dayKey: "2026-10-01")
        let sub = SubtaskItem(title: "合成子项 / Synthetic subtask", todo: todo)
        fixture.container.mainContext.insert(todo)
        fixture.container.mainContext.insert(sub)
        try fixture.container.mainContext.save()
        var calls = 0
        let content = VStack(alignment: .leading, spacing: 10) {
            HStack {
                ModernCheckbox(isDone: false) { calls += 1 }.accessibilityIdentifier("baseline.open")
                ModernCheckbox(isDone: true) { calls += 1 }.accessibilityIdentifier("baseline.done")
            }
            TaskRowSubtaskInlineList(subtasks: [.init(id: sub.id, todoId: todo.id, title: sub.title, isDone: false)]) { id in
                #expect(id == sub.id)
                calls += 1
            }
        }.padding(16).background(DaybookPalette.fill.page)
        let window = fixture.window(content, locale: locale, scheme: scheme, size: NSSize(width: 320, height: 140))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let buttons = Native.buttons(in: window)
        #expect(buttons.count == 3)
        let frames = try buttons.map { try Native.frame($0, in: window) }
        #expect(frames.filter { abs($0.width - 20) < 0.1 && abs($0.height - 20) < 0.1 }.count == 2)
        #expect(frames.filter { abs($0.width - 14) < 0.1 && abs($0.height - 14) < 0.1 }.count == 1)
        try Native.assertBounds(buttons, in: window)
        try Native.snapshot(window, name: "completion-baseline-\(locale)-\(scheme)")
        for button in buttons {
            try await Native.click(button, in: window)
        }
        #expect(calls == 3)
    }

    @Test(arguments: [ModernCheckbox.Presentation.task, .inlineSubtask, .detailSubtask], [false, true])
    func externalStateRejectionAndLifecycle(presentation: ModernCheckbox.Presentation, reduced: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = CompletionProbe()
        let window = fixture.window(CompletionProbeView(probe: probe, presentation: presentation)
            .environment(\.daybookButtonReduceMotionPreview, reduced)
            .transaction { $0.disablesAnimations = false }, size: NSSize(width: 120, height: 100))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try assertState(false, in: window)
        try await Native.click(Native.button("completion.probe", in: window), in: window)
        #expect(probe.actions == 1 && probe.done)
        try assertState(true, in: window)
        probe.done = false
        probe.reject = true
        try await SystemPageHost.settle(window)
        try await Task.sleep(for: .milliseconds(600))
        let before = try pixels(window)
        try await Native.click(Native.button("completion.probe", in: window), in: window)
        try await Task.sleep(for: .milliseconds(600))
        try assertState(false, in: window)
        #expect(probe.actions == 2)
        #expect(try pixels(window) == before, "拒绝动作后不得残留虚假勾选图形")
        probe.revision += 1
        try await SystemPageHost.settle(window)
        try assertState(false, in: window)
        try await Native.click(Native.button("completion.probe", in: window), in: window)
        probe.visible = false
        try await Task.sleep(for: .milliseconds(600))
        #expect(probe.actions == 3, "重建、动画和拆卸不得再次执行动作")
    }

    @Test(arguments: [ModernCheckbox.Presentation.task, .inlineSubtask, .detailSubtask])
    func disabledAndAccessibility(presentation: ModernCheckbox.Presentation) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = CompletionProbe()
        let window = fixture.window(CompletionProbeView(probe: probe, presentation: presentation))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        probe.disabled = true
        try await SystemPageHost.settle(window)
        let node = try Native.button("completion.probe", in: window)
        #expect((node.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == false)
        try await Native.click(node, in: window)
        _ = node.perform(NSSelectorFromString("accessibilityPerformPress"))
        try await SystemPageHost.settle(window)
        #expect(probe.actions == 0 && !probe.done)
        probe.disabled = false
        try await SystemPageHost.settle(window)
        let enabled = try Native.button("completion.probe", in: window)
        _ = enabled.perform(NSSelectorFromString("accessibilityPerformPress"))
        try await SystemPageHost.settle(window)
        #expect(probe.actions == 1 && probe.done)
        try assertState(true, in: window)
    }

    @Test(arguments: [ModernCheckbox.Presentation.task, .inlineSubtask, .detailSubtask])
    func hitAreaIncludesEmptyCenterAndEdges(presentation: ModernCheckbox.Presentation) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = CompletionProbe()
        probe.reject = true
        let window = fixture.window(CompletionProbeView(probe: probe, presentation: presentation)
            .environment(\.daybookButtonReduceMotionPreview, true))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let rect = try Native.frame(Native.button("completion.probe", in: window), in: window)
        #expect(rect.width == (presentation == .task ? 20 : (presentation == .inlineSubtask ? 14 : 12)))
        for x in [rect.minX + 0.5, rect.midX, rect.maxX - 0.5] {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = try #require(NSEvent.mouseEvent(with: type, location: NSPoint(x: x, y: rect.midY),
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
                NSApp.sendEvent(event)
            }
        }
        #expect(probe.actions == 3)
    }

    private func assertState(_ done: Bool, in window: NSWindow) throws {
        let node = try Native.button("completion.probe", in: window)
        #expect(Native.value(node, "accessibilityLabel") as? String ==
                L10n.string(done ? "checkbox.done" : "checkbox.open", locale: Locale(identifier: "en")))
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func existingGalleryShowsBothPresentationsAndExternalUpdate(locale: String, dark: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let window = fixture.window(DaybookControlsPreview(localeID: locale, dark: dark), locale: locale,
                                    scheme: dark ? .dark : .light, size: NSSize(width: 760, height: 640))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let task = try Native.button("preview.completion.task", in: window)
        let subtask = try Native.button("preview.completion.subtask", in: window)
        let detail = try Native.button("preview.completion.detailSubtask", in: window)
        // 展示页持续增加样例，先沿真实滚动容器显露本组再检查几何与投递点击。
        try await Native.reveal(task, in: window)
        try Native.assertBounds([task, subtask, detail], in: window)
        #expect(try Native.frame(detail, in: window).size == NSSize(width: 12, height: 12))
        let key = Locale(identifier: locale)
        #expect(Native.value(task, "accessibilityLabel") as? String == L10n.string("checkbox.open", locale: key))
        #expect(Native.value(subtask, "accessibilityLabel") as? String == L10n.string("checkbox.done", locale: key))
        let external = try Native.button("preview.completion.external", in: window)
        try await Native.reveal(external, in: window)
        try await Native.click(external, in: window)
        #expect(Native.value(try Native.button("preview.completion.task", in: window), "accessibilityLabel") as? String ==
                L10n.string("checkbox.done", locale: key))
        #expect(Native.value(try Native.button("preview.completion.subtask", in: window), "accessibilityLabel") as? String ==
                L10n.string("checkbox.open", locale: key))
        #expect(Native.value(try Native.button("preview.completion.detailSubtask", in: window), "accessibilityLabel") as? String ==
                L10n.string("checkbox.done", locale: key))
        try Native.snapshot(window, name: "completion-gallery-\(locale)-\(dark)")
    }

    private func pixels(_ window: NSWindow) throws -> Data {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }
}

@Observable @MainActor
private final class CompletionProbe {
    var done = false
    var reject = false
    var disabled = false
    var visible = true
    var revision = 0
    var actions = 0
}

private struct CompletionProbeView: View {
    let probe: CompletionProbe
    let presentation: ModernCheckbox.Presentation

    var body: some View {
        Group {
            if probe.visible {
                ModernCheckbox(isDone: probe.done, presentation: presentation) {
                    probe.actions += 1
                    if !probe.reject { probe.done.toggle() }
                }
                .accessibilityIdentifier("completion.probe")
                .disabled(probe.disabled)
                .id(probe.revision)
            }
        }.padding(16).background(DaybookPalette.fill.page)
    }
}
