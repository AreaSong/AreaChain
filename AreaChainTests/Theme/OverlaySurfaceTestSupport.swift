import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// C 阶段冻结的迁移前绘制，只用于测试对照；不复制候选内容或生产宿主。
struct OriginalOverlaySurface: ViewModifier {
    var attributes = false
    var presented = true

    func body(content: Content) -> some View {
        if attributes {
            content
                .background(RoundedRectangle(cornerRadius: DaybookRadius.small).fill(DaybookPalette.fill.page))
                .overlay(RoundedRectangle(cornerRadius: DaybookRadius.small)
                    .stroke(DaybookPalette.border.default.opacity(0.7), lineWidth: 0.7))
                .daybookElevation(.floating)
        } else {
            content.background {
                if presented {
                    RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
                        .fill(DaybookPalette.fill.page).daybookElevation(.floating)
                }
            }.overlay {
                if presented {
                    RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
                        .stroke(DaybookPalette.border.default.opacity(0.7), lineWidth: 0.7)
                }
            }
        }
    }
}

/// D 阶段只冻结手记主卡装饰；内容、悬停和业务仍直接挂载生产组件。
struct OriginalDiaryPreviewSurface: ViewModifier {
    var presented = true

    func body(content: Content) -> some View {
        content.background {
            if presented {
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(DaybookPalette.fill.page).daybookElevation(.floating)
            }
        }.overlay {
            if presented {
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .stroke(DaybookPalette.border.default.opacity(0.7), lineWidth: 0.7)
            }
        }
    }
}

/// E 阶段冻结原标签详情/帮助外壳，不借用新公共边框值，避免对照随实现一起变化。
struct OriginalDetailSurface: ViewModifier {
    var help = false

    func body(content: Content) -> some View {
        let radius = help ? DaybookRadius.medium : DaybookRadius.regular
        content.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(DaybookPalette.fill.page).daybookElevation(.floating)
        ).overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(DaybookPalette.border.default.opacity(0.6), lineWidth: 0.8)
        )
    }
}

@MainActor
enum OverlaySurfaceTestSupport {
    static let cases = DaybookOverlaySamples.cases
    static let attributes = DaybookOverlaySamples.attributes

    static func state(_ scenario: String) -> SyntaxAutocompleteState {
        DaybookOverlaySamples.state(scenario)
    }

    static func popup(_ scenario: String, state: SyntaxAutocompleteState, width: CGFloat, height: CGFloat) -> some View {
        DaybookOverlaySamples.popup(scenario, state: state, width: width, height: height)
    }

    static func bitmap(_ window: NSWindow) throws -> NSBitmapImageRep {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }

    static func record(_ window: NSWindow, name: String) throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "AreaChainSurfaceQA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try #require(bitmap(window).representation(using: .png, properties: [:]))
            .write(to: directory.appending(path: name + ".png"))
        let views = descendants(window.contentView)
        let frames = views.filter { $0 is NSScrollView || $0.identifier?.rawValue.hasPrefix("syntax.") == true }
            .map { view in
                ["id": view.identifier?.rawValue ?? String(describing: type(of: view)),
                 "frame": NSStringFromRect(view.convert(view.bounds, to: nil)),
                 "bounds": NSStringFromRect(view.bounds)]
            }
        try JSONSerialization.data(withJSONObject: frames, options: [.sortedKeys, .prettyPrinted])
            .write(to: directory.appending(path: name + ".json"))
    }

    static func descendants(_ view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return [view] + view.subviews.flatMap { descendants($0) }
    }
}
