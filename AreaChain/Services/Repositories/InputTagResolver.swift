import Foundation
import SwiftData

@MainActor
enum InputTagResolver {
    /// 一个输入名字会落到哪个标签：已有活标签、恢复墓碑，或新建。
    enum Effect: Equatable {
        case existing(TagItem), restore(TagItem), create
    }

    /// 只读：与 `resolve` 同一套匹配（规范化名字、按排序先取活标签、否则取第一个墓碑），不修改任何对象。
    static func preview(_ names: [String], in context: ModelContext) throws -> [(name: String, effect: Effect)] {
        let byName = index(try context.fetch(FetchDescriptor<TagItem>(sortBy: [SortDescriptor(\.sortOrder)])))
        return TagSyntax.uniqueNames(names).map { name in
            guard let existing = match(byName[TagSyntax.normalizedName(name)] ?? []) else { return (name, .create) }
            return (name, existing.deletedAt == nil ? .existing(existing) : .restore(existing))
        }
    }

    /// 仅修改当前事务，不自行保存；标签与所属内容必须一起成功或一起回滚。
    static func resolve(_ names: [String], in context: ModelContext) throws -> [UUID] {
        let tags = try context.fetch(FetchDescriptor<TagItem>(sortBy: [SortDescriptor(\.sortOrder)]))
        var byName = index(tags)
        var nextOrder = (tags.map(\.sortOrder).max() ?? -1) + 1
        return TagSyntax.uniqueNames(names).map { name in
            let key = TagSyntax.normalizedName(name)
            if let existing = match(byName[key] ?? []) {
                if existing.deletedAt != nil { existing.deletedAt = nil }
                return existing.id
            }
            let tag = TagItem(name: name, sortOrder: nextOrder)
            nextOrder += 1
            context.insert(tag)
            byName[key, default: []].append(tag)
            return tag.id
        }
    }

    static func merging(_ names: [String], into existing: String, in context: ModelContext) throws -> String {
        var seen: Set<UUID> = []
        let ids = TagIDList.parse(existing) + (try resolve(names, in: context))
        return TagIDList.encode(ids.filter { seen.insert($0).inserted })
    }

    // MARK: - 任务侧（任务、子任务、习惯）

    enum Protection: Equatable { case preset, privateTag }

    /// 任务侧从文字解析标签的唯一过滤规则，与指令侧 CommandTaskTagCatalog 的拒绝条件一致：手记预置名，或按同一匹配
    /// 落到的私密标签（活的或墓碑）。手记与标签管理不走这里——按标签加密手记正是靠关联私密标签实现的。
    static func protection(_ name: String, _ effect: Effect) -> (kind: Protection, title: String)? {
        let key = TagSyntax.normalizedName(name)
        if DiaryMemoTags.presets.contains(where: { TagSyntax.normalizedName($0) == key }) { return (.preset, name) }
        switch effect {
        case .existing(let tag), .restore(let tag): return tag.isPrivateDiary ? (.privateTag, tag.name) : nil
        case .create: return nil
        }
    }

    struct TaskSide: Equatable {
        /// `resolveForTask` 给关联的 ID；`mergingForTask` 给合并后的编码，ids 为合并后全集。
        let ids: [UUID]
        /// 被跳过的私密／预设标签名：不关联、不新建、不恢复。
        let skipped: [String]
        var encoded: String { TagIDList.encode(ids) }
    }

    /// 文字照常保存；被跳过的标签在保存成功后经 MutationFeedback 提示一次。
    static func resolveForTask(_ names: [String], in context: ModelContext) throws -> TaskSide {
        var allowed: [String] = []
        var skipped: [String] = []
        for (name, effect) in try preview(names, in: context) {
            if let blocked = protection(name, effect) { skipped.append(blocked.title) } else { allowed.append(name) }
        }
        let ids = try resolve(allowed, in: context)
        if !skipped.isEmpty {
            ModelChanges.afterPublication(in: context) { MutationFeedback.shared.reportSkippedTags(skipped) }
        }
        return .init(ids: ids, skipped: skipped)
    }

    /// 已经关联在对象上的私密或预设标签不自动移除（抽屉里仍显示，以便用户手动去掉）。
    static func mergingForTask(_ names: [String], into existing: String, in context: ModelContext) throws -> TaskSide {
        let resolved = try resolveForTask(names, in: context)
        var seen: Set<UUID> = []
        let ids = (TagIDList.parse(existing) + resolved.ids).filter { seen.insert($0).inserted }
        return .init(ids: ids, skipped: resolved.skipped)
    }

    private static func index(_ tags: [TagItem]) -> [String: [TagItem]] {
        var byName: [String: [TagItem]] = [:]
        byName.reserveCapacity(tags.count)
        for tag in tags {
            byName[TagSyntax.normalizedName(tag.name), default: []].append(tag)
        }
        return byName
    }

    private static func match(_ matches: [TagItem]) -> TagItem? {
        matches.first(where: { $0.deletedAt == nil }) ?? matches.first
    }
}
