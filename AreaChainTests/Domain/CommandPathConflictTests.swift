import Foundation
import Testing
@testable import AreaChain

struct CommandPathConflictTests {
    private func entry(_ id: String, _ path: String, _ category: CommandCategory = .modification) -> CommandDescriptor {
        CommandDescriptor(id: CommandID(rawValue: id), path: path, category: category)
    }

    private func catalog(_ entries: [CommandDescriptor]) -> CommandCatalog {
        let root = entry("catalog.root", "/", .group)
        let all = [root] + entries
        return CommandCatalog(entries: all.map { item in
            var item = item
            item.parentID = all.first { $0.path == CommandCatalog.parentPath(of: item.path) }?.id
            return item
        })
    }

    @Test func exactCanonicalChildWinsOverParameterAndPathAlias() throws {
        var parent = entry("setting.language", "/setting")
        parent.parameters = [.init(id: .value, type: .choice([.init(value: "chinese")]))]
        let child = entry("child", "/setting/chinese", .navigation)
        var alias = entry("alias", "/other")
        alias.pathAliases = ["/setting/chinese"]
        let parser = CommandPathParser(catalog: catalog([parent, child, alias]))
        let result = parser.parse(.init(text: "/setting/chinese"))
        #expect(result.command?.id == child.id)
        #expect(result.arguments.isEmpty)
        let candidates = parser.parse(.init(text: "/setting/chi")).candidates
        #expect(candidates.contains { $0.command.id == child.id })
        #expect(!candidates.contains { $0.id.hasPrefix("argument:") })
        let exact = try #require(result.candidates.first)
        #expect(exact.command.id == child.id)
        #expect(exact.match == .exactPath)
    }

    @Test func crossBranchAliasCompletionKeepsIdentityAndFollowingText() throws {
        let group = entry("group.setting", "/setting", .group)
        var command = entry("other", "/other")
        command.pathAliases = ["/setting/shared"]
        let parser = CommandPathParser(catalog: catalog([group, command]))
        let text = "/setting/sha/suffix"
        let result = parser.parse(.init(text: text, cursorLocation: "/setting/sha".utf16.count))
        let candidate = try #require(result.candidates.first { $0.command.id == command.id })
        #expect(result.accepting(candidate, in: text, hasMarkedText: false)?.text == "/other/suffix")
    }

    @Test func aliasAndParameterConflictIsNotSilentlyResolved() {
        var parent = entry("setting.language", "/setting")
        parent.parameters = [.init(id: .value, type: .choice([.init(value: "chinese")]))]
        var child = entry("child", "/setting/child")
        child.pathAliases = ["/setting/chinese"]
        let parser = CommandPathParser(catalog: catalog([parent, child]))
        let result = parser.parse(.init(text: "/setting/chinese"))
        #expect(result.state == .invalid)
        #expect(result.diagnostics.first?.issue == .ambiguous)
        #expect(Set(result.diagnostics.first?.commandIDs ?? []) == [parent.id, child.id])
        #expect(result.arguments.isEmpty)
        #expect(result.candidates.count >= 2)
    }

    @Test func duplicateAliasesAndChoiceAliasesRemainAmbiguous() {
        var first = entry("first", "/first")
        var second = entry("second", "/second")
        first.pathAliases = ["/shared"]
        second.pathAliases = ["/shared"]
        let parser = CommandPathParser(catalog: catalog([second, first]))
        let result = parser.parse(.init(text: "/shared"))
        #expect(result.state == .invalid)
        #expect(result.diagnostics.first?.issue == .ambiguous)
        #expect(result.candidates.map(\.command.id) == [first.id, second.id])
        var language = entry("setting.language", "/language")
        language.parameters = [.init(id: .value, type: .choice([.init(value: "chinese"), .init(value: "Chinese")]))]
        let ambiguous = CommandPathParser(catalog: catalog([language])).parse(.init(text: "/language/Chinese"))
        #expect(ambiguous.diagnostics.first?.issue == .ambiguous)
        #expect(ambiguous.arguments.isEmpty)
        #expect(ambiguous.candidates.count == 2)
    }

    @Test func orderingIsStableAcrossCatalogOrderAndLocale() {
        let exact = entry("exact", "/set")
        let prefix = entry("prefix", "/setting")
        var alias = entry("alias", "/alpha")
        alias.pathAliases = ["/set"]
        var aliasPrefix = entry("aliasPrefix", "/beta")
        aliasPrefix.pathAliases = ["/settings"]
        let entries = [aliasPrefix, prefix, alias, exact]
        for locale in [Locale(identifier: "en"), Locale(identifier: "zh-Hans")] {
            let forward = CommandPathParser(catalog: catalog(entries)).parse(.init(text: "/set", locale: locale))
            let backward = CommandPathParser(catalog: catalog(entries.reversed())).parse(.init(text: "/set", locale: locale))
            #expect(forward.candidates.map(\.command.id) == [exact.id, prefix.id, alias.id, aliasPrefix.id])
            #expect(forward.candidates.map(\.id) == backward.candidates.map(\.id))
        }
    }

    @Test func restrictedCanonicalCannotFallBackToPermittedAliasOrParameter() throws {
        var allowed = entry("allowed", "/allowed")
        allowed.pathAliases = ["/blocked"]
        allowed.parameters = [.init(id: .value, type: .choice([.init(value: "child")]))]
        let blocked = entry("blocked", "/blocked")
        let child = entry("child", "/allowed/child")
        let parser = CommandPathParser(catalog: catalog([allowed, blocked, child]))
        let configuration = try #require(CommandDiscoveryConfiguration.selector(allowing: [allowed.id], explanationKey: "test"))
        for text in ["/blocked", "/blocked/child", "/allowed/child"] {
            let result = parser.parse(.init(text: text, configuration: configuration))
            #expect(result.diagnostics.first?.issue == .restricted)
            #expect(result.arguments.isEmpty)
            #expect(!result.candidates.contains { $0.id.hasPrefix("argument:") })
        }
    }

    @Test func scalarTailsUseValidationAndNeverReadClockOrNativeServices() {
        let definitions: [(String, CommandParameterType, String, CommandValue)] = [
            ("bool", .boolean, "true", .boolean(true)),
            ("number", .number(1...10, integer: true), "3", .number(3)),
            ("day", .day, "2024-02-29", .day("2024-02-29")),
            ("time", .time, "09:30", .time(570))
        ]
        for (name, type, text, expected) in definitions {
            var command = entry(name, "/" + name)
            command.parameters = [.init(id: .value, type: type)]
            command.availability = .unavailable(reasonKey: "test")
            let parser = CommandPathParser(catalog: catalog([command]))
            let result = parser.parse(.init(text: "/\(name)/\(text)"))
            #expect(result.arguments.first?.value == expected)
            #expect(result.argumentIssues == [.unavailable])
            #expect(result.command?.availability == command.availability)
            #expect(result.command?.isExecutable == false)
            for invalid in ["tomorrow", "NaN", "infinity", "2025-02-29", "25:00"] {
                #expect(parser.parse(.init(text: "/\(name)/\(invalid)")).arguments.isEmpty)
            }
            #expect(parser.parse(.init(text: "/\(name)/")).candidates.allSatisfy { !$0.insertText.contains("2026") })
        }
    }

    @Test func chineseAndGraphemeReplacementUseUTF16Ranges() throws {
        let text = "/应用设置/语错👩🏽‍💻e\u{301}/中文"
        let result = CommandPathParser().parse(.init(text: text, cursorLocation: "/应用设置/语".utf16.count))
        let candidate = try #require(result.candidates.first { $0.command.id.rawValue == "setting.language" })
        #expect(candidate.replacementRange.location == "/应用设置/".utf16.count)
        #expect(candidate.replacementRange.length == "语错👩🏽‍💻e\u{301}".utf16.count)
        #expect(result.accepting(candidate, in: text, hasMarkedText: false)?.text == "/应用设置/language/中文")
    }
}
