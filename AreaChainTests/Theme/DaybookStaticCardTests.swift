import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookStaticCardTests {
    @Test(arguments: [ColorScheme.light, .dark])
    func originalControlsPreviewShowsBothCardPolicies(scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let window = support.window(DaybookControlsPreview(localeID: "en", dark: scheme == .dark),
                                    scheme: scheme, size: NSSize(width: 760, height: 640))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let labels = MenuButtonTestSupport.labels(in: window)
        #expect(labels.contains(MenuButtonTestSupport.localized("controls.preview.surface.static", "en")))
        #expect(labels.contains(MenuButtonTestSupport.localized("controls.preview.surface.interactive", "en")))
        try OverlaySurfaceTestSupport.record(window, name: "static-card-gallery-\(scheme)")
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func completeEdgesMatchFrozenDecoration(scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let content = Text(verbatim: "Synthetic").frame(width: 180, height: 72)
            .overlay(alignment: .topTrailing) { Color.red.frame(width: 16, height: 16).offset(x: 8, y: -8) }
        let original = support.window(content.modifier(FrozenYesterdayCard()).padding(32),
                                      scheme: scheme, size: NSSize(width: 244, height: 136))
        defer { SystemPageHost.release(original) }
        try await SystemPageHost.settle(original)
        let before = try OverlaySurfaceTestSupport.bitmap(original)
        let current = support.window(content.daybookStaticCardSurface().padding(32),
                                     scheme: scheme, size: NSSize(width: 244, height: 136))
        defer { SystemPageHost.release(current) }
        try await SystemPageHost.settle(current)
        let after = try OverlaySurfaceTestSupport.bitmap(current)
        #expect(before.pixelsWide == after.pixelsWide && before.pixelsHigh == after.pixelsHigh)
        #expect(RowBubbleTestSupport.bytes(before) == RowBubbleTestSupport.bytes(after))
        try OverlaySurfaceTestSupport.record(original, name: "static-card-frozen-\(scheme)")
        try OverlaySurfaceTestSupport.record(current, name: "static-card-current-\(scheme)")
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func pointerDoesNotChangeStaticSurfaceButCardStillReacts(scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let pointer = NSEvent.mouseLocation
        defer { RowBubbleTestSupport.warp(pointer) }
        for interactive in [false, true] {
            let probe = StaticCardProbe()
            let window = support.window(StaticCardSample(probe: probe, interactive: interactive),
                                        scheme: scheme, size: NSSize(width: 280, height: 160))
            defer { SystemPageHost.release(window) }
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await RowBubbleTestSupport.move(NSPoint(x: 10, y: 10), in: window)
            let before = try OverlaySurfaceTestSupport.bitmap(window)
            try await RowBubbleTestSupport.move(NSPoint(x: 65, y: 60), in: window)
            try await Task.sleep(for: .milliseconds(250))
            let hovered = try OverlaySurfaceTestSupport.bitmap(window)
            #expect((RowBubbleTestSupport.bytes(before) == RowBubbleTestSupport.bytes(hovered)) == !interactive)
            try await RowBubbleTestSupport.move(NSPoint(x: 10, y: 10), in: window)
            try await Task.sleep(for: .milliseconds(250))
            #expect(try RowBubbleTestSupport.bytes(before) == RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(window)))
            if interactive {
                probe.selected = true
                try await SystemPageHost.settle(window)
                #expect(try RowBubbleTestSupport.bytes(before) != RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(window)))
            }
        }
    }

    @Test(arguments: ["send", "queue"])
    func buttonsKeepTheirOwnBoundsAndContentIdentity(delivery: String) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = StaticCardProbe()
        let window = support.window(StaticCardSample(probe: probe), size: NSSize(width: 280, height: 160))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let button = try SettingsButtonTestSupport.button("static.card.action", in: window)
        let frame = try SettingsButtonTestSupport.frame(button, in: window)
        let identity = try #require(probe.identity)
        #expect(probe.appearances == 1)
        try await SurfaceEventTestSupport.click(NSPoint(x: frame.midX, y: frame.midY), in: window, delivery: delivery)
        #expect(probe.actions == 1)
        for point in [NSPoint(x: 60, y: 80), NSPoint(x: 50, y: 44), NSPoint(x: 49, y: 80), NSPoint(x: 20, y: 20)] {
            try await SurfaceEventTestSupport.click(point, in: window, delivery: delivery)
            #expect(probe.actions == 1, "卡片空白、圆角、外缘均不能扩成按钮")
        }
        probe.text = "Updated"
        probe.selected = true
        try await SystemPageHost.settle(window)
        #expect(probe.identity == identity && probe.appearances == 1)
        let updated = try SettingsButtonTestSupport.button("static.card.action", in: window)
        try await SettingsButtonTestSupport.click(updated, in: window)
        #expect(probe.actions == 2)
    }
}

/// 只冻结两处旧装饰，不复制 TasksPage 的布局、内容或业务组合。
struct FrozenYesterdayCard: ViewModifier {
    func body(content: Content) -> some View {
        content.background(RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
            .fill(DaybookPalette.cardSurface))
            .overlay(RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.8))
    }
}

@Observable @MainActor private final class StaticCardProbe {
    var actions = 0
    var appearances = 0
    var identity: UUID?
    var text = "Synthetic"
    var selected = false
}

private struct StaticCardSample: View {
    let probe: StaticCardProbe
    var interactive = false
    @State private var identity = UUID()

    private var content: some View {
        Button { probe.actions += 1 } label: { Text(verbatim: probe.text) }
            .buttonStyle(.plain)
            .accessibilityIdentifier("static.card.action")
            .frame(width: 180, height: 72)
            .onAppear { probe.appearances += 1; probe.identity = identity }
    }

    var body: some View {
        if interactive { content.daybookSurface(.card, isSelected: probe.selected) }
        else { content.daybookStaticCardSurface() }
    }
}
