import AppKit
import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 任务、子任务、习惯一侧从文字解析标签时，照常保存文字，但不关联私密标签与预设标签，
/// 保存成功后给出一次提示；手记一侧仍关联私密标签（按标签加密手记靠它实现）。
@Suite(.serialized) @MainActor struct TaskSideTagFilterTests {
    @MainActor final class Scenario {
        let io: TaskCaptureFixture
        let work = TagItem(name: "工作", sortOrder: 0)
        let secret = TagItem(name: "私账", sortOrder: 1, isPrivateDiary: true)
        let buried = TagItem(name: "旧私", sortOrder: 2, deletedAt: Date(timeIntervalSince1970: 9), isPrivateDiary: true)
        let todo = TodoItem(title: "原标题", dayKey: "2026-10-20")
        let routine = DailyRoutine(title: "原习惯", sortOrder: 0, createdDayKey: "2026-10-01")
        let noticesBefore = MutationFeedback.shared.skippedTagNoticeCount
        var context: ModelContext { io.context }
        /// 正文同时带公开、私密（活的）与私密墓碑三种标签。
        static let tags = "#工作 #私账 #旧私"

        init() throws {
            io = try TaskCaptureFixture()
            [work, secret, buried].forEach(io.context.insert)
            io.context.insert(todo)
            io.context.insert(routine)
            try io.context.save()
        }

        /// UI 入口自带默认边界；包一层私有外层事务，保证不向真实提醒、日历发布。
        func inPrivateTransaction(_ work: () throws -> Void) throws {
            try ModelChanges.transaction(in: context, boundary: io.boundary, work)
        }

        func expectFiltered(_ encoded: String, extra: [UUID] = [], sourceLocation: SourceLocation = #_sourceLocation) throws {
            #expect(TagIDList.parse(encoded) == extra + [work.id], sourceLocation: sourceLocation)
            #expect(buried.deletedAt != nil, "私密墓碑不恢复", sourceLocation: sourceLocation)
            let names = try context.fetch(FetchDescriptor<TagItem>()).map(\.name).sorted()
            #expect(names == ["工作", "旧私", "私账"], "不新建同名标签", sourceLocation: sourceLocation)
            #expect(MutationFeedback.shared.skippedTagNoticeCount == noticesBefore + 1, sourceLocation: sourceLocation)
            #expect(MutationFeedback.shared.lastSkippedTags == ["私账", "旧私"], sourceLocation: sourceLocation)
        }
    }

    @Test func quickAddTodoSavesTextButSkipsPrivateTags() throws {
        let scenario = try Scenario()
        let result = scenario.io.create("买菜 " + Scenario.tags)
        #expect(result.saved)
        let todo = try #require(scenario.io.readTodos().first { $0.title == "买菜" })
        try scenario.expectFiltered(todo.tagIDs)
    }

    @Test func todoTitleEditSavesTextButSkipsPrivateTags() throws {
        let scenario = try Scenario()
        let dependencies = TaskMutationService.TitleDependencies(
            repository: { SwiftDataTaskRepository(context: $0) }, transaction: scenario.io.boundary,
            registerLocalModification: { _ in }, requestReminderAccessIfNeeded: { _ in })
        let result = TaskMutationService.editTitle(scenario.todo, rawInput: "新标题 " + Scenario.tags,
                                                   in: scenario.context, dependencies: dependencies)
        #expect(result.saved && scenario.todo.title == "新标题")
        try scenario.expectFiltered(scenario.todo.tagIDs)
    }

    @Test func todoNotesSaveTextButSkipPrivateTags() throws {
        let scenario = try Scenario()
        let notes = "备注 " + Scenario.tags
        try scenario.inPrivateTransaction {
            #expect(TaskNotesService.save(notes, for: scenario.todo, in: scenario.context,
                                          repository: SwiftDataTaskRepository(context: scenario.context),
                                          requestReminderAccess: { _ in }))
        }
        #expect(scenario.todo.notes == notes)
        try scenario.expectFiltered(scenario.todo.tagIDs)
    }

    @Test func routineNotesSaveTextButSkipPrivateTags() throws {
        let scenario = try Scenario()
        let notes = "习惯备注 " + Scenario.tags
        try scenario.inPrivateTransaction {
            #expect(TaskNotesService.save(notes, for: scenario.routine, in: scenario.context,
                                          repository: SwiftDataRoutineRepository(context: scenario.context),
                                          requestReminderAccess: { _ in }))
        }
        #expect(scenario.routine.notes == notes)
        try scenario.expectFiltered(scenario.routine.tagIDs)
    }

    @Test func routineQuickAddSavesTextButSkipsPrivateTags() throws {
        let scenario = try Scenario()
        try scenario.inPrivateTransaction {
            #expect(RoutineCaptureService.capture(.init(text: "晨跑 " + Scenario.tags, sortOrder: 5), in: scenario.context,
                                                  repository: SwiftDataRoutineRepository(context: scenario.context),
                                                  requestReminderAccess: { _ in }))
        }
        let routine = try #require(scenario.context.fetch(FetchDescriptor<DailyRoutine>()).first { $0.title == "晨跑" })
        try scenario.expectFiltered(routine.tagIDs)
    }

    @Test func routineTitleEditSavesTextButSkipsPrivateTags() throws {
        let scenario = try Scenario()
        let dependencies = RoutineMutationService.Dependencies(
            repository: { SwiftDataRoutineRepository(context: $0) }, transaction: scenario.io.boundary,
            registerLocalModification: { _ in }, requestReminderAccessIfNeeded: { _ in })
        let result = RoutineMutationService.editTitle(scenario.routine, rawInput: "新习惯 " + Scenario.tags,
                                                      in: scenario.context, dependencies: dependencies)
        #expect(result.saved && scenario.routine.title == "新习惯")
        try scenario.expectFiltered(scenario.routine.tagIDs)
    }

    @Test func structuredRecurringItemSkipsPrivateTagsButKeepsPickedIDs() throws {
        let scenario = try Scenario()
        var draft = RecurringCaptureDraft.fresh
        draft.title = "冥想 #私账"
        draft.notes = "说明 #工作 #旧私"
        let picked = UUID()
        draft.tagIDs = [picked]
        try scenario.inPrivateTransaction {
            #expect(DayBoardMutations.addRecurringItem(draft, sortOrder: 3, context: scenario.context))
        }
        let routine = try #require(scenario.context.fetch(FetchDescriptor<DailyRoutine>()).first { $0.title == "冥想" })
        #expect(routine.notes == "说明 #工作 #旧私")
        try scenario.expectFiltered(routine.tagIDs, extra: [picked])
    }

    @Test func subtaskAddAndEditSaveTextButSkipPrivateTags() throws {
        let scenario = try Scenario()
        let repository = SwiftDataTaskRepository(context: scenario.context)
        var subtask: SubtaskItem?
        try scenario.inPrivateTransaction {
            subtask = try repository.addSubtask(to: scenario.todo.id, title: "子项 " + Scenario.tags)
        }
        let added = try #require(subtask)
        #expect(added.title == "子项")
        try scenario.expectFiltered(added.tagIDs)
        try scenario.inPrivateTransaction {
            try repository.editSubtask(id: added.id, title: "改名 #私账")
        }
        #expect(added.title == "改名" && TagIDList.parse(added.tagIDs) == [scenario.work.id])
        #expect(MutationFeedback.shared.skippedTagNoticeCount == scenario.noticesBefore + 2)
        #expect(MutationFeedback.shared.lastSkippedTags == ["私账"])
    }

    @Test func clipboardCaptureKeepsTextButSkipsPrivateTags() throws {
        let scenario = try Scenario()
        let text = "剪贴 " + Scenario.tags
        let payload = try #require(ClipboardPayload.make(text: text, hasImage: false, imageTitle: "图"))
        let capture = ClipboardCapture.Capture(payload: payload, image: nil, todoID: UUID(), attachmentID: UUID(),
                                               dayKey: "2026-10-20", sourceBundleID: "")
        let root = FileManager.default.temporaryDirectory.appending(path: "areachain-m1-clip-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        var todo: TodoItem?
        try scenario.inPrivateTransaction {
            todo = try ClipboardCapture.apply(capture, storage: AttachmentStore(root: root), in: scenario.context)
        }
        let saved = try #require(todo)
        #expect(saved.title == payload.title)
        try scenario.expectFiltered(saved.tagIDs)
    }

    @Test func existingProtectedAssociationIsNotRemoved() throws {
        let scenario = try Scenario()
        scenario.todo.tagIDs = TagIDList.encode([scenario.secret.id])
        try scenario.context.save()
        try scenario.inPrivateTransaction {
            #expect(TaskNotesService.save("又写 #私账 #工作", for: scenario.todo, in: scenario.context,
                                          repository: SwiftDataTaskRepository(context: scenario.context),
                                          requestReminderAccess: { _ in }))
        }
        #expect(TagIDList.parse(scenario.todo.tagIDs) == [scenario.secret.id, scenario.work.id])
        #expect(MutationFeedback.shared.lastSkippedTags == ["私账"])
    }

    @Test func presetNamesAreSkippedAndNeverCreated() throws {
        let scenario = try Scenario()
        var resolved: InputTagResolver.TaskSide?
        try scenario.inPrivateTransaction {
            resolved = try InputTagResolver.resolveForTask(["日记", "工作", "新标签"], in: scenario.context)
        }
        let result = try #require(resolved)
        #expect(result.skipped == ["日记"])
        let created = try #require(scenario.context.fetch(FetchDescriptor<TagItem>()).first { $0.name == "新标签" })
        #expect(result.ids == [scenario.work.id, created.id])
        #expect(try scenario.context.fetch(FetchDescriptor<TagItem>()).allSatisfy { $0.name != "日记" })
    }

    @Test func failedSaveShowsNoSkippedNotice() throws {
        let scenario = try Scenario()
        struct Failure: Error {}
        #expect(throws: Failure.self) {
            try ModelChanges.transaction(in: scenario.context, boundary: scenario.io.boundary) {
                _ = try InputTagResolver.mergingForTask(["私账"], into: "", in: scenario.context)
                throw Failure()
            }
        }
        #expect(MutationFeedback.shared.skippedTagNoticeCount == scenario.noticesBefore)
    }

    /// 回归：手记一侧不经任务侧过滤，私密标签照常关联，也不出提示。
    @Test func diaryStillLinksPrivateTags() async throws {
        let scenario = try Scenario()
        // 合成保险库：内存配置与假系统钥匙，不触碰真实钥匙串。
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        try await vault.create(password: "m1-synthetic-pass", systemUnlock: false)
        vault.lock()
        let root = FileManager.default.temporaryDirectory.appending(path: "areachain-m1-diary-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = SwiftDataDiaryRepository(context: scenario.context, vault: vault,
                                                  attachmentStore: AttachmentStore(keys: vault.keys, root: root),
                                                  attachmentRoot: root)
        var entry: DiaryEntry?
        try scenario.inPrivateTransaction {
            entry = try repository.addDiary(text: "私记 #私账", dayKey: "2026-10-20", tagIDs: [], allowLockedInsert: true)
        }
        let saved = try #require(entry)
        #expect(TagIDList.contains(saved.tagIDs, scenario.secret.id))
        #expect(saved.hasProtectedContent)
        #expect(MutationFeedback.shared.skippedTagNoticeCount == scenario.noticesBefore)
    }
}
