import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct DaybookScrollerTests {
    @Test func scrollerAttachesToScrollView() async throws {
        let view = ScrollView {
            VStack {
                ForEach(0..<100) { i in
                    Text("Row \(i)")
                }
            }
        }
        .daybookScroll()

        let host = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.orderFront(nil)
        defer {
            window.orderOut(nil)
            window.contentView = nil
        }

        try await Task.sleep(nanoseconds: 200_000_000)

        func findFirst<T: NSView>(in v: NSView, type: T.Type) -> T? {
            if let target = v as? T { return target }
            for sub in v.subviews {
                if let found = findFirst(in: sub, type: type) { return found }
            }
            return nil
        }

        let sv = try #require(findFirst(in: host, type: NSScrollView.self))
        let overlay = try #require(sv.subviews.first(where: { $0 is DaybookFloatingScrollerOverlay }) as? DaybookFloatingScrollerOverlay)
        #expect(overlay.frame.width == 14)
        #expect(overlay.superview === sv)
    }
}
