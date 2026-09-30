import Foundation

struct ManualOrderEntry: Equatable, Identifiable {
    var id: UUID
    var dayKey: String
    var sortOrder: Int

    var identity: UUID { id }
}

enum ManualOrder {
    /// 只在同一天内把 `moving` 插到 `target` 前面，并重写这一天的手动顺序。
    static func reordered(
        _ entries: [ManualOrderEntry],
        moving: UUID,
        before target: UUID
    ) -> [ManualOrderEntry]? {
        guard moving != target,
              let from = entries.firstIndex(where: { $0.id == moving }),
              let targetIndex = entries.firstIndex(where: { $0.id == target }),
              entries[from].dayKey == entries[targetIndex].dayKey else {
            return nil
        }
        var next = entries
        let item = next.remove(at: from)
        let destination = next.firstIndex(where: { $0.id == target }) ?? next.endIndex
        next.insert(item, at: destination)
        let day = item.dayKey
        var index = 0
        for offset in next.indices where next[offset].dayKey == day {
            next[offset].sortOrder = index
            index += 1
        }
        return next
    }

    static func reordered(_ ids: [UUID], moving: UUID, before target: UUID) -> [UUID]? {
        guard moving != target,
              let from = ids.firstIndex(of: moving),
              ids.contains(target) else { return nil }
        var next = ids
        next.remove(at: from)
        let destination = next.firstIndex(of: target) ?? next.endIndex
        next.insert(moving, at: destination)
        return next
    }
}

enum BoardReorderToken {
    private static let prefix = "board-order:"

    static func encode(_ id: UUID) -> String {
        prefix + id.uuidString
    }

    static func decode(_ raw: String) -> UUID? {
        guard raw.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(raw.dropFirst(prefix.count)))
    }
}
