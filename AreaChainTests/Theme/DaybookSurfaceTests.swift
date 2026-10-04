import AppKit
import SwiftUI
import Testing
@testable import AreaChain

struct DaybookSurfaceTests {
    @Test func standardConfigurationFollowsTheBaseline() {
        let row = DaybookSurfaceConfiguration.standard(for: .row)
        #expect(row.radius == DaybookRadius.small)
        #expect(row.minHeight == nil)
        #expect(row.padding == EdgeInsets())

        let card = DaybookSurfaceConfiguration.standard(for: .card)
        #expect(card.radius == DaybookRadius.medium)

        let panel = DaybookSurfaceConfiguration.standard(for: .panel)
        #expect(panel.radius == DaybookMetrics.Radius.panel)

        let banner = DaybookSurfaceConfiguration.standard(for: .banner)
        #expect(banner.radius == DaybookMetrics.Radius.inputComposer)
        #expect(banner.padding.top == 10)
        #expect(banner.padding.leading == 10)
    }

    @Test func configureCanChangeRadiusWithoutChangingTheVariantDefault() {
        var card = DaybookSurfaceConfiguration.standard(for: .card)
        card.radius = DaybookRadius.small
        #expect(card.radius == DaybookRadius.small)
        #expect(DaybookSurfaceConfiguration.standard(for: .card).radius == DaybookRadius.medium)
    }
}

@Suite(.serialized) @MainActor
struct DaybookFloatingSurfaceTests {
    @Test(arguments: [ColorScheme.light, .dark])
    func matchesFrozenDrawingIncludingOutsideEdges(scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        for presentation in [DaybookFloatingSurface.suggestions, .readOnly, .smallBackground] {
            let sample = Text(verbatim: "Synthetic").frame(width: 180, height: 72)
                // 越界图形能区分整体阴影/背景阴影，并发现额外裁切。
                .overlay(alignment: .topTrailing) { Circle().fill(.red).frame(width: 16, height: 16).offset(x: 8, y: -8) }
            let original = support.window(sample.modifier(FrozenFloatingSurface(presentation: presentation)).padding(32),
                                          scheme: scheme, size: NSSize(width: 244, height: 136))
            defer { SystemPageHost.release(original) }
            try await SystemPageHost.settle(original)
            let before = try OverlaySurfaceTestSupport.bitmap(original)
            let current = support.window(sample.daybookSurface(floating: presentation).padding(32),
                                         scheme: scheme, size: NSSize(width: 244, height: 136))
            defer { SystemPageHost.release(current) }
            try await SystemPageHost.settle(current)
            let after = try OverlaySurfaceTestSupport.bitmap(current)
            #expect(before.pixelsWide == after.pixelsWide && before.pixelsHigh == after.pixelsHigh)
            #expect(pixels(before) == pixels(after), "完整外缘、圆角、描边和内容越界阴影必须逐像素相同")
            try OverlaySurfaceTestSupport.record(original, name: "frozen-\(presentation)-\(scheme)")
            try OverlaySurfaceTestSupport.record(current, name: "surface-\(presentation)-\(scheme)")
        }
    }

    @Test(arguments: [DaybookFloatingSurface.suggestions, .readOnly, .smallBackground])
    func disabledDecorationKeepsPreviewIdentityAndGeometry(presentation: DaybookFloatingSurface) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let model = SurfaceIdentityProbe()
        let window = support.window(SurfaceIdentitySample(model: model, presentation: presentation), size: NSSize(width: 280, height: 160))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let before = try NativeSyntaxUI.frame("syntax.surface.identity", in: window)
        let identity = try #require(model.identity)
        for presented in [false, true, false] {
            model.presented = presented
            try await SystemPageHost.settle(window)
            #expect(model.appearances == 1)
            #expect(model.identity == identity && model.stateReads == 1)
            #expect(try NativeSyntaxUI.frame("syntax.surface.identity", in: window) == before)
        }
        let plain = support.window(Text(verbatim: "Synthetic").frame(width: 180, height: 72),
                                   size: NSSize(width: 280, height: 160))
        defer { SystemPageHost.release(plain) }
        try await SystemPageHost.settle(plain)
        #expect(try pixels(OverlaySurfaceTestSupport.bitmap(window)) == pixels(OverlaySurfaceTestSupport.bitmap(plain)))
    }

    @Test func decorationDoesNotExpandPointerInterception() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        for presentation in [DaybookFloatingSurface.suggestions, .readOnly, .smallBackground] {
            var traces: [[Int]] = []
            for original in [true, false] {
                let model = SurfacePointerProbe()
                let window = support.window(SurfacePointerSample(model: model, original: original, presentation: presentation),
                                            size: NSSize(width: 280, height: 160))
                defer { SystemPageHost.release(window) }
                try await NativeSyntaxUI.prepareFocus(in: window)
                try await SystemPageHost.settle(window)
                // 内容中心、透明圆角、边缘和外侧阴影分别走 NSApplication 事件。
                for point in [NSPoint(x: 140, y: 80), NSPoint(x: 51, y: 45),
                              NSPoint(x: 49, y: 80), NSPoint(x: 42, y: 80), NSPoint(x: 140, y: 36)] {
                    for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                        let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                            context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
                        NSApp.sendEvent(event)
                    }
                    try await SystemPageHost.settle(window)
                    model.trace.append(model.inside * 100 + model.outside)
                }
                #expect(model.inside == 1)
                #expect(model.outside >= 3)
                traces.append(model.trace)
            }
            #expect(traces[0] == traces[1])
        }
    }

    private func pixels(_ bitmap: NSBitmapImageRep) -> Data {
        guard let data = bitmap.bitmapData else { return Data() }
        return Data(bytes: data, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func smallBackgroundPreservesRowHoverLayering(scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        for hovered in [false, true] {
            for presented in [false, true] {
                let content = Text(verbatim: "Synthetic 09:00").frame(width: 240, height: 57)
                    .daybookSurface(.row, isHovered: hovered, isSelected: false)
                let original = support.window(content.modifier(OriginalDiaryPreviewSurface(presented: presented)).padding(32),
                    scheme: scheme, size: NSSize(width: 304, height: 121))
                defer { SystemPageHost.release(original) }
                try await SystemPageHost.settle(original)
                let before = try OverlaySurfaceTestSupport.bitmap(original)
                let current = support.window(content.daybookSurface(floating: .smallBackground, isPresented: presented).padding(32),
                    scheme: scheme, size: NSSize(width: 304, height: 121))
                defer { SystemPageHost.release(current) }
                try await SystemPageHost.settle(current)
                #expect(try pixels(before) == pixels(OverlaySurfaceTestSupport.bitmap(current)))
                let suffix = "row-\(scheme)-\(hovered)-\(presented)"
                try OverlaySurfaceTestSupport.record(original, name: "frozen-" + suffix)
                try OverlaySurfaceTestSupport.record(current, name: "surface-" + suffix)
            }
        }
    }
}

@Observable @MainActor private final class SurfaceIdentityProbe {
    var presented = true
    var appearances = 0
    var identity: UUID?
    var stateReads = 0
}

private struct SurfaceIdentitySample: View {
    let model: SurfaceIdentityProbe
    let presentation: DaybookFloatingSurface
    @State private var identity = UUID()
    @State private var stateReads = 0
    var body: some View {
        Text(verbatim: "Synthetic").frame(width: 180, height: 72)
            .onAppear {
                model.appearances += 1
                stateReads += 1
                model.identity = identity
                model.stateReads = stateReads
            }
            .background(SyntaxViewAnchor("syntax.surface.identity"))
            .daybookSurface(floating: presentation, isPresented: model.presented)
    }
}

@Observable @MainActor private final class SurfacePointerProbe {
    var inside = 0
    var outside = 0
    var trace: [Int] = []
}

private struct SurfacePointerSample: View {
    let model: SurfacePointerProbe
    let original: Bool
    let presentation: DaybookFloatingSurface

    private var content: some View {
        Button { model.inside += 1 } label: { Text(verbatim: "Synthetic") }
            .buttonStyle(.plain).frame(width: 180, height: 72)
    }

    var body: some View {
        Color.gray.onTapGesture { model.outside += 1 }.overlay {
            if original {
                content.modifier(FrozenFloatingSurface(presentation: presentation))
            } else {
                content.daybookSurface(floating: presentation)
            }
        }
    }
}

/// 冻结装饰共用同一合成内容，不复制任何生产预览业务。
private struct FrozenFloatingSurface: ViewModifier {
    let presentation: DaybookFloatingSurface

    func body(content: Content) -> some View {
        if presentation == .smallBackground {
            content.modifier(OriginalDiaryPreviewSurface())
        } else {
            content.modifier(OriginalOverlaySurface(attributes: presentation == .readOnly))
        }
    }
}
