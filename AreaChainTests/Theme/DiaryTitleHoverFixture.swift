import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Observable @MainActor
final class DiaryTitleHoverProbe {
    var entry: DiaryEntry
    var sensitive = false
    var mounted = true
    var inset: CGFloat
    var selections = 0

    init(lower: Bool, long: Bool) {
        entry = DiaryEntry(text: String(repeating: "Synthetic 合成长标题 ", count: long ? 8 : 4)
            .trimmingCharacters(in: .whitespaces), dayKey: "2026-10-06")
        inset = lower ? 300 : 0
    }
}

@MainActor
final class DiaryTitleHoverFixture {
    let support: SettingsButtonTestSupport
    let probe: DiaryTitleHoverProbe
    let chrome = BoardRowChrome()
    let window: NSWindow
    private let pointer = NSEvent.mouseLocation

    init(lower: Bool = true, variant: Int = 0, scrollable: Bool = false) throws {
        support = try SettingsButtonTestSupport(isolatedPreferences: true)
        probe = DiaryTitleHoverProbe(lower: lower, long: variant == 1)
        support.container.mainContext.insert(probe.entry)
        try support.container.mainContext.save()
        let host = DiaryTitleHoverHost(probe: probe, chrome: chrome, width: variant == 0 ? 316 : 260)
        let content = Group {
            if scrollable { ScrollView { host.frame(height: 1000, alignment: .top) } }
            else { host }
        }
        window = support.window(content,
            locale: variant == 0 ? "en" : "zh-Hans", scheme: variant == 0 ? .light : .dark,
            size: NSSize(width: variant == 0 ? 380 : 324, height: variant == 0 ? 540 : 620))
    }

    var regions: [RowBubbleHoverView] { Self.regions(window.contentView) }
    var hasBubble: Bool { !regions.isEmpty }

    static func regions(_ view: NSView?) -> [RowBubbleHoverView] {
        guard let view else { return [] }
        return (view as? RowBubbleHoverView).map { [$0] } ?? view.subviews.flatMap { regions($0) }
    }

    func bubbleFrame() throws -> CGRect {
        let region = try #require(regions.first)
        return region.convert(region.bounds, to: nil)
    }

    func open() async throws -> CGRect {
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await move(NSPoint(x: 8, y: 8))
        let node = try #require(SettingsButtonTestSupport.elements(window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityValue") as? String == probe.entry.text
        })
        let title = try SettingsButtonTestSupport.frame(node, in: window)
        try await RowBubbleTestSupport.move(NSPoint(x: title.midX, y: title.midY), in: window)
        try await Task.sleep(for: .milliseconds(450))
        try #require(hasBubble, "标题真实进入后必须显示气泡")
        return title
    }

    func enterBubble() async throws {
        let bubble = try bubbleFrame()
        try await move(NSPoint(x: bubble.midX, y: bubble.midY))
        #expect(chrome.isTitleBubbleHovered && hasBubble)
    }

    func move(_ point: NSPoint) async throws {
        try await RowBubbleTestSupport.move(point, in: window)
        try await Task.sleep(for: .milliseconds(180))
        print("DIARY_N move=\(point) row=\(chrome.isRowHovered) title=\(chrome.isTitleTextHovered) bubble=\(chrome.isTitleBubbleHovered) rawTitle=\(chrome.isTitlePointerInside) regions=\(regions.count)")
    }

    func dispatch(_ point: NSPoint) throws {
        RowBubbleTestSupport.warp(window.convertPoint(toScreen: point))
        let event = try #require(NSEvent.mouseEvent(with: .mouseMoved, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 0, pressure: 0))
        NSApp.sendEvent(event)
    }

    func command(_ pressed: Bool) async throws {
        let event = try #require(NSEvent.keyEvent(with: .flagsChanged, location: .zero,
            modifierFlags: pressed ? .command : [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: 55))
        NSApp.sendEvent(event)
        try await SystemPageHost.settle(window)
    }

    func expectRemoved() async throws {
        // 原 snappy 弹簧淡出可能仍保留 AppKit 视图；逻辑退出已在调用前按原延迟断言。
        try await Task.sleep(for: .milliseconds(450))
        #expect(!hasBubble)
    }

    func close() {
        SystemPageHost.release(window)
        support.cleanup()
        RowBubbleTestSupport.warp(pointer)
    }
}

private struct DiaryTitleHoverHost: View {
    let probe: DiaryTitleHoverProbe
    let chrome: BoardRowChrome
    let width: CGFloat

    var body: some View {
        VStack {
            Spacer().frame(height: probe.inset)
            if probe.mounted {
                DiarySummaryRow(entry: probe.entry, projectedSensitive: probe.sensitive,
                    onSelect: { probe.selections += 1 }, onDelete: {}, chrome: chrome).frame(width: width)
            }
            Spacer()
        }.padding(32)
    }
}
