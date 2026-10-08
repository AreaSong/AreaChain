import Foundation
import SwiftData

extension InputTagResolver {
    /// 结构化入口只执行已接受的目标；先核实整份最终集合，再改模型，绝不按名字任取首项。
    static func apply(_ plan: CommandTaskTagPlan, creationIDs: [String: UUID], in context: ModelContext) throws -> [UUID] {
        guard plan.problems.isEmpty else { throw TaskCreateCommandIssue.invalidInput }
        let rows = try SwiftDataCatalogRepository(context: context).fetchTags(includeDeleted: true)
        let lookup = CommandTaskTagLookup(.init(directoryID: UUID(), readID: UUID(), revision: 0,
            coverage: .complete, records: rows.map(TaskCreateTagCatalogReader.record)))
        guard lookup.catalogProblems.isEmpty else { throw TaskCreateCommandIssue.stale }
        let resolved = try plan.final.map { try resolve($0, lookup: lookup, creationIDs: creationIDs) }
        let newIDs = Array(creationIDs.values)
        guard Set(newIDs).count == newIDs.count, !rows.contains(where: { newIDs.contains($0.id) }),
              Set(resolved).count == resolved.count else { throw TaskCreateCommandIssue.identityCollision }
        var remaining = plan.final.filter { $0.effect == .createAndAssociate }.count
        var order = try creationOrder(rows.map(\.sortOrder), count: remaining)
        for (association, id) in zip(plan.final, resolved) {
            switch association.effect {
            case .associateLive: break
            case .restoreAndAssociate:
                guard let tag = rows.first(where: { $0.id == id }) else { throw TaskCreateCommandIssue.stale }
                tag.deletedAt = nil
            case .createAndAssociate:
                guard case .newName(let name, _) = association.target else { throw TaskCreateCommandIssue.stale }
                context.insert(TagItem(id: id, name: name, sortOrder: order))
                remaining -= 1
                if remaining > 0 { order += 1 }
            }
        }
        return resolved
    }

    /// 先检查整个新建区间；末项等于 Int.max 时不再计算一个不会使用的下一序号。
    static func creationOrder(_ orders: [Int], count: Int) throws -> Int {
        guard count > 0 else { return 0 }
        let maximum = orders.max() ?? -1
        guard !maximum.addingReportingOverflow(count).overflow else { throw TaskCreateCommandIssue.invalidInput }
        return maximum + 1
    }

    private static func resolve(_ association: CommandTaskTagAssociation, lookup: CommandTaskTagLookup,
                                creationIDs: [String: UUID]) throws -> UUID {
        let selection: CommandTaskTagSelection
        let id: UUID
        switch association.target {
        case .existing(let row):
            guard let existing = row.id,
                  association.effect == (row.state == .live ? .associateLive : .restoreAndAssociate) else {
                throw TaskCreateCommandIssue.stale
            }
            selection = .id(existing)
            id = existing
        case .newName(let name, let key):
            guard association.effect == .createAndAssociate, let reserved = creationIDs[key],
                  key == TagSyntax.normalizedName(name) else { throw TaskCreateCommandIssue.stale }
            selection = .name(name)
            id = reserved
        }
        guard case .success(let current) = lookup.resolve(selection), current == association.target else {
            throw TaskCreateCommandIssue.stale
        }
        return id
    }
}
