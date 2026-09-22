import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct WorkspaceLayoutTests {
    @Test func nativeFieldKeepsTheDeclaredSizeAndWeightWhenEditing() async throws {
        let host = NSHostingView(rootView: field())
        let window = makeWindow(host, size: NSSize(width: 360, height: 70))
        defer { window.makeFirstResponder(nil); window.contentView = nil; window.orderOut(nil) }
        try await settle(host)
        let normal = try #require(nativeField(in: host))
        #expect(normal.font == NSFont.systemFont(ofSize: 13, weight: .regular))

        host.rootView = field(size: DaybookType.titleSize, weight: .semibold)
        try await settle(host)
        let title = try #require(nativeField(in: host))
        #expect(title.font == NSFont.systemFont(ofSize: 16, weight: .semibold))
        window.makeFirstResponder(title)
        let editor = try #require(title.currentEditor() as? NSTextView)
        #expect(editor.font == title.font)
        #expect(editor.delegate === title)
    }

    @Test func pageHeaderKeepsTitleAndContentOriginsWithOptionalSubtitle() async throws {
        var titleOrigins: [CGFloat] = []
        for showsSubtitle in [false, true] {
            let header = DaybookPageHeader {
                Text("今日待办").font(DaybookType.title).background(WorkspaceMetricMarker(name: "title"))
            } subtitle: {
                if showsSubtitle { Text("9月14日 周一").font(DaybookType.subtitle) }
            } trailing: {
                Color.clear.frame(width: 36, height: 36)
            }
            .background(WorkspaceMetricMarker(name: "header"))
            .environment(\.workspaceEmbedded, true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            let host = NSHostingView(rootView: header)
            let window = makeWindow(host, size: NSSize(width: 520, height: 80))
            defer { window.contentView = nil; window.orderOut(nil) }
            try await settle(host)
            let title = try #require(marker("title", in: host))
            let frame = title.convert(title.bounds, to: host)
            titleOrigins.append(frame.minY)
            let headerMarker = try #require(marker("header", in: host))
            #expect(abs(headerMarker.bounds.height - WorkspaceLayout.headerHeight) < 1)
        }
        #expect(abs(titleOrigins[0] - titleOrigins[1]) < 1)
    }

    @Test func pageHeaderHasNoMinimumHeightOutsideTheWorkspace() async throws {
        let header = DaybookPageHeader {
            Text("今日待办").font(DaybookType.title)
        } subtitle: {
            EmptyView()
        } trailing: {
            EmptyView()
        }
        .background(WorkspaceMetricMarker(name: "header"))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let host = NSHostingView(rootView: header)
        let window = makeWindow(host, size: NSSize(width: 520, height: 80))
        defer { window.contentView = nil; window.orderOut(nil) }
        try await settle(host)
        let headerMarker = try #require(marker("header", in: host))
        #expect(headerMarker.bounds.height < WorkspaceLayout.headerHeight)
    }

    private func field(size: CGFloat = DaybookType.bodySize, weight: NSFont.Weight = .regular) -> DaybookTextField {
        DaybookTextField(text: .constant("原生输入字号核验"), placeholder: "输入", fontSize: size,
                         fontWeight: weight, focus: .constant(false), onSubmit: {})
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

    private func nativeField(in view: NSView) -> DaybookAppKitTextField? {
        (view as? DaybookAppKitTextField) ?? view.subviews.lazy.compactMap { nativeField(in: $0) }.first
    }

    private func marker(_ name: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == name { return view }
        return view.subviews.lazy.compactMap { marker(name, in: $0) }.first
    }
}

private struct WorkspaceMetricMarker: NSViewRepresentable {
    let name: String
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.identifier = NSUserInterfaceItemIdentifier(name)
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {}
}
