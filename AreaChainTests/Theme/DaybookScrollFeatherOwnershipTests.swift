import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookScrollFeatherOwnershipTests {
    @Test(arguments: [0, 1, 2])
    func peersNestedDisabledAndMultipleWindows(mode: Int) async throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { fixture.cleanup() }
        let first = ScrollOwnershipEvidence.window(FeatherOwnershipContent(mode: mode),
            locale: "en", size: .init(width: 600, height: 260))
        let other = ScrollOwnershipEvidence.window(FeatherOwnershipContent(mode: 0),
            locale: "zh-Hans", size: .init(width: 600, height: 260))
        defer { SystemPageHost.release(first); SystemPageHost.release(other) }
        try await SystemPageHost.settle(first)
        try await SystemPageHost.settle(other)
        let targets = try targets(first)
        let foreignEdges = edges(other)
        #expect(targets.count == 2)
        #expect(edges(first).count == (mode == 1 ? 1 : 2))
        if mode == 2 { #expect(targets["inner"]?.enclosingScrollView === targets["outer"]) }
        for edge in edges(first) {
            let scroll = try #require(edge.currentScrollView)
            #expect(targets.values.contains { $0 === scroll })
            #expect(edge.scope?.host?.currentScrollView === scroll)
            #expect(edge.scope?.host?.currentOverlay?.superview === scroll)
            #expect(FeatherTestEvidence.state(edge) == [false, true])
        }
        #expect(edges(first).contains { $0.currentScrollView === targets[mode == 2 ? "outer" : "first"] })
        #expect(edges(first).contains { $0.currentScrollView === targets[mode == 2 ? "inner" : "second"] } == (mode != 1))
        for target in targets.values {
            let original = targets.values.filter { $0 !== target }.map { $0.contentView.bounds }
            let maximum = try #require(target.documentView).bounds.height - target.documentVisibleRect.height
            target.contentView.scroll(to: .init(x: 0, y: maximum / 2))
            try await Task.sleep(for: .milliseconds(100))
            for edge in edges(first) where edge.currentScrollView === target {
                #expect(FeatherTestEvidence.state(edge) == [true, true])
            }
            #expect(targets.values.filter { $0 !== target }.map { $0.contentView.bounds } == original)
            #expect(foreignEdges.allSatisfy { FeatherTestEvidence.state($0) == [false, true] })
            target.contentView.scroll(to: .zero)
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    private func edges(_ window: NSWindow) -> [DaybookScrollEdgeObserverNSView] {
        ScrollNativeEvidence.views(window).compactMap { $0 as? DaybookScrollEdgeObserverNSView }
    }

    private func targets(_ window: NSWindow) throws -> [String: NSScrollView] {
        let markers = ScrollNativeEvidence.views(window).compactMap { $0 as? FeatherIdentityView }
        return try Dictionary(uniqueKeysWithValues: markers.map {
            (try #require($0.identifier?.rawValue), try #require($0.enclosingScrollView))
        })
    }
}

private struct FeatherOwnershipContent: View {
    var mode: Int
    var body: some View {
        if mode == 2 {
            ScrollView {
                VStack {
                    FeatherIdentity(name: "outer").frame(height: 1)
                    list("inner", enabled: true).frame(height: 180)
                    Color.red.frame(height: 1200)
                }
            }.daybookScroll(featherEdges: true)
        } else {
            HStack {
                list("first", enabled: true)
                list("second", enabled: mode == 0)
            }
        }
    }
    private func list(_ name: String, enabled: Bool) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                FeatherIdentity(name: name).frame(height: 1)
                Color.red.frame(height: 1200)
            }
        }.daybookScroll(featherEdges: enabled)
    }
}

private struct FeatherIdentity: NSViewRepresentable {
    let name: String
    func makeNSView(context: Context) -> FeatherIdentityView {
        let view = FeatherIdentityView()
        view.identifier = .init(name)
        return view
    }
    func updateNSView(_ nsView: FeatherIdentityView, context: Context) {}
}
private final class FeatherIdentityView: NSView {}
