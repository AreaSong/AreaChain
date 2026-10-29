import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// J1 服务层：diary.create／diary.body 经 prepare → accept →（确认）→ 托管封存 → 借用 → 提交；
/// 只有普通手记直接执行，受保护目标在读取正文前拒绝，正文含私密标签被拒，超长已有正文改为打开原页面，
/// 锁定后旧借用失效，哨兵正文不出现在预览、接受、Run、Facts、托管描述与追踪里。合成内存库与隔离保险箱。
@Suite(.serialized) @MainActor struct DiaryBodyCommandTests {
    static let sentinel = "M4-SENTINEL-手记哨兵-5b1e"

    static func body(_ operation: CommandFieldOperation, _ text: String) -> CommandArgument {
        .init(parameter: .body, operation: operation, value: .longText(text))
    }

    static func tags(_ ids: [UUID]) -> CommandArgument { .init(parameter: .tags, operation: .add, value: .tags(ids)) }

    static func diary(_ f: TaskSimpleFixture, _ text: String, tags: [TagItem] = []) throws -> DiaryEntry {
        try f.insert(DiaryEntry(text: text, dayKey: TaskSimpleFixture.today, tagIDs: TagIDList.encode(tags.map(\.id))))
    }

    static func confirmAndSubmit(_ f: TaskSimpleFixture, _ accepted: CommandSimpleAcceptance) throws -> CommandSimpleFacts {
        _ = try f.adapter.confirm(accepted, expecting: f.handoff.owned().lease)
        return try f.submit(accepted)
    }

    @Test func createFollowsComposerClassificationAndOffersOpeningTheNote() throws {
        let f = try TaskSimpleFixture(diary: true)
        let work = try f.insert(TagItem(name: "工作", sortOrder: 0))
        let (accepted, facts) = try f.run("diary.create", arguments: [
            Self.body(.assign, "  周会 // 讨论了排期 #新话题  "), f.day(TaskSimpleFixture.today), Self.tags([work.id])])
        #expect(facts.state == .saved && f.count("save") == 1 && f.escrow.count == 0)
        let creation = try #require(facts.creation)
        let entry = try #require(try f.stored(DiaryEntry.self).first { $0.id == creation.id })
        // 与手记页快速新增同一结果：标题行与正文拆分、#标签解析为标签（含新建）、选中的标签一并关联。
        let composer = DiaryWriteService.capture("周会 // 讨论了排期 #新话题")
        #expect(entry.text == composer.text && entry.dayKey == TaskSimpleFixture.today)
        #expect(try Set(TaskCommandSpecs.tagNames(entry.tagIDs, in: f.context)) == ["工作", "新话题"])
        #expect(accepted.preview.before.changes(to: accepted.preview.after).contains { $0.title == "#新话题" && $0.before == nil })
        #expect(f.adapter.openTarget(facts) == .init(object: creation, parent: nil, viewingTrash: false))
        // 新建身份在准备时固定：仓储拒绝同一身份第二次写入，重试不会另建。
        #expect(throws: (any Error).self) {
            try f.diaries.diaries(f.context).addDiary(text: "再来", dayKey: TaskSimpleFixture.today, tagIDs: [],
                                                      allowLockedInsert: false, creationID: creation.id)
        }
        f.context.rollback()
        #expect(try f.stored(DiaryEntry.self).count == 1)
    }

    /// 正文里解析出私密标签（活的或已删除的）、或选中要关联私密标签，都在写入前拒绝并引导到原手记页；不写、不托管。
    @Test(arguments: [0, 1, 2])
    func createRefusesPrivateTagsBeforeWriting(_ variant: Int) throws {
        let f = try TaskSimpleFixture(diary: true)
        let secret = try f.insert(TagItem(name: "私密", sortOrder: 0, isPrivateDiary: true))
        try f.insert(TagItem(name: "旧私密", sortOrder: 1, deletedAt: .now, isPrivateDiary: true))
        let arguments = [[Self.body(.assign, "带 #私密"), f.day(TaskSimpleFixture.today)],
                         [Self.body(.assign, "带 #旧私密"), f.day(TaskSimpleFixture.today)],
                         [Self.body(.assign, "普通"), f.day(TaskSimpleFixture.today), Self.tags([secret.id])]][variant]
        try f.queue("diary.create", arguments: arguments)
        #expect(throws: CommandSimpleIssue.invalidTarget(.diaryPrivateTag)) { try f.preview() }
        #expect(try f.stored(DiaryEntry.self).isEmpty && f.count("save") == 0 && f.escrow.count == 0)
    }

    @Test(arguments: [CommandFieldOperation.replace, .append])
    func bodyNeedsConfirmationAndUsesKeyedDigestBaseline(_ operation: CommandFieldOperation) throws {
        let f = try TaskSimpleFixture(diary: true)
        let entry = try Self.diary(f, "原文 #甲")
        try f.queue("diary.body", targets: [.init(type: .diary, id: entry.id)], arguments: [Self.body(operation, "新段 #乙")])
        #expect(f.adapter.needsConfirmation(.init(rawValue: "diary.body")))
        let accepted = try f.accept()
        let field = try #require(accepted.preview.before.rows.first?.fields.first { $0.id == "body" })
        #expect(field.value == f.handoff.coordinator.textDigest.hex("原文 #甲") && !field.value.contains("原文"))
        #expect(throws: CommandSimpleIssue.confirmationRequired) { try f.submit(accepted) }
        let facts = try Self.confirmAndSubmit(f, accepted)
        #expect(facts.state == .saved && f.count("save") == 1)
        #expect(entry.text == (operation == .replace ? "新段 #乙" : "原文 #甲\n新段 #乙"))
        // 种子手记的 #甲 只在文字里、未关联；改写后按 editDiary 合并新正文里的标签。
        #expect(try Set(TaskCommandSpecs.tagNames(entry.tagIDs, in: f.context)) == (operation == .replace ? ["乙"] : ["甲", "乙"]))
    }

    /// 预览后别处改了正文：带键摘要不同，执行前复核拒绝，不覆盖别人的修改。
    @Test func externalEditAfterPreviewIsAConflict() throws {
        let f = try TaskSimpleFixture(diary: true)
        let entry = try Self.diary(f, "原文")
        try f.queue("diary.body", targets: [.init(type: .diary, id: entry.id)], arguments: [Self.body(.replace, "指令改写")])
        let accepted = try f.accept()
        _ = try f.adapter.confirm(accepted, expecting: f.handoff.owned().lease)
        entry.text = "别处改过"
        try f.context.save()
        #expect(throws: CommandSimpleIssue.invalidTarget(.changed)) { try f.submit(accepted) }
        #expect(entry.text == "别处改过")
    }

    /// 加密正文（不可解的随机字节）、私密标记（哨兵明文）、挂私密标签三种受保护目标都在读取正文前拒绝：
    /// 保险箱锁定时任何读取都会抛 PrivacyError.locked，而这里得到的是 protectedDiary；哨兵不出现在错误与追踪里。
    @Test(arguments: [0, 1, 2])
    func protectedTargetsAreRefusedWithoutReadingTheirBody(_ variant: Int) throws {
        let f = try TaskSimpleFixture(diary: true)
        let entry = try Self.protectedEntry(f, variant)
        #expect(throws: PrivacyError.self) { try DiaryContent.read(entry, vault: f.vault) }
        try f.queue("diary.body", targets: [.init(type: .diary, id: entry.id)], arguments: [Self.body(.append, "x")])
        var caught: Error?
        do { _ = try f.preview() } catch { caught = error }
        #expect(caught as? CommandSimpleIssue == .invalidTarget(.protectedDiary))
        #expect(!String(reflecting: caught as Any).contains(Self.sentinel) && !f.io.trace.joined().contains(Self.sentinel))
        #expect(f.count("save") == 0 && f.escrow.count == 0)
    }

    /// 三种受保护手记：0 加密正文、1 私密标记（明文为哨兵）、2 挂私密标签（明文为哨兵）。
    static func protectedEntry(_ f: TaskSimpleFixture, _ variant: Int) throws -> DiaryEntry {
        switch variant {
        case 0:
            let entry = try diary(f, "")
            entry.encryptedText = Data((0..<48).map { UInt8($0) })
            entry.privacyVaultID = UUID()
            try f.context.save()
            return entry
        case 1:
            let entry = try diary(f, sentinel)
            entry.isPrivate = true
            try f.context.save()
            return entry
        default:
            return try diary(f, sentinel, tags: [try f.insert(TagItem(name: "私密", sortOrder: 0, isPrivateDiary: true))])
        }
    }

    @Test func privateTagInBodyIsRefused() throws {
        let f = try TaskSimpleFixture(diary: true)
        try f.insert(TagItem(name: "私密", sortOrder: 0, isPrivateDiary: true))
        let entry = try Self.diary(f, "普通正文")
        try f.queue("diary.body", targets: [.init(type: .diary, id: entry.id)], arguments: [Self.body(.append, "补 #私密")])
        #expect(throws: CommandSimpleIssue.invalidTarget(.diaryPrivateTag)) { try f.preview() }
        #expect(entry.text == "普通正文" && f.count("save") == 0)
    }

    /// 已有正文超过 64KiB 不在指令里改，改为打开原手记页。
    @Test func existingBodyOverLimitOpensTheOriginalPage() throws {
        let f = try TaskSimpleFixture(diary: true)
        let entry = try Self.diary(f, String(repeating: "长", count: CommandLongTextLimit.maxUTF8Bytes / 3 + 1))
        try f.queue("diary.body", targets: [.init(type: .diary, id: entry.id)], arguments: [Self.body(.append, "x")])
        #expect(throws: CommandSimpleIssue.invalidTarget(.diaryTooLong)) { try f.preview() }
        #expect(CommandSimpleProblem.diaryPageProblems.contains(.diaryTooLong))
        #expect(UnifiedSearchSimpleCopy.opensDiaryPage("unified.simple.problem.diaryTooLong"))
    }

    /// 封存后锁定：借用资格作废，执行报 locked、不写；还回草稿后正文逐字还原。
    @Test func lockAfterSealBlocksTheLoanAndReturnsTheDraft() throws {
        let f = try TaskSimpleFixture(diary: true)
        let entry = try Self.diary(f, "原文")
        try f.queue("diary.body", targets: [.init(type: .diary, id: entry.id)], arguments: [Self.body(.replace, "锁定前正文")])
        let accepted = try f.accept()
        _ = try f.adapter.confirm(accepted, expecting: f.handoff.owned().lease)
        try f.escrow.seal(accepted, runID: UUID(), expecting: f.handoff.owned().lease)
        f.io.center.post(name: .privacyWillLock, object: nil)
        let run = try f.execution()
        guard case .attempt(let attempt) = try f.handoff.send(.beginStep(run.stamp)) else { throw CommandExecutionError.stale }
        let operation = try #require(run.operation(accepted.preview.item.id))
        #expect(throws: CommandSimpleIssue.invalidTarget(.locked)) {
            try f.adapter.execute(.init(lease: f.handoff.owned().lease, operation: operation, attempt: attempt))
        }
        #expect(entry.text == "原文" && f.count("save") == 0)
        try f.returnToDraft()
        let draft = try #require(f.handoff.state().plan.items.first?.draft)
        #expect(draft.arguments.first?.value == .longText("锁定前正文") && f.escrow.count == 0)
    }

    @Test(arguments: ["diary.create", "diary.body"])
    func sentinelStaysInsideDraftEscrowAndLoan(_ command: String) throws {
        let f = try TaskSimpleFixture(diary: true)
        let entry = try Self.diary(f, "原文")
        if command == "diary.create" {
            try f.queue(command, arguments: [Self.body(.assign, Self.sentinel), f.day(TaskSimpleFixture.today)])
        } else {
            try f.queue(command, targets: [.init(type: .diary, id: entry.id)], arguments: [Self.body(.append, Self.sentinel)])
        }
        #expect(LongTextLoanExportTests.surfaces([try f.handoff.state()]).contains(Self.sentinel), "正对照：封存前在宿主草稿里")
        let accepted = try f.accept()
        if command == "diary.body" { _ = try f.adapter.confirm(accepted, expecting: f.handoff.owned().lease) }
        let facts = try f.submit(accepted)
        #expect(facts.state == .saved)
        #expect(!(try LongTextLoanExportTests.exported(f, accepted, facts)).contains(Self.sentinel))
        #expect(try f.stored(DiaryEntry.self).contains { $0.text.contains(Self.sentinel) }, "正对照：落库正文里有")
    }
}

extension TaskSimpleFixture {
    func enabled(_ value: Bool) -> CommandArgument { .init(parameter: .enabled, operation: .assign, value: .boolean(value)) }
}
