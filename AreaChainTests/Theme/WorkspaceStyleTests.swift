import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct WorkspaceStyleTests {
    @Test func workspaceStyleIsOptIn() {
        #expect(EnvironmentValues().daybookViewStyle == .standard)
        #expect(DaybookViewStyle.standard.doneText == DaybookTheme.done)
        #expect(DaybookViewStyle.workspace.doneText == DaybookTheme.muted)
        #expect(DaybookType.titleSize == 16)
        #expect(DaybookType.bodySize == 13)
        #expect(DaybookType.subtitleSize == 12)
        #expect(DaybookType.captionSize == 11)
    }

    @Test func workspaceTextAndControlsMeetContrastTargets() {
        let lightSurfaces = [WorkspaceSwatch.paperLight, WorkspaceSwatch.surfaceLight, WorkspaceSwatch.inputLight,
                             WorkspaceSwatch.hoverLight, WorkspaceSwatch.selectionLight]
        let darkSurfaces = [WorkspaceSwatch.paperDark, WorkspaceSwatch.surfaceDark, WorkspaceSwatch.inputDark,
                            WorkspaceSwatch.hoverDark, WorkspaceSwatch.selectionDark]
        for surface in lightSurfaces {
            #expect(ContrastMath.ratio(DaybookSwatch.inkLight, surface) >= 4.5)
            #expect(ContrastMath.ratio(DaybookSwatch.mutedLight, surface) >= 4.5)
            #expect(ContrastMath.ratio(WorkspaceSwatch.controlLight, surface) >= 3)
        }
        for surface in darkSurfaces {
            #expect(ContrastMath.ratio(DaybookSwatch.inkDark, surface) >= 4.5)
            #expect(ContrastMath.ratio(DaybookSwatch.mutedDark, surface) >= 4.5)
            #expect(ContrastMath.ratio(WorkspaceSwatch.controlDark, surface) >= 3)
        }
    }

    @Test(arguments: [false, true])
    func inputChromeKeepsStandardAndWorkspaceStrokesSeparate(focused: Bool) {
        #expect(DaybookViewStyle.standard.inputBorderWidth(focused: focused, kind: .search) == (focused ? 1.6 : 1))
        for kind in [DaybookInputKind.composer, .search, .editor] {
            #expect(DaybookViewStyle.workspace.inputBorderWidth(focused: focused, kind: kind) == (focused ? 1.4 : 0.8))
        }
        #expect(DaybookViewStyle.standard.inputBorderWidth(focused: focused, kind: .composer) == (focused ? 1.4 : 0.8))
    }

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
            .environment(\.daybookViewStyle, .workspace)
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

    @Test func workspaceInputAndFilterUseTheirSharedControlMetrics() async throws {
        let content = VStack(alignment: .leading, spacing: 12) {
            Text("输入").frame(height: 22)
                .daybookInputChrome(focused: false, kind: .composer)
                .background(WorkspaceMetricMarker(name: "composer"))
            Text("搜索").frame(height: 20)
                .daybookInputChrome(focused: false, kind: .search)
                .background(WorkspaceMetricMarker(name: "search"))
            WorkspaceFilterLabel(isSelected: false) { Text("标签") }
                .background(WorkspaceMetricMarker(name: "filter"))
        }
        .environment(\.daybookViewStyle, .workspace)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let host = NSHostingView(rootView: content)
        let window = makeWindow(host, size: NSSize(width: 360, height: 160))
        defer { window.contentView = nil; window.orderOut(nil) }
        try await settle(host)
        for (name, height) in [("composer", WorkspaceStyle.composerHeight), ("search", WorkspaceStyle.controlHeight), ("filter", WorkspaceStyle.controlHeight)] {
            let view = try #require(marker(name, in: host))
            #expect(abs(view.bounds.height - height) < 1, "\(name) 高度应为 \(height)")
        }
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
