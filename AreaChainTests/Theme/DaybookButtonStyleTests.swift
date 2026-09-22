import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct DaybookButtonStyleTests {
    @Test func sizesFollowMetrics() {
        #expect(DaybookButtonSize.regular.hit == DaybookMetrics.Hit.regular)
        #expect(DaybookButtonSize.compact.hit == DaybookMetrics.Hit.compact)
        #expect(DaybookButtonSize.inline.hit == DaybookMetrics.Hit.inline)
        #expect(DaybookButtonSize.regular.radius == DaybookMetrics.Radius.control)
        #expect(DaybookButtonSize.compact.radius == DaybookMetrics.Radius.inline)
        #expect(DaybookButtonVariant.icon.isIcon)
        #expect(DaybookButtonVariant.iconActive.isIcon)
        #expect(!DaybookButtonVariant.quiet.isIcon)
        #expect(!DaybookButtonVariant.pill(tint: .red).isIcon)
    }

    @Test func iconButtonsUseSquareHitAreas() async throws {
        let content = HStack(spacing: 12) {
            DaybookIconButton(systemName: "xmark", label: "common.close", size: .regular, action: {})
                .background(ButtonMarker(name: "regular"))
            DaybookIconButton(systemName: "xmark", label: "common.close", size: .compact, action: {})
                .background(ButtonMarker(name: "compact"))
            DaybookIconButton(systemName: "xmark", label: "common.close", size: .inline, action: {})
                .background(ButtonMarker(name: "inline"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let host = NSHostingView(rootView: content)
        let window = makeWindow(host, size: NSSize(width: 240, height: 80))
        defer { window.contentView = nil; window.orderOut(nil) }
        try await settle(host)
        for (name, hit) in [("regular", DaybookMetrics.Hit.regular), ("compact", DaybookMetrics.Hit.compact), ("inline", DaybookMetrics.Hit.inline)] {
            let view = try #require(marker(name, in: host))
            #expect(abs(view.bounds.width - hit) < 1, "\(name) 宽应为 \(hit)")
            #expect(abs(view.bounds.height - hit) < 1, "\(name) 高应为 \(hit)")
        }
    }

    @Test func textButtonDoesNotForceASquareFrame() async throws {
        let content = Button("清除筛选", action: {})
            .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            .background(ButtonMarker(name: "text"))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let host = NSHostingView(rootView: content)
        let window = makeWindow(host, size: NSSize(width: 240, height: 80))
        defer { window.contentView = nil; window.orderOut(nil) }
        try await settle(host)
        let view = try #require(marker("text", in: host))
        #expect(view.bounds.width > DaybookMetrics.Hit.compact)
        #expect(view.bounds.height < DaybookMetrics.Hit.regular)
    }

    private func makeWindow(_ view: NSView, size: NSSize) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.setContentSize(size)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    private func settle(_ view: NSView) async throws {
        view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        view.layoutSubtreeIfNeeded()
    }

    private func marker(_ name: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == name { return view }
        return view.subviews.lazy.compactMap { marker(name, in: $0) }.first
    }
}

private struct ButtonMarker: NSViewRepresentable {
    let name: String
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.identifier = NSUserInterfaceItemIdentifier(name)
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {}
}
