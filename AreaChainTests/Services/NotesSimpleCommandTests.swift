import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 检查点 A：备注保存的共享入口与抽取前算法逐字等价；todo.notes／routine.notes 经骨架执行同一入口。
@Suite(.serialized) @MainActor struct NotesSimpleCommandTests {
    /// 两份相同的合成库：固定 UUID 的标签、另一待办上的公开图片，便于新旧实现分别运行后逐项比较。
    @MainActor final class Scenario {
        static let workID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        static let oldID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
        static let todoID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
        static let routineID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
        let fixture: TaskCaptureFixture
        let root: URL
        var requests: [Int?] = []
        var context: ModelContext { fixture.context }
        var attachments: TaskNotesService.Attachments { .init(store: AttachmentStore(root: root), root: root) }

        init() throws {
            fixture = try TaskCaptureFixture()
            root = FileManager.default.temporaryDirectory.appending(path: "areachain-tm6-notes-\(UUID().uuidString)",
                                                                    directoryHint: .isDirectory)
            let context = fixture.context
            context.insert(TagItem(id: Self.workID, name: "工作", sortOrder: 0))
            context.insert(TagItem(id: Self.oldID, name: "旧", sortOrder: 1, deletedAt: Date(timeIntervalSince1970: 5)))
            context.insert(TodoItem(id: Self.todoID, title: "备注对象", dayKey: "2026-10-19", tagIDs: Self.workID.uuidString,
                                    notes: "原备注"))
            context.insert(DailyRoutine(id: Self.routineID, title: "习惯对象", sortOrder: 0, createdDayKey: "2026-10-01"))
            let other = TodoItem(title: "图片所有者", dayKey: "2026-10-19")
            context.insert(other)
            context.insert(AttachmentItem(ownerKind: AttachmentOwner.todo.rawValue, ownerID: other.id, filename: "图.png"))
            try context.save()
        }

        deinit { try? FileManager.default.removeItem(at: root) }

        func todo() throws -> TodoItem { try TaskCommandSpecs.todo(Self.todoID, in: context) }
        func routine() throws -> DailyRoutine { try TaskCommandSpecs.routine(Self.routineID, in: context) }

        /// 比较用的规范快照：新标签 UUID 不同，按名字比较。
        func snapshot() throws -> [String] {
            let reader = ModelContext(fixture.container)
            let tags = try reader.fetch(FetchDescriptor<TagItem>())
            let name = { (id: UUID) in tags.first { $0.id == id }?.name ?? "?" }
            let todo = try #require(try reader.fetch(FetchDescriptor<TodoItem>()).first { $0.id == Self.todoID })
            let routine = try #require(try reader.fetch(FetchDescriptor<DailyRoutine>()).first)
            let links = try reader.fetch(FetchDescriptor<AttachmentItem>()).filter { $0.ownerID == Self.todoID || $0.ownerID == Self.routineID }
            return [todo.notes, TagIDList.parse(todo.tagIDs).map(name).joined(separator: ","), "\(String(describing: todo.remindMinutes))",
                    "\(todo.isImportant)\(todo.isUrgent)", routine.notes, TagIDList.parse(routine.tagIDs).map(name).joined(separator: ","),
                    "\(String(describing: routine.remindMinutes))", "\(routine.isImportant)\(routine.isUrgent)"]
                + tags.map { "\($0.name)|\($0.sortOrder)|\($0.deletedAt == nil)" }.sorted()
                + links.map { "\($0.ownerID == Self.todoID ? "todo" : "routine")|\($0.filename)|\($0.storageID != nil)" }.sorted()
                + ["requests:\(requests)"]
        }
    }

    nonisolated static let inputs = ["正文 #工作 #旧 #新标签 !p1 @18:00 @图.png", "", "只有文字", "#新标签 #NEW标签 !p3"]

    @Test(arguments: inputs)
    func sharedEntryMatchesPreExtractionAlgorithm(_ notes: String) throws {
        let legacy = try Scenario()
        let shared = try Scenario()
        #expect(TaskTM6LegacyRules.saveNotes(notes, for: try legacy.todo(), context: legacy.context,
                                             boundary: legacy.fixture.boundary, attachments: legacy.attachments) { legacy.requests.append($0) })
        #expect(TaskTM6LegacyRules.saveNotes(notes, for: try legacy.routine(), context: legacy.context,
                                             boundary: legacy.fixture.boundary, attachments: legacy.attachments) { legacy.requests.append($0) })
        for owner in [true, false] {
            var remind: Int?
            let saved = ModelChanges.perform(in: shared.context, boundary: shared.fixture.boundary) {
                remind = owner
                    ? try TaskNotesService.apply(notes, to: shared.todo(), repository: SwiftDataTaskRepository(context: shared.context),
                                                 in: shared.context, attachments: shared.attachments)
                    : try TaskNotesService.apply(notes, to: shared.routine(), repository: SwiftDataRoutineRepository(context: shared.context),
                                                 in: shared.context, attachments: shared.attachments)
            }
            #expect(saved)
            shared.requests.append(remind)
        }
        #expect(try shared.snapshot() == legacy.snapshot())
        #expect(shared.fixture.trace == legacy.fixture.trace)
    }

    /// 原界面入口仍走原上下文与原授权回调；共享入口的 save 与逐字副本结果相同。
    @Test func uiSaveKeepsSignatureAndSemantics() throws {
        let legacy = try Scenario()
        let shared = try Scenario()
        let text = "界面保存 #工作 #新标签 !p2"
        #expect(TaskTM6LegacyRules.saveNotes(text, for: try legacy.todo(), context: legacy.context,
                                             boundary: .init(), attachments: legacy.attachments) { legacy.requests.append($0) })
        #expect(TaskNotesService.save(text, for: try shared.todo(), in: shared.context,
                                      repository: SwiftDataTaskRepository(context: shared.context)) { shared.requests.append($0) })
        #expect(try shared.snapshot() == legacy.snapshot())
        let ui = try Scenario()
        #expect(DayBoardMutations.saveNotes(text, for: try ui.todo()))
        #expect(try Array(ui.snapshot().dropLast()) == Array(legacy.snapshot().dropLast()))
    }

    /// 长文守卫保持：即使把备注规格装进骨架，准备也被 blocksUnprotectedExport 拒绝，不写库、不发布。
    @Test func longTextGuardStillBlocksExecution() throws {
        let f = try TaskSimpleFixture()
        let todo = try f.insert(TodoItem(title: "守卫", dayKey: TaskSimpleFixture.today, notes: "原备注"))
        let guarded = SimpleCommandAdapter(coordinator: f.handoff.coordinator, environment: f.environment,
                                           specs: TaskCommandSpecs.pendingLongText(f.dependencies), capability: .open)
        try f.queue("todo.notes", targets: [.init(type: .todo, id: todo.id)], arguments: [f.notes(.replace, "新备注")])
        #expect(throws: CommandSimpleIssue.invalidArguments) {
            try guarded.prepare(plan: f.handoff.state().plan.stamp, expecting: f.handoff.owned().lease)
        }
        #expect(throws: CommandPlanError.protectedContent) {
            try f.handoff.send(.sealPlan(f.handoff.state().plan.stamp, runID: UUID()))
        }
        #expect(!f.adapter.supports(.init(rawValue: "todo.notes")) && !f.adapter.supports(.init(rawValue: "routine.capture")))
        #expect(todo.notes == "原备注" && f.count("save") == 0 && f.count("ui") == 0)
    }

    @Test func specPreviewListsDerivedChangesAndSavesLikeTheDetailPanel() throws {
        let f = try TaskSimpleFixture()
        let work = try f.insert(TagItem(name: "工作", sortOrder: 0))
        let old = try f.insert(TagItem(name: "旧", sortOrder: 1, deletedAt: Date(timeIntervalSince1970: 5)))
        let todo = try f.insert(TodoItem(title: "写周报", dayKey: TaskSimpleFixture.today, tagIDs: work.id.uuidString, notes: "原备注"))
        let owner = try f.insert(TodoItem(title: "图片所有者", dayKey: TaskSimpleFixture.today))
        try f.insert(AttachmentItem(ownerKind: AttachmentOwner.todo.rawValue, ownerID: owner.id, filename: "图.png"))
        let text = "新备注 #旧 #新标签 !p1 @18:00 @图.png"
        let call = CommandSimpleCall(input: f.input([.init(type: .todo, id: todo.id)], [f.notes(.replace, text)]))
        let spec = try f.pending("todo.notes")
        let (before, after) = try f.preview(spec, call)
        let changes = before.changes(to: after)
        #expect(Set(changes.map(\.field)) == ["notes", "tags", "remind", "priority", "tagState", "attachment"])
        #expect(changes.contains { $0.title == "#旧" && $0.before == .localized("unified.simple.tagState.deleted") })
        #expect(changes.contains { $0.title == "#新标签" && $0.before == nil })
        #expect(changes.contains { $0.title == "@图.png" && $0.before == nil })
        #expect(f.count("save") == 0 && !f.context.hasChanges && old.deletedAt != nil && todo.notes == "原备注")
        // 基线只存摘要：没有原备注明文，描述也不含内容。
        let baseline = try #require(before.rows.first { $0.key == todo.id.uuidString }?.fields.first { $0.id == "notes" })
        #expect(baseline.value != "原备注" && baseline.value.count == 64 && !String(describing: before).contains("原备注"))
        let result = try f.runSpec(spec, call)
        #expect(result.after == after && result.followUp && f.authorizations == [1080] && f.count("save") == 1)
        // 与详情页同一入口：在另一份相同的库里直接调 TaskNotesService，结果逐项一致。
        let stored = try #require(try f.stored(TodoItem.self).first { $0.id == todo.id })
        let tags = try f.stored(TagItem.self)
        #expect(stored.notes == text && stored.remindMinutes == 1080 && stored.isImportant && stored.isUrgent)
        #expect(TagIDList.parse(stored.tagIDs).compactMap { id in tags.first { $0.id == id }?.name } == ["工作", "旧", "新标签"])
        #expect(tags.allSatisfy { $0.deletedAt == nil })
        #expect(try f.stored(AttachmentItem.self).contains { $0.ownerID == todo.id && $0.filename == "图.png" })
    }

    @Test func appendClearAndUnchangedFollowTheSameFinalText() throws {
        let f = try TaskSimpleFixture()
        let todo = try f.insert(TodoItem(title: "追加", dayKey: TaskSimpleFixture.today, notes: "第一行"))
        let append = try f.runSpec(f.pending("todo.notes"),
                                   .init(input: f.input([.init(type: .todo, id: todo.id)], [f.notes(.append, "第二行 !p2")])))
        #expect(todo.notes == "第一行\n第二行 !p2" && todo.isImportant && !todo.isUrgent && !append.followUp)
        let routine = try f.insert(DailyRoutine(title: "清空", sortOrder: 0, createdDayKey: "2026-10-01", notes: "旧备注"))
        _ = try f.runSpec(f.pending("routine.notes"), .init(input: f.input([.init(type: .routine, id: routine.id)], [f.notes(.clear)])))
        #expect(routine.notes.isEmpty && f.authorizations.isEmpty)
        let same = try f.insert(TodoItem(title: "不变", dayKey: TaskSimpleFixture.today, notes: "保持"))
        let (before, after) = try f.preview(f.pending("todo.notes"),
                                            .init(input: f.input([.init(type: .todo, id: same.id)], [f.notes(.replace, "保持")])))
        #expect(before == after)
    }

    @Test func multipleTargetsListEachAndRollBackTogether() throws {
        let f = try TaskSimpleFixture()
        let first = try f.insert(TodoItem(title: "第一", dayKey: TaskSimpleFixture.today))
        let second = try f.insert(TodoItem(title: "第二", dayKey: TaskSimpleFixture.today))
        let call = CommandSimpleCall(input: f.input([.init(type: .todo, id: first.id), .init(type: .todo, id: second.id)],
                                                    [f.notes(.replace, "共同 #共享新标签")]))
        let (_, after) = try f.preview(f.pending("todo.notes"), call)
        // 每个目标各自一行；两个目标引用同一个新标签只建一次。
        #expect(after.rows.filter { [first.id.uuidString, second.id.uuidString].contains($0.key) }.count == 2)
        #expect(after.rows.filter { $0.key.hasPrefix("tag:") }.count == 1)
        // 同一个失败仓储贯穿两次写入：第二个目标写入后抛错。
        let failing = TaskTM6FailureRepository(f.context, failOn: 2)
        f.tasks = { _ in failing }
        #expect(throws: (any Error).self) { try f.runSpec(f.pending("todo.notes"), call) }
        #expect(failing.calls == 2)
        #expect(first.notes.isEmpty && second.notes.isEmpty && f.count("save") == 0 && f.authorizations.isEmpty)
        #expect(try f.stored(TagItem.self).isEmpty)
        f.tasks = { SwiftDataTaskRepository(context: $0) }
        _ = try f.runSpec(f.pending("todo.notes"), call)
        let tags = try f.stored(TagItem.self)
        #expect(first.notes == "共同 #共享新标签" && second.notes == first.notes && tags.count == 1)
    }

    @Test func protectedSourceDeletedTargetAndOversizeAreRejected() throws {
        let f = try TaskSimpleFixture()
        let todo = try f.insert(TodoItem(title: "受保护", dayKey: TaskSimpleFixture.today))
        let deleted = try f.insert(TodoItem(title: "已删", dayKey: TaskSimpleFixture.today, deletedAt: .now))
        let full = try f.insert(TodoItem(title: "长", dayKey: TaskSimpleFixture.today,
                                         notes: String(repeating: "a", count: CommandLongTextLimit.maxUTF8Bytes)))
        f.protected = [todo.id]
        let spec = try f.pending("todo.notes")
        let call = { (id: UUID, op: CommandFieldOperation) in
            CommandSimpleCall(input: f.input([.init(type: .todo, id: id)], [f.notes(op, "b")]))
        }
        #expect(throws: CommandSimpleIssue.invalidTarget(.protectedSource)) { try f.preview(spec, call(todo.id, .replace)) }
        #expect(throws: CommandSimpleIssue.invalidTarget(.deleted)) { try f.preview(spec, call(deleted.id, .replace)) }
        #expect(throws: CommandSimpleIssue.invalidTarget(.tooLong)) { try f.preview(spec, call(full.id, .append)) }
        #expect(f.count("save") == 0)
    }
}
