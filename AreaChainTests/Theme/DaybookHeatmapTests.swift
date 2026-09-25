import Testing
@testable import AreaChain

struct DaybookHeatmapTests {
    @Test func heatmapLevelsStayDistinctAndPeakMeetsPaperContrast() {
        #expect(DaybookPalette.heatmap.color(for: 0) != DaybookPalette.heatmap.color(for: 4))
        #expect(DaybookPalette.heatmap.color(for: 1) != DaybookPalette.heatmap.color(for: 2))
        #expect(DaybookPalette.heatmap.color(for: 5) == DaybookPalette.heatmap.color(for: 4))
        #expect(ContrastMath.ratio(DaybookSwatch.stampLight, DaybookSwatch.paperLight) >= 4.5)
        #expect(ContrastMath.ratio(DaybookSwatch.stampDark, DaybookSwatch.paperDark) >= 4.5)
        #expect(ContrastMath.ratio(DaybookSwatch.inkLight, DaybookSwatch.paperLight) >= 4.5)
        #expect(ContrastMath.ratio(DaybookSwatch.inkDark, DaybookSwatch.paperDark) >= 4.5)
    }
}
