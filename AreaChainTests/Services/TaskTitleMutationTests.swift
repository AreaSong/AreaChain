import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskTitleMutationTests {
    @Test(arguments: ["", " \n ", " 原标题 ", "普通标题", "标题 !p4", "标题 @18:00", "标题 #Work #恢复 #新 !p3 @15:00",
                      "标题 // 派生备注 #新 !p2 @18:00", "标题 ／／ 备注", "标题\n新备注\n第二行", "标题 // ", "#Work", "@18:00", "!p1"])
    func frozenAlgorithmUIAndServiceAgree(text: String) throws {
        let fixtures = try (0..<3).map { _ in try TaskTitleFixture() }
        for fixture in fixtures {
            fixture.todo.tagIDs = TaskTitleFixture.liveID.uuidString.lowercased() + "," + TaskTitleFixture.liveID.uuidString
            try fixture.io.context.save()
        }
        let original = fixtures[0].original(text)
        let ui = DayBoardMutations.editTodoWithSyntax(fixtures[1].todo, rawInput: text, dependencies: fixtures[1].dependencies)
        let result = fixtures[2].edit(text)
        #expect(original == ui && ui == result.saved)
        #expect(try fixtures[0].fields() == fixtures[1].fields())
        #expect(try fixtures[1].fields() == fixtures[2].fields())
        for fixture in fixtures.dropFirst() {
            #expect(fixture.io.trace.filter { $0 != "fact" } == fixtures[0].io.trace)
            #expect(fixture.io.authorizations == fixtures[0].io.authorizations)
            #expect(fixture.io.failures == fixtures[0].io.failures)
        }
        if result.saved {
            #expect(result.targetID == TaskTitleFixture.taskID)
            #expect(fixtures[2].io.registered == [result.targetID])
            #expect(TagIDList.parse(fixtures[2].todo.tagIDs).first == TaskTitleFixture.liveID)
        }
    }

    @Test func notesOnlyOverwriteWhenNonemptyAndTagsNeverUnlink() throws {
        let fixture = try TaskTitleFixture()
        let originalNotes = fixture.todo.notes
        #expect(fixture.edit("标题 // ").saved)
        #expect(fixture.todo.notes == originalNotes)
        #expect(fixture.edit("另一个标题").saved)
        #expect(fixture.todo.notes == originalNotes && TagIDList.parse(fixture.todo.tagIDs) == [fixture.live.id])
        #expect(fixture.todo.isImportant && !fixture.todo.isUrgent && fixture.todo.remindMinutes == 420)
        #expect(fixture.edit("新标题 // 非空备注 !p3 @18:00").saved)
        #expect(fixture.todo.notes == "非空备注" && !fixture.todo.isImportant && fixture.todo.isUrgent)
        #expect(fixture.todo.remindMinutes == 1080)
        #expect(TaskTitleEdit("新标题 // 非空备注")?.writeFields == [.title, .tagIDs, .notes])
    }

    @Test func sameValuesStillSavePublishAndNormalizeRawTagIDs() throws {
        let fixture = try TaskTitleFixture()
        fixture.todo.tagIDs = "\(fixture.live.id.uuidString.lowercased()),\(fixture.live.id)"
        try fixture.io.context.save()
        #expect(fixture.edit("原标题").saved)
        #expect(fixture.todo.tagIDs == fixture.live.id.uuidString)
        #expect(fixture.edit("原标题").saved)
        #expect(fixture.io.trace.filter { $0 == "save" }.count == 2)
        #expect(fixture.io.trace.filter { $0 == "ui" }.count == 2)
        #expect(fixture.io.authorizations.isEmpty)
    }

    @Test func privateEventsAndLocalFactPrecedeFakeSystemRequests() throws {
        let fixture = try TaskTitleFixture()
        var defaultEvents = 0
        let observer = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: nil) { _ in
            defaultEvents += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        var dependencies = fixture.dependencies
        dependencies.registerLocalModification = { id in
            let stored = try #require(fixture.io.readTodos().first)
            #expect(stored.id == id && stored.title == "已修改")
            #expect(fixture.io.trace == ["save", "saved"])
            fixture.io.trace.append("fact")
        }
        let result = fixture.edit("已修改 @18:00", dependencies: dependencies)
        #expect(result.saved && result.transaction?.save == .returned && result.transaction?.publication == .returned)
        #expect(result.reminderRequest == .returned && defaultEvents == 0)
        #expect(fixture.io.trace == ["save", "saved", "fact", "ui", "reminderRefresh", "calendarRefresh", "authorize"])
        #expect(fixture.io.authorizations == [1080])
    }

    @Test func oldPrivateTagPolicyStillWorksOnlyOnCompatibilityPath() throws {
        let fixture = try TaskTitleFixture()
        fixture.live.isPrivateDiary = true
        let preset = TagItem(name: "日记", sortOrder: 2)
        fixture.io.context.insert(preset)
        fixture.todo.tagIDs = TagIDList.encode([preset.id])
        try fixture.io.context.save()
        #expect(fixture.edit("标题 #Work").saved)
        #expect(TagIDList.parse(fixture.todo.tagIDs) == [preset.id, fixture.live.id])
        try fixture.queue("普通指令")
        #expect(throws: CommandTaskTitlePreviewIssue.self) { try fixture.preview() }
    }

    @Test func routineAndNotesConsumersRetainTheirOriginalSemantics() throws {
        let fixture = try TaskTitleFixture()
        let routine = DailyRoutine(title: "原习惯", sortOrder: 9)
        fixture.io.context.insert(routine)
        try fixture.io.context.save()
        // 无提醒 token，原授权入口提前返回；仓储提交全部继承显式私有外层边界。
        try ModelChanges.transaction(in: fixture.io.context, boundary: fixture.io.boundary) {
            #expect(DayBoardMutations.editRoutineWithSyntax(routine, rawInput: "习惯 #Work !p3 // 习惯备注"))
            #expect(DayBoardMutations.saveNotes("备注原文 #恢复 !p4", for: fixture.todo))
            #expect(DayBoardMutations.saveNotes("习惯原文 #Work !p2", for: routine))
            #expect(DayBoardMutations.addCapturedRoutine(text: "新增习惯 #Work", sortOrder: 10, context: fixture.io.context))
        }
        #expect(routine.title == "习惯" && routine.notes == "习惯原文 #Work !p2")
        #expect(routine.isImportant && !routine.isUrgent)
        #expect(fixture.todo.title == "原标题" && fixture.todo.notes == "备注原文 #恢复 !p4")
        #expect(!fixture.todo.isImportant && !fixture.todo.isUrgent && fixture.todo.remindMinutes == 420)
        #expect(TagIDList.parse(fixture.todo.tagIDs) == [fixture.live.id, fixture.deleted.id])
        #expect(try fixture.io.context.fetchCount(FetchDescriptor<DailyRoutine>()) == 2)
        #expect(fixture.io.authorizations.isEmpty && fixture.io.trace.filter { $0 == "save" }.count == 1)
    }
}
