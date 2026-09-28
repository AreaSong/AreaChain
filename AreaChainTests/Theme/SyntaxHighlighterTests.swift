import AppKit
import Testing
@testable import AreaChain

@MainActor
struct SyntaxHighlighterTests {
    @Test func generatesAttributedStringWithColors() {
        let text = "@01:00 团队开会 #工作 !p1"
        let font = NSFont.systemFont(ofSize: 13)
        let attr = SyntaxHighlighter.attributedString(for: text, font: font)
        #expect(attr.string == text)

        let nsText = text as NSString
        // 验证 @01:00 范围的颜色
        let timeRange = nsText.range(of: "@01:00")
        var timeEffective = NSRange(location: 0, length: 0)
        let timeColor = attr.attribute(.foregroundColor, at: timeRange.location, effectiveRange: &timeEffective) as? NSColor
        #expect(timeColor != nil)
        #expect(timeColor == NSColor(DaybookPalette.accent.base))

        // 验证 #工作 范围的颜色
        let tagRange = nsText.range(of: "#工作")
        let tagColor = attr.attribute(.foregroundColor, at: tagRange.location, effectiveRange: nil) as? NSColor
        #expect(tagColor != nil)
        #expect(tagColor == DaybookPalette.Syntax.tagNS)

        // 验证 !p1 范围的颜色
        let priorityRange = nsText.range(of: "!p1")
        let priorityColor = attr.attribute(.foregroundColor, at: priorityRange.location, effectiveRange: nil) as? NSColor
        #expect(priorityColor != nil)
        #expect(priorityColor == NSColor.systemRed)

        // 验证普通文本 团队开会 为默认墨水色
        let titleRange = nsText.range(of: "团队开会")
        let titleColor = attr.attribute(.foregroundColor, at: titleRange.location, effectiveRange: nil) as? NSColor
        #expect(titleColor == NSColor(DaybookPalette.text.primary))
    }

    @Test func appliesHighlightingToTextStorage() {
        let text = "@15:30 跑步打卡"
        let font = NSFont.systemFont(ofSize: 13)
        let storage = NSTextStorage(string: text)
        SyntaxHighlighter.applyHighlighting(to: storage, font: font)

        let nsText = text as NSString
        let timeRange = nsText.range(of: "@15:30")
        let timeColor = storage.attribute(.foregroundColor, at: timeRange.location, effectiveRange: nil) as? NSColor
        #expect(timeColor == NSColor(DaybookPalette.accent.base))
    }

    @Test func skipsRebuildingUnchangedStorageAndRebuildsAfterEdit() {
        let text = "@15:30 跑步打卡 #工作"
        let font = NSFont.systemFont(ofSize: 13)
        let storage = NSTextStorage(string: text)
        SyntaxHighlighter.applyHighlighting(to: storage, font: font)
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: fullRange)
        SyntaxHighlighter.applyHighlighting(to: storage, font: font)
        #expect(
            (storage.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? NSNumber)?.intValue
                == NSUnderlineStyle.single.rawValue
        )

        storage.replaceCharacters(in: fullRange, with: "!p1 跑步打卡")
        SyntaxHighlighter.applyHighlighting(to: storage, font: font)
        #expect(storage.attribute(.underlineStyle, at: 0, effectiveRange: nil) == nil)
        let priorityColor = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(priorityColor == NSColor.systemRed)
    }

    @Test func repeatedHighlightOfSameTextStaysFasterThanChangingText() {
        let font = NSFont.systemFont(ofSize: 13)
        let stable = NSTextStorage(string: "@15:30 团队开会 #工作 !p1 记得带材料")
        let changing = NSTextStorage(string: "@15:30 团队开会 #工作 !p1 记得带材料")
        SyntaxHighlighter.applyHighlighting(to: stable, font: font)
        SyntaxHighlighter.applyHighlighting(to: changing, font: font)

        var skipSamples: [TimeInterval] = []
        var rebuildSamples: [TimeInterval] = []
        for _ in 1...3 {
            skipSamples.append(elapsedSeconds {
                for _ in 0..<400 {
                    SyntaxHighlighter.applyHighlighting(to: stable, font: font)
                }
            })
            rebuildSamples.append(elapsedSeconds {
                for index in 0..<400 {
                    let suffix = " \(index)"
                    changing.replaceCharacters(
                        in: NSRange(location: 0, length: changing.length),
                        with: "@15:30 团队开会 #工作 !p1 记得带材料" + suffix
                    )
                    SyntaxHighlighter.applyHighlighting(to: changing, font: font)
                }
            })
        }
        let skipMedian = medianElapsed(skipSamples)
        let rebuildMedian = medianElapsed(rebuildSamples)
        #expect(skipMedian < 0.2, "skip median \(skipMedian)s vs rebuild median \(rebuildMedian)s")
        #expect(skipMedian <= rebuildMedian + 0.05)
        print("SYNTAX_HIGHLIGHT skip=\(skipMedian) rebuild=\(rebuildMedian)")
    }

    @Test func syntaxColorPaletteMatches() {
        #expect(DaybookPalette.Syntax.tagNS == NSColor.daybook(name: "daybook.syntax.tag", swatch: DaybookSwatch.tagLight, dark: DaybookSwatch.tagDark))
        #expect(DaybookPalette.Syntax.timeNS == NSColor(DaybookPalette.accent.base))
        #expect(DaybookPalette.Syntax.p1NS == NSColor.systemRed)
        #expect(DaybookPalette.Syntax.p2NS == NSColor.systemOrange)
        #expect(DaybookPalette.Syntax.p3NS == NSColor.systemBlue)
        #expect(DaybookPalette.Syntax.p4NS == NSColor(DaybookPalette.text.secondary))

        #expect(DaybookPalette.Syntax.priorityColor(for: "!p1") == DaybookPalette.Syntax.p1)
        #expect(DaybookPalette.Syntax.priorityColor(for: "quadrant.iu") == DaybookPalette.Syntax.p1)
        #expect(DaybookPalette.Syntax.priorityColor(for: "!p2") == DaybookPalette.Syntax.p2)
        #expect(DaybookPalette.Syntax.priorityColor(for: "quadrant.i") == DaybookPalette.Syntax.p2)
        #expect(DaybookPalette.Syntax.priorityColor(for: "!p3") == DaybookPalette.Syntax.p3)
        #expect(DaybookPalette.Syntax.priorityColor(for: "quadrant.u") == DaybookPalette.Syntax.p3)
        #expect(DaybookPalette.Syntax.priorityColor(for: "!p4") == DaybookPalette.Syntax.p4)
        #expect(DaybookPalette.Syntax.priorityColor(for: "quadrant.rest") == DaybookPalette.Syntax.p4)
    }

    private func elapsedSeconds(_ work: () -> Void) -> TimeInterval {
        let start = CFAbsoluteTimeGetCurrent()
        work()
        return CFAbsoluteTimeGetCurrent() - start
    }

    private func medianElapsed(_ samples: [TimeInterval]) -> TimeInterval {
        let ordered = samples.sorted()
        return ordered[ordered.count / 2]
    }
}
