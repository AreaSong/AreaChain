import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct DaybookInputShellTests {
    @Test func standardConfigurationFollowsMetrics() {
        let composer = DaybookInputShellConfiguration.standard(for: .composer)
        #expect(composer.height == DaybookMetrics.inputHeight)
        #expect(composer.radius == DaybookMetrics.Radius.inputComposer)
        #expect(composer.insets.top == 7)
        let search = DaybookInputShellConfiguration.standard(for: .search)
        #expect(search.height == DaybookMetrics.controlHeight)
        #expect(search.radius == 6)
        #expect(search.insets.top == 4)
        let editor = DaybookInputShellConfiguration.standard(for: .editor)
        #expect(editor.height == nil)
        #expect(editor.radius == DaybookMetrics.Radius.inputEditor)
    }

    @Test func composerAndSearchUseFixedHeightsAndEditorGrows() async throws {
        let content = VStack(alignment: .leading, spacing: 12) {
            DaybookInputShell(kind: .composer, focused: false) { Text("输入").frame(height: 20) }
                .background(InputShellMarker(name: "composer"))
            DaybookInputShell(kind: .search, focused: true) { Text("搜索").frame(height: 18) }
                .background(InputShellMarker(name: "search"))
            DaybookInputShell(kind: .editor, focused: false) { Text("编辑").frame(minHeight: 64) }
                .background(InputShellMarker(name: "editor"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let host = NSHostingView(rootView: content)
        let window = makeWindow(host, size: NSSize(width: 360, height: 240))
        defer { window.contentView = nil; window.orderOut(nil) }
        try await settle(host)
        let composer = try #require(marker("composer", in: host))
        #expect(abs(composer.bounds.height - DaybookMetrics.inputHeight) < 1)
        let search = try #require(marker("search", in: host))
        #expect(abs(search.bounds.height - DaybookMetrics.controlHeight) < 1)
        let editor = try #require(marker("editor", in: host))
        let editorInsets = DaybookMetrics.inputInsets(.editor)
        #expect(editor.bounds.height >= 64 + editorInsets.top + editorInsets.bottom - 1)
    }

    @Test func configureOverridesMinHeight() async throws {
        let content = DaybookInputShell(kind: .editor, focused: false, configure: { $0.minHeight = 90 }) {
            Text("编辑")
        }
        .background(InputShellMarker(name: "editor"))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let host = NSHostingView(rootView: content)
        let window = makeWindow(host, size: NSSize(width: 360, height: 200))
        defer { window.contentView = nil; window.orderOut(nil) }
        try await settle(host)
        let editor = try #require(marker("editor", in: host))
        #expect(editor.bounds.height >= 89)
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

private struct InputShellMarker: NSViewRepresentable {
    let name: String
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.identifier = NSUserInterfaceItemIdentifier(name)
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {}
}
