import Foundation

struct BoardFilter: Equatable {
    var projectID: UUID? = nil
    var tagID: UUID? = nil
    var bundleID: String? = nil
    var isHighPriorityOnly: Bool = false

    var isActive: Bool {
        projectID != nil || tagID != nil || bundleID != nil || isHighPriorityOnly
    }

    func withProject(_ id: UUID?) -> BoardFilter {
        var next = self
        next.projectID = id
        return next
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
        return next
    }
}

struct ClassifyBits: Equatable {
    var projectID: UUID? = nil
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

    var titleKeyName: String {
        switch self {
        case .importantUrgent: "quadrant.iu"
        case .important: "quadrant.i"
        case .urgent: "quadrant.u"
        case .rest: "quadrant.rest"
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

    static func matches(_ bits: ClassifyBits, filter: BoardFilter, projectIDs: Set<UUID>? = nil) -> Bool {
        if filter.isHighPriorityOnly, !(bits.isImportant || bits.isUrgent) { return false }
        if let projectID = filter.projectID {
            let allowed = projectIDs ?? [projectID]
            guard let current = bits.projectID, allowed.contains(current) else { return false }
        }
        if let tagID = filter.tagID, !TagIDList.contains(bits.tagIDs, tagID) { return false }
        if let bundleID = filter.bundleID, bits.sourceBundleID != bundleID { return false }
        return true
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

enum AttachmentOwner: String, Equatable {
    case routine
    case todo
    case diary
}
