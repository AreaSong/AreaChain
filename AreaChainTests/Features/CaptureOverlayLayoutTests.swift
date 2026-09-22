import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct CaptureOverlayLayoutTests {
    @Test func initialFocusRecoversFromAnAccessoryActivationPolicy() async throws {
        let previousPolicy = NSApp.activationPolicy()
        defer { NSApp.setActivationPolicy(previousPolicy) }
        NSApp.setActivationPolicy(.accessory)
        let host = try CaptureOverlayHost(workspace: false)
        defer { host.close() }
        try await host.settle()
        #expect(NSApp.activationPolicy() == .regular)
        #expect(NSApp.isActive && host.window.isVisible && host.window.isKeyWindow)
        try await host.enter("前台准备之后输入")
        #expect(host.draft.text == "前台准备之后输入")
    }

    @Test(arguments: [false, true])
    func syntaxAndAttributesNeverResizeTheList(workspace: Bool) async throws {
        let host = try CaptureOverlayHost(workspace: workspace)
        defer { host.close() }
        try await host.settle()
        let baseline = try host.viewportFrame()
        let texts = ["#工作", "#工作 开会 !p1 @09:00"]
            + [9, 10].map { count in (1...count).map { "#标签\($0)" }.joined(separator: " ") }
        for text in texts {
            try await host.enter(text)
            try await host.waitForOverlay("syntax.overlay.candidates")
            _ = try NativeSyntaxUI.frame("syntax.overlay.candidates", in: host.window)
            #expect(try host.viewportFrame() == baseline)
            try host.pressEscape()
            try await host.waitForOverlay("syntax.overlay.candidates", visible: false)
            #expect(!NativeSyntaxUI.identifiers(in: host.window).contains("syntax.overlay.candidates"))
            #expect(try host.viewportFrame() == baseline)
        }
        try await host.enter("")
        #expect(try host.viewportFrame() == baseline)
    }

    @Test
    func attributeDetailsAreReadOnlyAndKeepTheInputGeometry() async throws {
        let workspace = true
        let host = try CaptureOverlayHost(workspace: workspace)
        defer { host.close() }
        try await host.settle()
        let viewport = try host.viewportFrame()
        let button = try NativeSyntaxUI.frame("syntax.attributes.button", in: host.window)
        let input = try host.inputFrame()
        try await host.enter("#工作 #新标签 !p1 @09:00 开会")
        let editor = try host.editor()
        let selection = editor.selectedRange()
        let text = host.draft.text
        #expect(try NativeSyntaxUI.frame("syntax.attributes.button", in: host.window) == button)
        #expect(try host.inputFrame() == input)
        try host.click("syntax.attributes.button")
        try await host.waitForOverlay("syntax.overlay.attributes")
        _ = try NativeSyntaxUI.frame("syntax.overlay.attributes", in: host.window)
        #expect(!NativeSyntaxUI.identifiers(in: host.window).contains("syntax.overlay.candidates"))
        #expect(host.draft.text == text && editor.selectedRange() == selection)
        #expect(host.window.firstResponder === editor)
        #expect(try host.viewportFrame() == viewport)
        #expect(try host.container.mainContext.fetchCount(FetchDescriptor<TagItem>()) == 1)
        #expect(!host.container.mainContext.hasChanges)
        try host.snapshot(workspace ? "workspace-attributes-dark" : "capture-attributes-light")
        try host.pressEscape()
        try await host.waitForOverlay("syntax.overlay.attributes", visible: false)
        #expect(!NativeSyntaxUI.identifiers(in: host.window).contains("syntax.overlay.attributes"))
        #expect(host.draft.text == text && editor.selectedRange() == selection)
        try host.click("syntax.attributes.button")
        try await host.waitForOverlay("syntax.overlay.attributes")
        try host.click("syntax.attributes.close")
        try await host.waitForOverlay("syntax.overlay.attributes", visible: false)
        #expect(!NativeSyntaxUI.identifiers(in: host.window).contains("syntax.overlay.attributes"))
        #expect(host.draft.text == text && editor.selectedRange() == selection)
        try host.click("syntax.attributes.button")
        try await host.waitForOverlay("syntax.overlay.attributes")
        try host.click("syntax.attributes.button")
        try await host.waitForOverlay("syntax.overlay.attributes", visible: false)
        #expect(!NativeSyntaxUI.identifiers(in: host.window).contains("syntax.overlay.attributes"))
    }

    @Test(arguments: [false, true])
    func candidatesDoNotClickThroughAndOnlyOnePanelIsVisible(workspace: Bool) async throws {
        let host = try CaptureOverlayHost(workspace: workspace)
        defer { host.close() }
        try await host.settle()
        let viewport = try host.viewportFrame()
        try await host.enter("#工")
        try await host.waitForOverlay("syntax.overlay.candidates")
        let candidate = try NativeSyntaxUI.frame("syntax.candidate.tag_工作", in: host.window)
        let overlap = try #require(host.rowFrames().map { $0.intersection(candidate) }.first { !$0.isEmpty && !$0.isNull })
        let point = NSPoint(x: overlap.midX, y: overlap.midY)
        try host.click(at: point)
        try await host.settle()
        #expect(host.draft.text == "#工作 ")
        #expect(host.draft.rowActions == 0)
        #expect(try host.editor().selectedRange() == NSRange(location: 4, length: 0))
        #expect(try host.viewportFrame() == viewport)
        if workspace {
            try await host.enter("#新标签")
            try host.click("syntax.attributes.button")
            try await host.waitForOverlay("syntax.overlay.attributes")
            let ids = NativeSyntaxUI.identifiers(in: host.window)
            #expect(ids.contains("syntax.overlay.attributes") && !ids.contains("syntax.overlay.candidates"))
            try await host.enter("#工")
            try await host.waitForOverlay("syntax.overlay.candidates")
            #expect(NativeSyntaxUI.identifiers(in: host.window).contains("syntax.overlay.candidates"))
            #expect(!NativeSyntaxUI.identifiers(in: host.window).contains("syntax.overlay.attributes"))
            try host.snapshot("workspace-candidates-dark")
        } else {
            try host.snapshot("capture-candidates-light")
        }
    }

    @Test(arguments: [false, true])
    func panelFooterDoesNotActivateTheTaskUnderneath(workspace: Bool) async throws {
        let host = try CaptureOverlayHost(workspace: workspace)
        defer { host.close() }
        try await host.settle()
        try await host.enter("#工")
        try await host.waitForOverlay("syntax.overlay.candidates")
        let panel = try NativeSyntaxUI.frame("syntax.overlay.candidates", in: host.window)
        let footer = CGRect(x: panel.minX, y: panel.minY, width: panel.width, height: 22)
        let overlap = try #require(host.rowFrames().map { $0.intersection(footer) }.first { !$0.isEmpty && !$0.isNull })
        try host.click(at: NSPoint(x: overlap.midX, y: overlap.midY))
        try await host.settle()
        #expect(host.draft.rowActions == 0)
        #expect(host.draft.text == "#工")
        #expect(NativeSyntaxUI.identifiers(in: host.window).contains("syntax.overlay.candidates"))
    }

    @Test func inspectorHostsOneUnclippedOverlay() async throws {
        let host = try CaptureOverlayHost(workspace: false)
        defer { host.close() }
        let todo = TodoItem(title: "检查器测试", dayKey: DayKey.today())
        host.container.mainContext.insert(todo)
        try host.container.mainContext.save()
        host.show(
            TaskDetailDrawer(taskID: .constant(todo.id)).environment(\.workspaceEmbedded, true),
            size: NSSize(width: 380, height: 640)
        )
        try await host.settle()
        let editor = try #require(host.nativeViews().compactMap { $0 as? DaybookAppKitTextView }.first)
        #expect(host.window.makeFirstResponder(editor))
        // 聚焦会异步更新 SwiftUI 绑定，等待交接结束再模拟下一次用户输入。
        try await host.settle()
        #expect(host.window.firstResponder === editor)
        editor.insertText("#工", replacementRange: NSRange(location: 0, length: 0))
        try await host.settle()
        #expect(editor.string == "#工")
        try await host.waitForOverlay("syntax.overlay.candidates")
        let panel = try NativeSyntaxUI.frame("syntax.overlay.candidates", in: host.window)
        let content = try #require(host.window.contentView)
        #expect(content.convert(content.bounds, to: nil).contains(panel))
        #expect(host.nativeViews().filter { $0.identifier?.rawValue == "syntax.overlay.event-monitor" }.count == 1)
        try host.click("syntax.candidate.tag_工作")
        try await host.settle()
        #expect(editor.string == "#工作 ")
        #expect(todo.notes.isEmpty)
        #expect(host.window.firstResponder === editor)
        try host.snapshot("inspector-candidates")
    }

    @Test(arguments: [false, true])
    func clearingAfterSubmitKeepsViewportAndScrollPosition(workspace: Bool) async throws {
        let host = try CaptureOverlayHost(workspace: workspace)
        defer { host.close() }
        try await host.settle()
        let scroll = try host.listScrollView()
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 140))
        scroll.reflectScrolledClipView(scroll.contentView)
        try await host.settle()
        let origin = scroll.contentView.bounds.origin
        let viewport = try host.viewportFrame()
        try await host.enter("#工作 保存草稿")
        #expect(scroll.contentView.bounds.origin == origin)
        try host.pressReturn()
        try await host.settle()
        #expect(host.draft.text.isEmpty && host.draft.submissions == 1)
        #expect(try host.viewportFrame() == viewport)
        #expect(scroll.contentView.bounds.origin == origin)
    }

    @Test func captureKeepsKeyboardSubmissionAndFocus() async throws {
        let host = try CaptureOverlayHost(workspace: false)
        defer { host.close() }
        try await host.settle()
        let viewport = try host.viewportFrame()
        try await host.enter("键盘添加待办")
        let editor = try host.editor()
        try host.snapshot("capture-keyboard-draft")
        try host.pressReturn()
        try await host.settle()
        #expect(host.draft.text.isEmpty)
        #expect(host.draft.submissions == 1 && host.draft.diarySubmissions == 0)
        #expect(host.window.firstResponder === editor)
        #expect(try host.viewportFrame() == viewport)

        try await host.enter("键盘记录手记")
        try host.pressReturn(modifiers: .command)
        try await host.settle()
        #expect(host.draft.text.isEmpty)
        #expect(host.draft.submissions == 1 && host.draft.diarySubmissions == 1)
        #expect(host.window.firstResponder === editor)
        #expect(try host.viewportFrame() == viewport)
    }
}

@Observable
@MainActor
private final class CaptureOverlayDraft {
    var text = ""
    var focused = true
    var submissions = 0
    var diarySubmissions = 0
    var rowActions = 0
    let rowIDs = (0..<30).map { _ in UUID() }

    func submit() {
        submissions += 1
        text = ""
    }

    func submitDiary() {
        diarySubmissions += 1
        text = ""
    }
}

private struct CaptureOverlayFixture: View {
    @Bindable var draft: CaptureOverlayDraft
    let workspace: Bool

    var body: some View {
        VStack(spacing: 8) {
            if workspace {
                DaybookComposer(
                    text: $draft.text, placeholder: "capture.placeholder.today",
                    focus: $draft.focused, onSubmit: draft.submit
                )
            } else {
                CaptureField(
                    text: $draft.text, focus: $draft.focused, onTodo: draft.submit, onDiary: draft.submitDiary
                )
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<30) { index in
                        Text("任务 \(index)").frame(maxWidth: .infinity, alignment: .leading).padding(6)
                            .background(BoardRowPointerRegion(
                                id: draft.rowIDs[index],
                                plainDoubleClick: true,
                                onSelect: { _, _ in draft.rowActions += 1 },
                                onDoubleClick: { draft.rowActions += 1 }
                            ))
                    }
                }
            }
            .background(CaptureGeometryProbe())
        }
        .padding(12)
        .background(DaybookTheme.paper)
        .syntaxOverlayHost()
    }
}

private struct CaptureGeometryProbe: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = CaptureGeometryView()
        view.identifier = NSUserInterfaceItemIdentifier("capture.test.viewport")
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {}
}

private final class CaptureGeometryView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
private final class CaptureOverlayHost {
    private static var retainedContainers: [ModelContainer] = []
    let container: ModelContainer
    let draft = CaptureOverlayDraft()
    let window: NSWindow
    private let previousActivationPolicy = NSApp.activationPolicy()
    private var hasPreparedFocus = false

    init(workspace: Bool) throws {
        container = try ModelContainer(
            for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retainedContainers.append(container)
        container.mainContext.insert(TagItem(name: "工作", sortOrder: 0))
        try container.mainContext.save()
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: workspace ? 600 : 380, height: 490),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: workspace ? .darkAqua : .aqua)
        window.contentView = NSHostingView(rootView: CaptureOverlayFixture(draft: draft, workspace: workspace)
            .modelContainer(container).environment(\.locale, Locale(identifier: "zh-Hans"))
            .environment(\.workspaceEmbedded, workspace)
            .preferredColorScheme(workspace ? .dark : .light)
            .transaction { $0.disablesAnimations = true })
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.makeFirstResponder(nil)
        window.contentView = nil
        window.orderOut(nil)
        NSApp.setActivationPolicy(previousActivationPolicy)
    }

    func show<V: View>(_ view: V, size: NSSize) {
        window.contentView = NSHostingView(rootView: view
            .modelContainer(container).environment(\.locale, Locale(identifier: "zh-Hans"))
            .transaction { $0.disablesAnimations = true }
            .syntaxOverlayHost())
        window.setContentSize(size)
        window.makeKeyAndOrderFront(nil)
    }

    func nativeViews() -> [NSView] { descendants(window.contentView) }

    func settle() async throws {
        if !hasPreparedFocus {
            try await NativeSyntaxUI.prepareFocus(in: window)
            hasPreparedFocus = true
        }
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    func waitForOverlay(_ identifier: String, visible: Bool = true) async throws {
        // 冷启动的 SwiftUI/无障碍树可能晚于绑定更新；等待实际呈现条件，不重发输入或点击。
        let deadline = ContinuousClock.now + .seconds(1)
        while NativeSyntaxUI.identifiers(in: window).contains(identifier) != visible && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
            window.contentView?.layoutSubtreeIfNeeded()
        }
        let state = SyntaxAutocompleteState.forResponder(window.firstResponder)
        let existing = NativeSyntaxUI.identifiers(in: window)
        try #require(existing.contains(identifier) == visible,
                 "浮层呈现未就绪：\(identifier)，key=\(window.isKeyWindow)，active=\(state?.isActive == true)，attributes=\(state?.showsAttributes == true)，已有：\(existing)")
    }

    func viewportFrame() throws -> CGRect {
        let view = try #require(descendants(window.contentView).first { $0.identifier?.rawValue == "capture.test.viewport" })
        return view.convert(view.bounds, to: nil)
    }

    func enter(_ text: String) async throws {
        let field = try #require(descendants(window.contentView).compactMap { $0 as? DaybookAppKitTextField }.first)
        #expect(window.makeFirstResponder(field))
        // 原生焦点通知会回写绑定，输入前先让 SwiftUI 完成这一轮更新。
        try await settle()
        let editor = try #require(field.currentEditor() as? NSTextView)
        #expect(window.firstResponder === editor)
        editor.selectAll(nil)
        editor.insertText(text, replacementRange: editor.selectedRange())
        try await settle()
        #expect(editor.string == text && draft.text == text)
    }

    func editor() throws -> NSTextView {
        let field = try #require(descendants(window.contentView).compactMap { $0 as? DaybookAppKitTextField }.first)
        return try #require(field.currentEditor() as? NSTextView)
    }

    func inputFrame() throws -> CGRect {
        let field = try #require(descendants(window.contentView).compactMap { $0 as? DaybookAppKitTextField }.first)
        return field.convert(field.bounds, to: nil)
    }

    func rowFrames() -> [CGRect] {
        descendants(window.contentView).compactMap { $0 as? BoardRowPointerView }.map { $0.convert($0.bounds, to: nil) }
    }

    func listScrollView() throws -> NSScrollView {
        let row = try #require(descendants(window.contentView).compactMap { $0 as? BoardRowPointerView }.first)
        return try #require(row.enclosingScrollView)
    }

    func click(_ identifier: String) throws {
        try click(at: NativeSyntaxUI.center(identifier, in: window))
    }

    func click(at point: NSPoint) throws {
        try requireKeyWindow()
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            NSApp.postEvent(event, atStart: false)
        }
    }

    func pressEscape() throws {
        try press("\u{1b}", code: 53)
    }

    func pressReturn(modifiers: NSEvent.ModifierFlags = []) throws {
        try press("\r", code: 36, modifiers: modifiers)
    }

    private func press(_ character: String, code: UInt16, modifiers: NSEvent.ModifierFlags = []) throws {
        try requireKeyWindow()
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: character,
            charactersIgnoringModifiers: character, isARepeat: false, keyCode: code
        ))
        // 经原生事件队列派发，使 currentEvent、快捷键和本地事件监视器处于同一事件事务。
        NSApp.postEvent(event, atStart: false)
    }

    private func requireKeyWindow() throws {
        let foreground = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"
        try #require(window.isKeyWindow,
                     "测试窗口未激活：appActive=\(NSApp.isActive)，foreground=\(foreground)")
    }

    func snapshot(_ name: String) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-Overlay-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try #require(bitmap.representation(using: .png, properties: [:]))
            .write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
    }

    private func descendants(_ view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return [view] + view.subviews.flatMap { descendants($0) }
    }
}
