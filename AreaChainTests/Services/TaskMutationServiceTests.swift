import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct TaskMutationServiceTests {
    @Test(arguments: ["", " \n ", "普通标题", "标题 // 备注 #新 !p2 @18:00", "标题\n#新 备注\n第二行",
                      "#新", "!p4", "@18:00", "!p1", "标题 #Work #新 !p3 @15:00", "标题 ／／ 备注"])
    func originalUIAndSharedEntryHaveEqualFieldsAndEffects(text: String) throws {
        let fixtures = try (0..<3).map { _ in try TaskCaptureFixture() }
        let existingID = UUID()
        for fixture in fixtures {
            fixture.context.insert(TagItem(id: existingID, name: "Work", sortOrder: 0))
            fixture.context.insert(DailyRoutine(title: "排序基线", sortOrder: 7))
            try fixture.context.save()
        }
        let input = TaskMutationService.CaptureInput(text: text, dayKey: "2026-10-05",
                                                    tagIDs: [existingID, existingID], fallbackQuadrant: .important)
        let original = fixtures[0].original(input)
        let ui = DayBoardMutations.addCapturedTodo(text: text, dayKey: input.dayKey, context: fixtures[1].context,
            tagIDs: input.tagIDs, fallbackQuadrant: input.fallbackQuadrant, dependencies: fixtures[1].dependencies)
        let result = TaskMutationService.createCaptured(input, in: fixtures[2].context, dependencies: fixtures[2].dependencies)
        #expect(original == ui && ui == result.saved)
        #expect(try fixtures[0].fields() == fixtures[1].fields())
        #expect(try fixtures[1].fields() == fixtures[2].fields())
        for fixture in fixtures.dropFirst() {
            #expect(fixture.trace.filter { $0 != "fact" } == fixtures[0].trace)
            #expect(fixture.authorizations == fixtures[0].authorizations)
            #expect(fixture.failures == fixtures[0].failures)
        }
        if result.saved {
            #expect(result.savedID == result.candidateID)
            #expect(fixtures[2].registered == [result.savedID!])
            #expect(try fixtures[2].readTodos().first?.sortOrder == 8)
        }
    }

    @Test func metadataAndExplicitPriorityOverrideFallback() throws {
        let fixture = try TaskCaptureFixture()
        #expect(fixture.create("#1").saved)
        #expect(try fixture.readTodos().first?.title == "")
        let result = TaskMutationService.createCaptured(.init(text: "标题 !p4", dayKey: "2026-10-05",
            fallbackQuadrant: .importantUrgent), in: fixture.context, dependencies: fixture.dependencies)
        #expect(result.saved)
        let todo = try #require(fixture.readTodos().last)
        #expect(!todo.isImportant && !todo.isUrgent)
        #expect(fixture.create("!p4").state == .notSubmitted)
    }

    @Test func localFactPrecedesPrivateUIAndFakeSystemRequests() throws {
        let fixture = try TaskCaptureFixture()
        var defaultEvents = 0
        let observer = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: nil) { _ in
            defaultEvents += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        let result = fixture.create("标题 @18:00")
        #expect(defaultEvents == 0)
        #expect(result.state == .saved)
        #expect(fixture.trace == ["save", "saved", "fact", "ui", "reminderRefresh", "calendarRefresh", "authorize"])
        #expect(fixture.authorizations == [1080])
        #expect(result.transaction?.save == .returned)
        #expect(result.transaction?.publication == .returned)
    }

    @Test func changedLocallyAndDisabledCalendarRetainTheirPolicies() throws {
        let fixture = try TaskCaptureFixture()
        BoardEvents.changedLocally(dependencies: fixture.events)
        #expect(fixture.trace == ["ui", "reminderRefresh"])
        fixture.trace = []
        fixture.calendarEnabled = false
        #expect(fixture.create("标题").saved)
        #expect(fixture.trace == ["save", "saved", "fact", "ui", "reminderRefresh"])
        #expect(fixture.authorizations.isEmpty)
    }

    @Test(arguments: [false, true])
    func creationAndNewOrRestoredTagsShareCommit(fail: Bool) throws {
        let fixture = try TaskCaptureFixture()
        let date = Date(timeIntervalSince1970: 123)
        let old = TagItem(name: "旧", sortOrder: 2, deletedAt: date)
        fixture.context.insert(old)
        try fixture.context.save()
        var dependencies = fixture.dependencies
        if fail { dependencies.transaction.save = { _ in throw CocoaError(.fileWriteNoPermission) } }
        let result = fixture.create("标题 #旧 #新", dependencies: dependencies)
        #expect(result.state == (fail ? .commitUnknown : .saved))
        #expect(try fixture.readTodos().count == (fail ? 0 : 1))
        let tags = try fixture.context.fetch(FetchDescriptor<TagItem>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(tags.map(\.name) == (fail ? ["旧"] : ["旧", "新"]))
        #expect(old.deletedAt == (fail ? date : nil))
        if fail {
            #expect(fixture.registered.isEmpty && fixture.trace.isEmpty)
            #expect(fixture.failures == 1)
        } else {
            #expect(try fixture.readTodos().first.map { TagIDList.parse($0.tagIDs) } == tags.map(\.id))
        }
    }

    @Test func dirtyContextIsPresavedAndNotUndoneByCreationFailure() throws {
        let fixture = try TaskCaptureFixture()
        let unrelated = TodoItem(title: "旧", dayKey: "2026-10-04")
        fixture.context.insert(unrelated)
        try fixture.context.save()
        unrelated.title = "尚未保存的修改"
        var dependencies = fixture.dependencies
        dependencies.transaction.save = { _ in throw CocoaError(.fileWriteNoPermission) }
        let result = fixture.create("新任务 #新", dependencies: dependencies)
        #expect(result.transaction?.preSave == .returned)
        #expect(result.transaction?.save == .called)
        #expect(try fixture.readTodos().map(\.title) == ["尚未保存的修改"])
        #expect(try fixture.context.fetchCount(FetchDescriptor<TagItem>()) == 0)
        #expect(fixture.trace == ["preSave"])
    }

    @Test func savedThenThrownIsUnknownEvenWhenReadbackFindsTask() throws {
        let fixture = try TaskCaptureFixture()
        var dependencies = fixture.dependencies
        dependencies.transaction.save = { context in
            try context.save()
            throw CocoaError(.fileWriteUnknown)
        }
        let result = fixture.create("可能提交 #新", dependencies: dependencies)
        #expect(result.state == .commitUnknown && result.savedID == nil)
        #expect(result.transaction?.save == .called)
        #expect(try fixture.readTodos().map(\.id) == [result.candidateID!])
        #expect(fixture.trace.isEmpty && fixture.registered.isEmpty)
        #expect(fixture.authorizations.isEmpty)
    }

    @Test(arguments: [false, true])
    func postCommitFailuresNeverBecomeCreationFailure(registration: Bool) throws {
        let fixture = try TaskCaptureFixture()
        var dependencies = fixture.dependencies
        if registration {
            dependencies.registerLocalCreation = { _ in throw CocoaError(.fileWriteUnknown) }
        } else {
            dependencies.transaction.publish = { throw CocoaError(.fileWriteUnknown) }
        }
        let result = fixture.create("已保存 @18:00", dependencies: dependencies)
        #expect(result.saved && result.savedID != nil)
        #expect(result.registrationFailed == registration)
        #expect(result.transaction?.publicationFailed == !registration)
        #expect(try fixture.readTodos().count == 1)
        #expect(fixture.failures == 1 && fixture.authorizations == [1080])
    }

    @Test func legacyBoolKeepsDraftOnFailureAndClearsAfterLocalSuccess() throws {
        let fixture = try TaskCaptureFixture()
        var dependencies = fixture.dependencies
        dependencies.transaction.save = { _ in throw CocoaError(.fileWriteNoPermission) }
        var draft = "唯一草稿 #新"
        if DayBoardMutations.addCapturedTodo(text: draft, dayKey: "2026-10-05", context: fixture.context,
                                            dependencies: dependencies) { draft = "" }
        #expect(draft == "唯一草稿 #新" && fixture.failures == 1)
        dependencies = fixture.dependencies
        dependencies.transaction.publish = { throw CocoaError(.fileWriteUnknown) }
        if DayBoardMutations.addCapturedTodo(text: draft, dayKey: "2026-10-05", context: fixture.context,
                                            dependencies: dependencies) { draft = "" }
        #expect(draft.isEmpty)
        #expect(try fixture.readTodos().count == 1)
    }

    @Test func oldPrivateAndPresetTagPolicyIsNotReplacedByCommandGate() throws {
        let fixture = try TaskCaptureFixture()
        let tag = TagItem(name: "原任务标签", sortOrder: 0)
        tag.isPrivateDiary = true
        let preset = TagItem(name: "日记", sortOrder: 1)
        fixture.context.insert(tag)
        fixture.context.insert(preset)
        try fixture.context.save()
        let result = TaskMutationService.createCaptured(.init(text: "标题 #原任务标签", dayKey: "2026-10-05",
            tagIDs: [preset.id]), in: fixture.context, dependencies: fixture.dependencies)
        #expect(result.saved)
        #expect(try fixture.readTodos().first.map { TagIDList.parse($0.tagIDs) } == [preset.id, tag.id])
    }

    @Test(arguments: [false, true])
    func sourceStampStillUsesExistingRules(enabled: Bool) throws {
        let fixture = try TaskCaptureFixture()
        fixture.source = CaptureStamp.bundleID(enabled: enabled, frontmost: "qa.other", selfBundle: "qa.self")
        #expect(fixture.create("来源").saved)
        #expect(try fixture.readTodos().first?.sourceBundleID == (enabled ? "qa.other" : ""))
        #expect(CaptureStamp.bundleID(enabled: true, frontmost: "qa.self", selfBundle: "qa.self").isEmpty)
    }
}
