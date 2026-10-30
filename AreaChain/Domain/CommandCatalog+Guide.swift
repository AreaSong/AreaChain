import Foundation

/// 说明页完整目录的一组：根下一个直接子节点（scope 或 group）及其下全部可用指令。
/// `top == nil` 是“其他”组，收直接挂在根下、本身就是指令的条目（如 `/quit`）。
struct CommandGuideSection: Identifiable, Equatable, Sendable {
    let top: CommandDescriptor?
    let commands: [CommandDescriptor]

    static let otherNameKey = "searchGuide.catalog.other"

    var id: String { top?.id.rawValue ?? "other" }
    var nameKey: String { top?.nameKey ?? Self.otherNameKey }
}

extension CommandCatalog {
    /// 只收 category 不是 group/scope 的条目，每条恰好归入它最上层的祖先一次；
    /// 分组与组内顺序沿目录声明顺序，空组不出现，“其他”组放最后。
    func guideSections() -> [CommandGuideSection] {
        guard let root = entries.first(where: { $0.path == "/" }) else { return [] }
        let tops = children(of: root.id).filter { $0.category == .group || $0.category == .scope }
        var buckets: [CommandID: [CommandDescriptor]] = [:]
        var other: [CommandDescriptor] = []
        for entry in entries where entry.category != .group && entry.category != .scope {
            if let top = topAncestor(of: entry, root: root.id) { buckets[top, default: []].append(entry) }
            else { other.append(entry) }
        }
        var sections = tops.compactMap { top in
            buckets[top.id].map { CommandGuideSection(top: top, commands: $0) }
        }
        if !other.isEmpty { sections.append(CommandGuideSection(top: nil, commands: other)) }
        return sections
    }

    /// 根下的直接子节点；条目本身挂在根下或祖先链断开时返回 nil（归入“其他”，不猜测）。
    private func topAncestor(of entry: CommandDescriptor, root: CommandID) -> CommandID? {
        var current = entry
        var visited: Set<CommandID> = [entry.id]
        while let parent = current.parentID, parent != root {
            guard visited.insert(parent).inserted, let next = command(id: parent) else { return nil }
            current = next
        }
        return current.parentID == root && current.id != entry.id ? current.id : nil
    }
}
