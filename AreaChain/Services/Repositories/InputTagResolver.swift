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
