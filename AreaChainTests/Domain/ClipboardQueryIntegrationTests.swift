import Foundation
import Testing
@testable import AreaChain

struct ClipboardQueryIntegrationTests {
    @Test func rawUnifiedQueryPreservesSessionEvidenceAndHandoffScope() {
        let source = "/clipboard (missing | Alpha) -归档"
        let session = TodoQueryFixture.session(source)
        #expect(session.input == ContentQueryParser().parse(source, context: session.queryDates))
        let target = ContentQuerySession(page: QuerySessionFixture.page(.today(.init()), visit: "target"))
        let frozen = session.handedOff(to: target)
        let result = ClipboardQueryFixture.read(.unified(frozen), records: .complete([ClipboardQueryFixture.record(1)]))
        #expect(result.matches.count == 1 && result.requestID == TodoQueryFixture.requestID)
        #expect(result.typeAnalysis == frozen.typeAnalysis)
        #expect(result.matches[0].evidence.allSatisfy { evidence in frozen.conditions.contains { $0.id == evidence.conditionID } })
        #expect(result.matches[0].evidence.contains { $0.field == .clipboardPlainText && $0.alternativeIndex == 1 })
        let pageQuery = TodoQueryFixture.session("Alpha", page: .clipboard)
        #expect(ClipboardQueryFixture.read(.unified(pageQuery), records: .complete([ClipboardQueryFixture.record(1)])).matches.count == 1)
    }

    @Test func existingCommandParameterSelectionAndModeOptionsFeedReadOnlyRequest() throws {
        let path = CommandPathParser().parse(.init(text: "/clipboard/search"))
        let command = try #require(path.command)
        #expect(command.id.rawValue == "clipboard.search" && command.parameters.map(\.id) == [.query, .mode])
        #expect(command.parameters.first { $0.id == .query }?.required == false)
        #expect(path.diagnostics.contains { $0.issue == .chooseParameter && $0.parameterIDs == [.query, .mode] })
        let parameter = try #require(command.parameters.first { $0.id == .mode })
        for language in ["en", "zh-Hans"] {
            let options = CommandPathArguments.options(for: parameter, locale: Locale(identifier: language))
            #expect(options.map { $0.0 } == ["mixed", "exact", "regex"])
            for option in options {
                let argument = CommandPathArguments.argument(option.3, parameter: parameter)
                let mode = try ClipboardQueryModeRequest(commandID: command.id, arguments: [argument],
                    filters: TodoQueryFixture.session("/clipboard"))
                #expect(mode.needle.isEmpty && mode.mode.rawValue == option.0)
                let result = ClipboardQueryFixture.read(.explicit(mode), records: .complete([ClipboardQueryFixture.record(1, "")]))
                #expect(result.matches.count == 1 && result.isCompleteForCoveredTypes)
            }
        }
        #expect(CommandCatalogValidation.issues(in: .standard).isEmpty)
    }

    @Test func wholeRegexParameterBypassesContentGrammarAndDoesNotGrantScope() throws {
        let pattern = "^(Alpha|beta) #工作 !p1 /tasks$"
        let command = try #require(CommandCatalog.standard.command(path: "/clipboard/search"))
        let arguments: [CommandArgument] = [.init(parameter: .query, operation: .assign, value: .shortText(pattern)),
                                            .init(parameter: .mode, operation: .assign, value: .choice("regex"))]
        let mode = try ClipboardQueryModeRequest(commandID: command.id, arguments: arguments, filters: TodoQueryFixture.session("/clipboard"))
        #expect(mode.needle == pattern && mode.filters.conditions.allSatisfy { $0.value.dimension != .content(.text) })
        let response = ClipboardQueryFixture.read(.explicit(mode), records: .complete([ClipboardQueryFixture.record(1, "Alpha #工作 !p1 /tasks")]))
        #expect(response.matches.count == 1 && response.isCompleteForCoveredTypes)
        let global = try ClipboardQueryModeRequest(commandID: command.id, arguments: arguments, filters: TodoQueryFixture.session(""))
        #expect(ClipboardQueryFixture.read(.explicit(global), records: .failed).state == .notApplicable)
        let parsed = ContentQueryParser().parse("/clipboard/search " + pattern, context: mode.filters.queryDates)
        if case .command = parsed { } else { Issue.record("指令原文进入内容词法分析") }
    }

    @Test func invalidArgumentsAndRegexHaveDistinctDiagnostics() throws {
        let command = try #require(CommandCatalog.standard.command(path: "/clipboard/search"))
        let filters = TodoQueryFixture.session("/clipboard")
        #expect(throws: ClipboardQueryRequestError.invalidArguments([.missing(.mode)])) {
            try ClipboardQueryModeRequest(commandID: command.id, arguments: [], filters: filters)
        }
        let arguments: [CommandArgument] = [.init(parameter: .query, operation: .assign, value: .shortText("(")),
                                            .init(parameter: .mode, operation: .assign, value: .choice("regex"))]
        let request = try ClipboardQueryModeRequest(commandID: command.id, arguments: arguments, filters: filters)
        let invalid = ClipboardQueryFixture.read(.explicit(request), records: .complete([]))
        #expect(!invalid.queryIsValid && invalid.state == .invalidQuery && !invalid.coverage.didEvaluateRecords)
        #expect(invalid.diagnostics.map(\.issue) == [.invalidRegex])
        #expect(try ClipboardQueryFixture.explicit(.regex, "never", []).state == .evaluated)
        var empty = arguments
        empty[0].value = .shortText("  ")
        #expect(throws: ClipboardQueryRequestError.invalidArguments([.invalidValue(.query)])) {
            try ClipboardQueryModeRequest(commandID: command.id, arguments: empty, filters: filters)
        }
    }

    @Test func resultAndDescriptionsOmitPayloadAndRegexContents() throws {
        let marker = "synthetic-content-marker"
        var record = ClipboardQueryFixture.record(1, marker)
        record.html = "<b>synthetic-html-marker</b>"
        record.rtf = Data("synthetic-rtf-marker".utf8)
        record.imageFile = "synthetic-image-marker.png"
        record.filePaths = ["/tmp/synthetic-file-marker"]
        let mode = try ClipboardQueryModeRequest(mode: .regex, needle: marker, filters: TodoQueryFixture.session("/clipboard"))
        let input = ClipboardQueryInput.explicit(mode)
        let records = ClipboardQueryRecords.complete([record])
        let request = ClipboardQueryRequest(requestID: UUID(), input: input, records: records)
        let response = ClipboardQueryProvider.read(request)
        let match = try #require(response.matches.first)
        #expect(match.payload == .init(record) && match.plainText == marker)
        let invalid = try ClipboardQueryFixture.explicit(.regex, "(" + marker, [record])
        #expect(invalid.diagnostics.map(\.issue) == [.invalidRegex])
        record.imageFile = "/tmp/synthetic-file-marker"
        let badImage = ClipboardQueryFixture.read("/clipboard has:image", [record])
        #expect(badImage.diagnostics.map(\.issue) == [.invalidImageReference])
        let fields = Set(Mirror(reflecting: match).children.compactMap(\.label))
        #expect(fields.isDisjoint(with: ["html", "rtf", "imageFile", "filePaths", "contentHash", "record"]))
        let descriptions = [String(describing: mode), String(reflecting: mode), String(reflecting: input),
            String(describing: records), String(reflecting: records), String(describing: request), String(reflecting: request),
            String(describing: response), String(reflecting: response), String(describing: match), String(reflecting: match),
            String(reflecting: response.matches), String(reflecting: response.diagnostics),
            String(reflecting: invalid.diagnostics), String(reflecting: badImage.diagnostics),
            String(reflecting: ClipboardTextMatching(needle: marker, mode: .regex))]
        #expect(descriptions.allSatisfy { !$0.contains(marker) && !$0.contains("/tmp/") && !$0.contains("synthetic-html-marker") })
    }
}
