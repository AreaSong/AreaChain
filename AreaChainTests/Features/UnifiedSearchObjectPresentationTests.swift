import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchObjectPresentationTests {
    @Test func mixedBaselineAndSubtaskParentUseSafePreview() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        fixture.controller.syntheticBaselines[.init(rawValue: "todo.completion")] = .init([
            .init(subject: .object(.object(0)), parameter: .enabled): .uniform(.boolean(true)),
            .init(subject: .object(.object(1)), parameter: .enabled): .uniform(.boolean(false))])
        try fixture.startOperation("todo.completion")
        try await fixture.acceptObjects([.object(0), .object(1)])
        #expect(try fixture.draft.baseline.original(.enabled, targets: fixture.draft.targets) == .mixed)
        let host = UnifiedSearchTestHost(locale: "zh-Hans", results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await SettingsButtonTestSupport.reveal(try host.resultNode("unified.parameter.enabled"), in: host.window)
        try host.snapshot("objects-mixed-baseline")
        let childFixture = try UnifiedSearchResultsFixture()
        defer { childFixture.stop() }
        try childFixture.startOperation("subtask.completion")
        let child = CommandObjectReference(type: .subtask, id: QueryBatchFixture.id)
        try await childFixture.acceptObjects([child])
        let childHost = UnifiedSearchTestHost(layout: .compact, width: 304, locale: "zh-Hans", dark: true,
                                              results: childFixture.controller, operations: true)
        defer { childHost.close() }
        try await childHost.start()
        #expect(childFixture.controller.objectPreview(child)?.relations.first?.object.type == .todo)
        try childHost.snapshot("objects-subtask-parent")
    }

    @Test func hostsLanguagesThemesAndWidthsKeepNativeAnchor() async throws {
        for layout in UnifiedSearchInputLayout.allCases {
            for locale in ["en", "zh-Hans"] {
                for dark in [false, true] {
                    for minimum in [false, true] {
                        let fixture = try UnifiedSearchResultsFixture(.objectBatch(count: 12), pageSize: 4)
                        defer { fixture.stop() }
                        try fixture.startOperation("todo.completion")
                        let width = minimum ? layout.minimumWidth + 24 : (layout == .standard ? 620 : 380)
                        let host = UnifiedSearchTestHost(layout: layout, width: width, locale: locale, dark: dark,
                                                         results: fixture.controller, operations: true)
                        defer { host.close() }
                        try await host.start()
                        let field = try host.field
                        let anchor = field.convert(field.bounds, to: nil)
                        try await host.clickResult("unified.objects.choose.target")
                        await fixture.controller.objectSelectionTask?.value
                        try await host.settle()
                        let picker = try #require(fixture.controller.objectSelection)
                        fixture.controller.browseObjects(.selectVisible, stamp: picker.stamp)
                        try await host.settle()
                        try await SettingsButtonTestSupport.reveal(try host.resultNode("unified.objects.accept"), in: host.window)
                        #expect(field.convert(field.bounds, to: nil) == anchor)
                        try host.snapshot("objects-picker-\(layout)-\(locale)-\(dark)-\(minimum)")
                        try #require(fixture.controller.acceptObjects(picker.stamp))
                        await fixture.controller.objectSelectionTask?.value
                        try await host.settle()
                        #expect(try fixture.draft.targets.objects.count == 4)
                        #expect(field.convert(field.bounds, to: nil) == anchor)
                        let panel = try #require(SettingsButtonTestSupport.elements(host.window.contentView)
                            .compactMap { $0 as? UnifiedSearchOperationBoundary }.first)
                        let titles = SettingsButtonTestSupport.elements(panel).compactMap { $0 as? SearchFragmentLabel }
                        #expect(titles.filter { $0.stringValue.contains("Synthetic task") }.count == 4,
                                "读取修订必须更新原生目标标题，不能只让控制器查询变成可读")
                        try await SettingsButtonTestSupport.reveal(try host.resultNode("unified.objects.choose.target"), in: host.window)
                        try host.snapshot("objects-fixed-\(layout)-\(locale)-\(dark)-\(minimum)")
                    }
                }
            }
        }
    }

    @Test func occurrenceDatesStayDistinctAndSubtaskShowsParent() async throws {
        var batch = QueryBatchFixture.occurrences("date:2026-10-01..2026-10-02")
        batch.snapshots.diaries = .complete([])
        let fixture = try UnifiedSearchResultsFixture(batch, pageSize: 30)
        defer { fixture.stop() }
        try fixture.startOperation("occurrence.reopen")
        let picker = try await fixture.chooseObjects()
        let days = picker.browse.snapshot.units.flatMap(\.hits).filter { $0.type == .routineOccurrence }
        try #require(days.count == 2)
        #expect(Set(days.map(\.id)).count == 1)
        #expect(Set(days.compactMap(\.dayKey)) == ["2026-10-01", "2026-10-02"])
        for day in days { fixture.controller.toggleObject(day, stamp: picker.stamp) }
        try #require(fixture.controller.acceptObjects(picker.stamp))
        await fixture.controller.objectSelectionTask?.value
        #expect(try fixture.draft.targets.objects == days)
        let host = UnifiedSearchTestHost(layout: .compact, width: 304, locale: "en", dark: true,
                                         results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        for day in days {
            let row = try #require(fixture.controller.objectPreview(day))
            #expect(row.id.dayKey == day.dayKey)
            #expect(row.relations.first?.object.type == .routine)
        }
        try host.snapshot("objects-occurrence-dates")
    }
}
