import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 检查点 D：快速新增重复事项的共享入口与抽取前算法逐字等价；routine.capture 规格沿同一入口，
/// 但 body 是 longText，执行受导出守卫拒绝（受控借用另批），这里直接运行规格。
@Suite(.serialized) @MainActor struct RoutineCaptureCommandTests {
    nonisolated static let inputs = ["散步 #WORK #今日 @18:00", "  读书 !p1 #新标签\n备注第二行  ", "#只有标签", "   ", "看图 @图.png"]

    private func seed(_ fixture: TaskCaptureFixture) throws {
        fixture.context.insert(TagItem(id: NotesSimpleCommandTests.Scenario.workID, name: "Work", sortOrder: 0))
        fixture.context.insert(TagItem(name: "今日", sortOrder: 1, deletedAt: Date(timeIntervalSince1970: 3)))
        fixture.context.insert(DailyRoutine(title: "已有", sortOrder: 4, createdDayKey: "2026-10-01"))
        let owner = TodoItem(title: "图片所有者", dayKey: "2026-10-19")
        fixture.context.insert(owner)
        fixture.context.insert(AttachmentItem(ownerKind: AttachmentOwner.todo.rawValue, ownerID: owner.id, filename: "图.png"))
        try fixture.context.save()
    }

    private func snapshot(_ fixture: TaskCaptureFixture) throws -> [String] {
        let reader = ModelContext(fixture.container)
        let tags = try reader.fetch(FetchDescriptor<TagItem>())
        let name = { (id: UUID) in tags.first { $0.id == id }?.name ?? "?" }
        let routines = try reader.fetch(FetchDescriptor<DailyRoutine>()).filter { $0.title != "已有" }
        let links = try reader.fetch(FetchDescriptor<AttachmentItem>()).filter { link in routines.contains { $0.id == link.ownerID } }
        return routines.map { routine in
            [routine.title, "\(routine.sortOrder)", "\(String(describing: routine.remindMinutes))", "\(routine.isImportant)\(routine.isUrgent)",
             routine.notes, TagIDList.parse(routine.tagIDs).map(name).joined(separator: ","), routine.createdDayKey,
             "\(routine.isEnabled)\(String(describing: routine.weekdayMask))"].joined(separator: "|")
        } + tags.map { "\($0.name)|\($0.sortOrder)|\($0.deletedAt == nil)" }.sorted() + links.map(\.filename)
    }

    @Test(arguments: inputs)
    func sharedEntryMatchesPreExtractionAlgorithm(_ text: String) throws {
        let legacy = try TaskCaptureFixture()
        let shared = try TaskCaptureFixture()
        try seed(legacy)
        try seed(shared)
        let root = FileManager.default.temporaryDirectory.appending(path: "areachain-tm6-capture-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let attachments = TaskNotesService.Attachments(store: AttachmentStore(root: root), root: root)
        var legacyRequests: [Int?] = []
        var sharedRequests: [Int?] = []
        let legacySaved = TaskTM6LegacyRules.addCapturedRoutine(text: text, sortOrder: 5, context: legacy.context,
            boundary: legacy.boundary, createdDayKey: "2026-10-19", attachments: attachments) { legacyRequests.append($0) }
        var remind: Int?
        let sharedSaved = RoutineCaptureService.trimmed(text) != nil && ModelChanges.perform(in: shared.context, boundary: shared.boundary) {
            remind = try RoutineCaptureService.apply(.init(text: text, sortOrder: 5, createdDayKey: "2026-10-19"),
                                                     repository: SwiftDataRoutineRepository(context: shared.context),
                                                     in: shared.context, attachments: attachments).1
        }
        if sharedSaved { sharedRequests.append(remind) }
        #expect(sharedSaved == legacySaved && sharedRequests == legacyRequests)
        #expect(try snapshot(shared) == snapshot(legacy) && shared.trace == legacy.trace)
    }

    /// 原面板入口保留签名，经共享入口新建；与逐字副本相同。
    @Test func panelEntryKeepsSignature() throws {
        let legacy = try TaskCaptureFixture()
        let ui = try TaskCaptureFixture()
        try seed(legacy)
        try seed(ui)
        let attachments = TaskNotesService.Attachments()
        #expect(TaskTM6LegacyRules.addCapturedRoutine(text: "面板新增 #Work !p2", sortOrder: 9, context: legacy.context,
                                                      boundary: .init(), createdDayKey: DayKey.today(), attachments: attachments) { _ in })
        DayBoardMutations.routineRepositoryProvider = { _ in SwiftDataRoutineRepository(context: ui.context) }
        defer { DayBoardMutations.routineRepositoryProvider = nil }
        #expect(DayBoardMutations.addCapturedRoutine(text: "面板新增 #Work !p2", sortOrder: 9, context: ui.context))
        #expect(!DayBoardMutations.addCapturedRoutine(text: "   ", sortOrder: 9, context: ui.context))
        #expect(try snapshot(ui) == snapshot(legacy))
    }

    @Test func specPreviewListsParseResultsAndCreatesOnceWithReservedIdentity() throws {
        let f = try TaskSimpleFixture()
        let work = try f.insert(TagItem(name: "Work", sortOrder: 0))
        try f.insert(DailyRoutine(title: "已有", sortOrder: 7, createdDayKey: "2026-10-01", deletedAt: .now))
        let creation = CommandObjectReference(type: .routine, id: UUID())
        let call = CommandSimpleCall(input: f.input([], [f.body("晨读 !p1 @07:30 #work #新标签")]), creation: creation)
        let spec = try f.pending("routine.capture")
        #expect(spec.creates == .routine)
        let (before, after) = try f.preview(spec, call)
        let changes = before.changes(to: after)
        let routine = try #require(after.rows.first { $0.key == creation.id.uuidString })
        #expect(routine.title == "晨读" && routine.fields.map(\.id) == ["title", "remind", "priority", "tags", "notes", "order"])
        #expect(routine.fields.first { $0.id == "tags" }?.display == .verbatim("#Work #新标签"))
        #expect(routine.fields.first { $0.id == "order" }?.value == "8")
        #expect(changes.contains { $0.title == "#新标签" && $0.before == nil } && !changes.contains { $0.title == "#Work" })
        let existing = try f.stored(DailyRoutine.self)
        #expect(f.count("save") == 0 && existing.count == 1)
        let result = try f.runSpec(spec, call)
        #expect(result.followUp && f.authorizations == [450] && f.count("save") == 1)
        let created = try #require(try f.stored(DailyRoutine.self).first { $0.id == creation.id })
        #expect(created.sortOrder == 8 && created.isImportant && created.isUrgent && created.remindMinutes == 450)
        #expect(created.createdDayKey == TaskSimpleFixture.today && TagIDList.parse(created.tagIDs).first == work.id)
        // 同一身份再新建会被仓储拒绝，不会另建第二个。
        #expect(throws: (any Error).self) { try f.runSpec(spec, call) }
        #expect(try f.stored(DailyRoutine.self).filter { $0.id == creation.id }.count == 1)
    }

    @Test func emptyOrTokenlessTextIsRejectedAndLongTextGuardHolds() throws {
        let f = try TaskSimpleFixture()
        let spec = try f.pending("routine.capture")
        let creation = CommandObjectReference(type: .routine, id: UUID())
        #expect(throws: CommandSimpleIssue.invalidTarget(.untitled)) {
            try f.preview(spec, .init(input: f.input([], [f.body("   ")]), creation: creation))
        }
        #expect(throws: CommandSimpleIssue.invalidArguments) { try f.preview(spec, .init(input: f.input([], [f.body("没有身份")]))) }
        let guarded = SimpleCommandAdapter(coordinator: f.handoff.coordinator, environment: f.environment,
                                           specs: TaskCommandSpecs.pendingLongText(f.dependencies), capability: .open)
        try f.queue("routine.capture", arguments: [f.body("散步")])
        #expect(throws: CommandSimpleIssue.invalidArguments) {
            try guarded.prepare(plan: f.handoff.state().plan.stamp, expecting: f.handoff.owned().lease)
        }
        let stored = try f.stored(DailyRoutine.self)
        #expect(f.count("save") == 0 && stored.isEmpty)
    }
}
