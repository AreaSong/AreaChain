import Foundation

enum DiaryContentQueryTagPrivacyIssue: Equatable { case fetchFailed, ambiguousID(UUID) }

/// 全目录保护标志与关联名字是独立事实；成功也不证明旧正文没有保护标记。
struct DiaryContentQueryTagPrivacy: CustomStringConvertible, CustomDebugStringConvertible {
    let privateTagIDs: Set<UUID>?
    let coverage: ContentQuerySourceCoverage
    let issues: [DiaryContentQueryTagPrivacyIssue]
    var description: String { "DiaryContentQueryTagPrivacy(redacted)" }
    var debugDescription: String { description }

    @MainActor static func project(_ rows: [TagItem]) -> Self {
        let groups = Dictionary(grouping: rows, by: \.id)
        let duplicates = groups.keys.filter { groups[$0]?.count != 1 }.sorted { $0.uuidString < $1.uuidString }
        guard duplicates.isEmpty else {
            return .init(privateTagIDs: nil, coverage: .partial, issues: duplicates.map { .ambiguousID($0) })
        }
        return .init(privateTagIDs: Set(rows.filter(\.isPrivateDiary).map(\.id)), coverage: .complete, issues: [])
    }
}
