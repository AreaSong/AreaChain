import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DiaryTitleHoverTests {
    @Test(arguments: [false, true], [0, 1])
    func boundaryReturnExitAndRapidMovement(lower: Bool, variant: Int) async throws {
        let fixture = try DiaryTitleHoverFixture(lower: lower, variant: variant)
        defer { fixture.close() }
        let title = try await fixture.open()
        let bubble = try fixture.bubbleFrame()
        let row = try NativeSyntaxUI.frame("diary.summary." + fixture.probe.entry.id.uuidString, in: fixture.window)
        #expect(lower ? bubble.maxY > title.maxY : bubble.minY < title.minY)
        print("DIARY_N geometry lower=\(lower) row=\(row) title=\(title) bubble=\(bubble)")
        if lower {
            for vertical in [row.maxY - 1, row.maxY + 1] {
                let point = NSPoint(x: bubble.midX, y: vertical)
                try #require(bubble.insetBy(dx: 6, dy: 6).contains(point))
                try await fixture.move(point)
                #expect(fixture.chrome.isTitleBubbleHovered && fixture.hasBubble)
            }
        }
        try await fixture.move(NSPoint(x: bubble.midX, y: bubble.midY))
        #expect(fixture.chrome.isTitleBubbleHovered && fixture.hasBubble)
        // 复用 M 的标题中心路径；向上气泡与标题有原有重叠。
        let trigger = NSPoint(x: title.midX, y: title.midY)
        try await fixture.move(trigger)
        #expect(fixture.hasBubble && fixture.chrome.isTitleTextHovered)
        for _ in 0..<3 {
            try fixture.dispatch(NSPoint(x: bubble.midX, y: bubble.midY))
            try await Task.sleep(for: .milliseconds(20))
            try fixture.dispatch(trigger)
            try await Task.sleep(for: .milliseconds(20))
        }
        try await SystemPageHost.settle(fixture.window)
        #expect(fixture.hasBubble)
        try await fixture.move(NSPoint(x: 8, y: 8))
        #expect(!fixture.chrome.isTitleBubbleHovered && !fixture.chrome.isTitleTextHovered)
        try await fixture.expectRemoved()
        #expect(fixture.probe.selections == 0)
    }

    @Test func observedBubbleKeepsClickBoundaryAndUnmountCleanup() async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = RowBubbleProbe()
        let pointer = NSEvent.mouseLocation
        defer { RowBubbleTestSupport.warp(pointer) }
        let window = support.window(ObservedTitleSample(probe: probe), size: NSSize(width: 340, height: 340))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        // key window 就绪不保证 SwiftUI 已完成首轮原生子视图挂载。
        try await SystemPageHost.settle(window)
        let view = try #require(DiaryTitleHoverFixture.regions(window.contentView).first)
        let rect = view.convert(view.bounds, to: nil)
        #expect(view.hitTest(NSPoint(x: view.bounds.midX, y: view.bounds.midY)) == nil)
        for point in [NSPoint(x: rect.minX - 2, y: rect.midY),
                      NSPoint(x: rect.minX + 0.5, y: rect.minY + 0.5)] {
            try await SurfaceEventTestSupport.click(point, in: window)
            #expect(probe.copies == 0)
        }
        try await RowBubbleTestSupport.move(NSPoint(x: rect.midX, y: rect.midY), in: window)
        #expect(probe.hovers.last == true)
        try await SurfaceEventTestSupport.click(NSPoint(x: rect.midX, y: rect.midY), in: window)
        #expect(probe.copies == 1)
        probe.mounted = false
        try await SystemPageHost.settle(window)
        #expect(probe.hovers.last == false)
        let count = probe.hovers.count
        try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
        try await RowBubbleTestSupport.move(NSPoint(x: rect.midX, y: rect.midY), in: window)
        #expect(probe.hovers.count == count && probe.copies == 1)
        probe.mounted = true
        try await SystemPageHost.settle(window)
        #expect(!RowBubbleTestSupport.copied(window))
    }

    @Test func sensitiveCommandReplacementAndRemount() async throws {
        let fixture = try DiaryTitleHoverFixture()
        defer { fixture.close() }
        _ = try await fixture.open()
        try await fixture.enterBubble()
        fixture.probe.sensitive = true
        try await SystemPageHost.settle(fixture.window)
        #expect(!fixture.hasBubble && !fixture.chrome.isTitleBubbleHovered)
        #expect(!SurfaceConsumerUI.strings(fixture.window).contains { $0.contains("Synthetic") })
        try await fixture.move(NSPoint(x: 8, y: 8))
        fixture.probe.sensitive = false
        try await SystemPageHost.settle(fixture.window)
        #expect(!fixture.hasBubble)
        _ = try await fixture.open()
        try await fixture.enterBubble()
        try await fixture.command(true)
        #expect(fixture.chrome.isCommandPressed && !fixture.chrome.isTitleTextHovered)
        try await fixture.expectRemoved()
        try await fixture.move(NSPoint(x: 8, y: 8))
        try await fixture.command(false)
        #expect(!fixture.hasBubble)
        _ = try await fixture.open()
        fixture.probe.entry.text = "Replacement " + fixture.probe.entry.text
        try await SystemPageHost.settle(fixture.window)
        #expect(!fixture.hasBubble)
        try await fixture.move(NSPoint(x: 8, y: 8))
        _ = try await fixture.open()
        fixture.probe.mounted = false
        try await SystemPageHost.settle(fixture.window)
        #expect(!fixture.hasBubble && !fixture.chrome.isTitleTextHovered && !fixture.chrome.isTitleBubbleHovered)
        try await fixture.move(NSPoint(x: 8, y: 8))
        fixture.probe.mounted = true
        try await SystemPageHost.settle(fixture.window)
        #expect(!fixture.hasBubble)
        _ = try await fixture.open()
        try await fixture.enterBubble()
        #expect(fixture.hasBubble)
        let replacement = DiaryEntry(text: "Replacement row " + fixture.probe.entry.text, dayKey: "2026-10-06")
        fixture.support.container.mainContext.insert(replacement)
        fixture.probe.entry = replacement
        try await SystemPageHost.settle(fixture.window)
        #expect(!fixture.chrome.isTitleTextHovered && !fixture.chrome.isTitleBubbleHovered)
        try await fixture.expectRemoved()
        try await fixture.move(NSPoint(x: 8, y: 8))
        #expect(!fixture.hasBubble)
    }

    @Test func scrollUsesCurrentGeometry() async throws {
        let fixture = try DiaryTitleHoverFixture(scrollable: true)
        defer { fixture.close() }
        _ = try await fixture.open()
        let original = try fixture.bubbleFrame()
        try await fixture.enterBubble()
        let scroll = try #require(Self.scrollView(fixture.window.contentView))
        let clip = scroll.contentView
        clip.scroll(to: NSPoint(x: clip.bounds.minX, y: clip.bounds.minY + original.height + 30))
        scroll.reflectScrolledClipView(clip)
        try await SystemPageHost.settle(fixture.window)
        #expect(!fixture.chrome.isTitleBubbleHovered)
        try await fixture.expectRemoved()
        _ = try await fixture.open()
        let current = try fixture.bubbleFrame()
        #expect(abs(current.midY - original.midY) > original.height)
        try await fixture.enterBubble()
        #expect(fixture.chrome.isTitleBubbleHovered)
    }

    @Test func rowsDoNotHoldEachOther() async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let entries = [DiaryEntry(text: String(repeating: "Synthetic first ", count: 5).trimmingCharacters(in: .whitespaces), dayKey: "2026-10-06"),
                       DiaryEntry(text: String(repeating: "Synthetic second ", count: 5).trimmingCharacters(in: .whitespaces), dayKey: "2026-10-06")]
        let states = [BoardRowChrome(), BoardRowChrome()]
        for entry in entries { support.container.mainContext.insert(entry) }
        try support.container.mainContext.save()
        let window = support.window(VStack {
            Spacer().frame(height: 250)
            DiarySummaryRow(entry: entries[0], onDelete: {}, chrome: states[0]).frame(width: 316)
            DiarySummaryRow(entry: entries[1], onDelete: {}, chrome: states[1]).frame(width: 316)
            Spacer()
        }.padding(32), size: NSSize(width: 380, height: 600))
        defer { SystemPageHost.release(window) }
        let pointer = NSEvent.mouseLocation
        defer { RowBubbleTestSupport.warp(pointer) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
        var previousRegion: RowBubbleHoverView?
        for index in entries.indices {
            let node = try #require(SettingsButtonTestSupport.elements(window.contentView).first {
                SettingsButtonTestSupport.value($0, "accessibilityValue") as? String == entries[index].text
            })
            let title = try SettingsButtonTestSupport.frame(node, in: window)
            try await RowBubbleTestSupport.move(NSPoint(x: title.midX, y: title.midY), in: window)
            try await Task.sleep(for: .milliseconds(450))
            let candidates = DiaryTitleHoverFixture.regions(window.contentView).filter { $0 !== previousRegion }
            let region = try #require(candidates.first, "新行必须挂载自己的气泡，不能复用正在淡出的旧行几何")
            #expect(candidates.count == 1)
            previousRegion = region
            let bubble = region.convert(region.bounds, to: nil)
            print("DIARY_N row=\(index) title=\(title) bubble=\(bubble)")
            try await RowBubbleTestSupport.move(NSPoint(x: bubble.midX, y: bubble.midY), in: window)
            try await Task.sleep(for: .milliseconds(180))
            #expect(states[index].isTitleBubbleHovered && !states[1 - index].isTitleBubbleHovered)
            if index == 0, ProcessInfo.processInfo.environment["AREACHAIN_DIARY_N_SCREEN"] == "1" {
                window.title = "AreaChain N · Synthetic hover"
                try DiaryDiagnostic.record(window, phase: "N-screen-boundary")
                // 独立截图窗口期不投递指针事件；默认自动回归不等待桌面工具。
                try await Task.sleep(for: .seconds(40))
                #expect(states[0].isTitleBubbleHovered && window.isKeyWindow)
            }
        }
        try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
        try await Task.sleep(for: .milliseconds(180))
        #expect(states.allSatisfy { !$0.isTitleTextHovered && !$0.isTitleBubbleHovered })
    }

    private static func scrollView(_ view: NSView?) -> NSScrollView? {
        guard let view else { return nil }
        return (view as? NSScrollView) ?? view.subviews.compactMap { scrollView($0) }.first
    }

    @Test func layoutAndWindowOwnership() async throws {
        let first = try DiaryTitleHoverFixture()
        defer { first.close() }
        _ = try await first.open()
        let original = try first.bubbleFrame()
        try await first.enterBubble()
        first.probe.inset += original.height + 30
        try await SystemPageHost.settle(first.window)
        #expect(!first.chrome.isTitleBubbleHovered && !first.chrome.isTitleTextHovered)
        try await first.expectRemoved()
        _ = try await first.open()
        let moved = try first.bubbleFrame()
        #expect(abs(moved.midY - original.midY) > original.height)
        try await first.enterBubble()
        let second = try DiaryTitleHoverFixture(lower: false)
        defer { second.close() }
        _ = try await second.open()
        #expect(!first.window.isKeyWindow && !first.hasBubble && !first.chrome.isTitleBubbleHovered)
        try await second.enterBubble()
        #expect(second.hasBubble && !first.hasBubble)
        second.window.close()
        try await Task.sleep(for: .milliseconds(180))
        #expect(!second.chrome.isTitleBubbleHovered && !second.chrome.isTitleTextHovered)
        try await NativeSyntaxUI.prepareFocus(in: first.window)
        try await first.move(NSPoint(x: 8, y: 8))
        #expect(!first.hasBubble)
    }
}

private struct ObservedTitleSample: View {
    let probe: RowBubbleProbe
    var body: some View {
        ZStack {
            if probe.mounted {
                RowTitleBubble(title: "Synthetic 合成文本", growsUpward: true,
                    onCopy: { probe.copies += 1 }, onHover: { probe.hovers.append($0) })
                    .observingWindowHover(onInvalidate: {})
            }
        }.frame(width: 340, height: 340)
    }
}
