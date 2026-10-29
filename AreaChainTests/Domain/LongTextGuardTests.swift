import Foundation
import Testing
@testable import AreaChain

/// 长文守卫按目录声明的 longText 参数判定；clear 不带正文也必须经过托管才可放行。
@Suite(.serialized) @MainActor struct LongTextGuardTests {
    private static func draft(_ command: String, _ argument: CommandArgument?, type: CommandObjectType = .todo,
                              protection: CommandProtectionRequirement = .ordinary) -> CommandDraft {
        .init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: command),
              targets: .init(.single, objects: [.init(type: type, id: UUID())]),
              arguments: argument.map { [$0] } ?? [], protectionRequirement: protection)
    }

    private static func notes(_ operation: CommandFieldOperation, _ text: String? = nil) -> CommandArgument {
        .init(parameter: .notes, operation: operation, value: text.map { .longText($0) })
    }

    /// 用协调者的带键摘要给备注正文做印记（托管句柄新分配）。
    private static func mark(_ f: HandoffFixture, _ text: String, _ operation: CommandFieldOperation,
                             parameter: CommandParameterID = .notes) -> CommandLongTextImprint {
        f.coordinator.textDigest.imprint(text, parameter: parameter, operation: operation, escrow: UUID())
    }

    /// 复现旧守卫的漏洞：未托管的 clear 草稿不带正文，旧守卫按值判定时不命中，可以直接封存。
    @Test(arguments: [("todo.notes", CommandObjectType.todo), ("routine.notes", .routine)])
    func unescrowedClearIsRejectedAtSeal(_ command: String, _ type: CommandObjectType) throws {
        let f = try HandoffFixture()
        let draft = Self.draft(command, Self.notes(.clear), type: type)
        #expect(draft.check().staticallyValid)
        #expect(draft.blocksUnprotectedExport)
        try f.queue(draft)
        let item = try #require(f.state().plan.items.first)
        #expect(CommandPlanValidation.check([item]).items.first?.arguments == [.protectedContent])
        #expect(item.resolving() == nil)
        #expect(throws: CommandPlanError.protectedContent) { try f.seal() }
        #expect(try f.state().execution == nil && f.state().plan.items.count == 1)
    }

    /// 带正文、空值或未指定操作的 longText 参数都要托管；其余参数照旧按值判定。
    @Test func everyDeclaredLongTextArgumentNeedsEscrow() {
        for argument in [Self.notes(.replace, "正文"), Self.notes(.append, "追加"), Self.notes(.unspecified)] {
            #expect(Self.draft("todo.notes", argument).blocksUnprotectedExport)
        }
        let body = CommandArgument(parameter: .body, operation: .replace, value: .longText("快速新增"))
        #expect(Self.draft("routine.capture", body).blocksUnprotectedExport)
        // routine.create 的可选备注同样按目录类型判定；不带备注参数的草稿不受影响。
        #expect(Self.draft("routine.create", Self.notes(.clear)).blocksUnprotectedExport)
        let title = CommandArgument(parameter: .title, operation: .assign, value: .shortText("标题"))
        #expect(!Self.draft("todo.title", title).blocksUnprotectedExport)
        #expect(!Self.draft("routine.create", title).blocksUnprotectedExport)
        // 值是长文、参数却不是 longText 的草稿也照旧拦下。
        let misplaced = CommandArgument(parameter: .title, operation: .assign, value: .longText("错位"))
        #expect(Self.draft("todo.title", misplaced).blocksUnprotectedExport)
    }

    /// 受保护、required、unknown 仍然被拦，不论参数是否为长文。
    @Test func protectedRequiredAndUnknownStayBlocked() throws {
        for protection in [CommandProtectionRequirement.required, .unknown] {
            #expect(Self.draft("todo.notes", Self.notes(.clear), protection: protection).blocksUnprotectedExport)
            let title = CommandArgument(parameter: .title, operation: .assign, value: .shortText("标题"))
            #expect(Self.draft("todo.title", title, protection: protection).blocksUnprotectedExport)
        }
        var protected = Self.draft("todo.notes", Self.notes(.replace, "正文"))
        protected.acceptProtection(.init(payloadID: UUID(), revision: UUID()))
        #expect(protected.blocksUnprotectedExport && protected.arguments.isEmpty)
    }

    /// 印记只能由协调者封存核对放入：带对的印记封存后 Snapshot 只剩印记；摘要不符报 stale；计划里原有印记不能封存。
    @Test func onlyCoordinatorSealPlacesImprints() throws {
        let f = try HandoffFixture()
        let draft = Self.draft("todo.notes", Self.notes(.replace, "哨兵正文"))
        let itemID = try f.queue(draft)
        let plan = try f.state().plan.stamp
        let planDraft = try #require(f.state().plan.items.first?.draft.stamp)
        let wrong = Self.mark(f, "别的正文", .replace)
        #expect(throws: CommandPlanError.stale) {
            try f.coordinator.sealLongText(plan, runID: UUID(), imprints: [itemID: [wrong]], expecting: f.owned().lease)
        }
        #expect(throws: CommandPlanError.protectedContent) {
            try f.coordinator.sealLongText(plan, runID: UUID(), imprints: [:], expecting: f.owned().lease)
        }
        #expect(try f.state().execution == nil)
        let imprint = Self.mark(f, "哨兵正文", .replace)
        try f.coordinator.sealLongText(plan, runID: UUID(), imprints: [itemID: [imprint]], expecting: f.owned().lease)
        let run = try #require(f.state().execution)
        let sealed = try #require(run.snapshot.items.first?.draft)
        #expect(sealed.arguments.first?.value == .longTextImprint(imprint) && !sealed.blocksUnprotectedExport)
        #expect(sealed.stamp == planDraft)
        #expect(sealed.check().staticallyValid && run.snapshot.items.first?.resolving() != nil)
        #expect(!String(describing: run).contains("哨兵") && !String(describing: imprint).contains("哨兵"))
        // 计划里已有印记（不是经托管来的）：普通封存与托管封存都拒绝。
        let g = try HandoffFixture()
        try g.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.notes"),
                          targets: .init(.single, objects: [.init(type: .todo, id: UUID())]),
                          arguments: [.init(parameter: .notes, operation: .replace, value: .longTextImprint(imprint))]))
        #expect(throws: CommandPlanError.protectedContent) { try g.seal() }
        // 编辑入口不接受印记。
        var edited = Self.draft("todo.notes", Self.notes(.replace, "原文"))
        edited.edit(.init(parameter: .notes, operation: .replace, value: .longTextImprint(imprint)), expecting: edited.stamp)
        #expect(edited.arguments.first?.value == .longText("原文") && edited.version == 0)
    }

    /// clear 经托管后以空文印记封存；印记不能挪到别的参数或操作上。
    @Test func clearSealsAsEmptyImprintAndImprintShapeIsChecked() throws {
        let f = try HandoffFixture()
        let itemID = try f.queue(Self.draft("routine.notes", Self.notes(.clear), type: .routine))
        let clear = Self.mark(f, "", .clear)
        try f.coordinator.sealLongText(f.state().plan.stamp, runID: UUID(), imprints: [itemID: [clear]],
                                       expecting: f.owned().lease)
        let sealed = try #require(f.state().execution?.snapshot.items.first?.draft)
        #expect(sealed.longTextImprints == [clear] && clear.byteCount == 0 && sealed.check().staticallyValid)
        let replace = Self.mark(f, "x", .replace)
        let misplaced = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.notes"),
                                     targets: .init(.single, objects: [.init(type: .todo, id: UUID())]),
                                     arguments: [.init(parameter: .notes, operation: .append, value: .longTextImprint(replace))])
        #expect(misplaced.blocksUnprotectedExport && !misplaced.check().staticallyValid)
        let onTitle = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.title"),
                                   targets: .init(.single, objects: [.init(type: .todo, id: UUID())]),
                                   arguments: [.init(parameter: .title, operation: .assign, value: .longTextImprint(replace))])
        #expect(onTitle.blocksUnprotectedExport)
    }
}
