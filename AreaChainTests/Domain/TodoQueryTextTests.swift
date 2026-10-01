import Foundation
import Testing
@testable import AreaChain

struct TodoQueryTextTests {
    @Test func wordsUseCrossFieldANDWhilePhrasesStayWithinOneField() throws {
        var split = TodoQueryFixture.todo(1, title: "项目")
        split.notes = "汇报"
        let phrase = TodoQueryFixture.todo(2, title: "项目 汇报")
        let gap = TodoQueryFixture.todo(3, title: "项目 月度 汇报")
        let input = [split, phrase, gap]
        #expect(TodoQueryFixture.read("项目 汇报", input).matches.map(\.id.id) == input.map(\.id))
        #expect(TodoQueryFixture.read(#""项目 汇报""#, input).matches.map(\.id.id) == [phrase.id])
        let match = try #require(TodoQueryFixture.read("项目 汇报", [split]).matches.first)
        #expect(match.evidence.map(\.field) == [.title, .notes])
        #expect(match.evidence.map(\.alternativeIndex) == [0, 0])
        #expect(Set(match.evidence.map(\.conditionID)).count == 2)
    }

    @Test func orGroupsIntersectAndExclusionsCheckEveryTextField() {
        var first = TodoQueryFixture.todo(1, title: "项目 月报")
        first.notes = "正式发布"
        var excluded = first
        excluded.id = TodoQueryFixture.todo(2).id
        excluded.notes = "内部讨论 草稿"
        let third = TodoQueryFixture.todo(3, title: "周报 汇报")
        let input = [first, excluded, third]
        let response = TodoQueryFixture.read(#"(项目 | 周报) (月报 | 汇报) -草稿 -"内部讨论""#, input)
        #expect(response.queryIsValid && response.state == .evaluated)
        #expect(response.matches.map(\.id.id) == [first.id, third.id])
        let absence = response.matches.flatMap(\.evidence).filter { $0.kind == .absence }
        #expect(absence.count == 8)
        #expect(absence.allSatisfy { $0.range == nil })
        #expect(TodoQueryFixture.read("(草稿 | -周报)", input).matches.map(\.id.id) == [first.id, excluded.id])
    }

    @Test func unicodeEvidenceAddressesOriginalStringsAndDoesNotFuzz() throws {
        var todo = TodoQueryFixture.todo(1, title: "开头 👩🏽‍💻 Cafe\u{301} 中文")
        todo.notes = "🧑‍🚀 naïve 尾巴"
        let result = TodoQueryFixture.read("👩🏽‍💻 CAFE 中文 naive", [todo])
        let match = try #require(result.matches.first)
        let evidence = match.evidence
        #expect(evidence.count == 4)
        let expected = ["👩🏽‍💻", "Cafe\u{301}", "中文", "naïve"]
        for (item, substring) in zip(evidence, expected) {
            let original = item.field == .title ? match.title : match.notes
            let range = try #require(item.range)
            #expect(Range(range, in: original) != nil)
            #expect((original as NSString).substring(with: range).utf16.elementsEqual(substring.utf16))
            #expect(range == (original as NSString).range(of: substring))
        }
        #expect(TodoQueryFixture.read("caff", [todo]).matches.isEmpty)
        #expect(TodoQueryFixture.read("中 间", [todo]).matches.isEmpty)
    }

    @Test func taskTextDoesNotSearchTagNamesOrSubtaskTitles() {
        var todo = TodoQueryFixture.todo(1, title: "独立标题")
        todo.tagIDs = TodoQueryFixture.work.uuidString
        todo.subtasks = [TodoQueryFixture.subtask(1, parent: todo)]
        #expect(TodoQueryFixture.read("工作", [todo]).matches.isEmpty)
        #expect(TodoQueryFixture.read("合成子任务", [todo]).matches.isEmpty)
        #expect(TodoQueryFixture.read("#工作", [todo]).matches.count == 1)
    }

    @Test func descriptionsDoNotExpandQueryOrNotesAndNotesAreStoredOncePerResult() throws {
        var todo = TodoQueryFixture.todo(1, title: "合成标题")
        todo.notes = String(repeating: "甲乙丙 合成备注 ", count: 200)
        let state = TodoQueryFixture.session("甲 乙 丙")
        let request = TodoQueryRequest(requestID: TodoQueryFixture.requestID, session: state,
                                      todos: [todo], tagNames: [:], subtaskData: .unavailable)
        let result = TodoQueryProvider.read(request)
        let match = try #require(result.matches.first)
        #expect(match.notes == todo.notes && match.evidence.count == 3)
        for description in [String(describing: request), String(reflecting: request),
                            String(describing: result), String(reflecting: result),
                            String(describing: match), String(reflecting: [match])] {
            #expect(!description.contains("合成标题") && !description.contains("合成备注"))
        }
    }
}
