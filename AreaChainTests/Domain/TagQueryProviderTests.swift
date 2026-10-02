import Foundation
import Testing
@testable import AreaChain

struct TagQueryProviderTests {
    @Test func tagsAndGlobalReturnOnlyTagIdentities() {
        let tags = [TagQueryFixture.tag(1), TagQueryFixture.tag(2, "学习")]
        for source in ["/tags 工作", "工作"] {
            let result = TagQueryFixture.read(source, tags)
            #expect(result.matches.map(\.id) == [.init(type: .tag, id: tags[0].id)])
            #expect(result.state == .evaluated && result.isCompleteForCoveredTypes)
            #expect(result.coverage.coveredTypes == [.tag])
            #expect(result.coverage.isPartialTypeCoverage == !source.hasPrefix("/tags"))
        }
        let empty = TagQueryFixture.read("不存在", tags)
        #expect(empty.matches.isEmpty && empty.coverage.isPartialTypeCoverage)
    }

    @Test func wordsPhrasesOrAndExclusionMatchOnlyOriginalName() {
        let tags = [TagQueryFixture.tag(1, "工作 Alpha beta"), TagQueryFixture.tag(2, "beta 工作 Alpha"),
                    TagQueryFixture.tag(3, "工作 Alpha 归档"), TagQueryFixture.tag(4, "完全无关")]
        let cases: [(String, [Int])] = [
            ("/tags 工作 beta", [0, 1]), ("/tags \"Alpha beta\"", [0]),
            ("/tags (beta | 归档) 工作", [0, 1, 2]), ("/tags 工作 -归档", [0, 1]),
            ("/tags -工作", [3]), ("/tags -\"Alpha beta\" 工作", [1, 2])
        ]
        for (source, indices) in cases {
            #expect(TagQueryFixture.read(source, tags).matches.map(\.tag.id) == indices.map { tags[$0].id })
        }
        let result = TagQueryFixture.read("/tags (missing | beta) -归档", tags)
        #expect(result.matches[0].evidence.contains { $0.field == .tagName && $0.alternativeIndex == 1 })
        #expect(result.matches[0].evidence.contains { $0.kind == .absence && $0.range == nil })
    }

    @Test func localizedUnicodeRangesReferToWholeOriginalGraphemes() throws {
        let raw = "📚 👩🏽‍💻 Cafe\u{301} 工作"
        let tag = TagQueryFixture.tag(1, raw)
        for (needle, expected) in [("CAFE", "Cafe\u{301}"), ("👩🏽‍💻", "👩🏽‍💻"), ("工作", "工作")] {
            let result = TagQueryFixture.read("/tags " + needle, [tag])
            let match = try #require(result.matches.first)
            let range = try #require(match.evidence.first { $0.field == .tagName }?.range)
            #expect((raw as NSString).substring(with: range) == expected)
            #expect((raw as NSString).rangeOfComposedCharacterSequences(for: range) == range)
            #expect(match.tag.name == raw)
        }
    }

    @Test func defaultPreservesInputOrderAndCatalogAllIsExplicit() {
        var first = TagQueryFixture.tag(1)
        first.sortOrder = 20
        let second = TagQueryFixture.tag(2)
        let normal = TagQueryFixture.read("/tags", [first, second])
        #expect(normal.matches.map(\.tag.id) == [first.id, second.id])
        #expect(normal.ordering.requested == .inputOrder && normal.ordering.applied == .inputOrder)
        let catalog = TagQueryFixture.read("/tags", [first, second], view: .catalog(.all))
        #expect(catalog.matches.map(\.tag.id) == [second.id, first.id])
        #expect(catalog.ordering.applied == .sortOrder && catalog.ordering.isComplete)
    }

    @Test func originalPresetNameAndPrivateMetadataRemainVisibleWithoutAliases() {
        var preset = TagQueryFixture.tag(1, DiaryMemoTags.password)
        preset.isPrivateDiary = true
        preset.colorToken = TagColorToken.clay.rawValue
        let other = TagQueryFixture.tag(2, "Password")
        let result = TagQueryFixture.read("/tags 密码", [preset, other])
        #expect(result.matches.first?.tag == preset)
        #expect(result.matches.first?.tag.isDiaryPreset == true)
        #expect(result.matches.first?.tag.resolvedColorToken == .clay)
        #expect(TagQueryFixture.read("/tags password", [preset, other]).matches.map(\.tag.id) == [other.id])
        #expect(!other.isDiaryPreset)
        var invalidColor = other
        invalidColor.colorToken = "legacy-color"
        #expect(TagQueryFixture.read("/tags", [invalidColor]).matches.first?.tag.resolvedColorToken == .default)
        #expect(invalidColor.colorToken == "legacy-color")
    }

    @Test func descriptionsNeverExpandNamesOrQuerySource() {
        let tag = TagQueryFixture.tag(1, "NAME_REDACTION_SENTINEL")
        let request = TagQueryRequest(requestID: UUID(), session: TodoQueryFixture.session("/tags NAME_REDACTION_SENTINEL"), tags: [tag])
        let response = TagQueryProvider.read(request)
        let values: [Any] = [tag, request, response, response.matches[0]]
        for value in values {
            #expect(!String(describing: value).contains(tag.name))
            #expect(!String(reflecting: value).contains(tag.name))
        }
        #expect(!String(describing: response.diagnostics).contains(tag.name))
    }
}
