import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 骨架按目录状态拒绝未决／不可用指令；tag.color 与原标签页一致跳过预置标签；新建身份只分配一次。
@Suite(.serialized) @MainActor struct SimpleCommandSkeletonTests {
    /// 只为检验骨架准入：规格本身合法，拒绝只能来自目录状态。
    struct CatalogProbe: SimpleCommandSpec {
        let command: CommandID
        let shape = CommandSimpleShape.fixed(.tag)
        let copy = CommandSimpleCopy(preview: "", saved: "")
        func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState { .init() }
        func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                    in context: ModelContext) throws -> CommandSimpleState { .init() }
        func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {}
    }

    @Test func unresolvedOrUnavailableCatalogEntriesAreNeverAssembled() throws {
        let f = try SimpleCommandFixture()
        // tag.merge 涉及私密标签整条拒绝（用户决定），不是未决项。
        #expect(CommandCatalog.standard.command(id: .init(rawValue: "tag.merge"))?.availability == .declared)
        for (id, availability) in [("tag.cleanup", "unresolved"), ("tag.unlinkGlobal", "unavailable")] {
            let descriptor = try #require(CommandCatalog.standard.command(id: .init(rawValue: id)))
            #expect(descriptor.category == .modification && descriptor.interactions.isEmpty)
            #expect(String(describing: descriptor.availability).hasPrefix(availability))
            let adapter = SimpleCommandAdapter(coordinator: f.handoff.coordinator, environment: f.environment,
                                               specs: [CatalogProbe(command: .init(rawValue: id))], capability: .open)
            #expect(!adapter.supports(.init(rawValue: id)))
            #expect(throws: CommandSimpleIssue.unassembled) { try adapter.spec(.init(rawValue: id)) }
        }
        // 已声明、可入普通队列的标签指令照常装配。
        #expect(f.adapter.supports(.init(rawValue: "tag.color")) && f.adapter.supports(.init(rawValue: "tag.order")))
    }

    /// 与原标签页一致：预置标签静默跳过，预览与回执都列出被跳过的标签；全是预置时与仓储一样拒绝。
    @Test func tagColorSkipsPresetTagsAndListsThem() throws {
        let presetName = "工作 · Work"
        let f = try SimpleCommandFixture(isPreset: { $0.name == presetName })
        let targets = [f.target(f.tags[0]), f.target(f.tags[1])]
        try f.queue("tag.color", targets: targets, arguments: [f.color(.amber)])
        let preview = try f.preview()
        #expect(preview.after.rows.map(\.key) == [f.tags[1].id.uuidString])
        #expect(preview.after.notices == [.init(key: "unified.simple.tag.color.skipped", title: presetName)])
        let facts = try f.submit(f.adapter.accept(preview, expecting: f.handoff.owned().lease))
        #expect(facts.state == .saved && facts.after.notices == preview.after.notices)
        #expect(f.tags[0].colorToken == TagColorToken.default.rawValue && f.tags[1].colorToken == "amber" && f.count("save") == 1)
        let all = try SimpleCommandFixture(isPreset: { _ in true })
        try all.queue("tag.color", targets: [all.target(all.tags[0])], arguments: [all.color(.amber)])
        #expect(throws: CommandSimpleIssue.invalidTarget(.protected)) { try all.preview() }
        #expect(all.count("save") == 0)
    }

    /// 新建型规格：身份在准备时分配一次，接受、提交与写后核对都用它；未知结果锁住整条指令直到核对。
    struct CreateProbe: SimpleCommandCallSpec {
        let command = CommandID(rawValue: "routine.create")
        let shape = CommandSimpleShape.none
        let copy = CommandSimpleCopy(preview: "", saved: "")
        var creates: CommandObjectType? { .routine }

        func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
            let id = try #require(call.creation).id
            let rows = try context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.id == id }))
            return .init(rows: rows.map { .init(key: $0.id.uuidString, record: nil, title: $0.title,
                                                fields: [.init(id: "title", value: $0.title, display: .verbatim($0.title))]) })
        }

        func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
            let id = try #require(call.creation).id
            return .init(rows: [.init(key: id.uuidString, record: nil, title: "探针", fields: [.init(id: "title", value: "探针", display: .verbatim("探针"))])])
        }

        func apply(_ call: CommandSimpleCall, in context: ModelContext) throws {
            _ = try SwiftDataRoutineRepository(context: context).addRoutine(.init(title: "探针", createdDayKey: "2026-10-19",
                                                                                  creationID: call.creation?.id))
        }
    }

    @Test(arguments: [TaskCreateCommandIO.SaveMode.normal, .throwAfter])
    func creationIdentityIsReservedOnceAndLockedWhileUnknown(mode: TaskCreateCommandIO.SaveMode) throws {
        let f = try SimpleCommandFixture()
        let adapter = SimpleCommandAdapter(coordinator: f.handoff.coordinator, environment: f.environment,
                                           specs: [CreateProbe()], capability: .open)
        f.saveMode = mode
        let weekdays = CommandArgument(parameter: .weekdays, operation: .assign, value: .weekdays(WeekdayMask.all))
        try f.queue("routine.create", arguments: [.init(parameter: .title, operation: .assign, value: .shortText("探针")), weekdays])
        let preview = try adapter.prepare(plan: f.handoff.state().plan.stamp, expecting: f.handoff.owned().lease)
        let creation = try #require(preview.creation)
        #expect(creation.type == .routine && preview.lockKeys.contains("create:routine.create"))
        let accepted = try adapter.accept(preview, expecting: f.handoff.owned().lease)
        let facts = try adapter.submit(accepted: accepted, expecting: f.handoff.owned().lease)
        #expect(facts.creation == creation)
        let stored = try ModelContext(f.io.container).fetch(FetchDescriptor<DailyRoutine>())
        #expect(stored.map(\.id) == [creation.id])
        if mode == .throwAfter {
            #expect(facts.state == .unknown)
            #expect(throws: CommandSimpleIssue.verificationRequired) {
                try f.handoff.coordinator.simples.requireResolved(["create:routine.create"])
            }
            let run = try #require(f.handoff.state().execution)
            let operation = try #require(run.snapshot.items.first.flatMap { run.operation($0.id) })
            #expect(try adapter.verifyUnknown(operation, expecting: f.handoff.owned().lease).outcome == .applied)
        } else {
            #expect(facts.state == .saved)
        }
    }
}
