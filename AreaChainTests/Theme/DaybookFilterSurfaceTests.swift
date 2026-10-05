import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 只冻结 C 的旧装饰；居中描边/整体阴影仅为可区分的负对照，不复制筛选业务。
struct OriginalFilterSurface: ViewModifier {
    var centered = false
    var wholeShadow = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
        content.background(
            shape.fill(DaybookPalette.fill.page).daybookElevation(wholeShadow ? .flat : .floating)
        ).overlay {
            if centered { shape.stroke(DaybookPalette.border.default.opacity(0.65), lineWidth: 0.8) }
            else { shape.strokeBorder(DaybookPalette.border.default.opacity(0.65), lineWidth: 0.8) }
        }.daybookElevation(wholeShadow ? .floating : .flat)
    }
}

extension DaybookFloatingSurfaceTests {
    @Test(arguments: [ColorScheme.light, .dark])
    func controlsPreviewShowsProductionFilterLevels(scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let window = support.window(MenuBarFilterSurfaceSamples().padding(32),
                                    scheme: scheme, size: NSSize(width: 564, height: 308))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        try OverlaySurfaceTestSupport.record(window, name: "filter-controls-preview-\(scheme)")
        #expect(SurfaceConsumerUI.strings(window).contains("#Synthetic 合成标签"))
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func filterUsesInsetBorderAndBackgroundOnlyShadow(scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let sample = Text(verbatim: "Synthetic").frame(width: 180, height: 72)
            .overlay(alignment: .topTrailing) { Color.red.frame(width: 16, height: 16).offset(x: 8, y: -8) }
        let current = support.window(sample.daybookSurface(floating: .filterFlyout).padding(32),
                                     scheme: scheme, size: NSSize(width: 244, height: 136))
        defer { SystemPageHost.release(current) }
        try await SystemPageHost.settle(current)
        let bytes = try RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(current))
        for (centered, wholeShadow) in [(false, false), (true, false), (false, true)] {
            let window = support.window(sample.modifier(OriginalFilterSurface(centered: centered, wholeShadow: wholeShadow)).padding(32),
                                        scheme: scheme, size: NSSize(width: 244, height: 136))
            defer { SystemPageHost.release(window) }
            try await SystemPageHost.settle(window)
            let equal = try bytes == RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(window))
            #expect(equal == (!centered && !wholeShadow), "必须区分 0.8pt 内描边、居中描边与正文整体阴影")
        }
        #expect(DaybookFloatingSurface.filterFlyout.radius == DaybookRadius.regular)
        #expect(DaybookFloatingSurface.filterFlyout.borderWidth == 0.8)
        #expect(DaybookFloatingSurface.filterFlyout.borderOpacity == 0.65)
    }

    @Test func filterShellDoesNotIntroduceAutomaticHover() async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let pointer = NSEvent.mouseLocation
        defer { RowBubbleTestSupport.warp(pointer) }
        let window = support.window(Text(verbatim: "Synthetic").frame(width: 180, height: 72)
            .daybookSurface(floating: .filterFlyout), size: NSSize(width: 280, height: 160))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await RowBubbleTestSupport.move(NSPoint(x: 10, y: 10), in: window)
        let before = try RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(window))
        try await RowBubbleTestSupport.move(NSPoint(x: 65, y: 60), in: window)
        #expect(try before == RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(window)))
    }
}
