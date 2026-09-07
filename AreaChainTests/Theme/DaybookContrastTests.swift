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
}
