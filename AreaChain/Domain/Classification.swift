import Foundation

enum DateFilterScope: String, CaseIterable, Equatable, Sendable {
    case all
    case today
    case recent
    case overdue
    case upcoming
}

enum PriorityFilterScope: String, CaseIterable, Equatable, Sendable {
    case all
    case highPriorityOnly
    case p1
    case p2
    case p3
    case p4
}

struct BoardFilter: Equatable {
    var tagID: UUID? = nil
    var bundleID: String? = nil
    var isHighPriorityOnly: Bool = false
    var priorityScope: PriorityFilterScope = .all
    var dateScope: DateFilterScope = .all

    static let noneID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    var isNoTag: Bool { tagID == Self.noneID }

    var isActive: Bool {
        tagID != nil || bundleID != nil || isHighPriorityOnly || priorityScope != .all || dateScope != .all
    }

    func withTag(_ id: UUID?) -> BoardFilter {
        var next = self
        next.tagID = id
        return next
    }

    func withBundle(_ id: String?) -> BoardFilter {
        var next = self
        next.bundleID = id
        return next
    }

    func withHighPriority(_ flag: Bool) -> BoardFilter {
        var next = self
        next.isHighPriorityOnly = flag
        next.priorityScope = flag ? .highPriorityOnly : .all
        return next
    }

    func withPriorityScope(_ scope: PriorityFilterScope) -> BoardFilter {
        var next = self
        next.priorityScope = scope
        next.isHighPriorityOnly = scope == .highPriorityOnly
        return next
    }

    func withDateScope(_ scope: DateFilterScope) -> BoardFilter {
        var next = self
        next.dateScope = scope
        return next
    }
}

struct ClassifyBits: Equatable {
    var tagIDs: String = ""
    var isImportant: Bool = false
    var isUrgent: Bool = false
    var sourceBundleID: String = ""
}

enum TagIDList {
    static func parse(_ raw: String) -> [UUID] {
        raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
    }

    static func encode(_ ids: [UUID]) -> String {
        ids.map(\.uuidString).joined(separator: ",")
    }

    static func contains(_ raw: String, _ id: UUID) -> Bool {
        parse(raw).contains(id)
    }

    static func normalized(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }

    static func normalized(_ raw: String) -> String {
        encode(normalized(parse(raw)))
    }

    static func toggling(_ raw: String, _ id: UUID) -> String {
        var ids = parse(raw)
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.append(id)
        }
        return encode(ids)
    }
}

struct BoardSortKey: Equatable {
    var isImportant: Bool = false
    var isUrgent: Bool = false
    var remindMinutes: Int? = nil
    var createdAt: Date = Date(timeIntervalSince1970: 0)
}

enum QuadrantSlot: Int, CaseIterable, Identifiable {
    case importantUrgent
    case important
    case urgent
    case rest

    var id: Int { rawValue }

    var isImportant: Bool { self == .importantUrgent || self == .important }
    var isUrgent: Bool { self == .importantUrgent || self == .urgent }

    var badgeText: String {
        switch self {
        case .importantUrgent: "P1"
        case .important: "P2"
        case .urgent: "P3"
        case .rest: "P4"
        }
    }

    var titleKeyName: String {
        switch self {
        case .importantUrgent: "quadrant.iu"
        case .important: "quadrant.i"
        case .urgent: "quadrant.u"
        case .rest: "quadrant.rest"
        }
    }

    var subtitleKeyName: String {
        switch self {
        case .importantUrgent: "quadrant.iu.hint"
        case .important: "quadrant.i.hint"
        case .urgent: "quadrant.u.hint"
        case .rest: "quadrant.rest.hint"
        }
    }

    var iconName: String {
        switch self {
        case .importantUrgent: "exclamationmark.3"
        case .important: "calendar.badge.clock"
        case .urgent: "arrow.triangle.branch"
        case .rest: "archivebox"
        }
    }

    static func of(important: Bool, urgent: Bool) -> QuadrantSlot {
        switch (important, urgent) {
        case (true, true): return .importantUrgent
        case (true, false): return .important
        case (false, true): return .urgent
        default: return .rest
        }
    }
}

enum Classification {
    static func priorityRank(important: Bool, urgent: Bool) -> Int {
        QuadrantSlot.of(important: important, urgent: urgent).rawValue
    }

    static func matches(_ bits: ClassifyBits, filter: BoardFilter) -> Bool {
        if filter.priorityScope != .all {
            switch filter.priorityScope {
            case .all:
                break
            case .highPriorityOnly:
                if !(bits.isImportant || bits.isUrgent) { return false }
            case .p1:
                if !(bits.isImportant && bits.isUrgent) { return false }
            case .p2:
                if !(bits.isImportant && !bits.isUrgent) { return false }
            case .p3:
                if !(!bits.isImportant && bits.isUrgent) { return false }
            case .p4:
                if !(!bits.isImportant && !bits.isUrgent) { return false }
            }
        } else if filter.isHighPriorityOnly, !(bits.isImportant || bits.isUrgent) {
            return false
        }
        if let tagID = filter.tagID {
            if tagID == BoardFilter.noneID {
                guard TagIDList.parse(bits.tagIDs).isEmpty else { return false }
            } else {
                guard TagIDList.contains(bits.tagIDs, tagID) else { return false }
            }
        }
        if let bundleID = filter.bundleID, bits.sourceBundleID != bundleID { return false }
        return true
    }

    static func matchesListedTodo(
        _ bits: ClassifyBits, dayKey: String, isDone: Bool, todayKey: String,
        filter: BoardFilter
    ) -> Bool {
        guard matches(bits, filter: filter) else { return false }
        if filter.dateScope != .all {
            guard matchesDate(dayKey: dayKey, isDone: isDone, todayKey: todayKey, scope: filter.dateScope) else { return false }
        }
        return true
    }

    static func matchesListedRoutine(
        _ bits: ClassifyBits, filter: BoardFilter
    ) -> Bool {
        guard matches(bits, filter: filter) else { return false }
        return filter.dateScope != .overdue
    }

    static func matchesDate(dayKey: String, isDone: Bool, todayKey: String, scope: DateFilterScope) -> Bool {
        switch scope {
        case .all:
            return true
        case .today:
            return dayKey == todayKey
        case .recent:
            let weekAhead = DayKey.shifted(todayKey, by: 7)
            return dayKey >= todayKey && dayKey <= weekAhead
        case .overdue:
            return dayKey < todayKey && !isDone
        case .upcoming:
            return dayKey > todayKey && !isDone
        }
    }

    static func precedes(_ left: BoardSortKey, _ right: BoardSortKey) -> Bool {
        let leftRank = priorityRank(important: left.isImportant, urgent: left.isUrgent)
        let rightRank = priorityRank(important: right.isImportant, urgent: right.isUrgent)
        if leftRank != rightRank { return leftRank < rightRank }
        switch (left.remindMinutes, right.remindMinutes) {
        case let (a?, b?) where a != b:
            return a < b
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return left.createdAt < right.createdAt
        }
    }
}

enum ClipboardPayload {
    struct Result: Equatable {
        var title: String
        var attachImage: Bool
    }

    static func make(text: String?, hasImage: Bool, imageTitle: String) -> Result? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return Result(title: trimmed, attachImage: false)
        }
        if hasImage {
            return Result(title: imageTitle, attachImage: true)
        }
        return nil
    }
}

enum AttachmentOwner: String, Equatable, Hashable, Sendable {
    case routine
    case todo
    case diary
}

struct AttachmentOwnerKey: Hashable, Sendable {
    var kind: AttachmentOwner
    var id: UUID
}
