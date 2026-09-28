import Foundation
import SwiftData

/// 手记页一次 body 求值内复用的列表、标签计数和隐私投影。
/// 失效条件：entries / activeTags / allTags / searchQuery / selectedTagID / vault 可读内容变化。
/// 不是跨 body 的可变缓存；键盘事件会另建一份，不与 body 共享。
@MainActor
struct DiaryPageListModel {
    struct Row: Identifiable {
        var id: UUID { entry.id }
        let entry: DiaryEntry
        let isSensitive: Bool
    }

    let liveEntries: [DiaryEntry]
    let rows: [Row]
    let tagCounts: [UUID: Int]

    var filteredEntries: [DiaryEntry] { rows.map(\.entry) }

    private let rowsByID: [UUID: Row]

    func entry(_ id: UUID) -> DiaryEntry? { rowsByID[id]?.entry }
    func isSensitive(_ id: UUID) -> Bool { rowsByID[id]?.isSensitive ?? false }

    static func make(
        entries: [DiaryEntry],
        activeTags: [TagItem],
        allTags: [TagItem],
        searchQuery: String,
        selectedTagID: UUID?,
        vault: PrivacyVault
    ) -> DiaryPageListModel {
        let liveEntries = entries.filter { $0.deletedAt == nil }
        var tagCounts: [UUID: Int] = [:]
        for entry in liveEntries {
            for tagID in TagIDList.parse(entry.tagIDs) {
                tagCounts[tagID, default: 0] += 1
            }
        }

        let tagged: [DiaryEntry]
        if let selectedTagID {
            tagged = liveEntries.filter { TagIDList.contains($0.tagIDs, selectedTagID) }
        } else {
            tagged = liveEntries
        }

        let query = BoardSearch.parseQuery(searchQuery)
        let tagMap = Dictionary(uniqueKeysWithValues: activeTags.map { ($0.id, $0.name) })
        // 空查询与搜索 `hits` 不同，仍列出全部入围项；此时用模型 snapshot 即可，不读保险箱。
        // `!优先级` / `@时刻` 对手记整组退出，也不解密正文。
        let snapshots: [DiarySnapshot]
        if query.isEmpty {
            snapshots = tagged.map(\.snapshot)
        } else if BoardSearch.omitsDiaries(query) {
            snapshots = []
        } else {
            snapshots = tagged.map { DiaryContent.snapshot($0, vault: vault) }
        }
        let matchedIDs = BoardSearch.listedDiaries(snapshots, query: query, tagMap: tagMap).map(\.id)
        let taggedByID = Dictionary(uniqueKeysWithValues: tagged.map { ($0.id, $0) })
        let matched = matchedIDs.compactMap { taggedByID[$0] }.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.createdAt > rhs.createdAt
        }

        let rows = matched.map { entry in
            Row(entry: entry, isSensitive: DiaryPrivacy.isSensitive(entry.snapshot, tags: allTags))
        }
        let rowsByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        return DiaryPageListModel(
            liveEntries: liveEntries,
            rows: rows,
            tagCounts: tagCounts,
            rowsByID: rowsByID
        )
    }
}
