import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct QuadrantPreviewSurfaceTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func directProductionAppearance(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        for long in [false, true] {
            for hint in [false, true] {
                let probe = QuadrantPreviewStateProbe()
                probe.excerpt = long ? QuadrantPreviewTestSupport.sixLines : "Synthetic 摘要"
                probe.showsHint = hint
                let window = support.window(QuadrantPreviewSample(probe: probe), locale: locale, scheme: scheme,
                    size: CGSize(width: 340, height: 240))
                defer { SystemPageHost.release(window) }
                try await SystemPageHost.settle(window)
                let rect = try QuadrantPreviewTestSupport.frame(window)
                #expect(rect.width == 260 && rect.minX == 40)
                #expect(rect.height > (long ? 80 : 20) && rect.height < 140)
                #expect(probe.copies.isEmpty && probe.appearances == 1)
                QuadrantPreviewTestSupport.assertText(window, probe: probe, locale: locale, copied: false)
                try QuadrantPreviewTestSupport.record(window, name: "matrix-\(locale)-\(scheme)-\(long)-\(hint)",
                    frame: rect, probe: probe)
            }
        }
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func frozenDecorationMatchesStaticRowBubble(scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let surface = DaybookFloatingSurface.rowBubble(isHovered: false, isCopied: false)
        #expect(surface.borderOpacity == 0.9 && surface.borderWidth == 0.8)
        #expect(surface.borderColor == DaybookPalette.border.default.opacity(0.9))
        #expect(surface.shape.style == .continuous && surface.radius == DaybookRadius.small)
        // 旧 RowBubble 默认装饰与本轮旧预览逐项一致，复用冻结装饰，不复制完整预览业务。
        let content = Text(verbatim: "Synthetic\n合成正文").frame(width: 260, height: 110)
            .overlay(alignment: .topTrailing) { Color.red.frame(width: 8, height: 8).offset(x: 4, y: -4) }
        let old = support.window(content.modifier(OriginalRowBubbleSurface()).padding(32), scheme: scheme,
            size: CGSize(width: 324, height: 174))
        defer { SystemPageHost.release(old) }
        try await SystemPageHost.settle(old)
        let before = try RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(old))
        let new = support.window(content.daybookSurface(floating: surface).padding(32), scheme: scheme,
            size: CGSize(width: 324, height: 174))
        defer { SystemPageHost.release(new) }
        try await SystemPageHost.settle(new)
        #expect(try before == RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(new)))
    }

    @Test func sixLineAndProbeLimitsRemainBounded() {
        #expect(QuadrantTitleOverflow.previewLineLimit == 6)
        #expect(QuadrantTitleOverflow.previewProbeLimit == 360 && QuadrantTitleOverflow.overflowProbeLimit == 80)
        let title = String(repeating: "Synthetic合成全文", count: 2_000)
        let preview = QuadrantTitleOverflow.preview(title)
        #expect(preview.isPartial && preview.excerpt.count < 360)
        #expect(title.hasPrefix(preview.excerpt))
        #expect(QuadrantTitleOverflow.overflowsProbe(title, visibleWidth: 260))
    }
}
