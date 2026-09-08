import Testing
@testable import AreaChain

struct DaybookContrastTests {
    @Test func bodyTextMeetsAAOnPaper() {
        #expect(ContrastMath.ratio(DaybookSwatch.inkLight, DaybookSwatch.paperLight) >= 4.5)
        #expect(ContrastMath.ratio(DaybookSwatch.inkDark, DaybookSwatch.paperDark) >= 4.5)
        #expect(ContrastMath.ratio(DaybookSwatch.mutedLight, DaybookSwatch.paperLight) >= 4.5)
        #expect(ContrastMath.ratio(DaybookSwatch.mutedDark, DaybookSwatch.paperDark) >= 4.5)
    }

    @Test func stampAndDoneMeetAAOnPaper() {
        #expect(ContrastMath.ratio(DaybookSwatch.stampLight, DaybookSwatch.paperLight) >= 4.5)
        #expect(ContrastMath.ratio(DaybookSwatch.stampDark, DaybookSwatch.paperDark) >= 4.5)
        #expect(ContrastMath.ratio(DaybookSwatch.doneLight, DaybookSwatch.paperLight) >= 4.5)
        #expect(ContrastMath.ratio(DaybookSwatch.doneDark, DaybookSwatch.paperDark) >= 4.5)
        #expect(ContrastMath.ratio(DaybookSwatch.destructiveLight, DaybookSwatch.paperLight) >= 4.5)
        #expect(ContrastMath.ratio(DaybookSwatch.destructiveDark, DaybookSwatch.paperDark) >= 4.5)
    }

    @Test func checkmarkMeetsAAOnStamp() {
        #expect(ContrastMath.ratio(DaybookSwatch.checkmarkLight, DaybookSwatch.stampLight) >= 4.5)
        #expect(ContrastMath.ratio(DaybookSwatch.checkmarkDark, DaybookSwatch.stampDark) >= 4.5)
    }

    @Test func popoverDimensionsMeetCompactAndExpandLimits() {
        #expect(DaybookTheme.popoverWidth == 380)
        #expect(DaybookTheme.popoverMinHeight == 280)
        #expect(DaybookTheme.popoverMaxHeight == 490)
        #expect(DaybookTheme.popoverMinHeight < DaybookTheme.popoverMaxHeight)
        #expect(DaybookTheme.workspaceSize.width == 960)
        #expect(DaybookTheme.workspaceSize.height == 640)
    }
}
