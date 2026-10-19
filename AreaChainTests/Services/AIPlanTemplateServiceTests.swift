import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct AIPlanTemplateServiceTests {
    private static var retained: [ModelContainer] = []

    @Test func templateKitIncludesPublicTagsAndExcludesPrivateOrDeletedTags() throws {
        let publicWork = TagItem(name: "工作", sortOrder: 0)
        let publicSport = TagItem(name: "运动", sortOrder: 1)
        let privateTag = TagItem(name: "机密账本", sortOrder: 2)
        privateTag.isPrivateDiary = true
        let deletedTag = TagItem(name: "旧标签", sortOrder: 3, deletedAt: .now)
        let presetTag = TagItem(name: DiaryMemoTags.password, sortOrder: 4)

        let names = AIPlanTemplateService.publicTagNames(
            from: [publicWork, publicSport, privateTag, deletedTag, presetTag]
        )
        #expect(names == ["工作", "运动"])

        let entries = AIPlanTemplateService.templateEntries(publicTagNames: names, todayKey: "2026-10-11")
        let paths = entries.map { $0.path }
        #expect(paths.contains("areachain-ai-kit/README.md"))
        #expect(paths.contains("areachain-ai-kit/SKILL.md"))
        #expect(paths.contains("areachain-ai-kit/templates/plan-template.md"))
        #expect(paths.contains("areachain-ai-kit/templates/plan-template.json"))

        let skill = try #require(entries.first(where: { $0.path.hasSuffix("SKILL.md") }))
        #expect(skill.content.contains("#工作"))
        #expect(skill.content.contains("#运动"))
        #expect(!skill.content.contains("机密账本"))
        #expect(!skill.content.contains("旧标签"))
        #expect(skill.content.contains("新标签默认创建"))

        let zipData = AIPlanTemplateService.makeTemplateZipData(publicTagNames: names, todayKey: "2026-10-11")
        // 验证标准 ZIP Local File Header 签名 0x04034b50 ("PK\x03\x04")
        #expect(zipData.count > 256)
        #expect(zipData.prefix(4) == Data([0x50, 0x4b, 0x03, 0x04]))
    }

    @Test func exportedMarkdownAndJSONTemplatesCanBeImportedEndToEnd() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let existingWork = TagItem(name: "工作", sortOrder: 0)
        context.insert(existingWork)
        try context.save()

        let entries = AIPlanTemplateService.templateEntries(publicTagNames: ["工作"], todayKey: "2026-10-11")
        let mdEntry = try #require(entries.first(where: { $0.path.hasSuffix("plan-template.md") }))
        let jsonEntry = try #require(entries.first(where: { $0.path.hasSuffix("plan-template.json") }))

        // 1. 导入 Markdown 示例模板
        let mdSnapshot = try AIPlanTemplateService.decodeSnapshot(
            from: Data(mdEntry.content.utf8),
            fileExtension: "md",
            context: context,
            defaultDayKey: "2026-10-11"
        )
        try SnapshotImporter.validate(mdSnapshot, context: context)
        try SnapshotImporter.apply(mdSnapshot, context: context)

        let todosAfterMD = try context.fetch(FetchDescriptor<TodoItem>())
        let routinesAfterMD = try context.fetch(FetchDescriptor<DailyRoutine>())
        let diariesAfterMD = try context.fetch(FetchDescriptor<DiaryEntry>())
        let tagsAfterMD = try context.fetch(FetchDescriptor<TagItem>())

        #expect(todosAfterMD.count == 3)
        #expect(routinesAfterMD.count == 2)
        #expect(diariesAfterMD.count == 1)
        // 原有「工作」标签被复用，新标签（「测试」「成长」「运动」「小巧思」）被自动创建
        let tagNames = Set(tagsAfterMD.map(\.name))
        #expect(tagNames.contains("工作"))
        #expect(tagNames.contains("测试"))
        #expect(tagNames.contains("成长"))
        #expect(tagNames.contains("运动"))
        #expect(tagsAfterMD.filter { $0.name == "工作" }.count == 1)

        // 2. 导入轻量 JSON 示例模板
        let jsonSnapshot = try AIPlanTemplateService.decodeSnapshot(
            from: Data(jsonEntry.content.utf8),
            fileExtension: "json",
            context: context,
            defaultDayKey: "2026-10-11"
        )
        try SnapshotImporter.validate(jsonSnapshot, context: context)
        try SnapshotImporter.apply(jsonSnapshot, context: context)

        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == 5)
        #expect(try context.fetchCount(FetchDescriptor<DailyRoutine>()) == 4)
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 2)
    }

    @Test func privateDiaryInsertAndPlanImportKeepPrivateTagAndLockContentWithoutPromptingPassword() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let privateIdeaTag = TagItem(name: DiaryMemoTags.idea, sortOrder: 0)
        privateIdeaTag.isPrivateDiary = true
        let privatePasswordTag = TagItem(name: DiaryMemoTags.password, sortOrder: 1)
        privatePasswordTag.isPrivateDiary = true
        context.insert(privateIdeaTag)
        context.insert(privatePasswordTag)
        try context.save()

        let entries = AIPlanTemplateService.templateEntries(publicTagNames: [], todayKey: "2026-10-11")
        let mdEntry = try #require(entries.first(where: { $0.path.hasSuffix("plan-template.md") }))
        let snapshot = try AIPlanTemplateService.decodeSnapshot(
            from: Data(mdEntry.content.utf8),
            fileExtension: "md",
            context: context,
            defaultDayKey: "2026-10-11"
        )
        // 验证「小巧思」被设为私密手记标签时：免密直接导入成功、保留 #小巧思 标签，并自动标记为受保护私密手记
        try SnapshotImporter.validate(snapshot, context: context)
        try SnapshotImporter.apply(snapshot, context: context)
        let importedDiaries = try context.fetch(FetchDescriptor<DiaryEntry>())
        #expect(importedDiaries.count == 1)
        let imported = try #require(importedDiaries.first)
        #expect(TagIDList.contains(imported.tagIDs, privateIdeaTag.id))
        #expect(imported.hasProtectedContent)
        #expect(imported.isPrivate)

        // 验证手动输入带私密标签的手记：锁死状态下免密直接写入成功，查看时必须先解锁
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        try await vault.create(password: "test-drop-box-pass", systemUnlock: false)
        vault.lock()
        let repo = SwiftDataDiaryRepository(context: context, vault: vault)
        let manual = try repo.addDiary(
            text: "免密投递的私密手记 #小巧思",
            dayKey: "2026-10-11",
            tagIDs: [],
            allowLockedInsert: true
        )
        #expect(manual.hasProtectedContent)
        #expect(TagIDList.contains(manual.tagIDs, privateIdeaTag.id))
        #expect(throws: PrivacyError.locked) {
            try DiaryContent.read(manual, vault: vault)
        }
        try await vault.unlockWithPassword("test-drop-box-pass")
        #expect(try DiaryContent.read(manual, vault: vault) == "免密投递的私密手记 #小巧思")
        DiaryContent.sealPendingIfNeeded(manual, vault: vault)
        #expect(manual.encryptedText != nil && manual.text.isEmpty)
        #expect(try DiaryContent.read(manual, vault: vault) == "免密投递的私密手记 #小巧思")
    }

    private func makeContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retained.append(container)
        return container
    }
}
