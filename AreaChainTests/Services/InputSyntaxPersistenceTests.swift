import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct InputSyntaxPersistenceTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test(arguments: [false, true])
    func quotedWhitespaceNamesKeepExistingDiaryClassification(reusePreset: Bool) throws {
        let store = try container()
        if reusePreset {
            store.mainContext.insert(TagItem(name: "密码", sortOrder: 0))
            try store.mainContext.save()
        }
        let text = "#\" 密码 \" 测试正文"
        let entry = try SwiftDataDiaryRepository(container: store).addDiary(text: text, dayKey: "2026-09-13", tagIDs: [])
        let tags = try store.mainContext.fetch(FetchDescriptor<TagItem>())
        #expect(tags.map(\.name) == ["密码"])
        #expect(entry.text == text)
        let tagMap = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
        #expect(DiaryPrivacy.isSensitive(entry.snapshot, tagNames: tagMap))
        #expect(TagIDList.contains(entry.tagIDs, try #require(tags.first).id))
    }

    @Test func confirmedExampleCreatesReusesAndSearchesARealTag() throws {
        let store = try container()
        let repo = SwiftDataDiaryRepository(container: store)
        let first = try repo.addDiary(text: "#今日 今天很开心", dayKey: "2026-09-13", tagIDs: [])
        let second = try repo.addDiary(text: "另一条 #今日", dayKey: "2026-09-14", tagIDs: [])
        let tags = try store.mainContext.fetch(FetchDescriptor<TagItem>())
        #expect(tags.count == 1)
        let tag = try #require(tags.first)
        #expect(tag.name == "今日")
        #expect(first.text == "#今日 今天很开心")
        #expect(TagIDList.contains(first.tagIDs, tag.id))
        #expect(TagIDList.contains(second.tagIDs, tag.id))
        #expect(try repo.searchDiaries(query: "#今日 开心", tagID: nil, includeDeleted: false).map(\.id) == [first.id])
    }

    @Test func taskAndHabitEntryPointsReuseTagsAndPreserveTheirScopes() throws {
        let store = try container()
        let context = store.mainContext
        let project = ProjectItem(name: "项目", sortOrder: 0)
        let existing = TagItem(name: "Work", sortOrder: 0)
        context.insert(project)
        context.insert(existing)
        try context.save()
        #expect(DayBoardMutations.addCapturedTodo(
            text: "开会 #work #今日 !p1 @15:00\n#备注 内容", dayKey: "2026-09-15",
            context: context, projectID: project.id, tagIDs: [existing.id]
        ))
        let todo = try #require(context.fetch(FetchDescriptor<TodoItem>()).first)
        #expect(todo.title == "开会")
        #expect(todo.dayKey == "2026-09-15" && todo.projectID == project.id)
        #expect(todo.remindMinutes == 900 && todo.isImportant && todo.isUrgent)
        #expect(TagIDList.parse(todo.tagIDs).count == 3)
        #expect(todo.notes == "#备注 内容")
        #expect(DayBoardMutations.addCapturedRoutine(text: "散步 #WORK #今日 @18:00", sortOrder: 2, context: context))
        let routine = try #require(context.fetch(FetchDescriptor<DailyRoutine>()).first)
        #expect(routine.title == "散步" && routine.remindMinutes == 1080)
        #expect(TagIDList.contains(routine.tagIDs, existing.id))
        #expect(try context.fetchCount(FetchDescriptor<TagItem>()) == 3)
    }

    @Test func titleAndNotesEditsAddTagsWithoutDiscardingExistingAssociations() throws {
        let store = try container()
        let context = store.mainContext
        let todo = TodoItem(title: "旧标题", dayKey: "2026-09-13")
        let routine = DailyRoutine(title: "习惯", sortOrder: 0)
        context.insert(todo)
        context.insert(routine)
        try context.save()
        #expect(DayBoardMutations.editTodo(todo, title: "#今日 新标题"))
        let originalIDs = TagIDList.parse(todo.tagIDs)
        #expect(todo.title == "新标题" && originalIDs.count == 1)
        #expect(DayBoardMutations.updateNotes(for: todo, notes: "正文\n#生活 !p2 @18:00"))
        #expect(todo.notes == "正文\n#生活 !p2 @18:00")
        #expect(todo.isImportant && !todo.isUrgent && todo.remindMinutes == 1080)
        #expect(Set(TagIDList.parse(todo.tagIDs)).isSuperset(of: originalIDs))
        #expect(DayBoardMutations.updateNotes(for: routine, notes: "#今日 #生活 保留正文"))
        #expect(TagIDList.parse(routine.tagIDs).count == 2)
        #expect(DayBoardMutations.updateNotes(for: todo, notes: "删除文字里的标签并不解绑"))
        #expect(TagIDList.parse(todo.tagIDs).count == 2)
    }

    @Test func diaryEditingHandlesNewTagsOnAnyLineAndKeepsLiteralText() throws {
        let store = try container()
        let repo = SwiftDataDiaryRepository(container: store)
        let entry = try repo.addDiary(text: "原始正文", dayKey: "2026-09-13", tagIDs: [])
        let text = "第一行\n#今日 #\"项目 A\" 今天很开心\n\\#原文"
        try repo.editDiary(id: entry.id, text: text)
        #expect(entry.text == text)
        let tags = try store.mainContext.fetch(FetchDescriptor<TagItem>())
        #expect(Set(tags.map(\.name)) == Set(["今日", "项目 A"]))
        #expect(TagIDList.parse(entry.tagIDs).count == 2)
        try repo.editDiary(id: entry.id, text: "继续记录 #今日")
        #expect(try store.mainContext.fetchCount(FetchDescriptor<TagItem>()) == 2)
        #expect(TagIDList.parse(entry.tagIDs).count == 2)
    }

    @Test func subtaskTagsAreIndependentReusableAndRemovable() throws {
        let store = try container()
        let repo = SwiftDataTaskRepository(container: store)
        let parent = try repo.addTodo(CreateTodoParams(title: "父任务", dayKey: "2026-09-13"))
        let child = try repo.addSubtask(to: parent.id, title: "#今日 子任务")
        try repo.editSubtask(id: child.id, title: "#今日 #生活 新标题")
        #expect(child.title == "新标题")
        #expect(parent.tagIDs.isEmpty)
        #expect(TagIDList.parse(child.tagIDs).count == 2)
        let tag = try #require(store.mainContext.fetch(FetchDescriptor<TagItem>()).first { $0.name == "今日" })
        #expect(Catalog.matchingSubtasks([parent], tag: tag).map(\.id) == [child.id])
        #expect(Catalog.openCount(
            todos: [parent], routines: [], checks: [], project: nil, tag: tag, projects: [], dayKey: "2026-09-13"
        ) == 1)
        try SwiftDataCatalogRepository(container: store).purgeTag(id: tag.id)
        #expect(!TagIDList.contains(child.tagIDs, tag.id))
        #expect(TagIDList.parse(child.tagIDs).count == 1)
    }

    @Test func failedCombinedSaveRollsBackNewAndRestoredTagsWithTheirContents() throws {
        let store = try container()
        let context = store.mainContext
        let deletedAt = Date(timeIntervalSince1970: 123)
        let old = TagItem(name: "旧标签", sortOrder: 0, deletedAt: deletedAt)
        context.insert(old)
        try context.save()
        #expect(throws: CocoaError.self) {
            try ModelChanges.transaction(in: context, save: { _ in throw CocoaError(.fileWriteNoPermission) }) {
                _ = try SwiftDataDiaryRepository(container: store).addDiary(
                    text: "#旧标签 #新标签 内容", dayKey: "2026-09-13", tagIDs: []
                )
            }
        }
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<TagItem>()) == 1)
        #expect(old.deletedAt == deletedAt)
    }

    @Test func clipboardCreatesTagsButPreservesTheCapturedText() throws {
        let store = try container()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("AreaChain-tag-test-" + UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("#今日 今天很开心\n下一行 @18:00", forType: .string)
        #expect(ClipboardCapture.ingest(container: store, pasteboard: pasteboard))
        let todo = try #require(store.mainContext.fetch(FetchDescriptor<TodoItem>()).first)
        #expect(todo.title == "#今日 今天很开心\n下一行 @18:00")
        #expect(todo.remindMinutes == nil)
        #expect(TagIDList.parse(todo.tagIDs).count == 1)
    }

    @Test func subtaskTagsRoundTripThroughExportAndImport() throws {
        let source = try container()
        let repo = SwiftDataTaskRepository(container: source)
        let parent = try repo.addTodo(CreateTodoParams(title: "父任务", dayKey: "2026-09-13"))
        let child = try repo.addSubtask(to: parent.id, title: "内容 #今日")
        let tags = try source.mainContext.fetch(FetchDescriptor<TagItem>())
        let snapshot = SyncPort.makeSnapshot(routines: [], checks: [], todos: [parent], diaries: [], tags: tags)
        let decoded = try SyncPort.decode(SyncPort.encode(snapshot))
        #expect(decoded.todos.first?.subtasks.first?.tagIDs == child.tagIDs)
        let target = try container()
        try SnapshotImporter.apply(decoded, context: target.mainContext)
        let restored = try #require(target.mainContext.fetch(FetchDescriptor<SubtaskItem>()).first)
        #expect(restored.id == child.id && restored.tagIDs == child.tagIDs)
        #expect(restored.todo?.id == parent.id)

        let legacy = Data("{\"id\":\"\(UUID().uuidString)\",\"title\":\"旧子任务\",\"isDone\":false}".utf8)
        #expect(try JSONDecoder().decode(ExportedSubtask.self, from: legacy).tagIDs.isEmpty)
    }
}
