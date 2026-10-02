import Foundation
import Testing
@testable import AreaChain

struct TrashQueryProviderTests {
    @Test func explicitScopeAndOrdinaryScopesAreIsolated() {
        for source in ["", "合成", "/tasks", "/diaries", "/images", "/tags", "/subtasks", "/routines"] {
            let result = TrashQueryFixture.read(source)
            #expect(result.state == .notApplicable)
            #expect(result.matches.isEmpty && result.typeCoverage.isEmpty)
        }
        let result = TrashQueryFixture.read("/trash", TrashQueryFixture.all())
        #expect(result.state == .evaluated)
        #expect(result.definiteMatchCount == 6)
        #expect(!result.hasIncompleteInput)
    }

    @Test func sixTypesMatchTheirOwnText() {
        for (text, type) in [("合成任务", CommandObjectType.todo), ("合成子任务", .subtask),
                             ("合成习惯", .routine), ("合成正文", .diary), ("合成标签", .tag), ("synthetic", .image)] {
            let result = TrashQueryFixture.read("/trash \(text)", TrashQueryFixture.all())
            #expect(result.matches.map(\.id.type) == [type])
        }
    }

    @Test func conjunctionAlternativesPhraseExclusionAndUnicodeRanges() throws {
        var input = TrashFixture.input()
        var todo = TrashFixture.todo()
        todo.title = "Cafe\u{301} 👩🏽‍💻 项目 汇报"
        todo.notes = "会议"
        input.todos = [todo]
        let result = TrashQueryFixture.read("/trash (café | 不存在) \"项目 汇报\" -草稿 会议", input)
        let match = try #require(result.matches.first)
        let evidence = try #require(match.evidence.first { $0.field == .title && $0.range != nil })
        #expect((todo.title as NSString).substring(with: try #require(evidence.range)) == "Cafe\u{301}")
        #expect(match.evidence.contains { $0.kind == .absence })
        #expect(TrashQueryFixture.read("/trash café -会议", input).matches.isEmpty)
        #expect(TrashQueryFixture.read("/trash 不存在 会议", input).matches.isEmpty)
    }

    @Test func datesAndCreationNeverUseDeletionTimestamp() {
        var input = TrashQueryFixture.all()
        input.todos?[0].createdAt = TodoQueryFixture.created
        input.subtasks?[0].createdAt = TodoQueryFixture.created
        input.routines?[0].createdAt = TodoQueryFixture.created
        input.diaries?[0].createdAt = TodoQueryFixture.created
        input.images?[0].createdAt = TodoQueryFixture.created
        let createdDay = DayKey.from(TodoQueryFixture.created, calendar: TodoQueryFixture.session().queryDates.calendar)
        let result = TrashQueryFixture.read("/trash created:\(createdDay)", input)
        #expect(result.definiteMatchCount == 5)
        #expect(result.restrictedTypes[.tag] != nil)
        let dayResult = TrashQueryFixture.read("/trash date:2026-10-02", input)
        #expect(Set(dayResult.matches.map(\.id.type)) == [.todo, .subtask, .diary, .image])
        #expect(dayResult.undeterminedObjects.map(\.type) == [.routine])
        input.todos?[0].deletedAt = Date(timeIntervalSince1970: 42)
        input.subtasks?[0].deletedAt = Date(timeIntervalSince1970: 42)
        #expect(TrashQueryFixture.read("/trash date:1970-01-01", input).matches.isEmpty)
    }

    @Test func tagsStatusAndAttributesRetainTypeMeaning() {
        var input = TrashQueryFixture.all()
        let tags = TagIDList.encode([TodoQueryFixture.work])
        input.todos?[0].tagIDs = tags
        input.subtasks?[0].tagIDs = tags
        input.routines?[0].tagIDs = tags
        input.diaries?[0].tagIDs = tags
        input.privacy = .init(tagNames: TodoQueryFixture.names, privateTagIDs: [])
        #expect(TrashQueryFixture.read("/trash #工作", input).definiteMatchCount == 5)
        let done = TrashQueryFixture.read("/trash status:done", input)
        #expect(done.matches.isEmpty)
        #expect(done.nonmatchingObjects.contains(TrashFixture.ref(.subtask, TrashFixture.childID)))
        var session = TodoQueryFixture.session("/trash")
        session = TodoQueryFixture.add(.page(.routineStatus(.disabled)), to: session)
        #expect(TrashQueryFixture.read(session, input).matches.contains { $0.id.type == .routine })
        session = TodoQueryFixture.add(.page(.contentTypes([.todo])), to: session)
        session = TodoQueryFixture.add(.page(.reminderPresence(.unset)), to: session)
        #expect(TrashQueryFixture.read(session, input).definiteMatchCount == 1)
    }

    @Test func invalidQueryAndImpossibleTypesAreDistinctFromMissingData() {
        #expect(TrashQueryFixture.read("/trash \"unterminated").state == .invalidQuery)
        let result = TrashQueryFixture.read("/trash status:done status:open")
        #expect(result.state == .evaluated)
        #expect(result.restrictedTypes[.todo]?.reasons.contains { $0.issue == .contradiction } == true)
        #expect(result.matches.isEmpty)
        var session = TodoQueryFixture.session("/trash")
        session.conditions.append(session.conditions[0])
        #expect(TrashQueryFixture.read(session, TrashFixture.family()).state == .invalidQuery)
    }
}
