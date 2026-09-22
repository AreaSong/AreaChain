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
        #expect(timeColor == NSColor(DaybookTheme.stamp))

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
        #expect(titleColor == NSColor(DaybookTheme.ink))
    }

    @Test func appliesHighlightingToTextStorage() {
        let text = "@15:30 跑步打卡"
        let font = NSFont.systemFont(ofSize: 13)
        let storage = NSTextStorage(string: text)
        SyntaxHighlighter.applyHighlighting(to: storage, font: font)

        let nsText = text as NSString
        let timeRange = nsText.range(of: "@15:30")
        let timeColor = storage.attribute(.foregroundColor, at: timeRange.location, effectiveRange: nil) as? NSColor
        #expect(timeColor == NSColor(DaybookTheme.stamp))
    }

    @Test func syntaxColorPaletteMatches() {
        #expect(DaybookPalette.Syntax.tagNS == NSColor.daybook(name: "daybook.syntax.tag", swatch: DaybookSwatch.tagLight, dark: DaybookSwatch.tagDark))
        #expect(DaybookPalette.Syntax.timeNS == NSColor(DaybookTheme.stamp))
        #expect(DaybookPalette.Syntax.p1NS == NSColor.systemRed)
        #expect(DaybookPalette.Syntax.p2NS == NSColor.systemOrange)
        #expect(DaybookPalette.Syntax.p3NS == NSColor.systemBlue)
        #expect(DaybookPalette.Syntax.p4NS == NSColor(DaybookTheme.muted))

        #expect(DaybookPalette.Syntax.priorityColor(for: "!p1") == DaybookPalette.Syntax.p1)
        #expect(DaybookPalette.Syntax.priorityColor(for: "quadrant.iu") == DaybookPalette.Syntax.p1)
        #expect(DaybookPalette.Syntax.priorityColor(for: "!p2") == DaybookPalette.Syntax.p2)
        #expect(DaybookPalette.Syntax.priorityColor(for: "quadrant.i") == DaybookPalette.Syntax.p2)
        #expect(DaybookPalette.Syntax.priorityColor(for: "!p3") == DaybookPalette.Syntax.p3)
        #expect(DaybookPalette.Syntax.priorityColor(for: "quadrant.u") == DaybookPalette.Syntax.p3)
        #expect(DaybookPalette.Syntax.priorityColor(for: "!p4") == DaybookPalette.Syntax.p4)
        #expect(DaybookPalette.Syntax.priorityColor(for: "quadrant.rest") == DaybookPalette.Syntax.p4)
    }
}
