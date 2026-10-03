import Foundation

enum ContentQuerySortTimeSource: Equatable { case createdAt, copiedAt, executionDay, unavailable }
enum ContentQuerySortTimeIssue: Equatable { case missing, invalid, invalidDateEnvironment }

/// day 仅用于比较；instant 只在来源确有时刻时存在。无效值不进入比较键。
struct ContentQuerySortTime: Equatable {
    let source: ContentQuerySortTimeSource
    let day: String?
    let instant: Date?
    let issue: ContentQuerySortTimeIssue?

    init(match: ContentQueryBatchMatch, dates: ContentQueryDateContext) {
        let source: ContentQuerySortTimeSource
        let stamp: Date?
        switch match {
        case .todo(let value): source = .createdAt; stamp = value.createdAt
        case .subtask(let value): source = .createdAt; stamp = value.createdAt
        case .routine(let value): source = .createdAt; stamp = value.createdAt
        case .diary(let value): source = .createdAt; stamp = value.createdAt
        case .image(let value): source = .createdAt; stamp = value.createdAt
        case .clipboard(let value): source = .copiedAt; stamp = value.copiedAt
        case .tag: source = .unavailable; stamp = nil
        case .routineOccurrence: source = .executionDay; stamp = nil
        case .trash(let value):
            stamp = TrashQueryFields(value.object.fields).createdAt
            source = value.id.type == .tag ? .unavailable : .createdAt
        }
        self.source = source
        guard ContentQuerySnapshotValidation.validDay(dates.todayKey, dates: dates) else {
            day = nil; instant = nil; issue = .invalidDateEnvironment; return
        }
        if source == .executionDay {
            let key = match.id.dayKey
            let valid = key.map { ContentQuerySnapshotValidation.validDay($0, dates: dates) } ?? false
            day = valid ? key : nil; instant = nil; issue = valid ? nil : (key == nil ? .missing : .invalid)
        } else if let stamp {
            let valid = stamp != .distantPast && stamp != .distantFuture
                && ContentQuerySnapshotValidation.validTimestamp(stamp, dates: dates)
            day = valid ? DayKey.from(stamp, calendar: dates.calendar) : nil
            instant = valid ? stamp : nil; issue = valid ? nil : .invalid
        } else {
            day = nil; instant = nil; issue = .missing
        }
    }
}
