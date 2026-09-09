import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct DiaryMutationsTests {
    private func makeContainer() throws -> ModelContext {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func addDiaryAppliesSelectedHashAndAutoTags() throws {
        let context = try makeContainer()
        let idea = TagItem(name: "小巧思", sortOrder: 0)
        context.insert(idea)

        DayBoardMutations.addDiary(
            text: "一个灵感：家里 wifi 密码 #工作",
            dayKey: "2026-09-09",
            selectedTagIDs: [idea.id],
            tags: [idea],
            context: context
        )

        let diaries = try context.fetch(FetchDescriptor<DiaryEntry>())
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        let entry = try #require(diaries.first)
        let work = try #require(tags.first { $0.name == "工作" })
        let password = try #require(tags.first { $0.name == "密码" })
        #expect(TagIDList.contains(entry.tagIDs, idea.id))
        #expect(TagIDList.contains(entry.tagIDs, work.id))
        #expect(TagIDList.contains(entry.tagIDs, password.id))
    }

    @Test func ensurePresetTagsCreatesPasswordIdeaAndJournal() throws {
        let context = try makeContainer()
        DayBoardMutations.ensureDiaryPresetTags(among: [], context: context)
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        #expect(Set(tags.map(\.name)) == Set(DiaryMemoTags.presets))
    }

    @Test func toggleDiaryTagAddsAndRemoves() throws {
        let context = try makeContainer()
        let tag = TagItem(name: "日记", sortOrder: 0)
        let entry = DiaryEntry(text: "今天", dayKey: "2026-09-09")
        context.insert(tag)
        context.insert(entry)

        DayBoardMutations.toggleDiaryTag(entry, tagID: tag.id)
        #expect(TagIDList.contains(entry.tagIDs, tag.id))
        DayBoardMutations.toggleDiaryTag(entry, tagID: tag.id)
        #expect(!TagIDList.contains(entry.tagIDs, tag.id))
    }
}
