import Foundation

enum Catalog {
    static func liveProjects(_ items: [ProjectItem]) -> [ProjectItem] {
        items.filter { $0.deletedAt == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    static func liveTags(_ items: [TagItem]) -> [TagItem] {
        items.filter { $0.deletedAt == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    static func liveAttachments(for ownerID: UUID, in items: [AttachmentItem]) -> [AttachmentItem] {
        items
            .filter { $0.deletedAt == nil && $0.ownerID == ownerID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    static func nextSortOrder(_ orders: [Int]) -> Int {
        (orders.max() ?? -1) + 1
    }
}

struct ProjectOutlineRow: Equatable, Identifiable {
    var id: UUID
    var name: String
    var depth: Int
    var parentID: UUID?
}

enum ProjectTree {
    static func subtreeIDs(root: UUID, in projects: [ProjectItem]) -> Set<UUID> {
        let live = projects.filter { $0.deletedAt == nil }
        var result: Set<UUID> = [root]
        var grew = true
        while grew {
            grew = false
            for item in live where !result.contains(item.id) {
                if let parent = item.parentID, result.contains(parent) {
                    result.insert(item.id)
                    grew = true
                }
            }
        }
        return result
    }

    static func wouldCycle(moving id: UUID, to parentID: UUID?, in projects: [ProjectItem]) -> Bool {
        guard let parentID else { return false }
        if parentID == id { return true }
        return subtreeIDs(root: id, in: projects).contains(parentID)
    }

    static func outline(_ projects: [ProjectItem]) -> [ProjectOutlineRow] {
        let live = Catalog.liveProjects(projects)
        let byID = Dictionary(uniqueKeysWithValues: live.map { ($0.id, $0) })
        var children: [UUID: [ProjectItem]] = [:]
        for item in live {
            if let parent = item.parentID, byID[parent] != nil {
                children[parent, default: []].append(item)
            }
        }
        for key in children.keys {
            children[key]?.sort { $0.sortOrder < $1.sortOrder }
        }
        let roots = live.filter { item in
            guard let parent = item.parentID else { return true }
            return byID[parent] == nil
        }
        var rows: [ProjectOutlineRow] = []
        var seen: Set<UUID> = []
        func walk(_ item: ProjectItem, depth: Int) {
            guard seen.insert(item.id).inserted else { return }
            rows.append(ProjectOutlineRow(id: item.id, name: item.name, depth: depth, parentID: item.parentID))
            for child in children[item.id] ?? [] {
                walk(child, depth: depth + 1)
            }
        }
        for root in roots {
            walk(root, depth: 0)
        }
        return rows
    }

    static func pathLabel(_ id: UUID, in projects: [ProjectItem]) -> String {
        let byID = Dictionary(uniqueKeysWithValues: Catalog.liveProjects(projects).map { ($0.id, $0) })
        var names: [String] = []
        var current: UUID? = id
        var hops = 0
        while let key = current, let item = byID[key], hops < 20 {
            names.append(item.name)
            current = item.parentID
            hops += 1
        }
        return names.reversed().joined(separator: " / ")
    }

    static func allowedParents(for id: UUID, in projects: [ProjectItem]) -> [ProjectOutlineRow] {
        outline(projects).filter { !wouldCycle(moving: id, to: $0.id, in: projects) }
    }
}

struct AttachmentRef: Identifiable, Equatable, Hashable {
    var id: UUID
    var filename: String
}

struct AttachmentCluster: Equatable, Identifiable {
    var id: String { "\(kind.rawValue)-\(ownerID.uuidString)" }
    var kind: AttachmentOwner
    var ownerID: UUID
    var items: [AttachmentRef]
}

enum AttachmentClusters {
    static func grouped(_ items: [AttachmentItem]) -> [AttachmentCluster] {
        let live = items.filter { $0.deletedAt == nil }.sorted { $0.createdAt > $1.createdAt }
        var order: [(AttachmentOwner, UUID)] = []
        var buckets: [String: [AttachmentRef]] = [:]
        for item in live {
            guard let kind = AttachmentOwner(rawValue: item.ownerKind) else { continue }
            let key = "\(kind.rawValue)|\(item.ownerID.uuidString)"
            if buckets[key] == nil {
                order.append((kind, item.ownerID))
            }
            buckets[key, default: []].append(AttachmentRef(id: item.id, filename: item.filename))
        }
        let kindRank: [AttachmentOwner: Int] = [.todo: 0, .diary: 1, .routine: 2]
        return order
            .sorted { lhs, rhs in
                let left = kindRank[lhs.0] ?? 9
                let right = kindRank[rhs.0] ?? 9
                if left != right { return left < right }
                return lhs.1.uuidString < rhs.1.uuidString
            }
            .map { kind, ownerID in
                AttachmentCluster(kind: kind, ownerID: ownerID, items: buckets["\(kind.rawValue)|\(ownerID.uuidString)"] ?? [])
            }
    }
}

enum CloudKitAvailability {
    /// 当前 ad-hoc 签名没有 iCloud 容器；真同步以后再改 Persistence。
    static var isConfigured: Bool { false }
}
