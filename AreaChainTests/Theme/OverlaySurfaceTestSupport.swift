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

@MainActor
enum OverlaySurfaceTestSupport {
    static let cases = ["candidates", "task-combined", "task-preview", "diary-combined", "diary-preview", "empty", "attributes"]

    static func state(_ scenario: String) -> SyntaxAutocompleteState {
        let state = SyntaxAutocompleteState(context: scenario.hasPrefix("diary") ? .diaryCapture : .capture,
                                            allowsLivePreview: scenario.contains("combined") || scenario.contains("preview"))
        let text = scenario == "empty" ? "" : "Synthetic 合成 #工作 #工"
        state.update(text: text, cursorLocation: text.utf16.count,
                     availableTags: ["工作", "工程", "工具", "工时", "工单", "工艺", "工位", "工厂"])
        if scenario.contains("preview") { state.dismissSuggestionsOnly() }
        return state
    }

    static let attributes = CaptureAttributes(
        text: "Synthetic #工作 #新标签 #three #four #five #six !p1 @09:00", knownTags: ["工作"])

    @ViewBuilder
    static func popup(_ scenario: String, state: SyntaxAutocompleteState, width: CGFloat, height: CGFloat) -> some View {
        if scenario == "attributes" {
            CaptureAttributesPopup(attributes: attributes, maxHeight: height, state: state).frame(width: width)
        } else {
            SyntaxAutocompletePopup(state: state, width: width, maxHeight: height, motionDisabled: true, onCommit: { _ in })
        }
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
