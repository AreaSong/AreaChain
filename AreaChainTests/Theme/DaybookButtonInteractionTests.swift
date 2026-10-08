import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookButtonInteractionTests {
    @Test(arguments: [false, true])
    func disabledButtonsRejectMouseAndShortcut(disabled: Bool) async throws {
        var actions = 0
        let content = HStack {
            DaybookIconButton(systemName: "trash", label: "alert.trash.move", role: .destructive) { actions += 1 }
                .accessibilityIdentifier("button.icon")
            Button("common.save") { actions += 1 }
                .buttonStyle(DaybookButtonStyle(.prominent))
                .accessibilityIdentifier("button.text")
            CommandReturnButton(enabled: true, label: "common.save") { actions += 1 }
                .keyboardShortcut(.return, modifiers: .command)
        }.disabled(disabled).padding()
        let window = window(content)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        for id in ["button.icon", "button.text", "syntax.commandReturn.button"] {
            try click(NativeSyntaxUI.center(id, in: window), in: window)
            try await SystemPageHost.settle(window)
        }
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: 36
        ))
        _ = window.performKeyEquivalent(with: event)
        try await SystemPageHost.settle(window)
        #expect(actions == (disabled ? 0 : 4))
        #expect(accessibilityLabel("button.icon", in: window) == L10n.string("alert.trash.move", locale: Locale(identifier: "en")))
    }

    @Test(arguments: ["zh-Hans", "en"], [false, true])
    func galleryRenders(locale: String, dark: Bool) async throws {
        let window = window(DaybookControlsPreview(localeID: locale, dark: dark, longLabels: true),
                            size: NSSize(width: 760, height: 640))
        defer { SystemPageHost.release(window) }
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        try await SystemPageHost.settle(window)
        let name = L10n.string("dev.controls.sample", locale: Locale(identifier: locale))
        #expect(name != "dev.controls.sample")
        #expect(SystemPageHost.labels(in: window).contains(name))
        let native = SettingsButtonTestSupport.self
        let segmentTitle = L10n.string("dev.controls.segments", locale: Locale(identifier: locale))
        #expect(native.elements(window.contentView).contains {
            native.value($0, "accessibilityValue") as? String == segmentTitle
        })
        try native.snapshot(window, name: "segment-gallery-\(locale)-\(dark)")
        let checkbox = try #require(native.elements(window.contentView).first {
            native.value($0, "accessibilityIdentifier") as? String == "preview.checkbox"
        })
        #expect(native.value(checkbox, "accessibilityLabel") as? String ==
                L10n.string("dev.controls.checkbox.longLabel", locale: Locale(identifier: locale)))
        #expect((native.value(checkbox, "accessibilityValue") as? NSNumber)?.boolValue == true)
        try await native.reveal(checkbox, in: window)
        try native.assertBounds([checkbox], in: window)
        try await NativeSyntaxUI.prepareFocus(in: window)
        let external = try native.button("preview.checkbox.external", in: window)
        try await native.reveal(external, in: window)
        try await native.click(external, in: window)
        #expect((native.value(checkbox, "accessibilityValue") as? NSNumber)?.boolValue == false)
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AreaChainButtonQA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent("buttons-\(locale)-\(dark ? "dark" : "light").png"))
    }

    /// 通过测试环境变量保留窗口供人工交互；默认只做挂载，不影响日常测试耗时。
    @Test func interactiveGallery() async throws {
        let platform = ProcessInfo.processInfo.environment["AREACHAIN_PLATFORM_QA"] == "1"
            ? ControlsPlatformAcceptance() : nil
        let content = Group {
            if let platform {
                VStack(spacing: 0) {
                    ControlsPlatformToolbar(session: platform)
                    DaybookControlsPreview()
                }
            } else { DaybookControlsPreview() }
        }
        let window = window(content, size: NSSize(width: 760, height: 640))
        defer { SystemPageHost.release(window) }
        defer { platform?.close() }
        window.title = "Daybook Controls (QA)"
        let seconds = min(600, max(0, Int(ProcessInfo.processInfo.environment["AREACHAIN_CONTROLS_PREVIEW_SECONDS"] ?? "0") ?? 0))
        platform?.start(gallery: window, seconds: TimeInterval(seconds))
        do {
            try await NativeSyntaxUI.prepareFocus(in: window)
            if let platform {
                try await platform.waitUntilFinished()
                #expect(platform.fixtureFailures == 0 && platform.evidence.failure == nil)
                return
            }
        } catch {
            platform?.close(reason: error is CancellationError ? .cancelled : .error)
            throw error
        }
        let deadline = ContinuousClock.now + .seconds(seconds)
        while window.isVisible && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    @Test func platformFixturesMountAndRelease() async throws {
        let platform = ControlsPlatformAcceptance()
        defer { platform.close() }
        let host = window(Text("P QA"))
        platform.start(gallery: host)
        for scene in ControlsPlatformAcceptance.Scene.allCases {
            platform.selection = scene
            platform.openSelected()
            #expect(platform.fixtureFailures == 0)
            #expect(platform.activeWindowNumber != nil)
            try await Task.sleep(for: .milliseconds(250))
        }
        platform.close()
        #expect(platform.activeWindowNumber == nil)
    }

    @Test func platformToolbarOpensAndRecordsScene() async throws {
        let platform = ControlsPlatformAcceptance()
        let host = window(VStack(spacing: 0) {
            ControlsPlatformToolbar(session: platform)
            DaybookControlsPreview()
        }, size: NSSize(width: 760, height: 640))
        defer { SystemPageHost.release(host) }
        defer { platform.close() }
        try await NativeSyntaxUI.prepareFocus(in: host)
        platform.start(gallery: host)
        try await SystemPageHost.settle(host)
        let button = try SettingsButtonTestSupport.button("打开 / Open", in: host)
        try SettingsButtonTestSupport.assertBounds([button], in: host)
        let frame = try SettingsButtonTestSupport.frame(button, in: host)
        let point = NSPoint(x: frame.midX, y: frame.midY)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            NSApp.postEvent(try MenuButtonTestSupport.mouse(type, at: point, in: host), atStart: false)
        }
        try await SystemPageHost.settle(host)
        #expect(platform.fixtureFailures == 0 && platform.recordedOpens == 1)
        #expect(platform.activeWindowNumber != nil)
        let evidence = try String(contentsOf: #require(platform.evidenceURL), encoding: .utf8)
        #expect(evidence.contains("\"kind\":\"open\""))
    }

    @Test(arguments: ["zh-Hans", "en"], [false, true])
    func platformFeedbackIsVisible(locale: String, dark: Bool) async throws {
        let platform = ControlsPlatformAcceptance()
        platform.chinese = locale == "zh-Hans"
        platform.dark = dark
        let host = window(ControlsPlatformToolbar(session: platform), size: NSSize(width: 700, height: 320))
        defer { platform.close() }
        platform.start(gallery: host)
        platform.openSelected()
        let input = try #require(platform.input)
        input.draft.text = "abc"
        input.draft.submit("todo")
        try await SystemPageHost.settle(input.window)
        let labels = FormInputTestSupport.labels(in: input.window).joined(separator: " ")
        #expect(labels.contains("Synthetic counters") && labels.contains("不创建生产列表记录"))
        #expect(labels.contains(platform.evidence.runID) && labels.contains(platform.lastCallback))
        #expect(labels.contains("待办 / Todo: 1") && labels.contains("手记 / Diary: 0"))
        try SystemPageHost.assertContained(["qa.capture.counts", "qa.capture.callback", "qa.lifecycle.status"], in: input.window)
        try SettingsButtonTestSupport.snapshot(input.window, name: "P-feedback-\(locale)-\(dark)")
    }

    @Test(arguments: [ControlsPlatformAcceptance.Scene.nativeStepper, .daybookStepper])
    func platformStepperObservationPreservesTrace(scene: ControlsPlatformAcceptance.Scene) throws {
        let platform = ControlsPlatformAcceptance()
        defer { platform.close() }
        platform.start(gallery: window(Text("P QA")))
        platform.selection = scene
        platform.openSelected()
        let state = try #require(platform.stepper)
        let trace = try #require(state.trace)
        state.integerBinding.wrappedValue = 510
        let phases = trace.items.map(\.kind)
        let writes = state.writes
        platform.recordObservation()
        platform.close()
        #expect(trace.items.map(\.kind) == phases && state.integer == 510 && state.writes == writes)
        let rows = try ControlsPlatformTestSupport.rows(platform)
        #expect(rows.filter { $0["kind"] as? String == "stepper-trace" }.count == phases.count)
    }

    private func window<Content: View>(_ content: Content, size: NSSize = NSSize(width: 400, height: 160)) -> NSWindow {
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        let host = NSHostingView(rootView: content.environment(\.locale, Locale(identifier: "en")))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.setContentSize(size)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    private func accessibilityLabel(_ identifier: String, in window: NSWindow) -> String? {
        guard let root = window.contentView else { return nil }
        var queue: [NSObject] = [root]
        var visited = Set<ObjectIdentifier>()
        while let node = queue.popLast() {
            guard visited.insert(ObjectIdentifier(node)).inserted else { continue }
            func value(_ name: String) -> Any? {
                let selector = NSSelectorFromString(name)
                return node.responds(to: selector) ? node.perform(selector)?.takeUnretainedValue() : nil
            }
            if value("accessibilityIdentifier") as? String == identifier,
               let name = (value("accessibilityLabel") ?? value("accessibilityTitle")) as? String {
                return name
            }
            if let view = node as? NSView { queue.append(contentsOf: view.subviews) }
            if let children = value("accessibilityChildren") as? [NSObject] { queue.append(contentsOf: children) }
        }
        return nil
    }

    private func click(_ point: NSPoint, in window: NSWindow) throws {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            NSApp.sendEvent(event)
        }
    }
}
