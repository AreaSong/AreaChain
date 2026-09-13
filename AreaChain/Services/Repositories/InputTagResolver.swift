import Foundation
import SwiftData

@MainActor
enum InputTagResolver {
    /// 仅修改当前事务，不自行保存；标签与所属内容必须一起成功或一起回滚。
    static func resolve(_ names: [String], in context: ModelContext) throws -> [UUID] {
        var tags = try context.fetch(FetchDescriptor<TagItem>(sortBy: [SortDescriptor(\.sortOrder)]))
        return TagSyntax.uniqueNames(names).map { name in
            let key = TagSyntax.normalizedName(name)
            let matches = tags.filter { TagSyntax.normalizedName($0.name) == key }
            if let existing = matches.first(where: { $0.deletedAt == nil }) ?? matches.first {
                existing.deletedAt = nil
                return existing.id
            }
            let tag = TagItem(name: name, sortOrder: (tags.map(\.sortOrder).max() ?? -1) + 1)
            context.insert(tag)
            tags.append(tag)
            return tag.id
        }
    }

    static func merging(_ names: [String], into existing: String, in context: ModelContext) throws -> String {
        var seen: Set<UUID> = []
        let ids = TagIDList.parse(existing) + (try resolve(names, in: context))
        return TagIDList.encode(ids.filter { seen.insert($0).inserted })
    }
}
