import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 手记写入共享入口的抽出等价。旧实现逐字复制自抽出前的原界面代码（DiaryQuickComposerView.submitNote、
/// DayBoardMutations.diaryTodoTitle／diaryTodoNotes、DiarySummaryRow.contentPresentation），用同一批样例对照；
/// 另证明保护判定只看记录字段与标签关联，不读取、不解密受保护正文。
@Suite(.serialized) @MainActor struct DiaryWriteServiceTests {
    /// 隔离保险箱（未配置即锁定）与临时附件目录；仓储只经它们写入。
    static func repository(_ f: TaskSimpleFixture, _ vault: PrivacyVault) -> SwiftDataDiaryRepository {
        SwiftDataDiaryRepository(context: f.context, vault: vault, attachmentStore: AttachmentStore(root: f.root), attachmentRoot: f.root)
    }

    static let samples = [
        "标题 // 正文第一行\n第二行 #日记", "  只有正文 #工作  ", "\\#不是标签 也不是 \\// 分隔", "首行\n第二行\n第三行",
        "\n\n只有后文", "a", "#日记", "标题 //", "// 只有正文", "多个 #甲 #乙 标签 // 体 #丙", "  \n  ", "emoji 🧪 // 第二段",
    ]

    // MARK: - 抽出前的旧实现（只作对照，不被生产代码调用）

    static func legacyCapture(_ rawText: String) -> (String, [String]) {
        let parsed = NaturalLanguageParser.parseDiaryCapture(rawText)
        let textToSave: String = {
            if parsed.hasNoteSeparator && !parsed.cleanTitle.isEmpty {
                return parsed.cleanTitle + (parsed.body.isEmpty ? "" : "\n" + parsed.body)
            } else if !parsed.body.isEmpty {
                return parsed.body
            } else {
                return NaturalLanguageParser.unescapeSyntax(rawText)
            }
        }()
        return (textToSave, parsed.tagNames)
    }

    static func legacyTodo(_ stored: String) -> (String, String)? {
        let raw = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let title: String = {
            guard let newlineIndex = raw.firstIndex(of: "\n") else { return raw }
            let firstLine = String(raw[..<newlineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rest = String(raw[raw.index(after: newlineIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return firstLine.isEmpty ? rest : firstLine
        }()
        let notes: String = {
            guard let newlineIndex = raw.firstIndex(of: "\n") else { return "" }
            return String(raw[raw.index(after: newlineIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        return (title, notes)
    }

    static func legacyPresentation(_ text: String) -> (String, String?) {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let newlineIndex = raw.firstIndex(of: "\n") else { return (raw, nil) }
        let firstLine = String(raw[..<newlineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let rest = String(raw[raw.index(after: newlineIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if firstLine.isEmpty { return (rest, nil) }
        return (firstLine, rest.isEmpty ? nil : rest)
    }

    @Test(arguments: samples)
    func sharedRulesMatchTheLegacyInlineCode(_ sample: String) {
        let trimmed = sample.trimmingCharacters(in: .whitespacesAndNewlines)
        let capture = DiaryWriteService.capture(trimmed)
        let legacy = Self.legacyCapture(trimmed)
        #expect(capture.text == legacy.0 && capture.tagNames == legacy.1)
        let todo = DiaryWriteService.todoText(from: sample)
        #expect(todo?.title == Self.legacyTodo(sample)?.0 && todo?.notes == Self.legacyTodo(sample)?.1)
        let split = DiaryCopyContent.split(sample)
        #expect(split.mainText == Self.legacyPresentation(sample).0 && split.note == Self.legacyPresentation(sample).1)
        #expect(DiaryCopyContent.text(.record, from: sample) == sample)
        #expect(DiaryCopyContent.text(.title, from: sample) == split.mainText)
        #expect(DiaryCopyContent.text(.notes, from: sample) == split.note)
    }

    /// 原界面入口仍经共享入口写入：菜单栏／今日页的“记一条”与快速新增（允许锁定时插入）、手记卡片转任务。
    @Test func originalEntryPointsStillWriteThroughTheSharedEntry() throws {
        let f = try TaskSimpleFixture()
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        DayBoardMutations.diaryRepositoryProvider = { [f] _ in Self.repository(f, vault) }
        DayBoardMutations.taskRepositoryProvider = { [f] in SwiftDataTaskRepository(context: $0 ?? f.context) }
        defer {
            DayBoardMutations.diaryRepositoryProvider = nil
            DayBoardMutations.taskRepositoryProvider = nil
        }
        let capture = DiaryWriteService.capture("会议 // 记录 #工作")
        let ids = Set(try InputTagResolver.resolve(capture.tagNames, in: f.context))
        #expect(DayBoardMutations.addDiary(text: capture.text, dayKey: TaskSimpleFixture.today, selectedTagIDs: ids, context: f.context))
        let entry = try #require(try f.context.fetch(FetchDescriptor<DiaryEntry>()).first)
        #expect(try entry.text == "会议\n记录" && TaskCommandSpecs.tagNames(entry.tagIDs, in: f.context) == ["工作"])
        #expect(DayBoardMutations.convertDiaryToTodo(entry, context: f.context))
        let todo = try #require(try f.stored(TodoItem.self).first)
        #expect(try todo.title == "会议" && todo.notes == "记录" && todo.tagIDs.isEmpty && f.stored(DiaryEntry.self).count == 1)
        // 敏感手记与标签读取失败照旧拒绝。
        let secret = try f.insert(DiaryEntry(text: "秘密\n内容", dayKey: TaskSimpleFixture.today))
        secret.isPrivate = true
        #expect(!DayBoardMutations.convertDiaryToTodo(secret, tags: [], context: f.context))
        #expect(!DayBoardMutations.convertDiaryToTodo(entry, tags: nil, context: f.context))
        #expect(try f.stored(TodoItem.self).count == 1)
    }

    /// 受保护的三种来源（加密正文、私密标记、挂私密标签）判为非普通且不读正文：保险箱锁定时任何读取都会抛 locked，
    /// 而判定照常返回；加密正文是不可解的随机字节，私密标记的明文是哨兵，都不会出现在判定结果里。
    @Test func protectionRuleNeverReadsProtectedBodies() throws {
        let f = try TaskSimpleFixture()
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        let privateTag = try f.insert(TagItem(name: "私密", sortOrder: 0, isPrivateDiary: true))
        let encrypted = try f.insert(DiaryEntry(text: "", dayKey: TaskSimpleFixture.today))
        encrypted.encryptedText = Data((0..<48).map { UInt8($0) })
        encrypted.privacyVaultID = UUID()
        let marked = try f.insert(DiaryEntry(text: "M4-SENTINEL 私密标记正文", dayKey: TaskSimpleFixture.today))
        marked.isPrivate = true
        let tagged = try f.insert(DiaryEntry(text: "挂私密标签", dayKey: TaskSimpleFixture.today, tagIDs: privateTag.id.uuidString))
        let plain = try f.insert(DiaryEntry(text: "普通", dayKey: TaskSimpleFixture.today))
        try f.context.save()
        let tags = try f.context.fetch(FetchDescriptor<TagItem>())
        #expect(!vault.isUnlocked)
        for entry in [encrypted, marked] {
            #expect(throws: PrivacyError.locked) { try DiaryContent.read(entry, vault: vault) }
            #expect(!DiaryWriteService.isOrdinary(entry, tags: tags))
        }
        #expect(!DiaryWriteService.isOrdinary(tagged, tags: tags) && DiaryWriteService.isOrdinary(plain, tags: tags))
        #expect(DiaryWriteService.becomesProtected(text: "x #私密", tagIDs: [], tags: tags))
        #expect(DiaryWriteService.becomesProtected(text: "x", tagIDs: [privateTag.id], tags: tags))
        #expect(!DiaryWriteService.becomesProtected(text: "x #普通", tagIDs: [], tags: tags))
        // 已删除的私密标签同样算（与仓储 protectionTags 同口径）。
        privateTag.deletedAt = .now
        #expect(DiaryWriteService.becomesProtected(text: "x #私密", tagIDs: [], tags: tags))
    }
}
