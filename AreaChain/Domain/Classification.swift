import Foundation

struct BoardFilter: Equatable {
    var projectID: UUID? = nil
    var tagID: UUID? = nil
    var bundleID: String? = nil

    var isActive: Bool {
        projectID != nil || tagID != nil || bundleID != nil
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

enum Classification {
    static func priorityRank(important: Bool, urgent: Bool) -> Int {
        switch (important, urgent) {
        case (true, true): return 0
        case (true, false): return 1
        case (false, true): return 2
        default: return 3
        }
    }

    static func matches(_ bits: ClassifyBits, filter: BoardFilter) -> Bool {
        if let projectID = filter.projectID, bits.projectID != projectID { return false }
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
