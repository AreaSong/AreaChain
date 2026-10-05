import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct DashboardScrollTests {
    @Test func productionOwnershipBeforeEvents() async throws {
        let support = try DashboardScrollTestSupport()
        defer { support.close() }
        try await NativeSyntaxUI.prepareFocus(in: support.window)
        try await SystemPageHost.settle(support.window)
        let targets = try support.targets()
        support.record(targets, label: "ownership-before-events")
        try #require(DashboardScrollTestSupport.overlays(targets.outer).count == 1)
        try #require(DashboardScrollTestSupport.overlays(targets.trend).isEmpty)
        try #require(DashboardScrollTestSupport.overlays(targets.heat).isEmpty)
        #expect(targets.outer.hasVerticalScroller == support.isBaseline && !targets.outer.hasHorizontalScroller)
        #expect(!targets.trend.hasHorizontalScroller && !targets.heat.hasHorizontalScroller)
        #expect(ScrollNativeEvidence.views(support.window).filter { $0 is DaybookScrollEdgeObserverNSView }.isEmpty)
    }

    @Test func updatesResizeReopenAndPointerNavigation() async throws {
        for iteration in 0..<2 {
            let support = try DashboardScrollTestSupport()
            defer { support.close() }
            try await NativeSyntaxUI.prepareFocus(in: support.window)
            try await SystemPageHost.settle(support.window)
            let targets = try support.targets()
            try support.requireOwnership(targets)
            try await support.verifyUpdates(targets)
            try await support.verifyPointerAndNavigation(targets)
            support.record(targets, label: "reopen-\(iteration)")
        }
    }

    @Test(arguments: 0..<12)
    func productionOwnershipAndAxes(scenario: Int) async throws {
        let size = [NSSize(width: 960, height: 640), NSSize(width: 300, height: 360),
                    NSSize(width: 1200, height: 900)][scenario / 4]
        let support = try DashboardScrollTestSupport(locale: scenario.isMultiple(of: 2) ? "en" : "zh-Hans",
            scheme: scenario % 4 < 2 ? .light : .dark, size: size,
            populated: scenario.isMultiple(of: 2), embedded: scenario != 3)
        defer { support.close() }
        try await NativeSyntaxUI.prepareFocus(in: support.window)
        try await SystemPageHost.settle(support.window)
        let targets = try support.targets()
        support.record(targets, label: "scenario\(scenario)-initial")
        try support.requireOwnership(targets)
        try await support.capturePositions(targets, name: "scenario\(scenario)")
        #expect(DashboardScrollTestSupport.overlays(targets.outer).count == (support.isBaseline ? 0 : 1))
        #expect(DashboardScrollTestSupport.overlays(targets.trend).isEmpty)
        #expect(DashboardScrollTestSupport.overlays(targets.heat).isEmpty)
        #expect(targets.outer.hasVerticalScroller == support.isBaseline && !targets.outer.hasHorizontalScroller)
        #expect(ScrollNativeEvidence.views(support.window).filter { $0 is DaybookScrollEdgeObserverNSView }.isEmpty)
        #expect(!targets.trend.hasHorizontalScroller && !targets.heat.hasHorizontalScroller)
        let originalTodos = support.todos.map(\.snapshot)
        let horizontalOrigins = [targets.trend, targets.heat].map { $0.contentView.bounds.origin }
        try await support.wheel(targets.outer, horizontal: false)
        #expect([targets.trend, targets.heat].map { $0.contentView.bounds.origin } == horizontalOrigins)
        let maximum = max(0, try #require(targets.outer.documentView).bounds.height - targets.outer.contentSize.height)
        #expect((targets.outer.contentView.bounds.minY > 0) == (maximum > 0))
        for target in [targets.trend, targets.heat] {
            let others = targets.all.filter { $0 !== target }
            let origins = others.map { $0.contentView.bounds.origin }
            try await support.wheel(target, horizontal: true)
            #expect(others.map { $0.contentView.bounds.origin } == origins)
            let overflow = try #require(target.documentView).bounds.width > target.contentSize.width + 1
            print("DASHBOARD_HORIZONTAL scenario=\(scenario) overflow=\(overflow)")
            if scenario / 4 == 1 { #expect(overflow) }
            #expect((target.contentView.bounds.minX > 0) == overflow)
        }
        support.record(targets, label: "scenario\(scenario)-wheel")
        let snapshot = DashboardProjection.project(todos: support.todos.map(\.snapshot),
            routines: [], checks: [], diaries: [], todayKey: support.today)
        #expect(snapshot.summary.todayStat.completedCount == (scenario.isMultiple(of: 2) ? 12 : 0))
        #expect(support.todos.map(\.snapshot) == originalTodos)
        #expect(!support.fixture.container.mainContext.hasChanges)
    }
}
