import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct RowBubbleSurfaceTests {
    @Test func policiesKeepCopiedPriorityAndOriginalGeometry() {
        for hovered in [false, true] {
            for copied in [false, true] {
                let surface = DaybookFloatingSurface.rowBubble(isHovered: hovered, isCopied: copied)
                let expected = copied ? DaybookPalette.accent.base.opacity(0.7)
                    : (hovered ? DaybookPalette.cardBorderHover : DaybookPalette.border.default.opacity(0.9))
                #expect(surface.borderColor == expected)
                #expect(surface.radius == DaybookRadius.small && surface.borderWidth == 0.8)
                #expect(surface.shape.style == .continuous)
            }
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func fullEdgesMatchFrozenDrawing(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        for hovered in [false, true] {
            for copied in [false, true] {
                let sample = Text(verbatim: locale == "en" ? "Synthetic multiline\ncontent" : "合成多行\n正文")
                    .frame(width: 210, height: 80)
                    .overlay(alignment: .topTrailing) {
                        Circle().fill(.red).frame(width: 16, height: 16).offset(x: 8, y: -8)
                    }
                let old = support.window(sample.modifier(OriginalRowBubbleSurface(hovered: hovered, copied: copied)).padding(32),
                    locale: locale, scheme: scheme, size: NSSize(width: 274, height: 144))
                defer { SystemPageHost.release(old) }
                try await SystemPageHost.settle(old)
                let before = try RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(old))
                let new = support.window(sample.daybookSurface(floating: .rowBubble(isHovered: hovered, isCopied: copied)).padding(32),
                    locale: locale, scheme: scheme, size: NSSize(width: 274, height: 144))
                defer { SystemPageHost.release(new) }
                try await SystemPageHost.settle(new)
                #expect(new.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == (scheme == .dark ? .darkAqua : .aqua))
                #expect(try before == RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(new)),
                        "包含完整阴影、居中描边和越界内容；不能裁掉外缘以隐藏差异")
                try OverlaySurfaceTestSupport.record(new, name: "f-surface-\(locale)-\(scheme)-\(hovered)-\(copied)")
            }
        }
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func existingControlsPreviewShowsDynamicShellAndExternalArrows(scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let window = support.window(DaybookControlsPreview(localeID: "en", dark: scheme == .dark, longLabels: false),
            scheme: scheme, size: NSSize(width: 760, height: 640))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let label = try #require(SettingsButtonTestSupport.elements(window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityValue") as? String
                == "Production bubbles · card-only shadow · external arrows"
        })
        try await SettingsButtonTestSupport.reveal(label, in: window)
        try OverlaySurfaceTestSupport.record(window, name: "f-gallery-\(scheme)")
        #expect(try #require(window.contentView).bounds.contains(SettingsButtonTestSupport.frame(label, in: window)))
    }

    @Test func dynamicStateAndPresentationKeepContentIdentity() async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = BubbleSurfaceIdentity()
        let window = support.window(BubbleSurfaceIdentitySample(probe: probe), size: NSSize(width: 300, height: 160))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let frame = try NativeSyntaxUI.frame("syntax.bubble.identity", in: window)
        let identity = try #require(probe.identity)
        for presented in [true, false, true] {
            for hovered in [false, true] {
                for copied in [false, true] {
                    probe.presented = presented
                    probe.hovered = hovered
                    probe.copied = copied
                    try await SystemPageHost.settle(window)
                    #expect(probe.appearances == 1 && probe.identity == identity)
                    #expect(try NativeSyntaxUI.frame("syntax.bubble.identity", in: window) == frame)
                }
            }
        }
    }

    @Test(arguments: [false, true], [false, true])
    func dynamicBorderDoesNotInterceptContent(hovered: Bool, copied: Bool) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        var calls = 0
        let window = support.window(Button { calls += 1 } label: {
            Text(verbatim: "Synthetic").frame(width: 180, height: 72)
        }.buttonStyle(.plain).daybookSurface(floating: .rowBubble(isHovered: hovered, isCopied: copied)),
            size: NSSize(width: 280, height: 160))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SurfaceEventTestSupport.click(NSPoint(x: 140, y: 80), in: window)
        #expect(calls == 1)
    }
}

@Observable @MainActor private final class BubbleSurfaceIdentity {
    var presented = true
    var hovered = false
    var copied = false
    var identity: UUID?
    var appearances = 0
}

private struct BubbleSurfaceIdentitySample: View {
    let probe: BubbleSurfaceIdentity
    @State private var identity = UUID()

    var body: some View {
        Text(verbatim: "Synthetic").frame(width: 210, height: 80)
            .onAppear { probe.appearances += 1; probe.identity = identity }
            .background(SyntaxViewAnchor("syntax.bubble.identity"))
            .daybookSurface(floating: .rowBubble(isHovered: probe.hovered, isCopied: probe.copied), isPresented: probe.presented)
    }
}
