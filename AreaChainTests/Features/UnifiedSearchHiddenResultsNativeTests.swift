import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// 不读结果的系统指令输入期间结果区隐藏（保持挂载）：AppKit 侧真实点击与 Tab 不能落到看不见的结果上；
/// 关闭工作台被挡与菜单栏转交被挡的说明块在中英文、浅深色、正常与最小窗口下的截图（人工逐张查看）。
/// 前台套件：发真实鼠标与键盘事件，不打 .backgroundWindow。只用内存库与合成文字。
@Suite(.serialized) @MainActor struct UnifiedSearchHiddenResultsNativeTests {
    @Test func hiddenResultsTakeNoClickOrTab() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        let fakes = SystemCommandFakes()
        _ = fakes.install(fixture)
        try await fixture.start(focus: .foreground)
        let window = try #require(fixture.window)
        let before = try fixture.session.presentation().pagination
        try #require(!before.snapshot.visible.isEmpty)
        let boundary = try #require(SettingsButtonTestSupport.elements(window.contentView)
            .compactMap { $0 as? UnifiedSearchResultsBoundary }.first)
        // 隐藏前记下结果区里各可交互元素的位置；隐藏后同一位置的命中不能落在结果区里。
        let frames = SettingsButtonTestSupport.elements(boundary).compactMap { try? SettingsButtonTestSupport.frame($0, in: window) }
            .filter { $0.width > 2 && $0.height > 2 }
        try #require(!frames.isEmpty, "结果区应有可交互元素")
        try await fixture.enter("/window/workspace/reveal")
        try #require(fixture.controller.hidesResultsForCommand)
        let content = try #require(window.contentView)
        for frame in frames.prefix(40) {
            let point = NSPoint(x: frame.midX, y: frame.midY)
            guard let hit = content.hitTest(content.superview?.convert(point, from: nil) ?? point) else { continue }
            #expect(!Self.inside(hit, boundary), "命中落在隐藏的结果上：\(hit)")
        }
        // 真实点击结果区下半部（面板之外的位置）：不打开任何结果、不导航。
        let lower = try #require(frames.max { $0.minY > $1.minY })
        try await Self.click(NSPoint(x: lower.midX, y: lower.midY), in: window)
        try await fixture.settle()
        #expect(fixture.controller.returnSearch == nil && fixture.router.destination == nil)
        #expect(try fixture.session.presentation().pagination.browse.active == before.browse.active)
        // Tab 走完整个键盘环，焦点不进入结果区。
        let field = try #require(SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSTextField }
            .first { $0.cell is UnifiedSearchFieldCell && !UnifiedSearchFocusHost.insideOperation($0) })
        window.makeFirstResponder(field)
        try await fixture.settle()
        for _ in 0..<12 {
            try await Self.key(48, "\t", in: window)
            if let responder = window.firstResponder as? NSView {
                #expect(!Self.inside(responder, boundary), "Tab 焦点进入了隐藏的结果：\(responder)")
            }
        }
        #expect(fixture.controller.returnSearch == nil && fakes.shows == 0, "Tab 不能触发执行")
    }

    /// 关闭工作台被挡、菜单栏转交被挡两块说明：每种外观各取正常与最小窗口截图，并断言文字不越出窗口、彼此不重叠。
    @Test(arguments: [0, 1, 2, 3]) func blockedPanelsLayout(_ style: Int) async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        let fakes = SystemCommandFakes()
        _ = fakes.install(fixture)
        try await fixture.start(style: style, focus: .foreground)
        let window = try #require(fixture.window)
        _ = fixture.controller.beginOperation(.init(rawValue: "todo.create"), source: fixture.controller.buffer)
        try #require(fixture.controller.operations?.active != nil)
        for size in ["normal", "minimum"] {
            if size == "minimum" {
                window.setFrame(NSRect(origin: window.frame.origin, size: DaybookMetrics.Window.workspaceMinSize), display: true)
            }
            try await fixture.enter("/window/workspace/close")
            try await Self.key(53, "\u{1b}", in: window)  // 收起候选浮层，截图只看面板
            #expect(fixture.controller.navigationMessage != "unified.handoff.blocked", "改字后转交被挡说明应收起")
            try #require(fixture.controller.systemActionBlocked)
            try Self.expectReadable(["unified.system.warning", "unified.system.unsaved.draft",
                                     "unified.system.unsaved.discardDraft", "unified.system.unsaved.review"], in: window)
            try await fixture.snapshot("closeBlocked-\(style)-\(size)")
            // 菜单栏转交被挡：工作台保留自己的草稿文字，只给出说明块。
            try await fixture.enter("/tasks/new")
            try await Self.key(53, "\u{1b}", in: window)
            fixture.controller.reportBlockedHandoff()
            try await fixture.settle()
            try #require(fixture.controller.showsBlockedHandoff)
            try Self.expectReadable(["unified.system.warning", "unified.system.unsaved.draft",
                                     "unified.system.unsaved.review"], in: window)
            try await fixture.snapshot("handoffBlocked-\(style)-\(size)")
        }
    }

    /// 指定元素都在窗口内容区内、彼此不重叠（同一说明块里的文字与按钮）。
    static func expectReadable(_ identifiers: [String], in window: NSWindow) throws {
        let content = try #require(window.contentView)
        var frames: [(String, NSRect)] = []
        for id in identifiers {
            guard let node = SettingsButtonTestSupport.elements(content).first(where: {
                SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == id
            }) else { Issue.record("缺少 \(id)"); continue }
            let frame = try SettingsButtonTestSupport.frame(node, in: window)
            #expect(content.bounds.insetBy(dx: -1, dy: -1).contains(frame), "\(id) 越出窗口：\(frame) / \(content.bounds)")
            #expect(frame.width > 4 && frame.height > 4, "\(id) 被压扁：\(frame)")
            frames.append((id, frame))
        }
        for (index, first) in frames.enumerated() {
            for second in frames.dropFirst(index + 1) {
                #expect(!first.1.insetBy(dx: 1, dy: 1).intersects(second.1.insetBy(dx: 1, dy: 1)),
                        "\(first.0) 与 \(second.0) 重叠：\(first.1) / \(second.1)")
            }
        }
    }

    static func inside(_ view: NSView, _ boundary: NSView) -> Bool { view === boundary || view.isDescendant(of: boundary) }

    static func click(_ point: NSPoint, in window: NSWindow) async throws {
        try #require(window.isKeyWindow, "测试窗口不是 key window")
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            NSApp.sendEvent(event)
        }
        try await SystemPageHost.settle(window)
    }

    static func key(_ code: UInt16, _ character: String, in window: NSWindow) async throws {
        try #require(window.isKeyWindow, "测试窗口不是 key window")
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: character, charactersIgnoringModifiers: character, isARepeat: false, keyCode: code))
        NSApp.sendEvent(event)
        try await SystemPageHost.settle(window)
    }
}
