import Foundation
import Testing
@testable import AreaChain

struct CommandPathTests {
    private let parser = CommandPathParser()

    @Test func requiredEditingStatesAndBilingualPaths() {
        let cases: [(String, CommandPathState)] = [
            ("/", .group), ("/set", .incompletePath), ("/setting", .group), ("/setting/", .group),
            ("/settings", .group), ("/application settings", .group), ("/应用设置", .group),
            ("/setting/language", .incompleteArguments), ("/setting/language/", .incompleteArguments),
            ("/setting/language/chinese", .command), ("/应用设置/语言/简中", .command),
            ("/settings/language/中文", .command), ("/change language/Chinese", .command),
            ("/tasks", .scope), ("/go/today", .command)
        ]
        for (input, state) in cases {
            let result = parser.parse(.init(text: input))
            #expect(result.state == state, "\(input): \(result.diagnostics)")
            #expect(result.input == input)
            if state == .command && input.contains("language") || input.contains("简中") {
                #expect(result.arguments.first?.value == .choice("chinese"))
            }
        }
    }

    @Test func completionsDoNotRequireTrailingSlashAndReuseTranslations() throws {
        for input in ["/", "/set", "/setting", "/setting/", "/settings/", "/应用设置/", "/语言"] {
            let result = parser.parse(.init(text: input, locale: Locale(identifier: "zh-Hans")))
            #expect(result.candidates.contains { $0.command.id.rawValue == "setting.language" }, "\(input)")
        }
        for input in ["/setting/language", "/setting/language/", "/setting/language/简"] {
            let result = parser.parse(.init(text: input, locale: Locale(identifier: "zh-Hans")))
            let candidate = try #require(result.candidates.first { $0.id.hasSuffix(":chinese") })
            #expect(candidate.title == L10n.format("language.chinese", locale: Locale(identifier: "zh-Hans")))
            #expect(candidate.category == .modification)
            let edit = try #require(result.accepting(candidate, in: input, hasMarkedText: false))
            #expect(edit.text == "/setting/language/chinese")
            #expect(edit.intent == .setArgument(candidate.command.id, .init(parameter: .value, operation: .assign, value: .choice("chinese"))))
        }
    }

    @Test func unknownIncompleteAndComplexArgumentsStayEditable() {
        let cases = ["/unknown", "/setting/unknown", "/setting//language", "/setting/language/not-a-language"]
        for text in cases {
            let result = parser.parse(.init(text: text))
            #expect(result.input == text)
            #expect(!result.diagnostics.isEmpty)
            #expect(result.arguments.isEmpty)
        }
        for text in ["/tasks/add/title", "/tasks/status/done", "/diaries/body/text", "/data/import/select/file"] {
            let result = parser.parse(.init(text: text))
            #expect(result.arguments.isEmpty)
            #expect(!result.diagnostics.isEmpty)
        }
        let multiple = parser.parse(.init(text: "/tasks/status/done"))
        #expect(multiple.state == .incompleteArguments)
        #expect(multiple.diagnostics.first?.issue == .chooseParameter)
        #expect(multiple.diagnostics.first?.parameterIDs == [.status, .routineStatus])
        let secure = parser.parse(.init(text: "/privacy/set-password/synthetic"))
        #expect(secure.state == .invalid)
        #expect(secure.arguments.isEmpty)
    }

    @Test func ordinaryTextPathsURLsAndProtectedBodiesDoNotTrigger() {
        for text in ["hello", "hello /setting", " /setting", "https://example.com/setting", "/Users/synthetic/file",
                     "./setting/language", "//server/share", "`/setting`", "```\n/setting\n```", "[/setting](https://example.com)", "\\/setting"] {
            let result = parser.parse(.init(text: text))
            #expect(result.state == .ordinaryText, "\(text)")
            #expect(result.candidates.isEmpty)
        }
        let protected = parser.parse(.init(text: "/setting/`language`", cursorLocation: 14))
        #expect(protected.candidates.isEmpty)
        #expect(protected.arguments.isEmpty)
    }

    @Test func cursorReplacementPreservesSuffixAndComposition() throws {
        let text = "/setting/lanWRONG/chinese 后续👩🏽‍💻e\u{301}"
        let result = parser.parse(.init(text: text, cursorLocation: "/setting/lan".utf16.count))
        let candidate = try #require(result.candidates.first { $0.command.id.rawValue == "setting.language" })
        #expect(candidate.replacementRange == NSRange(location: 9, length: 8))
        let edit = try #require(result.accepting(candidate, in: text, hasMarkedText: false))
        #expect(edit.text == "/setting/language/chinese 后续👩🏽‍💻e\u{301}")
        #expect(edit.cursorLocation == 17)
        #expect(result.accepting(candidate, in: text + "!", hasMarkedText: false) == nil)
        #expect(result.accepting(candidate, in: text.precomposedStringWithCanonicalMapping, hasMarkedText: false) == nil)
        #expect(result.accepting(candidate, in: text, hasMarkedText: true) == nil)
        let composing = parser.parse(.init(text: "/set", hasMarkedText: true))
        #expect(composing.requiresCompositionEnd)
        let first = try #require(composing.candidates.first)
        #expect(composing.accepting(first, in: "/set", hasMarkedText: false) == nil)
    }

    @Test func cursorInsideKnownMultiwordAliasReplacesTheAlias() throws {
        let text = "/application settings/language/中文"
        let result = parser.parse(.init(text: text, cursorLocation: "/application".utf16.count))
        let candidate = try #require(result.candidates.first { $0.command.id.rawValue == "group.setting" })
        #expect(candidate.replacementRange == NSRange(location: 1, length: "application settings".utf16.count))
        #expect(result.accepting(candidate, in: text, hasMarkedText: false)?.text == "/setting/language/中文")
    }

    @Test func unicodeBoundariesRejectInvalidOffsetsWithoutClamping() {
        let text = "/setting/👩🏽‍💻e\u{301}中文"
        for offset in [-1, Int.max, text.utf16.count + 1, 10, 12, 14, 17] {
            let result = parser.parse(.init(text: text, cursorLocation: offset))
            #expect(result.diagnostics.first?.issue == .invalidCursor, "offset \(offset)")
            #expect(CommandPathCompletion(catalog: .standard).candidates(.init(text: text), cursor: offset).isEmpty)
            #expect(result.candidates.isEmpty)
        }
        for range in [NSRange(location: NSNotFound, length: 1), NSRange(location: 0, length: Int.max),
                      NSRange(location: 9, length: 1), NSRange(location: 16, length: 1)] {
            #expect(!CommandPathText.valid(range, in: text))
        }
        #expect(CommandPathText.valid(NSRange(location: 9, length: "👩🏽‍💻e\u{301}中文".utf16.count), in: text))
    }

    @Test func contentScopesDoNotHideCommandsAndSelectorsCannotBeBypassed() throws {
        let language = CommandID(rawValue: "setting.language")
        let configuration = try #require(CommandDiscoveryConfiguration.selector(allowing: [language], explanationKey: "test"))
        for path in ["/setting/appearance", "/settings/change appearance/dark", "/change appearance/dark", "/setting/login/true"] {
            let result = parser.parse(.init(text: path, configuration: configuration))
            #expect(result.diagnostics.first?.issue == .restricted, "\(path)")
            #expect(result.arguments.isEmpty)
            #expect(result.candidates.allSatisfy { $0.command.id == language || $0.category == .group })
        }
        for scope in CommandContentScope.allCases {
            #expect(parser.parse(.init(text: "/", contentScopes: [scope])).candidates == parser.parse(.init(text: "/")).candidates)
        }
        #expect(parser.parse(.init(text: "/setting", configuration: configuration)).state == .group)
        #expect(parser.parse(.init(text: "/settings/language/chinese", configuration: configuration)).arguments.first?.value == .choice("chinese"))
    }

    @Test func entireCatalogRemainsUnwiredAndPreservesAvailability() {
        for command in CommandCatalog.standard.entries {
            let result = parser.parse(.init(text: command.path))
            #expect(result.command == command, "\(command.path)")
            #expect(result.command?.execution == .unwired)
            #expect(result.command?.isExecutable == false)
            #expect(result.command?.availability == command.availability)
            for candidate in result.candidates {
                #expect(!candidate.command.isExecutable)
                #expect(candidate.command.execution == .unwired)
            }
        }
    }
}
