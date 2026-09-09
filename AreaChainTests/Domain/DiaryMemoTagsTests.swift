import Foundation
import Testing
@testable import AreaChain

struct DiaryMemoTagsTests {
    @Test func presetsArePasswordIdeaAndJournal() {
        #expect(DiaryMemoTags.presets == ["密码", "小巧思", "日记"])
    }

    @Test func autoTagDetectsPasswordIdeaAndJournalKeywords() {
        #expect(DiaryMemoTags.autoTagNames(in: "wifi 密码 pwd") == ["密码"])
        #expect(DiaryMemoTags.autoTagNames(in: "一个小巧思 idea") == ["小巧思"])
        #expect(DiaryMemoTags.autoTagNames(in: "今日日记 journal") == ["日记"])
        #expect(
            DiaryMemoTags.autoTagNames(in: "灵感：保险箱 password 写进日记") == ["密码", "小巧思", "日记"]
        )
        #expect(DiaryMemoTags.autoTagNames(in: "买菜") == [])
    }

    @Test func passwordNameMatchesExplicitAndEnglish() {
        #expect(DiaryMemoTags.isPasswordName("密码"))
        #expect(DiaryMemoTags.isPasswordName("MyPassword"))
        #expect(!DiaryMemoTags.isPasswordName("小巧思"))
    }

    @Test func orderedPutsPresetsFirst() {
        struct Tag {
            var name: String
        }
        let tags = [Tag(name: "工作"), Tag(name: "日记"), Tag(name: "密码")]
        let ordered = DiaryMemoTags.ordered(tags, name: { $0.name }, isActive: { _ in true })
        #expect(ordered.map(\.name) == ["密码", "日记", "工作"])
    }
}
