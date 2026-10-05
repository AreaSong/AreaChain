import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Observable @MainActor
final class QuadrantPreviewStateProbe {
    var excerpt = "Synthetic 摘要"
    var title = "Synthetic 全文：摘要以外的内容不会进入预览排版。"
    var showsHint = true
    var mounted = true
    var copies: [String] = []
    var hovers: [Bool] = []
    var appearances = 0
    let id = UUID()
}

/// 直接挂载生产组件；只有宿主记录回调，不复制预览正文、反馈或 Task。
struct QuadrantPreviewSample: View {
    let probe: QuadrantPreviewStateProbe
    var anchor: CGRect?
    var size = CGSize(width: 340, height: 240)

    var body: some View {
        ZStack(alignment: anchor == nil ? .center : .topLeading) {
            Color.clear
            if probe.mounted {
                preview.onAppear { probe.appearances += 1 }
            }
        }.frame(width: size.width, height: size.height)
    }

    @ViewBuilder private var preview: some View {
        if let anchor {
            QuadrantPreviewOverlay(
                preview: QuadrantFloatingPreview(id: probe.id, title: probe.title,
                    excerpt: probe.excerpt, showsHint: probe.showsHint),
                anchor: anchor, containerSize: size,
                onCopy: { probe.copies.append($0) }, onHover: { probe.hovers.append($0) })
        } else {
            QuadrantTitlePreview(excerpt: probe.excerpt, showsHint: probe.showsHint,
                onCopy: { probe.copies.append("no-argument") }, onHover: { probe.hovers.append($0) })
                .background(SyntaxViewAnchor("syntax.quadrant.preview"))
        }
    }
}

@MainActor
enum QuadrantPreviewTestSupport {
    static let sixLines = (1...6).map { "Synthetic 合成第\($0)行" }.joined(separator: "\n")

    static func frame(_ window: NSWindow, probe: QuadrantPreviewStateProbe? = nil) throws -> CGRect {
        let id = probe.map { "quadrant.titleBubble.\($0.id.uuidString)" } ?? "syntax.quadrant.preview"
        return try NativeSyntaxUI.frame(id, in: window)
    }

    /// baseline/current 文件在同一隔离 QA 容器内；比较完整画布，包含全部外缘和阴影。
    static func record(_ window: NSWindow, name: String, frame: CGRect, probe: QuadrantPreviewStateProbe) throws {
        let phase = ProcessInfo.processInfo.environment["AREACHAIN_QUADRANT_PHASE"] ?? "current"
        let directory = FileManager.default.temporaryDirectory.appending(path: "AreaChainQuadrantPreviewQA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bitmap = try OverlaySurfaceTestSupport.bitmap(window)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let evidence: [String: Any] = ["frame": NSStringFromRect(frame), "copies": probe.copies,
            "hovers": probe.hovers, "appearances": probe.appearances,
            "strings": SurfaceConsumerUI.strings(window).sorted()]
        let json = try JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys, .prettyPrinted])
        for (suffix, data) in [("png", png), ("json", json)] {
            let file = directory.appending(path: "\(phase)-\(name).\(suffix)")
            try data.write(to: file)
            if phase == "migrated" {
                let baseline = directory.appending(path: "baseline-\(name).\(suffix)")
                #expect(try Data(contentsOf: baseline) == data, "完整生产消费者基线不等价：\(name).\(suffix)")
            }
        }
        print("QUADRANT_PREVIEW_QA \(phase) \(name) frame=\(frame) copies=\(probe.copies.count) path=\(directory.path)")
    }

    static func assertText(_ window: NSWindow, probe: QuadrantPreviewStateProbe, locale: String, copied: Bool) {
        let strings = SurfaceConsumerUI.strings(window)
        let feedback = L10n.string("diary.copied", locale: Locale(identifier: locale))
        let hint = L10n.string("quadrant.preview.more", locale: Locale(identifier: locale))
        #expect(strings.contains(copied ? feedback : probe.excerpt))
        #expect(strings.contains(hint) == (probe.showsHint && !copied))
        #expect(!strings.contains(probe.title), "显示摘要不能把全文送入排版")
    }
}

/// 用直接生产预览建立已知坐标参照，不复制 overlay 的零尺寸锚点结构或预览业务。
struct QuadrantPositionedPreviewSample: View {
    let probe: QuadrantPreviewStateProbe
    let origin: CGPoint
    let size: CGSize

    var body: some View {
        Color.clear.frame(width: size.width, height: size.height)
            .overlay(alignment: .topLeading) {
                QuadrantTitlePreview(excerpt: probe.excerpt, showsHint: probe.showsHint,
                    onCopy: {}, onHover: { _ in })
                    .frame(width: 260, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: true)
                    .offset(x: origin.x, y: origin.y)
            }
    }
}
