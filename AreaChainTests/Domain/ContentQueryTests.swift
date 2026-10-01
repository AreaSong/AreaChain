import Foundation
import Testing
@testable import AreaChain

struct ContentQueryTests {
    private var context: ContentQueryDateContext {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return .init(todayKey: "2026-10-01", calendar: calendar)
    }

    private func query(_ source: String) throws -> ContentQuery {
        guard case .content(let query) = ContentQueryParser().parse(source, context: context) else {
            throw QueryExpected()
        }
        return query
    }

    private struct QueryExpected: Error {}

    @Test func requiredCompositeQuery() throws {
        let source = "/tasks 汇报 (#工作 | #学习) -#归档 status:open"
        let result = try query(source)
        #expect(result.source == source)
        #expect(result.isReady)
        #expect(result.scopes.map(\.scope) == [.tasks])
        #expect(result.clauses.count == 4)
        #expect(result.clauses[0].alternatives[0].atom == .text("汇报", phrase: false))
        #expect(result.clauses[1].alternatives.map(\.atom) == [.tag("工作"), .tag("学习")])
        #expect(result.clauses[2].alternatives[0].excluded)
        #expect(result.clauses[3].alternatives[0].atom == .status(.open))
    }

    @Test func wordsPhrasesAndExclusionsRetainDistinctSemantics() throws {
        let result = try query(#"项目 汇报 "项目 汇报" -草稿 -"内部讨论" #工作 #重要 -#归档"#)
        #expect(result.isReady)
        #expect(result.clauses.map { $0.alternatives[0].atom } == [
            .text("项目", phrase: false), .text("汇报", phrase: false), .text("项目 汇报", phrase: true),
            .text("草稿", phrase: false), .text("内部讨论", phrase: true), .tag("工作"), .tag("重要"), .tag("归档")
        ])
        #expect(result.clauses.map { $0.alternatives[0].excluded } == [false, false, false, true, true, false, false, true])
    }

    @Test func quotedTagsEscapesAndProtectedCode() throws {
        let source = ##"#"项目 汇报" #"a\"b" \#工作 `#代码 status:done` [链接](https://example.test/#标签)"##
        let result = try query(source)
        #expect(result.isReady)
        #expect(result.clauses.map { $0.alternatives[0].atom } == [
            .tag("项目 汇报"), .tag("a\"b"), .text("#工作", phrase: false),
            .text("`#代码 status:done`", phrase: true), .text("[链接](https://example.test/#标签)", phrase: true)
        ])
        let multiline = try query("```\n#工作 status:done\n``` #真实")
        #expect(multiline.clauses.count == 2)
        #expect(multiline.clauses.last?.alternatives.first?.atom == .tag("真实"))
        #expect(multiline.isReady)
    }

    @Test func unicodeDiagnosticRangesAreOriginalUTF16() throws {
        let prefix = "中文 👩🏽‍💻 e\u{301} "
        let source = prefix + "\"未闭合 🧑‍🚀"
        let result = try query(source)
        let diagnostic = try #require(result.diagnostics.first)
        #expect(diagnostic.issue == .incompleteQuote)
        #expect(diagnostic.range == NSRange(location: prefix.utf16.count, length: source.utf16.count - prefix.utf16.count))
        #expect((source as NSString).substring(with: diagnostic.range) == "\"未闭合 🧑‍🚀")
        #expect(CommandPathText.valid(diagnostic.range, in: source))
        #expect(!result.isReady)
        #expect(result.source.utf16.elementsEqual(source.utf16))
    }

    @Test func invalidStructuresAreNeverPartiallyReady() throws {
        let cases: [(String, ContentQueryIssue)] = [
            ("(#工作 | status:done)", .mixedDimensions), ("(#工作 | (#学习 | #重要))", .nestedGroup),
            ("(#工作 | #学习", .incompleteGroup), ("(#工作 |)", .incompleteCondition),
            ("#工作 | #学习", .unsupportedStructure), ("(#工作 #学习)", .unsupportedStructure),
            ("-status:done", .unsupportedExclusion), ("date:", .incompleteCondition), ("date:2026-10-", .incompleteCondition),
            ("status:o", .incompleteCondition), ("@15:", .incompleteCondition),
            ("(/tasks | /diaries)", .unsupportedStructure),
            ("has:video", .invalidCondition), ("field:value", .invalidCondition),
            ("abc\\q", .invalidEscape), ("abc\\", .incompleteEscape), ("\"a\\q\"", .invalidCondition)
        ]
        for (text, issue) in cases {
            let result = try query(text)
            #expect(result.diagnostics.contains { $0.issue == issue }, "\(text): \(result.diagnostics)")
            #expect(!result.isReady)
            #expect(result.source == text)
        }
    }

    @Test func sameDimensionAlternativesSupportAllAtoms() throws {
        for source in [
            "(项目 | \"项目 汇报\" | -草稿)", "(#工作 | -#学习)", "(!p1 | !p2)", "(@15:30 | @16:00)",
            "(status:open | status:done)", "(date:today | date:2026-10-07)",
            "(created:2026-01-01 | created:2026-10-01)", "(has:image | has:image)"
        ] {
            let result = try query(source)
            #expect(result.isReady, "\(source): \(result.diagnostics)")
            #expect(result.clauses.count == 1)
        }
    }

    @Test func duplicateAndContradictoryConditionsArePreserved() throws {
        let duplicate = try query("#工作 #工作 status:open status:open")
        #expect(duplicate.clauses.count == 4)
        #expect(duplicate.diagnostics.filter { $0.issue == .duplicateCondition }.count == 2)
        #expect(duplicate.isReady)
        for source in [
            "#工作 -#工作", "草稿 -草稿", #"草稿 -"草稿""#, "status:open status:done", "!p1 !p2", "@15:30 @16:00",
            "(#工作 | #学习) -#工作 -#学习", "(status:open | status:done) status:open status:done",
            "date:2026-10-01..2026-10-03 date:2026-10-04..2026-10-07",
            "(date:2026-01-01 | date:2026-03-01) date:2026-02-01",
            "(#a | #b) (-#a | #b) (#a | -#b) (-#a | -#b)"
        ] {
            let result = try query(source)
            #expect(result.isStructurallyValid)
            let analysis = TodoQueryFixture.session(source).typeAnalysis
            #expect(analysis.assessment(for: .todo)?.reasons.contains { $0.issue == .contradiction } == true, "\(source)")
            #expect(!result.clauses.isEmpty)
        }
        #expect(try query("(#工作 | #学习) -#工作").isReady)
        #expect(try query("date:2026-10-01..2026-10-07 date:2026-10-07").isReady)
    }

    @Test func priorityReminderAndBilingualFieldsUseStableSemantics() throws {
        let english = try query("!p1 @15:30 status:open date:today created:2026-10-01 has:image")
        let chinese = try query("!重要且紧急 @15:30 状态:未完成 日期:今天 创建日期:2026-10-01 包含:图片")
        #expect(english.isReady && chinese.isReady)
        #expect(english.clauses.map { $0.alternatives[0].atom } == chinese.clauses.map { $0.alternatives[0].atom })
        #expect(english.clauses[0].alternatives[0].atom == .priority(.init(isImportant: true, isUrgent: true)))
        #expect(english.clauses[1].alternatives[0].atom == .reminder(930))
        #expect(!(try query("@25:30")).isReady)
    }

    @Test func scopesAndCommandsRemainSeparateAndNeverExecute() throws {
        for source in ["/setting/language/chinese", "/tasks/title/正文 #工作", "/tasks/status/done", "/set", "/unknown"] {
            guard case .command(let result) = ContentQueryParser().parse(source, context: context) else {
                Issue.record("expected command: \(source)"); continue
            }
            #expect(result.input == source)
            #expect(result.command?.isExecutable != true)
        }
        for (source, scope) in [("/clipboard 汇报", CommandContentScope.clipboard), ("/trash #工作", .trash)] {
            let result = try query(source)
            #expect(result.scopes.first?.scope == scope)
            #expect(result.isReady)
        }
        #expect(!(try query("/tasks /clipboard")).isReady)
        #expect(try query("/tasks /tasks").isReady)
        #expect(!(try query("/tasks /setting/language/chinese")).isReady)
        #expect(try query("/tmp/example.txt").isReady)
        #expect(try query("\\/tasks").scopes.isEmpty)
        #expect(try query("`/tasks` #工作").scopes.isEmpty)
    }

    @Test func excessiveBooleanAnalysisHasExplicitDiagnostic() throws {
        let source = (0..<129).map { "#tag\($0)" }.joined(separator: " ")
        let result = try query(source)
        #expect(result.clauses.count == 129)
        #expect(result.isStructurallyValid)
        let analysis = TodoQueryFixture.session(source).typeAnalysis
        #expect(analysis.assessment(for: .todo)?.reasons.contains { $0.issue == .analysisLimit } == true)
        #expect(analysis.possibleTypes.contains(.todo))
    }
}

extension ContentQueryTests {
    @Test func scopeAliasesAndCommandPrefixConflictsUseTheInjectedCatalog() throws {
        var tasks = CommandDescriptor(id: .init(rawValue: "scope.tasks"), path: "/tasks", category: .scope)
        tasks.contentScope = .tasks
        tasks.pathAliases = ["/我的任务", "/all tasks"]
        var action = CommandDescriptor(id: .init(rawValue: "synthetic.action"), path: "/action", category: .modification)
        action.pathAliases = ["/tasks action"]
        let parser = ContentQueryParser(catalog: .init(entries: [tasks, action]))
        for source in ["/我的任务 #工作", "/all tasks 汇报"] {
            guard case .content(let result) = parser.parse(source, context: context) else {
                Issue.record("expected content: \(source)"); continue
            }
            #expect(result.isReady)
            #expect(result.scopes.first?.scope == .tasks)
            #expect(result.clauses.count == 1)
        }
        for source in ["/tasks action", "/tasks action #正文"] {
            guard case .command(let result) = parser.parse(source, context: context) else {
                Issue.record("command body entered content query: \(source)"); continue
            }
            #expect(result.input == source)
        }
    }
}
