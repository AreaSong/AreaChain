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
        #expect(DaybookMetrics.Window.popoverWidth == 380)
        #expect(DaybookMetrics.Window.popoverMinHeight == 280)
        #expect(DaybookMetrics.Window.popoverMaxHeight == 490)
        #expect(DaybookMetrics.Window.popoverMinHeight < DaybookMetrics.Window.popoverMaxHeight)
        #expect(DaybookMetrics.Window.workspaceSize.width == 960)
        #expect(DaybookMetrics.Window.workspaceSize.height == 640)
    }

    @Test func pagePaddingUsesSixteenPoints() {
        #expect(DaybookSpacing.page == 16)
        #expect(DaybookSpacing.lg == 16)
    }
}
