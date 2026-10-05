import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct RowBubbleConsumerTests {
    @Test(arguments: ["row", "task", "diary"], [false, true])
    func titleHoverRetainsProductionBubble(consumer: String, lower: Bool) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let title = String(repeating: "Synthetic 合成长标题 ", count: 4).trimmingCharacters(in: .whitespaces)
        let entry = DiaryEntry(text: title + "\nSynthetic note", dayKey: "2026-10-04")
        support.container.mainContext.insert(entry)
        try support.container.mainContext.save()
        let sample = Group {
            if consumer == "row" { DiarySummaryRow(entry: entry, onDelete: {}) }
            else if consumer == "task" { LiveComposerPreviewHeader(text: title, onClose: {}) }
            else { LiveDiaryComposerPreview(text: title, onCopy: { _, _ in false }) }
        }
        let window = support.window(VStack {
            if lower { Spacer().frame(height: 300) }
            sample.frame(width: 316)
            Spacer()
        }.padding(32), size: NSSize(width: 380, height: 540))
        defer { SystemPageHost.release(window) }
        let pointer = NSEvent.mouseLocation
        defer { RowBubbleTestSupport.warp(pointer) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
        let original = try #require(textNodes(title, window: window).first, "AX: \(SurfaceConsumerUI.strings(window))")
        let rect = try SettingsButtonTestSupport.frame(original, in: window)
        try await RowBubbleTestSupport.move(NSPoint(x: rect.midX, y: rect.midY), in: window)
        try await Task.sleep(for: .milliseconds(450))
        let nodes = textNodes(title, window: window)
        let frames = try nodes.map { try SettingsButtonTestSupport.frame($0, in: window) }
        let bubble = frames.first { $0.height > rect.height + 2 }
        try OverlaySurfaceTestSupport.record(window, name: "f-consumer-\(consumer)-\(lower)")
        #expect(bubble != nil, "原生标题进入应显示多行正文气泡；历史失败单独保留")
        if let bubble {
            try await RowBubbleTestSupport.move(NSPoint(x: bubble.midX, y: bubble.midY), in: window)
            try await Task.sleep(for: .milliseconds(450))
            #expect(textNodes(title, window: window).count >= 2, "进入气泡应保留正文")
        }
        #expect(entry.text == title + "\nSynthetic note" && !support.container.mainContext.hasChanges)
    }

    @Test(arguments: [false, true])
    func taskNoteHoverCandidateExclusionAndRetention(lower: Bool) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = NoteConsumerProbe()
        let window = support.window(VStack {
            if lower { Spacer().frame(height: 300) }
            NoteConsumerSample(probe: probe).frame(width: 316)
            Spacer()
        }.padding(32), size: NSSize(width: 380, height: 540))
        defer { SystemPageHost.release(window) }
        let pointer = NSEvent.mouseLocation
        defer { RowBubbleTestSupport.warp(pointer) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
        let title = try #require(textNodes("Synthetic", window: window).first)
        let rect = try SettingsButtonTestSupport.frame(title, in: window)
        // 原 HStack 间距 5、图标水平 padding 3.5；从真实标题边界进入其右侧备注指示器。
        let indicator = NSPoint(x: rect.maxX + 10, y: rect.midY)
        try await RowBubbleTestSupport.move(indicator, in: window)
        try await Task.sleep(for: .milliseconds(450))
        let note = try #require(textNodes("Synthetic note", window: window).first)
        let noteRect = try SettingsButtonTestSupport.frame(note, in: window)
        try await RowBubbleTestSupport.move(NSPoint(x: noteRect.midX, y: noteRect.midY), in: window)
        try await Task.sleep(for: .milliseconds(450))
        #expect(!textNodes("Synthetic note", window: window).isEmpty)
        try OverlaySurfaceTestSupport.record(window, name: "f-consumer-note-\(lower)")
        probe.suggestions = true
        try await SystemPageHost.settle(window)
        #expect(textNodes("Synthetic note", window: window).isEmpty)
        probe.suggestions = false
        try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
        try await RowBubbleTestSupport.move(indicator, in: window)
        try await Task.sleep(for: .milliseconds(450))
        #expect(!textNodes("Synthetic note", window: window).isEmpty)
        #expect(probe.appearances == 1 && !support.container.mainContext.hasChanges)
    }

    @Test func diaryConditionsRemainDistinctAndSensitiveContentIsHidden() async throws {
        let title = String(repeating: "Synthetic ", count: 8)
        let entry = DiaryEntry(text: title + "\nSynthetic note", dayKey: "2026-10-04")
        let chrome = BoardRowChrome()
        var row = DiarySummaryRow(entry: entry, onDelete: {}, chrome: chrome)
        chrome.isTitleTextHovered = true
        #expect(row.shouldShowTitleBubble && !row.shouldShowNoteBubble)
        chrome.isTitleTextHovered = false
        chrome.isTitleBubbleHovered = true
        #expect(row.shouldShowTitleBubble)
        chrome.isTitleBubbleHovered = false
        chrome.isNoteHovered = true
        #expect(row.shouldShowNoteBubble)
        chrome.isNoteHovered = false
        chrome.isNoteBubbleHovered = true
        #expect(row.shouldShowNoteBubble)
        chrome.isCommandPressed = true
        #expect(!row.shouldShowNoteBubble && !row.shouldShowTitleBubble)
        chrome.isCommandPressed = false
        row.projectedSensitive = true
        #expect(!row.shouldShowNoteBubble && !row.shouldShowTitleBubble)
        #expect(row.contentPresentation.note == nil && !row.previewText.contains("Synthetic"))
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let window = support.window(row.frame(width: 316).padding(32), size: NSSize(width: 380, height: 240))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        #expect(!SurfaceConsumerUI.strings(window).contains { $0.contains("Synthetic") })
    }

    private func textNodes(_ text: String, window: NSWindow) -> [NSObject] {
        SettingsButtonTestSupport.elements(window.contentView).filter {
            SettingsButtonTestSupport.value($0, "accessibilityValue") as? String == text
        }
    }
}

@Observable @MainActor private final class NoteConsumerProbe {
    var suggestions = false
    var appearances = 0
}

private struct NoteConsumerSample: View {
    let probe: NoteConsumerProbe
    var body: some View {
        LiveComposerPreviewHeader(text: "Synthetic // Synthetic note", showsSuggestions: probe.suggestions, onClose: {})
            .onAppear { probe.appearances += 1 }
    }
}
