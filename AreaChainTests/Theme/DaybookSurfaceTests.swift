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
    func helpClipRemainsAfterTheEntireDecoration(scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let clip = RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
        let sample = Color.red.frame(width: 180, height: 72)
        let old = support.window(sample.modifier(OriginalDetailSurface(help: true)).clipShape(clip).padding(32),
            scheme: scheme, size: NSSize(width: 244, height: 136))
        defer { SystemPageHost.release(old) }
        try await SystemPageHost.settle(old)
        let before = try OverlaySurfaceTestSupport.bitmap(old)
        let current = support.window(sample.daybookSurface(floating: .syntaxHelp).clipShape(clip).padding(32),
            scheme: scheme, size: NSSize(width: 244, height: 136))
        defer { SystemPageHost.release(current) }
        try await SystemPageHost.settle(current)
        #expect(try pixels(before) == pixels(OverlaySurfaceTestSupport.bitmap(current)))
        let full = support.window(sample.daybookSurface(floating: .syntaxHelp).padding(32),
            scheme: scheme, size: NSSize(width: 244, height: 136))
        defer { SystemPageHost.release(full) }
        try await SystemPageHost.settle(full)
        #expect(try pixels(before) != pixels(OverlaySurfaceTestSupport.bitmap(full)), "帮助原裁切不能删掉以显露阴影")
        try OverlaySurfaceTestSupport.record(current, name: "e-help-clipped-\(scheme)")
        try OverlaySurfaceTestSupport.record(full, name: "e-help-full-\(scheme)")
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func matchesFrozenDrawingIncludingOutsideEdges(scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        for presentation in [DaybookFloatingSurface.suggestions, .readOnly, .smallBackground, .tagDetail, .syntaxHelp, .filterFlyout] {
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

    @Test(arguments: [DaybookFloatingSurface.suggestions, .readOnly, .smallBackground, .tagDetail, .syntaxHelp, .filterFlyout])
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

    @Test(arguments: [DaybookFloatingSurface.suggestions, .readOnly, .smallBackground, .tagDetail, .syntaxHelp, .filterFlyout], ["send", "queue"])
    func decorationDoesNotExpandPointerInterception(presentation: DaybookFloatingSurface, delivery: String) async throws {
        for shell in [SurfacePointerDecoration.plain, .frozen, .current, .hidden] {
            try await pointerOwnership(presentation: presentation, shell: shell, delivery: delivery)
        }
    }

    @Test(arguments: [SurfacePointerDecoration.plain, .frozen, .current], ["send", "queue"])
    func mediumCenterEventOwnership(shell: SurfacePointerDecoration, delivery: String) async throws {
        try await pointerOwnership(presentation: .syntaxHelp, shell: shell, delivery: delivery)
    }

    private func pointerOwnership(presentation: DaybookFloatingSurface, shell: SurfacePointerDecoration, delivery: String) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let model = SurfacePointerProbe()
        let window = support.window(SurfacePointerSample(model: model, decoration: shell, presentation: presentation),
            size: NSSize(width: 280, height: 160))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let buttons = SettingsButtonTestSupport.buttons(in: window)
        try #require(buttons.count == 1)
        let rect = try SettingsButtonTestSupport.frame(#require(buttons.first), in: window)
        try await SystemPageHost.settle(window)
        let stable = try SettingsButtonTestSupport.frame(#require(buttons.first), in: window)
        #expect(rect == stable && rect.width < 180 && rect.height < 72)
        #expect(rect.contains(NSPoint(x: 140, y: 80)))
        SurfaceEventTestSupport.note("\(presentation) \(shell) \(delivery) button AX=\(rect) outer=180x72")
        // 冻结 medium 精确刻画旧故障；它通过不代表旧功能通过，也不能决定公共壳的成功预期。
        let expectedClick = shell == .frozen && presentation == .syntaxHelp ? 0 : 1
        for (name, point) in [("center", NSPoint(x: 140, y: 80)),
                              ("AX-center", NSPoint(x: rect.midX, y: rect.midY)),
                              ("label-inset", NSPoint(x: rect.minX + 2, y: rect.midY))] {
            let before = model.inside
            try await SurfaceEventTestSupport.click(point, in: window, delivery: delivery)
            #expect(model.inside == before + expectedClick, "\(presentation) \(shell) \(delivery) \(name)")
            #expect(model.outside == 0, "内容点击不能重复回调或穿透到宿主")
        }
        #expect(model.inside == 3 * expectedClick)
        try await boundaryOwnership(model: model, window: window, shell: shell, delivery: delivery)
    }

    private func boundaryOwnership(model: SurfacePointerProbe, window: NSWindow,
                                   shell: SurfacePointerDecoration, delivery: String) async throws {
        let beforeBoundary = model.inside
        let points = [NSPoint(x: 60, y: 80), NSPoint(x: 51, y: 45), NSPoint(x: 49, y: 80),
                      NSPoint(x: 42, y: 80), NSPoint(x: 140, y: 36)]
        for (index, point) in points.enumerated() {
            let outside = model.outside
            try await SurfaceEventTestSupport.click(point, in: window, delivery: delivery)
            #expect(model.inside == beforeBoundary, "空白、圆角外侧、边缘和阴影不能冒充 Button 点击区")
            let expectedHostClick = index == 0 && shell != .plain && shell != .hidden ? 0 : 1
            #expect(model.outside == outside + expectedHostClick, "\(shell) \(delivery) boundary[\(index)] 宿主恰好接收一次外部点击")
        }
        SurfaceEventTestSupport.note("boundary \(shell) inside=\(model.inside) outside=\(model.outside)")
    }

    @Test(arguments: [SurfacePointerDecoration.background, .border, .nonHittableBorder])
    func mediumDecorationLayerOwnership(shell: SurfacePointerDecoration) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let model = SurfacePointerProbe()
        let window = support.window(SurfacePointerSample(model: model, decoration: shell, presentation: .syntaxHelp),
            size: NSSize(width: 280, height: 160))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await SurfaceEventTestSupport.click(NSPoint(x: 140, y: 80), in: window)
        SurfaceEventTestSupport.note("layer \(shell) inside=\(model.inside) outside=\(model.outside)")
        // border 是故障层的刻画对照；公共完整外壳的成功要求独立断言，冻结壳保留已知故障。
        #expect(model.inside == (shell == .border ? 0 : 1))
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
}

private struct SurfacePointerSample: View {
    let model: SurfacePointerProbe
    let decoration: SurfacePointerDecoration
    let presentation: DaybookFloatingSurface

    private var content: some View {
        Button { model.inside += 1 } label: { Text(verbatim: "Synthetic") }
            .buttonStyle(.plain).frame(width: 180, height: 72)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
            .fill(DaybookPalette.fill.page).daybookElevation(.floating)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
            .stroke(DaybookPalette.border.default.opacity(0.6), lineWidth: 0.8)
    }

    var body: some View {
        Color.gray.onTapGesture { model.outside += 1 }.overlay {
            switch decoration {
            case .plain: content
            case .frozen: content.modifier(FrozenFloatingSurface(presentation: presentation))
            case .current: content.daybookSurface(floating: presentation)
            case .hidden: content.daybookSurface(floating: presentation, isPresented: false)
            case .background: content.background(background)
            case .border: content.overlay(border)
            case .nonHittableBorder:
                // 仅作测试消融，证明是否由描边接收；不改生产命中政策。
                content.background(background).overlay(border.allowsHitTesting(false))
            }
        }
    }
}

/// 冻结装饰共用同一合成内容，不复制任何生产预览业务。
private struct FrozenFloatingSurface: ViewModifier {
    let presentation: DaybookFloatingSurface

    func body(content: Content) -> some View {
        if presentation == .filterFlyout {
            content.modifier(OriginalFilterSurface())
        } else if presentation == .tagDetail || presentation == .syntaxHelp {
            content.modifier(OriginalDetailSurface(help: presentation == .syntaxHelp))
        } else if presentation == .smallBackground {
            content.modifier(OriginalDiaryPreviewSurface())
        } else {
            content.modifier(OriginalOverlaySurface(attributes: presentation == .readOnly))
        }
    }
}

// 只在 E 补验中分离原装饰层，生产 API 不增加诊断开关。
enum SurfacePointerDecoration: String {
    case plain, frozen, current, hidden, background, border, nonHittableBorder
}
