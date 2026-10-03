import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchResultsPresentationTests {
    @Test func bilingualNativeMatrixAndTwoLineFragments() async throws {
        for layout in UnifiedSearchInputLayout.allCases {
            for language in ["en", "zh-Hans"] {
                for dark in [false, true] {
                    for minimum in [false, true] {
                        var batch = UnifiedSearchResultsFixture.longText()
                        batch.options.locale = Locale(identifier: language)
                        let fixture = try UnifiedSearchResultsFixture(batch)
                        defer { fixture.stop() }
                        _ = try await fixture.publish()
                        let width = minimum ? layout.minimumWidth + 24 : (layout == .standard ? 760 : 380)
                        let host = UnifiedSearchTestHost(layout: layout, width: width, locale: language, dark: dark,
                                                         results: fixture.controller)
                        defer { host.close() }
                        try await host.start()
                        let id = try #require(fixture.page.snapshot.visible.first)
                        let title = try host.resultNode("unified.title." + id.searchIdentifier)
                        let summary = try host.resultNode("unified.summary." + id.searchIdentifier)
                        let titleFrame = try SettingsButtonTestSupport.frame(title, in: host.window)
                        let summaryFrame = try SettingsButtonTestSupport.frame(summary, in: host.window)
                        #expect(titleFrame.height >= 14 && titleFrame.height < 42)
                        #expect(summaryFrame.height >= 14 && summaryFrame.height < 42)
                        #expect(titleFrame.maxX <= width && summaryFrame.maxX <= width)
                        try host.snapshot("results-\(layout)-\(language)-\(dark)-\(minimum)")
                    }
                }
            }
        }
    }

    @Test func everySafeTypeAndExplicitOccurrences() async throws {
        var occurrence = QueryBatchFixture.occurrences("date:today")
        occurrence.snapshots.diaries = .complete([])
        let clipboard = QueryBatchFixture.replacingSession(UnifiedSearchResultsFixture.mixed(),
                                                          TodoQueryFixture.session("/clipboard"))
        for (name, input) in [("mixed", UnifiedSearchResultsFixture.mixed()), ("clipboard", clipboard), ("occurrence", occurrence)] {
            var batch = input
            batch.options.locale = Locale(identifier: "zh-Hans")
            let fixture = try UnifiedSearchResultsFixture(batch, pageSize: 20)
            defer { fixture.stop() }
            _ = try await fixture.publish()
            let host = UnifiedSearchTestHost(width: 700, locale: "zh-Hans", results: fixture.controller)
            defer { host.close() }
            try await host.start()
            let rows = try fixture.page.snapshot.source.rows
            if name == "mixed" {
                #expect(Set(rows.map(\.id.type)) == [.todo, .subtask, .routine, .diary, .image, .tag])
                let hidden = try #require(rows.first { $0.id.type == .diary })
                #expect(hidden.primary?.text != nil && hidden.summary == nil && hidden.expansion.isEmpty)
                #expect(rows.first { $0.id.type == .image }?.summary == nil)
            }
            if name == "occurrence" {
                #expect(!rows.isEmpty && rows.allSatisfy { $0.id.type == .routineOccurrence && $0.summary == nil })
                #expect(rows.allSatisfy { !$0.relations.isEmpty && $0.id.dayKey != nil })
            }
            for id in try fixture.page.snapshot.visible {
                // 用真实按钮定位让惰性列表滚到对应类型，再截图，避免只检查首屏占位。
                fixture.controller.browse(.init(version: try fixture.page.snapshot.version, action: .activate(id)),
                                          source: fixture.controller.buffer)
                try await host.settle()
                _ = try host.resultNode("unified.hit." + id.searchIdentifier)
                try host.snapshot("results-\(name)-\(id.type.rawValue)")
            }
        }
    }

    @Test func emptyUnknownProtectedAndUnreadCopyDiffer() async throws {
        var failed = QueryBatchFixture.empty("/tasks")
        failed.snapshots.todos = .failed
        var unread = QueryBatchFixture.empty("/tasks")
        unread.snapshots.todos = .partial([])
        var unknown = QueryBatchFixture.empty("/tags")
        let duplicate = TagQuerySnapshot(id: UUID(), name: "synthetic duplicate")
        unknown.snapshots.tags = .complete([duplicate, duplicate])
        var protected = UnifiedSearchResultsFixture.mixed()
        protected = QueryBatchFixture.replacingSession(protected, TodoQueryFixture.session("/images"))
        protected.snapshots.images = .complete(protected.snapshots.images.values!.map { var image = $0; image.protection = .protected; return image })
        let scenarios: [(String, ContentQueryBatch, String)] = [
            ("empty", QueryBatchFixture.empty("/tasks"), "unified.results.empty"),
            ("failed", failed, "unified.results.readFailed"), ("unread", unread, "unified.results.unread"),
            ("protected", protected, "unified.results.protected"),
            ("unknown", unknown, "unified.results.unknown"),
            ("input", QueryBatchFixture.empty("(needle"), "unified.results.incompleteInput"),
            ("inapplicable", QueryBatchFixture.empty("/tags status:done"), "unified.results.notApplicable")]
        for (name, batch, expected) in scenarios {
            let fixture = try UnifiedSearchResultsFixture(batch)
            defer { fixture.stop() }
            _ = try await fixture.publish()
            #expect(try UnifiedSearchResultCopy(fixture.page.status).emptyKey == expected)
            let host = UnifiedSearchTestHost(layout: .compact, width: 304, locale: "zh-Hans", results: fixture.controller)
            defer { host.close() }
            try await host.start()
            if try host.state.suggestions.isActive { try await host.key(53, "\u{1b}") }
            try host.snapshot("results-state-" + name)
        }
    }

    @Test func invalidHighlightDoesNotSplitGraphemes() {
        let text = "👨‍👩‍👧‍👦 中文 e\u{301}"
        let invalid = ContentQueryHighlight(range: NSRange(location: 1, length: 2), originalRange: .init(location: 1, length: 2),
            sources: [], contributions: [])
        let value = ContentQueryDisplayText(text: text, field: .notes, mapping: nil, highlights: [invalid], omittedPublicContent: false)
        let rendered = DaybookSearchResultText.attributed(value)
        #expect(String(rendered.characters) == text)
        #expect(rendered.runs.count == 1)
    }
}
