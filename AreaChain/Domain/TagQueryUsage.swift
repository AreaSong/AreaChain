import Foundation

/// completeTagIDs 只对列出的标签证明完整；其余项及缺项仍是局部读取。
enum TagQueryUsageCoverage: Equatable {
    case partial(completeTagIDs: Set<UUID>)
    case complete

    func contains(_ id: UUID) -> Bool {
        switch self {
        case .complete: true
        case .partial(let ids): ids.contains(id)
        }
    }
}

struct TagQueryUsageInput: CustomStringConvertible, CustomDebugStringConvertible {
    let records: [TagUsageRecord]
    let coverage: TagQueryUsageCoverage

    var description: String { "TagQueryUsageInput(redacted)" }
    var debugDescription: String { description }
}

enum TagQueryUsageState: Equatable { case unavailable, partial, complete, invalid }

/// 复用 TagUsage 的统计值，不重新读取关联对象或推导计数/最近时间。
struct TagQueryUsageReading {
    let state: TagQueryUsageState
    var record: TagUsageRecord?
    var diagnostics: [TagQueryDiagnostic] = []
}

struct TagQueryUsageReader {
    let input: TagQueryUsageInput?
    let dates: ContentQueryDateContext
    private let positions: [UUID: [Int]]

    init(input: TagQueryUsageInput?, dates: ContentQueryDateContext) {
        self.input = input
        self.dates = dates
        let records = input?.records ?? []
        positions = Dictionary(grouping: records.indices, by: { records[$0].tagID })
    }

    func read(_ id: UUID) -> TagQueryUsageReading {
        guard let input else {
            return .init(state: .unavailable, diagnostics: [.init(issue: .usageUnavailable)])
        }
        let indices = positions[id] ?? []
        guard indices.count <= 1 else {
            return .init(state: .invalid, diagnostics: [.init(issue: .duplicateUsageID, usageIndices: indices)])
        }
        if let index = indices.first {
            let record = input.records[index]
            let issues = validate(record)
            if !issues.isEmpty {
                return .init(state: .invalid, diagnostics: issues.map { .init(issue: $0, usageIndices: [index]) })
            }
        }
        guard input.coverage.contains(id) else {
            return .init(state: .partial, diagnostics: [.init(issue: .usageIncomplete, usageIndices: indices)])
        }
        return .init(state: .complete, record: indices.first.map { input.records[$0] }
                     ?? .init(tagID: id, activeCount: 0, latestCreatedAt: nil))
    }

    private func validate(_ record: TagUsageRecord) -> [TagQueryIssue] {
        var issues: [TagQueryIssue] = []
        if record.activeCount < 0 { issues.append(.negativeUsageCount) }
        if let stamp = record.latestCreatedAt, !ContentQuerySnapshotValidation.validTimestamp(stamp, dates: dates) {
            issues.append(.invalidUsageTimestamp)
        }
        // TagUsage.records 的正数必有最近创建时间，零数必须无时间；不能伪造另一套口径。
        if (record.activeCount == 0 && record.latestCreatedAt != nil)
            || (record.activeCount > 0 && record.latestCreatedAt == nil) {
            issues.append(.inconsistentUsageRecord)
        }
        return issues
    }
}
