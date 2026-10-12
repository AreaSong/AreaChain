import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
struct SyntaxOverlayPlacementTests {
    private static var retainedContainers: [ModelContainer] = []

    @Test func panelsPreferBelowAndFlipAboveNearTheBottom() {
        let size = CGSize(width: 380, height: 490)
        let preferred = CGSize(width: 240, height: 205)
        for y: CGFloat in [60, 410] {
            let anchor = CGRect(x: 24, y: y, width: 300, height: 30)
            let placement = SyntaxOverlayPlacement.resolve(anchor: anchor, container: size, preferred: preferred, prefersAbove: false)
            #expect(placement.growsUpward == (y == 410))
            #expect(CGRect(origin: .zero, size: size).contains(placement.frame))
            #expect(!placement.frame.intersects(anchor))
            #expect(placement.frame.size == preferred)
        }
    }

    @Test func narrowHostsConstrainThePanelAndOffscreenAnchorsDoNotPresent() {
        let size = CGSize(width: 220, height: 200)
        let anchor = CGRect(x: 175, y: 80, width: 30, height: 20)
        let placement = SyntaxOverlayPlacement.resolve(
            anchor: anchor, container: size, preferred: CGSize(width: 280, height: 280), prefersAbove: false
        )
        #expect(CGRect(origin: .zero, size: size).contains(placement.frame))
        #expect(placement.frame.width == 204)
        #expect(!placement.frame.intersects(anchor))
        #expect(SyntaxOverlayPlacement.resolve(
            anchor: CGRect(x: 0, y: 220, width: 100, height: 20), container: size,
            preferred: CGSize(width: 240, height: 100), prefersAbove: false
        ).frame == .zero)
    }

    @Test func attributePreviewUsesTheExistingParserWithoutChangingText() {
        let text = "#work #新标签 开会 !p1 @09:00"
        let attributes = CaptureAttributes(text: text, knownTags: ["Work"])
        #expect(attributes.count == 4)
        #expect(attributes.items.filter(\.isNewTag).map(\.title) == ["#新标签"])
        #expect(attributes.items.first { $0.id == "time" }?.title == "09:00")
        #expect(attributes.items.first { $0.id == "priority" }?.title == "quadrant.iu")
        #expect(CaptureAttributes(text: "普通内容", knownTags: []).count == 0)
        #expect(text == "#work #新标签 开会 !p1 @09:00")
    }

    @Test @MainActor func candidatesAndAttributesAreMutuallyExclusive() {
        let state = SyntaxAutocompleteState()
        state.update(text: "#工作", cursorLocation: 3, availableTags: ["工作"])
        #expect(state.isActive && !state.showsAttributes)
        state.showAttributes()
        #expect(!state.isActive && state.showsAttributes)
        state.update(text: "!p", cursorLocation: 2)
        #expect(state.isActive && !state.showsAttributes)
        state.dismiss()
        #expect(!state.hasPresentation)
    }

    @Test @MainActor func attributePreviewDoesNotInterruptMarkedText() {
        let state = SyntaxAutocompleteState()
        let editor = NSTextView()
        editor.setMarkedText("今", selectedRange: NSRange(location: 1, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        state.editor = editor
        state.showAttributes()
        #expect(!state.showsAttributes && editor.hasMarkedText())
    }

    @Test @MainActor func multilineDiaryWindowAnchorsCandidatesBelowTypedTriggerLine() async throws {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retainedContainers.append(container)
        for (index, name) in ["工作", "灵感", "复盘", "读书", "计划", "生活"].enumerated() {
            container.mainContext.insert(TagItem(name: name, sortOrder: index))
        }
        try container.mainContext.save()

        let session = DiaryEditorSession(
            source: .draft(BoardComposerDraft(), dayKey: "2026-09-13"),
            context: container.mainContext
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: DiaryWindowView(session: session, onPin: {})
                .modelContainer(container)
                .environment(AppPreferences.shared)
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .transaction { $0.disablesAnimations = true }
        )
        defer {
            window.makeFirstResponder(nil)
            window.contentView = nil
            window.orderOut(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try await NativeSyntaxUI.prepareFocus(in: window)
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.contentView?.layoutSubtreeIfNeeded()

        let editor = try #require(descendants(window.contentView).compactMap { $0 as? DaybookAppKitTextView }.first)
        #expect(window.makeFirstResponder(editor))
        try await Task.sleep(for: .milliseconds(80))
        editor.insertText("123 #", replacementRange: NSRange(location: 0, length: 0))
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.contentView?.layoutSubtreeIfNeeded()

        let scroll = try #require(editor.enclosingScrollView)
        let scrollFrameInWindow = scroll.convert(scroll.bounds, to: nil)
        let panelFrameInWindow = try NativeSyntaxUI.frame("syntax.overlay.candidates", in: window)

        // AppKit 窗口坐标原点在左下角：首行下方紧邻 scrollFrameInWindow.maxY，且候选面板保持完整高度。
        #expect(scrollFrameInWindow.height > 180)
        #expect(panelFrameInWindow.height >= 200)
        #expect(scrollFrameInWindow.maxY - panelFrameInWindow.maxY < 45)
        #expect(panelFrameInWindow.maxY > scrollFrameInWindow.minY + 150)
        #expect(panelFrameInWindow.minY >= 8)

        // 点击覆盖在多行编辑器上方的候选底栏不应穿透到 NSTextView 导致光标移动或关闭浮层。
        let footerPoint = NSPoint(x: panelFrameInWindow.midX, y: panelFrameInWindow.minY + 10)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: footerPoint, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            NSApp.sendEvent(event)
        }
        try await Task.sleep(for: .milliseconds(80))
        #expect(NativeSyntaxUI.identifiers(in: window).contains("syntax.overlay.candidates"))
        #expect(editor.selectedRange() == NSRange(location: 5, length: 0))

        // 点击候选条目直接完成标签替换并保持编辑器焦点。
        let candidatePoint = try NativeSyntaxUI.center("syntax.candidate.tag_工作", in: window)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: candidatePoint, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            NSApp.sendEvent(event)
        }
        try await Task.sleep(for: .milliseconds(120))
        #expect(editor.string == "123 #工作 ")
        #expect(window.firstResponder === editor)
    }

    private func descendants(_ view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return [view] + view.subviews.flatMap { descendants($0) }
    }
}
