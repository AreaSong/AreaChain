import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct DiaryPageListModelTests {
    @Test func emptyQueryListsLiveRowsAndProjectsPrivacyOnce() throws {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let work = TagItem(name: "工作", sortOrder: 0)
        let secret = TagItem(name: "密码", sortOrder: 1)
        context.insert(work)
        context.insert(secret)
        let older = DiaryEntry(text: "周报草稿", dayKey: "2026-09-10", createdAt: Date(timeIntervalSince1970: 1), tagIDs: work.id.uuidString)
        let pinned = DiaryEntry(text: "置顶备忘", dayKey: "2026-09-11", createdAt: Date(timeIntervalSince1970: 2), tagIDs: work.id.uuidString)
        pinned.isPinned = true
        let privateNote = DiaryEntry(text: "口令 #密码", dayKey: "2026-09-12", createdAt: Date(timeIntervalSince1970: 3))
        let removed = DiaryEntry(text: "已删", dayKey: "2026-09-09", createdAt: Date(timeIntervalSince1970: 0), tagIDs: work.id.uuidString)
        removed.deletedAt = .now
        for entry in [older, pinned, privateNote, removed] {
            context.insert(entry)
        }
        try context.save()

        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        let tags = [work, secret]
        let empty = DiaryPageListModel.make(
            entries: [older, pinned, privateNote, removed],
            activeTags: tags,
            allTags: tags,
            searchQuery: "",
            selectedTagID: nil,
            vault: vault
        )
        #expect(empty.liveEntries.map(\.id) == [older.id, pinned.id, privateNote.id])
        #expect(empty.rows.map(\.id) == [pinned.id, privateNote.id, older.id])
        #expect(empty.tagCounts[work.id] == 2)
        #expect(empty.isSensitive(privateNote.id))
        #expect(!empty.isSensitive(older.id))

        let keyword = DiaryPageListModel.make(
            entries: [older, pinned, privateNote, removed],
            activeTags: tags,
            allTags: tags,
            searchQuery: "周报",
            selectedTagID: nil,
            vault: vault
        )
        #expect(keyword.rows.map(\.id) == [older.id])
        #expect(keyword.tagCounts[work.id] == 2)

        let tagged = DiaryPageListModel.make(
            entries: [older, pinned, privateNote, removed],
            activeTags: tags,
            allTags: tags,
            searchQuery: "",
            selectedTagID: work.id,
            vault: vault
        )
        #expect(Set(tagged.rows.map(\.id)) == [older.id, pinned.id])

        let omitted = DiaryPageListModel.make(
            entries: [older, pinned, privateNote, removed],
            activeTags: tags,
            allTags: tags,
            searchQuery: "!p2",
            selectedTagID: nil,
            vault: vault
        )
        #expect(omitted.rows.isEmpty)
        #expect(omitted.liveEntries.count == 3)
    }

    @Test func emptyQueryListsLockedPrivateNotesWithoutMatchingCiphertext() async throws {
        let fixture = try await PrivacyFixture.make()
        defer { fixture.cleanup() }
        let tag = try fixture.tag()
        let secret = "LOCKED_LIST_SENTINEL_9D"
        let note = try fixture.repository.addDiary(text: secret, dayKey: "2026-09-15", tagIDs: [tag.id])
        fixture.vault.lock()

        let listed = DiaryPageListModel.make(
            entries: [note],
            activeTags: [tag],
            allTags: [tag],
            searchQuery: "",
            selectedTagID: nil,
            vault: fixture.vault
        )
        #expect(listed.rows.map(\.id) == [note.id])
        #expect(listed.isSensitive(note.id))
        #expect(throws: PrivacyError.locked) { try DiaryContent.read(note, vault: fixture.vault) }

        let keyword = DiaryPageListModel.make(
            entries: [note],
            activeTags: [tag],
            allTags: [tag],
            searchQuery: secret,
            selectedTagID: nil,
            vault: fixture.vault
        )
        #expect(keyword.rows.isEmpty)
    }
}
