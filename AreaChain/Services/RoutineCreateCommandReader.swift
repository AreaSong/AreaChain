import Foundation
import SwiftData

extension RoutineCommandEnvironment {
    struct Creation {
        let now: () -> Date
        let calendar: Calendar
        let source: ([CommandArgument]) throws -> CommandRoutineCreateEligibility
    }

    func creationQualification(_ arguments: [CommandArgument]) throws -> CommandRoutineCreateSource {
        guard let creation else { throw RoutineCreateIssue.unassembled }
        let evidence: CommandRoutineCreateEligibility
        do { evidence = try creation.source(arguments) } catch { throw RoutineCreateIssue.sourceUnavailable }
        guard evidence.input.protection == .ordinary, evidence.environment.protection == .ordinary else {
            throw RoutineCreateIssue.protectedContent
        }
        try validateClean()
        return .init(environmentID: id, contextID: ObjectIdentifier(context), storageID: ObjectIdentifier(context.container),
                     eligibility: evidence)
    }
}

@MainActor final class RoutineCreateCommandReader {
    unowned let environment: RoutineCommandEnvironment
    init(environment: RoutineCommandEnvironment) { self.environment = environment }

    func read(_ item: CommandPlanItem, lease: CommandHostLease, plan: CommandPlanStamp,
              catalog: CommandTaskTagCatalog) throws -> CommandRoutineCreatePreview {
        try CommandRoutineCreatePreview.validate(item, allowingDependencies: true)
        let input = try CommandRoutineCreatePreview.input(item.draft)
        let source = try environment.creationQualification(item.draft.arguments)
        guard let creation = environment.creation else { throw RoutineCreateIssue.unassembled }
        let day = DayKey.from(creation.now(), calendar: creation.calendar)
        guard let date = DayKey.date(from: day, calendar: creation.calendar),
              DayKey.from(date, calendar: creation.calendar) == day else { throw RoutineCreateIssue.dateChanged }
        let basis = try sortBasis()
        let maximum = basis.map(\.order).max() ?? -1
        let next = maximum.addingReportingOverflow(1)
        guard !next.overflow else { throw RoutineCreateIssue.unreliableSort }
        guard try environment.reader.catalogReader.current().evidence() == catalog.evidence() else { throw RoutineCreateIssue.stale }
        let composition = CommandTaskCreateComposition.compose(title: input.title, day: day, arguments: item.draft.arguments, catalog: catalog)
        let tagOrders = try SwiftDataCatalogRepository(context: environment.context).fetchTags(includeDeleted: true).map(\.sortOrder)
        _ = try InputTagResolver.creationOrder(tagOrders, count: composition.tags.final.filter { $0.effect == .createAndAssociate }.count)
        return .init(lease: lease, plan: plan, item: item.stamp, draft: item.draft.stamp, arguments: item.draft.arguments,
                     source: source, catalog: try catalog.evidence(), sortBasis: basis, sortOrder: next.partialValue,
                     weekdayMask: input.mask, composition: composition)
    }

    func validate(_ preview: CommandRoutineCreatePreview, item: CommandPlanItem) throws {
        let current = try read(item, lease: preview.lease, plan: preview.plan, catalog: environment.reader.catalogReader.current())
        guard current.createdDayKey == preview.createdDayKey else { throw RoutineCreateIssue.dateChanged }
        guard current.sortBasis == preview.sortBasis else { throw RoutineCreateIssue.sortChanged }
        guard current == preview else { throw RoutineCreateIssue.stale }
    }

    private func sortBasis() throws -> [CommandRoutineCreateSortRow] {
        let repository = environment.dependencies.repository(environment.context)
        guard repository.routineMutationContext === environment.context else { throw RoutineCommandIssue.invalidRepository }
        let rows: [DailyRoutine]
        do { rows = try repository.fetchRoutines(includeDisabled: true, includeDeleted: true) }
        catch { throw RoutineCreateIssue.unreliableSort }
        guard Set(rows.map(\.id)).count == rows.count, rows.allSatisfy({ $0.modelContext === environment.context }) else {
            throw RoutineCreateIssue.unreliableSort
        }
        // 全表行不由界面强持有；重新物化不能把同一存储行误判成另一条定义。
        return rows.map { .init(id: $0.id, record: $0.persistentModelID, order: $0.sortOrder) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func requireAbsent(_ accepted: CommandRoutineCreateAcceptance) throws {
        let rows = try SwiftDataRoutineRepository(context: environment.context).fetchRoutines(withID: accepted.creationID)
        let catalog = try environment.reader.catalogReader.current()
        let ids = Array(accepted.tagCreationIDs.values)
        guard rows.isEmpty, Set(ids).count == ids.count, !ids.contains(accepted.creationID),
              !catalog.records.contains(where: { $0.id.map(ids.contains) ?? false }) else { throw RoutineCreateIssue.identityCollision }
    }
}
