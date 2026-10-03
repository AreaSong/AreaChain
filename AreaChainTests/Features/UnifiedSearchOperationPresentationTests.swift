import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchOperationPresentationTests {
    @Test func bothHostsLanguagesThemesAndWidthsKeepAnchor() async throws {
        for layout in UnifiedSearchInputLayout.allCases {
            for locale in ["en", "zh-Hans"] {
                for dark in [false, true] {
                    for minimum in [false, true] {
                        let fixture = try UnifiedSearchResultsFixture()
                        defer { fixture.stop() }
                        _ = try await fixture.publish()
                        fixture.controller.syntheticBaselines[.init(rawValue: "setting.language")] = .init([
                            .init(subject: .ambient, parameter: .value): .uniform(.choice("system"))])
                        try fixture.startOperation("setting.language")
                        let width = minimum ? layout.minimumWidth + 24 : (layout == .standard ? 620 : 380)
                        let host = UnifiedSearchTestHost(layout: layout, width: width, locale: locale, dark: dark,
                                                         results: fixture.controller, operations: true)
                        defer { host.close() }
                        try await host.start()
                        let field = try host.field
                        let before = field.convert(field.bounds, to: nil)
                        let candidates = try NativeSyntaxUI.frame("syntax.unified.candidates", in: host.window)
                        #expect(candidates.minY >= before.maxY, "候选保留在输入上方")
                        #expect(candidates.minX >= 0 && candidates.maxX <= width)
                        let panel = try #require(SettingsButtonTestSupport.elements(host.window.contentView)
                            .compactMap { $0 as? UnifiedSearchOperationBoundary }.first)
                        #expect(panel.convert(panel.bounds, to: nil).maxY < before.minY)
                        try host.snapshot("operation-\(layout)-\(locale)-\(dark)-\(minimum)")
                        try await host.clickResult("unified.operation.disclosure")
                        #expect(!fixture.controller.operationExpanded)
                        #expect(field.convert(field.bounds, to: nil) == before)
                        #expect(try fixture.draft.arguments.isEmpty)
                    }
                }
            }
        }
    }

    @Test func realCatalogExamplesAndMissingRequirements() async throws {
        for id in ["setting.captureSource", "clipboard.interval", "todo.create", "routine.create",
                   "todo.notes", "shortcut.record", "privacy.setupMethod", "subtask.create"] {
            let fixture = try UnifiedSearchResultsFixture()
            defer { fixture.stop() }
            _ = try await fixture.publish()
            try fixture.startOperation(id)
            let host = UnifiedSearchTestHost(layout: .compact, width: 304, locale: "zh-Hans", dark: true,
                                             results: fixture.controller, operations: true)
            defer { host.close() }
            try await host.start()
            try await host.key(53, "\u{1b}")
            try host.snapshot("operation-example-" + id)
            #expect(try fixture.draft.commandID.rawValue == id)
            #expect(try !fixture.draft.check().isExecutable)
            if id == "todo.create" {
                try await host.clickResult("unified.operation.disclosure")
                try host.snapshot("operation-multiple-collapsed")
            }
        }
    }

    @Test func baselineUnknownAbsentMixedAndChoiceAliases() throws {
        let locale = Locale(identifier: "zh-Hans")
        #expect(UnifiedSearchOperationCopy.original(nil, locale: locale, calendar: .current) == "当前值尚未读取")
        #expect(UnifiedSearchOperationCopy.original(.mixed, locale: locale, calendar: .current) == "多个不同值")
        #expect(UnifiedSearchOperationCopy.original(.absent, locale: locale, calendar: .current) == "当前无值")
        let command = try #require(CommandCatalog.standard.command(id: .init(rawValue: "setting.language")))
        let parameter = try #require(command.parameters.first)
        let context = UnifiedSearchParameterContext(command: command, parameter: parameter, operation: .assign)
        #expect(context.value("简中") == .choice("chinese"))
        #expect(context.completion("简中", locale: Locale(identifier: "en")).candidates.count == 1)
    }
}
