import Foundation
import Testing
@testable import AreaChain

struct ClipboardQueryModeTests {
    @Test(arguments: ClipboardSearchMode.allCases)
    func extractedMatcherAndProviderMatchIndependentLegacyAlgorithm(_ mode: ClipboardSearchMode) throws {
        let texts = ["", "Alpha beta", "catalog", "Cafe\u{301}", "Café", "👩🏽‍💻测试 A b", "A\nb", "aa", "#工作 !p1"]
        let needles = ["", "  \n", "alp", "Alpha", "cta", "A b", "cafe", "é", "^", "$", "(?=a)", "a*", "(", "👩🏽‍💻试", "#工作"]
        let records = texts.enumerated().map { ClipboardQueryFixture.record($0.offset + 1, $0.element) }
        for needle in needles {
            let matching = ClipboardTextMatching(needle: needle, mode: mode)
            for text in texts {
                let expected = oldRanges(text, needle: needle, mode: mode)
                #expect(matching.ranges(in: text) == expected)
                #expect(ClipboardHistoryRules.highlightRanges(in: text, needle: needle, mode: mode) == expected)
                #expect(matching.matches(text) == oldMatches(text, needle: needle, mode: mode))
            }
            let expected = records.filter { oldMatches($0.plainText, needle: needle, mode: mode) }
            #expect(ClipboardHistoryRules.filtered(records, query: needle, mode: mode).map(\.id)
                == ClipboardHistoryRules.ordered(expected).map(\.id))
            let result = try ClipboardQueryFixture.explicit(mode, needle, records)
            if !matching.isValid {
                #expect(result.state == .invalidQuery && result.diagnostics.map(\.issue) == [.invalidRegex])
            } else {
                #expect(result.matches.map(\.id.id) == expected.map(\.id) && result.isCompleteForCoveredTypes)
                for match in result.matches {
                    #expect(match.mode == .legacy(mode))
                    #expect(match.modeEvidence?.ranges == oldRanges(match.plainText, needle: needle, mode: mode).map {
                        NSRange($0, in: match.plainText)
                    })
                }
            }
        }
    }

    @Test func explicitModeKeepsWholeNeedleWhileUnifiedUsesWords() throws {
        let record = ClipboardQueryFixture.record(1, "beta Alpha")
        #expect(ClipboardQueryFixture.read("/clipboard Alpha beta", [record]).matches.count == 1)
        #expect(try ClipboardQueryFixture.explicit(.mixed, "Alpha beta", [record]).matches.isEmpty)
        #expect(try ClipboardQueryFixture.explicit(.exact, "Alpha beta", [record]).matches.isEmpty)
        #expect(ClipboardQueryFixture.read("/clipboard cta", [ClipboardQueryFixture.record(2, "catalog")]).matches.isEmpty)
        #expect(try ClipboardQueryFixture.explicit(.mixed, "cta", [ClipboardQueryFixture.record(2, "catalog")]).matches.count == 1)
    }

    @Test func regexZeroLengthMatchesRemainFiniteEvidenceAndEmptyTextDoesNotMatch() throws {
        let records = [ClipboardQueryFixture.record(1, "aa"), ClipboardQueryFixture.record(2, "")]
        let response = try ClipboardQueryFixture.explicit(.regex, "(?=a)", records)
        #expect(response.matches.map(\.id.id) == [records[0].id])
        #expect(response.matches[0].modeEvidence?.ranges == [.init(location: 0, length: 0), .init(location: 1, length: 0)])
        #expect(try ClipboardQueryFixture.explicit(.regex, "^", records).matches.count == 1)
        #expect(try ClipboardQueryFixture.explicit(.regex, "", records).matches.count == 2)
    }

    @Test func modeIntersectsIndependentDateAndExactSource() throws {
        var first = ClipboardQueryFixture.record(1, "#工作 !p1 Alpha")
        first.copiedAt = ISO8601DateFormatter().date(from: "2026-10-01T01:00:00Z")!
        var old = first
        old.id = ClipboardQueryFixture.record(2).id
        old.copiedAt = old.copiedAt.addingTimeInterval(-86_400)
        var wrongSource = first
        wrongSource.id = ClipboardQueryFixture.record(3).id
        wrongSource.sourceBundleID = "COM.EXAMPLE.EDITOR"
        let filters = TodoQueryFixture.add(.page(.sourceApplication(first.sourceBundleID)),
            to: TodoQueryFixture.session("/clipboard date:today date:2026-09-30..2026-10-02"))
        let response = try ClipboardQueryFixture.explicit(.regex, "(#工作|#其他) !p1", [first, old, wrongSource], filters: filters)
        #expect(response.matches.map(\.id.id) == [first.id] && response.isCompleteForCoveredTypes)
        #expect(response.matches[0].evidence.contains { $0.field == .sourceApplication })
        let unified = ContentQueryReducer.reduce(filters, .setInput("/clipboard Alpha date:today")).state
        #expect(ClipboardQueryFixture.read(.unified(unified), records: .complete([first, wrongSource])).matches.map(\.id.id) == [first.id])
        var contradictory = filters
        contradictory.conditions.append(contradictory.makeCondition(.page(.sourceApplication("other")), origin: .user))
        #expect(try ClipboardQueryFixture.explicit(.exact, "Alpha", [first], filters: contradictory).state == .unsatisfiable)
    }

    @Test func filtersCannotKeepSecondTextTruthOrInvalidCommandInput() {
        for source in ["/clipboard Alpha", "/clipboard -Alpha", "/clipboard \"(a|b)#\""] {
            #expect(throws: ClipboardQueryRequestError.conflictingTextConditions) {
                try ClipboardQueryModeRequest(mode: .regex, needle: "a", filters: TodoQueryFixture.session(source))
            }
        }
        #expect(throws: ClipboardQueryRequestError.invalidFilters) {
            try ClipboardQueryModeRequest(mode: .regex, needle: "a", filters: TodoQueryFixture.session("/clipboard/search"))
        }
        var orphan = TodoQueryFixture.session("/clipboard Alpha")
        orphan.conditions.removeAll { $0.value.dimension == .content(.text) }
        #expect(throws: ClipboardQueryRequestError.conflictingTextConditions) {
            try ClipboardQueryModeRequest(mode: .mixed, needle: "b", filters: orphan)
        }
    }

    // 独立冻结提取前算法，避免只对比两个已委托同一实现的入口。
    private func oldMatches(_ text: String, needle: String, mode: ClipboardSearchMode) -> Bool {
        let needle = needle.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty { return true }
        if mode == .exact { return text.contains(needle) }
        return !oldRanges(text, needle: needle, mode: mode).isEmpty
    }

    private func oldRanges(_ text: String, needle: String, mode: ClipboardSearchMode) -> [Range<String.Index>] {
        let needle = needle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty, !text.isEmpty else { return [] }
        switch mode {
        case .exact: return text.range(of: needle).map { [$0] } ?? []
        case .regex:
            guard (try? NSRegularExpression(pattern: needle)) != nil,
                  let expression = try? NSRegularExpression(pattern: needle, options: [.caseInsensitive]) else { return [] }
            return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range, in: text) }
        case .mixed:
            var search = text.startIndex
            var ranges: [Range<String.Index>] = []
            for character in needle {
                guard let found = text[search...].firstIndex(where: {
                    String($0).localizedCaseInsensitiveCompare(String(character)) == .orderedSame
                }) else { return [] }
                let next = text.index(after: found)
                ranges.append(found..<next)
                search = next
            }
            return ranges
        }
    }
}
