import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookScrollFeatherLifecycleTests {
    @Test func replacementAmbiguityLateNotificationAndDismantle() async throws {
        let f = ScrollBindingFixture()
        defer { f.close() }
        let first = f.scroll()
        f.insert(first)
        f.host.applyScroller()
        let edge = DaybookScrollEdgeObserverNSView()
        edge.scope = f.scope
        var changes: [[Bool]] = []
        edge.onEdgeChange = { changes.append([$0, $1]) }
        f.root.addSubview(edge)
        edge.refreshBinding()
        try await pause()
        #expect(edge.currentScrollView === first)
        #expect(changes.last == [false, true])
        let initialCount = changes.count
        for _ in 0..<10 { f.host.applyScroller(); edge.layout() }
        try await pause()
        #expect(changes.count == initialCount)
        first.contentView.scroll(to: .init(x: 0, y: 400))
        // 旧目标状态已排队但尚未发布；随即替换，检验代次而非只检验 token 移除。
        let second = f.scroll()
        first.removeFromSuperview()
        f.insert(second)
        f.host.applyScroller()
        try await pause()
        #expect(edge.currentScrollView === second)
        #expect(changes.last == [false, true])
        #expect(!changes.contains([true, true]))
        first.contentView.scroll(to: .init(x: 0, y: 800))
        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: first)
        try await pause()
        #expect(changes.count == initialCount)
        let ambiguous = f.scroll()
        f.insert(ambiguous)
        f.host.applyScroller()
        try await pause()
        #expect(edge.currentScrollView == nil && changes.last == [false, false])
        ambiguous.removeFromSuperview()
        f.host.applyScroller()
        try await pause()
        #expect(edge.currentScrollView === second && changes.last == [false, true])
        second.contentView.scroll(to: .init(x: 0, y: 400))
        let beforeDismantle = changes.count
        edge.dismantle()
        try await pause()
        #expect(changes.count == beforeDismantle)
        #expect(edge.currentScrollView == nil && FeatherTestEvidence.state(edge) == [false, false])
        #expect(second.contentView.postsBoundsChangedNotifications)
        #expect(f.host.currentOverlay?.superview === second)
        edge.removeFromSuperview()
        f.root.addSubview(edge)
        edge.refreshBinding()
        #expect(edge.currentScrollView == nil)
    }

    @Test func documentReplacementAndWindowDetachClearState() async throws {
        let f = ScrollBindingFixture()
        defer { f.close() }
        let target = f.scroll()
        f.insert(target)
        f.host.applyScroller()
        let edge = DaybookScrollEdgeObserverNSView()
        edge.scope = f.scope
        var changes: [[Bool]] = []
        edge.onEdgeChange = { changes.append([$0, $1]) }
        f.root.addSubview(edge)
        edge.refreshBinding()
        try await pause()
        let oldDocument = try #require(target.documentView)
        target.documentView = NSView(frame: .init(x: 0, y: 0, width: 300, height: 60))
        // 原生夹具显式标记布局；生产 SwiftUI document 替换由宿主布局入口重新核对身份。
        f.host.needsLayout = true
        f.root.layoutSubtreeIfNeeded()
        try await pause()
        #expect(changes.last == [false, false])
        oldDocument.setFrameSize(.init(width: 300, height: 2000))
        try await pause()
        #expect(changes.last == [false, false])
        target.documentView?.setFrameSize(.init(width: 300, height: 1200))
        try await pause()
        #expect(changes.last == [false, true])
        edge.removeFromSuperview()
        let count = changes.count
        target.contentView.scroll(to: .init(x: 0, y: 400))
        try await pause()
        #expect(changes.count == count)
        #expect(edge.currentScrollView == nil && FeatherTestEvidence.state(edge) == [false, false])
        f.root.addSubview(edge)
        try await pause()
        #expect(edge.currentScrollView === target && changes.last == [true, true])
        f.start.removeFromSuperview()
        try await pause()
        #expect(edge.currentScrollView == nil && changes.last == [false, false])
        edge.dismantle()
    }

    @Test func switchAndRemountDoNotRetainFeatherOrRecreateContent() async throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { fixture.cleanup() }
        let state = FeatherTestState()
        let window = ScrollOwnershipEvidence.window(FeatherTestContent(state: state),
            locale: "en", size: .init(width: 300, height: 240))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let original = try #require(scrolls(window).first)
        let overlay = try #require(original.subviews.compactMap { $0 as? DaybookFloatingScrollerOverlay }.first)
        original.contentView.scroll(to: .init(x: 0, y: 400))
        try await pause()
        #expect(FeatherTestEvidence.state(try #require(edges(window).first)) == [true, true])
        let hostBefore = ScrollNativeEvidence.views(window).compactMap { $0 as? DaybookScrollerHostNSView }.first
        print("FEATHER_TOGGLE before host=\(ScrollNativeEvidence.identity(hostBefore)) start=\(ScrollNativeEvidence.identity(hostBefore?.scope?.start)) overlay=\(ScrollNativeEvidence.identity(overlay))")
        state.enabled = false
        try await SystemPageHost.settle(window)
        #expect(edges(window).isEmpty && scrolls(window) == [original])
        let hostAfter = ScrollNativeEvidence.views(window).compactMap { $0 as? DaybookScrollerHostNSView }.first
        print("FEATHER_TOGGLE after host=\(ScrollNativeEvidence.identity(hostAfter)) start=\(ScrollNativeEvidence.identity(hostAfter?.scope?.start)) overlay=\(ScrollNativeEvidence.identity(hostAfter?.currentOverlay)) scroll=\(ScrollNativeEvidence.identity(hostAfter?.currentScrollView))")
        #expect(hostAfter === hostBefore && hostAfter?.currentScrollView === original)
        let current = original.subviews.compactMap { $0 as? DaybookFloatingScrollerOverlay }
        #expect(current.count == 1 && current.first === hostAfter?.currentOverlay)
        #expect(current == [overlay])
        state.height = 60
        state.enabled = true
        try await SystemPageHost.settle(window)
        #expect(FeatherTestEvidence.state(try #require(edges(window).first)) == [false, false])
        #expect(scrolls(window) == [original])
        state.visible = false
        try await SystemPageHost.settle(window)
        #expect(edges(window).isEmpty && overlay.superview == nil)
        state.height = 1200
        state.visible = true
        try await SystemPageHost.settle(window)
        #expect(scrolls(window).first !== original)
        #expect(FeatherTestEvidence.state(try #require(edges(window).first)) == [false, true])
    }

    private func pause() async throws { try await Task.sleep(for: .milliseconds(100)) }
    private func edges(_ window: NSWindow) -> [DaybookScrollEdgeObserverNSView] {
        ScrollNativeEvidence.views(window).compactMap { $0 as? DaybookScrollEdgeObserverNSView }
    }
    private func scrolls(_ window: NSWindow) -> [NSScrollView] {
        ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }
    }
}
