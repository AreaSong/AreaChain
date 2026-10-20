import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct TagSimpleCommandTests {
    @Test func createPreviewWritesNothingThenSavesOnce() throws {
        let f = try SimpleCommandFixture()
        try f.queue("tag.create", arguments: [f.name("  新标签 · New  ")])
        let preview = try f.preview()
        #expect(preview.before.rows.isEmpty && preview.after.rows.map(\.title) == ["新标签 · New"] && !preview.noChange)
        #expect(try f.live().count == 3 && f.count("save") == 0 && !f.context.hasChanges)
        let accepted = try f.adapter.accept(preview, expecting: f.handoff.owned().lease)
        #expect(try f.adapter.accept(preview, expecting: f.handoff.owned().lease) == accepted)
        let facts = try f.submit(accepted)
        #expect(facts.state == .saved && facts.save == .returned && facts.publication == .returned)
        #expect(f.count("save") == 1 && f.count("ui") == 1 && f.count("fact") == 1 && f.refreshes.count == 1)
        let created = try #require(try f.stored().first { $0.name == "新标签 · New" })
        // 与原界面新建一致：排在活标签最后、默认颜色、不是私密标签。
        #expect(created.sortOrder == 3 && created.colorToken == TagColorToken.default.rawValue && !created.isPrivateDiary)
        let unit = try #require(f.handoff.state().execution?.units.first)
        #expect(unit.simple == facts && unit.local == .committed)
        #expect(throws: (any Error).self) { try f.submit(accepted) }
        #expect(f.count("save") == 1)
    }

    @Test func createFollowsRepositoryNameRules() throws {
        // 空白名先被单行短文本的静态校验拒绝；重名按仓储的规范化名字比较。
        for (raw, issue) in [("   ", CommandSimpleIssue.invalidArguments), ("家庭 · Home", .invalidTarget(.nameTaken))] {
            let f = try SimpleCommandFixture()
            try f.queue("tag.create", arguments: [f.name(raw)])
            #expect(throws: issue) { try f.preview() }
            #expect(try f.live().count == 3 && f.count("save") == 0)
        }
        // 已删除标签的名字不算重名，沿用仓储只比较活标签。
        let f = try SimpleCommandFixture()
        let (_, facts) = try f.run("tag.create", arguments: [f.name("已删 · Gone")])
        #expect(try f.live().contains { $0.name == "已删 · Gone" } && facts.state == .saved)
    }

    @Test func renameChangesOnlyNameAndSameNameIsNoChange() throws {
        let f = try SimpleCommandFixture()
        let other = (f.tags[1].name, f.tags[1].colorToken, f.tags[1].sortOrder)
        let (_, facts) = try f.run("tag.rename", targets: [f.target(f.tags[0])], arguments: [f.name("新名 · Renamed")])
        #expect(facts.state == .saved && f.tags[0].name == "新名 · Renamed" && f.tags[0].sortOrder == 0)
        #expect((f.tags[1].name, f.tags[1].colorToken, f.tags[1].sortOrder) == other && f.count("save") == 1)
        #expect(facts.before.changes(to: facts.after).map(\.field) == ["name"])

        let same = try SimpleCommandFixture()
        let (_, unchanged) = try same.run("tag.rename", targets: [same.target(same.tags[1])], arguments: [same.name("家庭 · Home")])
        #expect(unchanged.state == .noChange && unchanged.save == .notCalled && same.count("save") == 0 && same.count("ui") == 0)
        #expect(try same.handoff.state().execution?.units.first?.receipt?.result == .noChange)
    }

    /// 原界面改名私密标签不需要解锁、保护按 UUID 关联；指令保持一致，私密标记不变。
    @Test func renameKeepsPrivateFlagAndRejectsTakenOrDeleted() throws {
        let f = try SimpleCommandFixture()
        let (_, facts) = try f.run("tag.rename", targets: [f.target(f.tags[2])], arguments: [f.name("日记 · Diary")])
        #expect(facts.state == .saved && f.tags[2].name == "日记 · Diary" && f.tags[2].isPrivateDiary)
        let taken = try SimpleCommandFixture()
        try taken.queue("tag.rename", targets: [taken.target(taken.tags[0])], arguments: [taken.name("家庭 · Home")])
        #expect(throws: CommandSimpleIssue.invalidTarget(.nameTaken)) { try taken.preview() }
        let gone = try SimpleCommandFixture()
        try gone.queue("tag.rename", targets: [gone.target(gone.deleted)], arguments: [gone.name("Back")])
        #expect(throws: CommandSimpleIssue.invalidTarget(.deleted)) { try gone.preview() }
        #expect(taken.count("save") + gone.count("save") == 0)
    }

    @Test func colorChangesFixedSetInOneSave() throws {
        let f = try SimpleCommandFixture()
        let targets = [f.target(f.tags[0]), f.target(f.tags[2])]
        let (_, facts) = try f.run("tag.color", targets: targets, arguments: [f.color(.amber)])
        #expect(facts.state == .saved && f.count("save") == 1 && f.count("ui") == 1)
        #expect(f.tags[0].colorToken == "amber" && f.tags[2].colorToken == "amber" && f.tags[1].colorToken == "ink")
        #expect(facts.after.rows.map(\.key) == targets.map(\.id.uuidString))
        let mixed = try SimpleCommandFixture()
        try mixed.queue("tag.color", targets: [mixed.target(mixed.tags[0]), mixed.target(mixed.deleted)], arguments: [mixed.color(.ink)])
        #expect(throws: CommandSimpleIssue.invalidTarget(.deleted)) { try mixed.preview() }
        #expect(mixed.tags[0].colorToken == TagColorToken.default.rawValue && mixed.count("save") == 0)
    }

    /// 合并批 M-1 D：用 position 表达新位置（同三个任务排序指令），越界与非整数拒绝；墓碑不参与排序。
    @Test func orderMovesOneTagToTypedPosition() throws {
        let f = try SimpleCommandFixture()
        let before = try f.live()
        let (_, facts) = try f.run("tag.order", targets: [f.target(before[2])], arguments: [Self.position(1)])
        #expect(facts.state == .saved && f.count("save") == 1)
        #expect(try f.live().map(\.id) == [before[2], before[0], before[1]].map(\.id) && f.deleted.sortOrder == 3)
        for (raw, issue) in [(0.0, CommandSimpleIssue.invalidTarget(.outOfRange)), (9, .invalidTarget(.outOfRange)),
                             (1.5, .invalidArguments)] {
            let g = try SimpleCommandFixture()
            try g.queue("tag.order", targets: [g.target(g.tags[0])], arguments: [Self.position(raw)])
            #expect(throws: issue) { try g.preview() }
            #expect(g.count("save") == 0)
        }
        let unchanged = try SimpleCommandFixture()
        let first = try unchanged.live()[0]
        let (accepted, _) = try unchanged.run("tag.order", targets: [unchanged.target(first)], arguments: [Self.position(1)])
        #expect(accepted.preview.noChange && unchanged.count("save") == 0)
    }

    static func position(_ value: Double) -> CommandArgument {
        .init(parameter: .position, operation: .assign, value: .number(value))
    }

    @Test func targetChangedAfterAcceptanceIsNotSubmitted() throws {
        let f = try SimpleCommandFixture()
        try f.queue("tag.rename", targets: [f.target(f.tags[0])], arguments: [f.name("新名 · Renamed")])
        let accepted = try f.accept()
        f.tags[0].colorToken = "slate"
        f.tags[0].name = "外部改名 · External"
        try f.context.save()
        #expect(throws: CommandSimpleIssue.invalidTarget(.changed)) { try f.submit(accepted) }
        #expect(f.count("save") == 0 && f.count("ui") == 0 && f.tags[0].name == "外部改名 · External")
        #expect(try f.handoff.state().execution == nil)
    }

    @Test func failureBeforeTransactionKeepsInputAndDoesNotSave() throws {
        let f = try SimpleCommandFixture()
        try f.queue("tag.rename", targets: [f.target(f.tags[0])], arguments: [f.name("新名 · Renamed")])
        let accepted = try f.accept()
        f.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        #expect(throws: (any Error).self) { try f.submit(accepted) }
        let facts = try #require(f.handoff.state().execution?.units.first?.simple)
        #expect(facts.state == .notSubmitted && !facts.conflict && f.count("save") == 0 && f.count("ui") == 0)
        #expect(f.tags[0].name == "工作 · Work" && facts.input == accepted.preview.input)
    }

    /// 实际写入与预览不一致：保存前核对失败，整体回滚，不发布。
    @Test func driftBetweenWriteAndPreviewRollsBack() throws {
        let f = try SimpleCommandFixture()
        f.repository = { DriftingCatalogRepository(context: $0) }
        let (_, facts) = try f.run("tag.rename", targets: [f.target(f.tags[0])], arguments: [f.name("新名 · Renamed")])
        #expect(facts.state == .notSubmitted && facts.save == .notCalled && f.count("save") == 0 && f.count("ui") == 0)
        #expect(try f.stored().contains { $0.name == "工作 · Work" } && f.tags[0].name == "工作 · Work")
        #expect(f.refreshes.isEmpty)
    }

    @Test(arguments: [TaskCreateCommandIO.SaveMode.throwBefore, .throwAfter])
    func unknownSaveIsNotRetriedAndVerifiesCurrentState(mode: TaskCreateCommandIO.SaveMode) throws {
        let f = try SimpleCommandFixture()
        f.saveMode = mode
        let (accepted, facts) = try f.run("tag.rename", targets: [f.target(f.tags[0])], arguments: [f.name("新名 · Renamed")])
        #expect(facts.state == .unknown && facts.save == .called && f.count("save") == 1 && f.count("ui") == 0)
        #expect(throws: (any Error).self) { try f.submit(accepted) }
        #expect(throws: CommandSimpleIssue.verificationRequired) {
            try f.handoff.coordinator.simples.requireResolved(accepted.preview.lockKeys)
        }
        let run = try #require(f.handoff.state().execution)
        let operation = try #require(run.snapshot.items.first.flatMap { run.operation($0.id) })
        let verification = try f.adapter.verifyUnknown(operation, expecting: f.handoff.owned().lease)
        #expect(verification.outcome == (mode == .throwAfter ? .applied : .notApplied))
        #expect(try f.stored().contains { $0.name == "新名 · Renamed" } == (mode == .throwAfter))
        // 确定结果才解除阻止；原 unknown 回执不提升，也没有再次保存。
        #expect((try? f.handoff.coordinator.simples.requireResolved(accepted.preview.lockKeys)) != nil)
        #expect(try f.handoff.state().execution?.units.first?.local == .unknown && f.count("save") == 1)
    }

    @Test func closedByDefaultAndOnlyOrdinaryCommandsWithoutConfirmation() throws {
        let closed = try SimpleCommandFixture(capability: .closed)
        #expect(!closed.adapter.supports(.init(rawValue: "tag.create")))
        try closed.queue("tag.create", arguments: [closed.name("X")])
        #expect(throws: CommandSimpleIssue.unassembled) { try closed.preview() }
        let unassembled = SimpleCommandAdapter(coordinator: closed.handoff.coordinator)
        #expect(!unassembled.supports(.init(rawValue: "tag.create")))
        // 需要独立确认的指令即使提供了规格也不能借骨架绕过确认。
        struct TrashLike: SimpleCommandSpec {
            let command = CommandID(rawValue: "tag.trash")
            let shape = CommandSimpleShape.single(.tag)
            let copy = CommandSimpleCopy(preview: "", saved: "")
            func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState { .init() }
            func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                        in context: ModelContext) throws -> CommandSimpleState { .init() }
            func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {}
        }
        let f = try SimpleCommandFixture()
        let guarded = SimpleCommandAdapter(coordinator: f.handoff.coordinator, environment: f.environment,
                                           specs: [TrashLike()], capability: .open)
        #expect(!guarded.supports(.init(rawValue: "tag.trash")))
        // 多项计划没有简单指令的家族：整体拒绝，不挑子集执行。
        let multi = MultiPlanCommandAdapter(coordinator: f.handoff.coordinator, adapters: .init())
        #expect(throws: CommandMultiPlanIssue.unassembled) { try multi.family(for: .init(rawValue: "tag.create")) }
    }
}
