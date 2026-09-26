import Foundation

struct TaskSelectionModifiers: OptionSet, Equatable {
    let rawValue: Int
    static let shift = Self(rawValue: 1 << 0)
    static let command = Self(rawValue: 1 << 1)
}

/// 范围只能来自屏幕上的顺序，不能从无序集合或隐藏任务推导。
struct TaskSelection: Equatable {
    var ids: Set<UUID> = []
    var anchorID: UUID?

    mutating func select(_ id: UUID, in visibleIDs: [UUID], modifiers: TaskSelectionModifiers = []) {
        guard let end = visibleIDs.firstIndex(of: id) else { return }
        reconcile(with: visibleIDs)
        if modifiers.contains(.shift) {
            let start = anchorID.flatMap { visibleIDs.firstIndex(of: $0) } ?? end
            let range = Set(visibleIDs[min(start, end)...max(start, end)])
            ids = modifiers.contains(.command) ? ids.union(range) : range
            if anchorID == nil { anchorID = id }
        } else if modifiers.contains(.command) {
            if !ids.insert(id).inserted { ids.remove(id) }
            anchorID = id
        } else {
            ids = [id]
            anchorID = id
        }
    }

    mutating func reconcile(with visibleIDs: [UUID]) {
        let visible = Set(visibleIDs)
        ids.formIntersection(visible)
        if let anchorID, !visible.contains(anchorID) { self.anchorID = nil }
    }

    /// 只移除上一份顺序里消失的标识。另一分区的选择不在这份顺序中，不能被这次刷新清掉。
    mutating func dropRemoved(from previous: [UUID], to next: [UUID]) {
        let removed = Set(previous).subtracting(next)
        guard !removed.isEmpty else { return }
        ids.subtract(removed)
        if let anchorID, removed.contains(anchorID) { self.anchorID = nil }
    }

    mutating func focus(_ id: UUID?) {
        ids = id.map { Set([$0]) } ?? []
        anchorID = id
    }
}
