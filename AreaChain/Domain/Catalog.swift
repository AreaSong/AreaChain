import Foundation

enum Catalog {
    static func liveProjects(_ items: [ProjectItem]) -> [ProjectItem] {
        items.filter { $0.deletedAt == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    static func liveTags(_ items: [TagItem]) -> [TagItem] {
        items.filter { $0.deletedAt == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 待办侧使用的标签，不含手记三分类。
    static func liveTaskTags(_ items: [TagItem]) -> [TagItem] {
        liveTags(items).filter { !DiaryMemoTags.isPresetName($0.name) }
    }

    /// 抽屉选择器：预设分类仅在该项已打上时出现，方便去掉。
    static func taskPickerTags(_ items: [TagItem], attachedIDs: String) -> [TagItem] {
        liveTags(items).filter { tag in
            if DiaryMemoTags.isPresetName(tag.name) {
                return TagIDList.contains(attachedIDs, tag.id)
            }
            return true
        }
    }

    static func liveAttachments(for ownerID: UUID, in items: [AttachmentItem]) -> [AttachmentItem] {
        items
            .filter { $0.deletedAt == nil && $0.ownerID == ownerID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    static func nextSortOrder(_ orders: [Int]) -> Int {
        (orders.max() ?? -1) + 1
    }

    static func matches(
        projectID: UUID?,
        tagIDs: String,
        project: ProjectItem?,
        tag: TagItem?,
        projects: [ProjectItem]
    ) -> Bool {
        if let project {
            guard let projectID else { return false }
            return ProjectTree.subtreeIDs(root: project.id, in: projects).contains(projectID)
        }
        if let tag {
            return TagIDList.contains(tagIDs, tag.id)
        }
        return false
    }

    static func matchingTodos(
        _ items: [TodoItem],
        project: ProjectItem?,
        tag: TagItem?,
        projects: [ProjectItem]
    ) -> [TodoItem] {
        items.filter {
            $0.deletedAt == nil
                && matches(projectID: $0.projectID, tagIDs: $0.tagIDs, project: project, tag: tag, projects: projects)
        }
    }

    static func matchingRoutines(
        _ items: [DailyRoutine],
        project: ProjectItem?,
        tag: TagItem?,
        projects: [ProjectItem]
    ) -> [DailyRoutine] {
        items.filter {
            $0.deletedAt == nil
                && matches(projectID: $0.projectID, tagIDs: $0.tagIDs, project: project, tag: tag, projects: projects)
        }
        .sorted { $0.sortOrder < $1.sortOrder }
    }

    static func openCount(
        todos: [TodoItem],
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        project: ProjectItem?,
        tag: TagItem?,
        projects: [ProjectItem],
        dayKey: String
    ) -> Int {
        let openTodos = matchingTodos(todos, project: project, tag: tag, projects: projects)
            .filter { !$0.isDone }
            .count
        let snaps = checks.compactMap(\.snapshot)
        let openRoutines = matchingRoutines(routines, project: project, tag: tag, projects: projects)
            .filter {
                DayBoardLogic.isRoutineDue($0.snapshot, on: dayKey)
                    && !DayBoardLogic.isRoutineDone($0.snapshot, checks: snaps, on: dayKey)
            }
            .count
        return openTodos + openRoutines
    }

    static func reindexRoutines(_ items: [DailyRoutine], from source: IndexSet, to destination: Int) {
        var ordered = items
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in ordered.enumerated() {
            item.sortOrder = index
        }
    }

    static func unlinkProject(
        _ id: UUID,
        todos: [TodoItem],
        routines: [DailyRoutine],
        projects: [ProjectItem]
    ) {
        for todo in todos where todo.projectID == id {
            todo.projectID = nil
        }
        for routine in routines where routine.projectID == id {
            routine.projectID = nil
        }
        for child in projects where child.parentID == id {
            child.parentID = nil
        }
    }

    static func unlinkTag(
        _ id: UUID,
        todos: [TodoItem],
        routines: [DailyRoutine],
        diaries: [DiaryEntry]
    ) {
        for todo in todos where TagIDList.contains(todo.tagIDs, id) {
            todo.tagIDs = TagIDList.toggling(todo.tagIDs, id)
        }
        for routine in routines where TagIDList.contains(routine.tagIDs, id) {
            routine.tagIDs = TagIDList.toggling(routine.tagIDs, id)
        }
        for diary in diaries where TagIDList.contains(diary.tagIDs, id) {
            diary.tagIDs = TagIDList.toggling(diary.tagIDs, id)
        }
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
    static func grouped(_ items: [AttachmentItem], liveOwnerIDs: Set<UUID>? = nil) -> [AttachmentCluster] {
        let live = items.filter { item in
            guard item.deletedAt == nil else { return false }
            if let liveOwnerIDs {
                return liveOwnerIDs.contains(item.ownerID)
            }
            return true
        }.sorted { $0.createdAt > $1.createdAt }
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
