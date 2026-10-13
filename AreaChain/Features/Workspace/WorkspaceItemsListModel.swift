import Foundation
import SwiftData

/// 工作台清单一次 body 求值内复用的行表、打卡索引和目录。
/// 失效条件：groups / checks / tags / attachments / todayKey 变化。不是跨 body 的可变缓存。
@MainActor
struct WorkspaceItemsListIdentity {
    let entries: [WorkspaceItemEntry]
    let entryIDs: [UUID]
    let checkIndex: DayBoardCheckIndex
    let checksByRoutine: [UUID: [CheckSnapshot]]
    let catalogs: TaskCatalogContext
    let streaks: [UUID: Int]
    let checks: [RoutineCheck]
    let todayKey: String
    let locale: Locale

    private let entriesByID: [UUID: WorkspaceItemEntry]

    func entry(_ id: UUID) -> WorkspaceItemEntry? { entriesByID[id] }

    var checkDaySignature: String {
        entries.map { "\($0.modelID.uuidString):\($0.checkDayKey):\($0.allowsCompletion)" }.joined(separator: "|")
    }

    func routineLookups(for id: UUID) -> RoutineDisplayLookups {
        RoutineDisplayLookups(
            checkIndex: checkIndex,
            currentStreak: streaks[id],
            routineCheckSnaps: checksByRoutine[id] ?? []
        )
    }

    private struct CacheKey: Equatable {
        let entryIDs: [UUID]
        let checksCount: Int
        let checksFingerprint: Int
        let tagsCount: Int
        let attachmentsCount: Int
        let todayKey: String
        let localeID: String
    }

    private static var cachedKey: CacheKey?
    private static var cachedIdentity: WorkspaceItemsListIdentity?

    static func make(
        groups: [WorkspaceItemGroup],
        todayKey: String,
        checks: [RoutineCheck],
        tags: [TagItem],
        attachments: [AttachmentItem],
        context: ModelContext,
        locale: Locale
    ) -> WorkspaceItemsListIdentity {
        let entries = groups.flatMap(\.entries)
        let entryIDs = entries.map(\.modelID)

        var hasher = Hasher()
        for check in checks {
            hasher.combine(check.id)
            hasher.combine(check.isDone)
            hasher.combine(check.isSkipped)
            hasher.combine(check.completedSubtaskIDs)
            hasher.combine(check.dayKey)
        }
        let checksFingerprint = hasher.finalize()

        let key = CacheKey(
            entryIDs: entryIDs,
            checksCount: checks.count,
            checksFingerprint: checksFingerprint,
            tagsCount: tags.count,
            attachmentsCount: attachments.count,
            todayKey: todayKey,
            localeID: locale.identifier
        )

        if cachedKey == key, let cachedIdentity {
            return cachedIdentity
        }

        let entriesByID = Dictionary(entries.map { ($0.modelID, $0) }, uniquingKeysWith: { first, _ in first })
        let checkSnaps = checks.compactMap(\.snapshot)
        let checkIndex = DayBoardCheckIndex(checkSnaps)
        let checksByRoutine = Dictionary(grouping: checkSnaps, by: \.routineId)
        let routineSnaps = entries.compactMap { entry -> RoutineSnapshot? in
            guard case .routine(let routine, _, _, _, _) = entry else { return nil }
            return routine.snapshot
        }
        let result = WorkspaceItemsListIdentity(
            entries: entries,
            entryIDs: entryIDs,
            checkIndex: checkIndex,
            checksByRoutine: checksByRoutine,
            catalogs: TaskCatalogContext(tags: tags, attachments: attachments, context: context),
            streaks: DayBoardPageProjection.currentStreaks(
                routines: routineSnaps,
                checksByRoutine: checksByRoutine,
                todayKey: todayKey
            ),
            checks: checks,
            todayKey: todayKey,
            locale: locale,
            entriesByID: entriesByID
        )
        cachedKey = key
        cachedIdentity = result
        return result
    }
}
