import Foundation

enum TodoDragToken {
    static let prefix = "areachain-todo:"
    static let routinePrefix = "areachain-routine:"

    static func encode(_ id: UUID) -> String {
        prefix + id.uuidString
    }

    static func encodeRoutine(_ id: UUID) -> String {
        routinePrefix + id.uuidString
    }

    static func decode(_ raw: String) -> UUID? {
        decode(raw, prefix: prefix)
    }

    static func decodeRoutine(_ raw: String) -> UUID? {
        decode(raw, prefix: routinePrefix)
    }

    private static func decode(_ raw: String, prefix: String) -> UUID? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(trimmed.dropFirst(prefix.count)))
    }
}
