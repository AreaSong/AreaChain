import Foundation
import Testing
@testable import AreaChain

struct CommandCatalogTests {
    private let catalog = CommandCatalog.standard

    @Test func completeCatalogHasValidStructureAndCoverage() {
        #expect(CommandFeature.allCases.count == 48)
        #expect(CommandCatalogValidation.issues(in: catalog).isEmpty)
        #expect(catalog.entries.filter { ![.group, .scope].contains($0.category) }.count > 200)
        for feature in CommandFeature.allCases {
            #expect(!catalog.commands(for: feature).isEmpty)
        }
    }

    @Test func mappingManifestMatchesAuthoritativeDocument() throws {
        let text = try String(contentsOf: root.appendingPathComponent("docs/unified-search-commands.md"), encoding: .utf8)
        let expression = try NSRegularExpression(pattern: #"\| (?:<a id="[^"]+"></a>)?([A-Z][0-9]+) "#)
        let source = text as NSString
        let names = expression.matches(in: text, range: NSRange(location: 0, length: source.length)).map {
            source.substring(with: $0.range(at: 1))
        }
        #expect(names.count == 48)
        #expect(Set(names) == Set(CommandFeature.allCases.map(\.rawValue)))
    }

    @Test func removedAndDuplicatedActionMappingsAreDetected() throws {
        let entry = try #require(catalog.command(path: "/tasks/add"))
        let slot = try #require(entry.coverage.first)
        let missing = CommandCatalog(entries: catalog.entries.filter { $0.id != entry.id })
        #expect(CommandCatalogValidation.issues(in: missing).contains(.missingCoverage(slot)))
        var duplicate = entry
        duplicate.path = "/tasks/duplicate"
        let result = CommandCatalogValidation.issues(in: CommandCatalog(entries: catalog.entries + [duplicate]))
        #expect(result.contains(.duplicateID(entry.id)))
        #expect(result.contains(.duplicateCoverage(slot)))
        var unknown = entry
        unknown.coverage = [CommandCoverage(feature: .t1, action: "unregistered")]
        #expect(CommandCatalogValidation.issues(in: CommandCatalog(entries: [unknown]))
            .contains(.unknownCoverage(unknown.coverage[0])))
    }

    @Test func malformedParentPathsAliasesAndPreviewReferencesAreDetected() throws {
        var entry = try #require(catalog.command(path: "/tasks/add"))
        entry.pathAliases = ["/tasks/add", "/任务/新增"]
        entry.parentID = entry.id
        entry.preview.append(.parameter(.method))
        let issues = CommandCatalogValidation.issues(in: CommandCatalog(entries: [entry]))
        #expect(issues.contains(.duplicatePath("/tasks/add")))
        #expect(issues.contains(.invalidPath("/任务/新增")))
        #expect(issues.contains(.invalidParent(entry.id)))
        #expect(issues.contains(.invalidPreview(entry.id, .method)))
    }

    @Test func scopeGroupNavigationAndMutationHaveDifferentSubmissionContracts() throws {
        let scope = try #require(catalog.command(path: "/tasks"))
        #expect(scope.category == .scope)
        #expect(scope.submission == .refineQuery)
        #expect(scope.contentScope?.inclusion == .ordinaryContent)
        #expect(catalog.command(path: "/go/today")?.submission == .navigate)
        #expect(catalog.command(path: "/setting")?.submission == .browse)
        #expect(catalog.command(path: "/tasks/add")?.submission == .previewModification)
        #expect(!catalog.children(of: scope.id).isEmpty)
        #expect(catalog.command(path: "/stats/today")?.category == .query)
    }

    @Test func contentScopesNeverHideGlobalCommands() throws {
        for scope in CommandContentScope.allCases {
            #expect(catalog.discover(contentScopes: [scope]) == catalog.entries)
        }
        let language = try #require(catalog.command(path: "/setting/language"))
        #expect(catalog.discover(contentScopes: [.diaries]).contains(language))
        let restriction = try #require(CommandDiscoveryConfiguration.selector(
            allowing: [language.id], explanationKey: "command.selector.restriction"
        ))
        let selected = catalog.discover(contentScopes: [.tasks], configuration: restriction)
        #expect(selected.contains(language))
        #expect(selected.allSatisfy { $0.id == language.id || $0.category == .group })
        #expect(CommandDiscoveryConfiguration.selector(allowing: [], explanationKey: " \n") == nil)
        #expect(CommandContentScope.clipboard.inclusion == .explicitOnly)
        #expect(CommandContentScope.trash.inclusion == .explicitOnly)
    }

    @Test func dangerousAndNonModificationActionsAreExcludedFromOrdinaryQueue() throws {
        for path in ["/go/today", "/quit", "/trash/delete", "/privacy/unprotect", "/backup/restore", "/recovery/reset-quit"] {
            let entry = try #require(catalog.command(path: path))
            #expect(entry.queue == .excluded)
            #expect(!entry.canEnterOrdinaryQueue)
            var broken = entry
            broken.queue = .eligibleAfterWiring
            #expect(CommandCatalogValidation.issues(in: CommandCatalog(entries: [broken])).contains(.unsafeQueue(entry.id)))
        }
        #expect(catalog.command(path: "/tasks/title")?.queue == .eligibleAfterWiring)
    }

    @Test func everyAdapterIsUnwiredAndNoUnknownCapabilityClaimsSupport() {
        for entry in catalog.entries {
            #expect(entry.execution == .unwired)
            #expect(!entry.isExecutable)
            #expect(!entry.canEnterOrdinaryQueue)
            #expect(entry.retry == .unverified)
            #expect(entry.undo == .unverified)
        }
        #expect(catalog.command(path: "/recovery/reset-quit")?.availability
            == .unavailable(reasonKey: "command.reason.recoveryDesign"))
        #expect(catalog.command(path: "/routines/checks/complete")?.availability
            == .unresolved(reasonKey: "command.reason.routineCompletion"))
    }

    @Test func targetTypesDoNotConflateParentsRecordsAndWindows() throws {
        #expect(catalog.command(path: "/subtasks/title")?.targetTypes == [.subtask])
        #expect(catalog.command(path: "/routines/weekdays")?.targetTypes == [.routine])
        #expect(catalog.command(path: "/routines/checks/skip")?.targetTypes == [.routineOccurrence])
        #expect(catalog.command(path: "/diaries/pinned")?.targetTypes == [.diary])
        #expect(catalog.command(path: "/window/diary/pinned")?.targetTypes == [.diaryWindow])
        #expect(catalog.command(path: "/tags/rename")?.targetTypes == [.tag])
        #expect(catalog.command(path: "/tasks/tags")?.targetTypes == [.todo])
        let subtask = try #require(catalog.command(path: "/subtasks/add"))
        #expect(!subtask.parameters.contains { [.day, .time, .priority].contains($0.id) })
        #expect(catalog.command(path: "/setting/icloud")?.parameters.isEmpty == true)
        #expect(catalog.command(path: "/images/add")?.parameters.first { $0.id == .file }?.type == .nativeFile(.image))
    }

    @Test func allVisibleResourcesResolveInBothLanguages() throws {
        let data = try Data(contentsOf: root.appendingPathComponent("AreaChain/Resources/Localizable.xcstrings"))
        let resource = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(resource["strings"] as? [String: Any])
        for entry in catalog.entries {
            var keys = [entry.nameKey, entry.summaryKey, entry.aliasKey] + entry.parameters.map { $0.id.nameKey }
            for parameter in entry.parameters {
                if case .choice(let choices) = parameter.type { keys += choices.flatMap { [$0.nameKey, $0.aliasKey] } }
            }
            switch entry.availability {
            case .unresolved(let key), .unavailable(let key): keys.append(key)
            case .declared: break
            }
            for key in keys {
                for language in ["en", "zh-Hans"] {
                    let item = try #require(strings[key] as? [String: Any], "Missing \(key)")
                    let locales = try #require(item["localizations"] as? [String: Any])
                    #expect(locales[language] != nil)
                    let value = L10n.format(key, locale: Locale(identifier: language))
                    #expect(value != key)
                    #expect(!value.isEmpty)
                }
            }
        }
    }

    @Test func stableMatchingDoesNotPretendToParseParameterPathsOrPrefixes() throws {
        let language = try #require(catalog.command(path: "/setting/language"))
        #expect(catalog.matches("语言", locale: Locale(identifier: "zh-Hans")).contains(language))
        #expect(catalog.matches("language", locale: Locale(identifier: "en")).contains(language))
        #expect(catalog.command(path: "/setting/language/chinese") == nil)
        #expect(catalog.matches("/set", locale: Locale(identifier: "en")).isEmpty)
        #expect(catalog.command(path: "/settings")?.id == catalog.command(path: "/setting")?.id)
        let choice = CommandChoice(value: "chinese")
        #expect(choice.matches("简体中文", locale: Locale(identifier: "zh-Hans")))
        #expect(choice.matches("chinese", locale: Locale(identifier: "en")))
    }

    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
}
