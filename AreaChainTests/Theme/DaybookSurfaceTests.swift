import SwiftUI
import Testing
@testable import AreaChain

struct DaybookSurfaceTests {
    @Test func standardConfigurationFollowsTheBaseline() {
        let row = DaybookSurfaceConfiguration.standard(for: .row)
        #expect(row.radius == DaybookRadius.small)
        #expect(row.minHeight == nil)
        #expect(row.padding == EdgeInsets())

        let card = DaybookSurfaceConfiguration.standard(for: .card)
        #expect(card.radius == DaybookRadius.medium)

        let panel = DaybookSurfaceConfiguration.standard(for: .panel)
        #expect(panel.radius == DaybookMetrics.Radius.panel)

        let banner = DaybookSurfaceConfiguration.standard(for: .banner)
        #expect(banner.radius == DaybookMetrics.Radius.inputComposer)
        #expect(banner.padding.top == 10)
        #expect(banner.padding.leading == 10)
    }

    @Test func configureCanChangeRadiusWithoutChangingTheVariantDefault() {
        var card = DaybookSurfaceConfiguration.standard(for: .card)
        card.radius = DaybookRadius.small
        #expect(card.radius == DaybookRadius.small)
        #expect(DaybookSurfaceConfiguration.standard(for: .card).radius == DaybookRadius.medium)
    }
}
