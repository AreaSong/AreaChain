import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookScrollLifecycleTests {
    @Test func replacementAmbiguityUnmountAndLateApply() async throws {
        let f = ScrollBindingFixture()
        defer { f.close() }
        let first = f.scroll()
        f.insert(first)
        f.host.applyScroller()
        weak var original: DaybookFloatingScrollerOverlay? = f.host.currentOverlay
        try #require(original != nil)
        for _ in 0..<10 { f.host.applyScroller(); f.root.layoutSubtreeIfNeeded() }
        #expect(f.host.currentOverlay === original)
        #expect(original?.superview === first)
        first.removeFromSuperview()
        f.host.applyScroller()
        #expect(f.host.currentOverlay == nil && !first.subviews.contains { $0 is DaybookFloatingScrollerOverlay })
        try await Task.sleep(for: .milliseconds(400))
        #expect(original == nil)
        let second = f.scroll()
        f.insert(second)
        f.host.applyScroller()
        weak var replacement: DaybookFloatingScrollerOverlay? = f.host.currentOverlay
        try #require(replacement != nil)
        #expect(replacement?.superview === second)
        f.start.removeFromSuperview()
        #expect(f.host.currentOverlay == nil && replacement?.superview == nil)
        f.root.addSubview(f.start, positioned: .below, relativeTo: second)
        f.host.applyScroller()
        #expect(f.host.currentScrollView === second)
        let ambiguous = f.scroll()
        f.insert(ambiguous)
        f.host.applyScroller()
        #expect(f.host.currentOverlay == nil)
        ambiguous.removeFromSuperview()
        f.host.applyScroller()
        #expect(f.host.currentScrollView === second)
        f.host.removeFromSuperview()
        f.host.dismantle()
        f.root.addSubview(f.host)
        try await SystemPageHost.settle(f.window)
        #expect(f.host.currentOverlay == nil)
        #expect(second.subviews.allSatisfy { !($0 is DaybookFloatingScrollerOverlay) })
        #expect(replacement == nil)
    }

    @Test func eachOwnerCleansOnlyItsOwnOverlayAndWindowsDoNotMix() async throws {
        let first = ScrollBindingFixture()
        let other = ScrollBindingFixture()
        defer { first.close(); other.close() }
        let target = first.scroll()
        first.insert(target)
        first.host.applyScroller()
        let secondHost = DaybookScrollerHostNSView()
        let secondScope = DaybookScrollScope()
        secondScope.start = first.start
        secondHost.scope = secondScope
        first.root.addSubview(secondHost)
        secondHost.applyScroller()
        let remaining = try #require(secondHost.currentOverlay)
        weak var removed: DaybookFloatingScrollerOverlay? = first.host.currentOverlay
        try #require(removed != nil)
        first.host.removeFromSuperview()
        try await Task.sleep(for: .milliseconds(400))
        #expect(removed == nil && remaining.superview === target)
        #expect(target.subviews.filter { $0 is DaybookFloatingScrollerOverlay }.count == 1)
        // 跨窗口的两端不是完整区间，即便唯一候选完全同尺寸也不能绑定。
        other.host.scope = secondScope
        other.host.applyScroller()
        #expect(other.host.currentOverlay == nil)
        secondHost.dismantle()
        #expect(remaining.superview == nil)
    }

    @Test func swiftUIRemovalRemountAndFocusedContentKeepIdentity() async throws {
        let state = ScrollPeerState()
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { fixture.cleanup() }
        let window = fixture.window(ScrollPeerContent(state: state), size: .init(width: 640, height: 260))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let original = ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }
        try #require(original.count == 2)
        let survivor = original[1]
        let overlay = try #require(survivor.subviews.compactMap { $0 as? DaybookFloatingScrollerOverlay }.first)
        weak var removedOverlay = original[0].subviews.compactMap { $0 as? DaybookFloatingScrollerOverlay }.first
        let editor = try #require(ScrollNativeEvidence.views(window).compactMap { $0 as? NSTextField }.last)
        window.makeFirstResponder(editor)
        let responder = window.firstResponder
        survivor.contentView.scroll(to: .init(x: 0, y: 80))
        let offset = survivor.contentView.bounds.origin
        state.revision += 1
        try await SystemPageHost.settle(window)
        #expect(window.firstResponder === responder)
        #expect(survivor.contentView.bounds.origin == offset)
        #expect(state.mounts == [0: 1, 1: 1])
        state.showFirst = false
        try await SystemPageHost.settle(window)
        #expect(removedOverlay == nil)
        #expect(overlay.superview === survivor)
        #expect(ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView } == [survivor])
        state.showFirst = true
        try await SystemPageHost.settle(window)
        #expect(state.mounts == [0: 2, 1: 1])
        #expect(survivor.subviews.compactMap { $0 as? DaybookFloatingScrollerOverlay } == [overlay])
        #expect(ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }
            .allSatisfy { $0.subviews.filter { $0 is DaybookFloatingScrollerOverlay }.count == 1 })
    }
}

@MainActor
final class ScrollBindingFixture {
    let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 300, height: 240),
                          styleMask: [.titled], backing: .buffered, defer: false)
    let root = NSView(frame: .init(x: 0, y: 0, width: 300, height: 240))
    let start = DaybookScrollBoundaryView()
    let host = DaybookScrollerHostNSView()
    let scope = DaybookScrollScope()

    init() {
        window.isReleasedWhenClosed = false
        window.contentView = root
        scope.start = start
        start.scope = scope
        host.scope = scope
        root.addSubview(start)
        root.addSubview(host)
    }

    func scroll() -> NSScrollView {
        let view = NSScrollView(frame: root.bounds)
        view.documentView = NSView(frame: .init(x: 0, y: 0, width: 300, height: 1200))
        return view
    }

    func insert(_ view: NSView) { root.addSubview(view, positioned: .below, relativeTo: host) }
    func close() { host.dismantle(); SystemPageHost.release(window) }
}

@MainActor @Observable
private final class ScrollPeerState {
    var showFirst = true
    var revision = 0
    var mounts: [Int: Int] = [:]
    var draft = "Synthetic draft"
}

private struct ScrollPeerContent: View {
    @Bindable var state: ScrollPeerState

    var body: some View {
        HStack {
            ForEach(state.showFirst ? [0, 1] : [1], id: \.self) { id in
                ScrollView {
                    VStack {
                        TextField("Synthetic", text: $state.draft)
                        ForEach(0..<40, id: \.self) { index in
                            Text("\(id) / \(index) / \(state.revision)").frame(height: 24)
                        }
                    }.onAppear { state.mounts[id, default: 0] += 1 }
                }.daybookScroll()
            }
        }
    }
}
