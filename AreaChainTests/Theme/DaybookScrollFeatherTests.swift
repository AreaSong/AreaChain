import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookScrollFeatherTests {
    @Test func automaticPositionsAndGeometry() async throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { fixture.cleanup() }
        let state = FeatherTestState()
        let window = ScrollOwnershipEvidence.window(FeatherTestContent(state: state), locale: "en", size: .init(width: 300, height: 240))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let scroll = try #require(ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }.first)
        let edge = try #require(ScrollNativeEvidence.views(window)
            .compactMap { $0 as? DaybookScrollEdgeObserverNSView }.first)
        let evidence = FeatherNotificationEvidence(scroll)
        defer { evidence.close() }
        for progress in [0.0, 0.5, 1.0] {
            let document = try #require(scroll.documentView)
            let maximum = document.bounds.height - scroll.documentVisibleRect.height
            scroll.contentView.scroll(to: .init(x: 0, y: maximum * progress))
            scroll.reflectScrolledClipView(scroll.contentView)
            try await Task.sleep(for: .milliseconds(100))
            print("FEATHER_POSITION p=\(progress) target=\(ScrollNativeEvidence.identity(scroll)) "
                + "selected=\(ScrollNativeEvidence.identity(edge.currentScrollView)) "
                + "doc=\(ScrollNativeEvidence.identity(document)) clip=\(ScrollNativeEvidence.identity(scroll.contentView)) "
                + "visible=\(scroll.documentVisibleRect) bounds=\(document.bounds) flipped=\(document.isFlipped) "
                + "state=\(FeatherTestEvidence.state(edge)) notifications=\(evidence.counts)")
            #expect(edge.currentScrollView === scroll)
            #expect(FeatherTestEvidence.state(edge) == [progress > 0, progress < 1])
        }
        state.height = 60
        try await SystemPageHost.settle(window)
        #expect(FeatherTestEvidence.state(edge) == [false, false])
        state.height = 1200
        try await SystemPageHost.settle(window)
        #expect(FeatherTestEvidence.state(edge) == [false, true])
        state.height = 360
        window.setContentSize(.init(width: 300, height: 500))
        try await SystemPageHost.settle(window)
        #expect(FeatherTestEvidence.state(edge) == [false, false])
        window.setContentSize(.init(width: 300, height: 180))
        try await SystemPageHost.settle(window)
        #expect(FeatherTestEvidence.state(edge) == [false, true])
        print("FEATHER_GEOMETRY notifications=\(evidence.counts)")
    }
}

@MainActor @Observable
final class FeatherTestState {
    var height: CGFloat = 1200
    var enabled = true
    var visible = true
    var reduced: Bool?
}

struct FeatherTestContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduced
    var state: FeatherTestState
    var body: some View {
        ZStack {
            if state.visible {
                ScrollView {
                Rectangle().fill(Color.red).frame(height: state.height)
            }.daybookScroll(featherEdges: state.enabled)
                .onAppear { state.reduced = reduced }
                .onChange(of: reduced) { _, value in state.reduced = value }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
enum FeatherTestEvidence {
    static func state(_ edge: DaybookScrollEdgeObserverNSView) -> [Bool] {
        let mirror = Mirror(reflecting: edge)
        return ["lastTop", "lastBottom"].compactMap { name in
            mirror.children.first { $0.label == name }?.value as? Bool
        }
    }
}

@MainActor
private final class FeatherNotificationEvidence {
    var counts: [String: Int] = [:]
    var tokens: [NSObjectProtocol] = []
    init(_ scroll: NSScrollView) {
        for (name, object) in [(NSScrollView.didLiveScrollNotification, scroll),
                               (NSView.boundsDidChangeNotification, scroll.contentView),
                               (NSView.frameDidChangeNotification, scroll.documentView!)] {
            tokens.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                self?.counts[name.rawValue, default: 0] += 1
            })
        }
    }
    func close() { tokens.forEach(NotificationCenter.default.removeObserver) }
}
