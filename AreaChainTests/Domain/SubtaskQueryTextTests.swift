import Foundation
import Testing
@testable import AreaChain

struct SubtaskQueryTextTests {
    @Test func textUsesOnlyChildTitleAndNeverParentNotesTitleOrTagNames() {
        var parent = SubtaskQueryFixture.parent(1, title: "独立内容")
        parent.title = "父任务 项目"
        parent.notes = "备注 汇报"
        parent.subtasks[0].tagIDs = TodoQueryFixture.work.uuidString
        for query in ["父任务", "项目 汇报", "备注", "工作"] {
            #expect(SubtaskQueryFixture.read(query, [parent]).matches.isEmpty)
        }
        #expect(SubtaskQueryFixture.read("独立 -父任务 -备注", [parent]).matches.count == 1)
        #expect(SubtaskQueryFixture.read("#工作", [parent]).matches.count == 1)
    }

    @Test func wordsPhrasesAndORBranchesKeepANDAndExclusionSemantics() throws {
        let parents = [SubtaskQueryFixture.parent(1, title: "项目 汇报"),
                       SubtaskQueryFixture.parent(2, title: "项目 月度 汇报"),
                       SubtaskQueryFixture.parent(3, title: "周报 汇报 内部草稿")]
        #expect(SubtaskQueryFixture.read("项目 汇报", parents).matches.map(\.id.id) == parents.prefix(2).map { $0.subtasks[0].id })
        #expect(SubtaskQueryFixture.read(#""项目 汇报""#, parents).matches.map(\.id.id) == [parents[0].subtasks[0].id])
        let result = SubtaskQueryFixture.read(#"(项目 | 周报) 汇报 -草稿 -"内部讨论""#, parents)
        #expect(result.matches.map(\.id.id) == parents.prefix(2).map { $0.subtasks[0].id })
        #expect(result.matches.flatMap(\.evidence).filter { $0.kind == .absence }.count == 4)
        #expect(result.matches.flatMap(\.evidence).filter { $0.kind == .absence }.allSatisfy { $0.range == nil })
        let alternatives = try #require(SubtaskQueryFixture.read("(项目 | 汇报)", [parents[0]]).matches.first)
        #expect(alternatives.evidence.map(\.alternativeIndex) == [0, 1])
        #expect(Set(alternatives.evidence.map(\.conditionID)).count == 1)
        #expect(SubtaskQueryFixture.read("(草稿 | -月度)", parents).matches.map(\.id.id)
            == [parents[0].subtasks[0].id, parents[2].subtasks[0].id])
    }

    @Test func unicodeRangesPointToOriginalChildTitleAndWholeGraphemes() throws {
        let parent = SubtaskQueryFixture.parent(1, title: "开头 👩🏽‍💻 Cafe\u{301} 中文 naïve")
        let result = SubtaskQueryFixture.read("👩🏽‍💻 CAFE 中文 naive", [parent])
        let match = try #require(result.matches.first)
        #expect(match.evidence.count == 4)
        for (item, expected) in zip(match.evidence, ["👩🏽‍💻", "Cafe\u{301}", "中文", "naïve"]) {
            let range = try #require(item.range)
            #expect(item.field == .title && item.relatedObject == nil)
            #expect(Range(range, in: match.title) != nil)
            #expect((match.title as NSString).substring(with: range).utf16.elementsEqual(expected.utf16))
            #expect(range == (match.title as NSString).range(of: expected))
        }
        #expect(SubtaskQueryFixture.read("caff", [parent]).matches.isEmpty)
    }

    @Test func requestResultAndCollectionDescriptionsDoNotExpandPayloads() throws {
        var parent = SubtaskQueryFixture.parent(1, title: "合成子标题")
        parent.title = "合成父标题"
        parent.notes = String(repeating: "合成父备注", count: 100)
        let request = SubtaskQueryRequest(requestID: TodoQueryFixture.requestID,
            session: TodoQueryFixture.session("合成子标题"), todos: [parent], tagNames: [:], subtaskData: .includedInSnapshots)
        let result = SubtaskQueryProvider.read(request)
        let match = try #require(result.matches.first)
        #expect(match.title == parent.subtasks[0].title && match.parentTitle == parent.title)
        for value in [String(describing: request), String(reflecting: request), String(describing: result),
                      String(reflecting: result), String(describing: match), String(reflecting: [match])] {
            #expect(!value.contains("合成子标题") && !value.contains("合成父标题") && !value.contains("合成父备注"))
        }
    }
}
