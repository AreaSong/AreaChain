import Foundation
import SwiftData
@testable import AreaChain

struct Phase1Graph: Codable {
    var scale: Int
    var store: String
    var seedMs: Double
    var todayKey: String
    var todos: Int
    var deletedTodos: Int
    var subtasks: Int
    var routines: Int
    var deletedRoutines: Int
    var disabledRoutines: Int
    var checks: Int
    var diaries: Int
    var deletedDiaries: Int
    var privateDiaries: Int
    var tags: Int
    var deletedTags: Int
    var attachments: Int
    var deletedAttachments: Int
    var os: String
    var processorCount: Int
    var physicalMemoryBytes: UInt64
    var buildConfiguration: String
}

@MainActor
final class Phase1Corpus {
    let container: ModelContainer
    let context: ModelContext
    let graph: Phase1Graph
    let tasks: SwiftDataTaskRepository
    let routines: SwiftDataRoutineRepository
    let diaries: SwiftDataDiaryRepository
    let catalog: SwiftDataCatalogRepository
    let vault: PrivacyVault
    let todayKey: String
    let probeTodoID: UUID
    let probeRoutineID: UUID
    let probeDiaryID: UUID
    let probeTagID: UUID
    let batchIDs: Set<UUID>
    let privateDiaryIDs: Set<UUID>
    let diskRoot: URL?
    let attachmentRoot: URL

    private init(
        container: ModelContainer,
        graph: Phase1Graph,
        vault: PrivacyVault,
        files: AttachmentStore,
        todayKey: String,
        probeTodoID: UUID,
        probeRoutineID: UUID,
        probeDiaryID: UUID,
        probeTagID: UUID,
        batchIDs: Set<UUID>,
        privateDiaryIDs: Set<UUID>,
        diskRoot: URL?,
        attachmentRoot: URL
    ) {
        self.container = container
        self.context = container.mainContext
        self.graph = graph
        self.vault = vault
        self.todayKey = todayKey
        self.probeTodoID = probeTodoID
        self.probeRoutineID = probeRoutineID
        self.probeDiaryID = probeDiaryID
        self.probeTagID = probeTagID
        self.batchIDs = batchIDs
        self.privateDiaryIDs = privateDiaryIDs
        self.diskRoot = diskRoot
        self.attachmentRoot = attachmentRoot
        self.tasks = SwiftDataTaskRepository(context: context, container: container)
        self.routines = SwiftDataRoutineRepository(context: context, container: container)
        self.diaries = SwiftDataDiaryRepository(
            context: context, container: container, vault: vault, attachmentStore: files, attachmentRoot: attachmentRoot
        )
        self.catalog = SwiftDataCatalogRepository(context: context, container: container)
    }

    func cleanup() {
        if let diskRoot {
            try? FileManager.default.removeItem(at: diskRoot)
        } else {
            try? FileManager.default.removeItem(at: attachmentRoot)
        }
    }

    func freshContext() -> ModelContext {
        ModelContext(container)
    }

    static func make(scale: Int, onDisk: Bool = false) async throws -> Phase1Corpus {
        let schema = Schema(AreaChainSchema.models)
        let diskRoot: URL?
        let attachmentRoot: URL
        let configuration: ModelConfiguration
        if onDisk {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-phase1-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            diskRoot = root
            attachmentRoot = root.appendingPathComponent("attachments")
            configuration = ModelConfiguration("Phase1", schema: schema, url: root.appendingPathComponent("store"), cloudKitDatabase: .none)
        } else {
            diskRoot = nil
            attachmentRoot = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-phase1-att-\(UUID().uuidString)")
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        }
        try FileManager.default.createDirectory(at: attachmentRoot, withIntermediateDirectories: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        try await vault.create(password: "phase1-synthetic-only", systemUnlock: false)
        let files = AttachmentStore(keys: vault.keys, root: attachmentRoot)
        let seeded = try seed(scale: scale, container: container, vault: vault, store: onDisk ? "disk" : "memory")
        return Phase1Corpus(
            container: container,
            graph: seeded.graph,
            vault: vault,
            files: files,
            todayKey: seeded.todayKey,
            probeTodoID: seeded.probeTodoID,
            probeRoutineID: seeded.probeRoutineID,
            probeDiaryID: seeded.probeDiaryID,
            probeTagID: seeded.probeTagID,
            batchIDs: seeded.batchIDs,
            privateDiaryIDs: seeded.privateDiaryIDs,
            diskRoot: diskRoot,
            attachmentRoot: attachmentRoot
        )
    }

    private struct Seeded {
        var graph: Phase1Graph
        var todayKey: String
        var probeTodoID: UUID
        var probeRoutineID: UUID
        var probeDiaryID: UUID
        var probeTagID: UUID
        var batchIDs: Set<UUID>
        var privateDiaryIDs: Set<UUID>
    }

    private static func seed(scale: Int, container: ModelContainer, vault: PrivacyVault, store: String) throws -> Seeded {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let todayKey = "2026-09-27"
        let context = container.mainContext
        let started = ProcessInfo.processInfo.systemUptime
        let tags = insertTags(count: min(40, max(8, scale / 50)), context: context)
        let liveTag = tags[1 % tags.count]
        let todos = insertTodos(scale: scale, todayKey: todayKey, calendar: calendar, tagIDs: TagIDList.encode([liveTag.id]), context: context)
        let liveTodos = todos.filter { $0.deletedAt == nil }
        insertSubtasks(count: max(10, scale / 5), onto: liveTodos, context: context)
        let routineSeed = insertRoutines(
            count: min(40, max(8, scale / 50)),
            checkDays: min(90, max(14, scale / 40)),
            todayKey: todayKey,
            calendar: calendar,
            tagIDs: TagIDList.encode([liveTag.id]),
            context: context
        )
        let routines = routineSeed.routines
        let diaries = try insertDiaries(
            count: max(12, scale / 10),
            todayKey: todayKey,
            calendar: calendar,
            liveTagIDs: TagIDList.encode([liveTag.id]),
            privateTag: tags[0],
            vault: vault,
            context: context
        )
        let privateDiaryIDs = Set(diaries.prefix(3).map(\.id))
        let attachmentCount = insertAttachments(
            count: max(6, scale / 20),
            todos: liveTodos,
            routines: routines,
            diaries: diaries,
            context: context
        )
        try context.save()
        return Seeded(
            graph: makeGraph(
                GraphInput(
                    scale: scale,
                    store: store,
                    seedMs: (ProcessInfo.processInfo.systemUptime - started) * 1_000,
                    todayKey: todayKey,
                    todos: todos,
                    subtasks: max(10, scale / 5),
                    routines: routines,
                    checkCount: routineSeed.checkCount,
                    diaries: diaries,
                    tags: tags,
                    attachments: attachmentCount
                )
            ),
            todayKey: todayKey,
            probeTodoID: liveTodos[0].id,
            probeRoutineID: routines.first { $0.deletedAt == nil }!.id,
            probeDiaryID: diaries.first { $0.deletedAt == nil && !$0.hasProtectedContent }!.id,
            probeTagID: liveTag.id,
            batchIDs: Set(liveTodos.prefix(min(100, max(8, liveTodos.count / 10))).map(\.id)),
            privateDiaryIDs: privateDiaryIDs
        )
    }

    private static func insertTags(count: Int, context: ModelContext) -> [TagItem] {
        (0..<count).map { index in
            let tag = TagItem(name: "基线标签\(index)", sortOrder: index)
            if index == 0 { tag.isPrivateDiary = true }
            if index == count - 1 { tag.deletedAt = Date(timeIntervalSince1970: 1) }
            context.insert(tag)
            return tag
        }
    }

    private static func insertTodos(
        scale: Int, todayKey: String, calendar: Calendar, tagIDs: String, context: ModelContext
    ) -> [TodoItem] {
        (0..<scale).map { index in
            let todo = TodoItem(
                title: "基线待办 \(index)",
                isDone: index % 10 == 0,
                dayKey: DayKey.shifted(todayKey, by: -(index % 14), calendar: calendar),
                createdAt: Date(timeIntervalSince1970: Double(index)),
                remindMinutes: index % 10 == 1 ? 600 : nil,
                deletedAt: index % 10 == 9 ? Date(timeIntervalSince1970: 2) : nil,
                tagIDs: index % 4 == 0 ? tagIDs : "",
                isImportant: index % 7 == 0,
                notes: index % 11 == 0 ? "备注 \(index)" : ""
            )
            context.insert(todo)
            return todo
        }
    }

    private static func insertSubtasks(count: Int, onto todos: [TodoItem], context: ModelContext) {
        for index in 0..<count {
            context.insert(
                SubtaskItem(
                    title: "子任务 \(index)",
                    isDone: index % 5 == 0,
                    sortOrder: index,
                    deletedAt: index % 10 == 9 ? Date(timeIntervalSince1970: 3) : nil,
                    todo: todos[index % todos.count]
                )
            )
        }
    }

    private static func insertRoutines(
        count: Int, checkDays: Int, todayKey: String, calendar: Calendar, tagIDs: String, context: ModelContext
    ) -> (routines: [DailyRoutine], checkCount: Int) {
        let created = DayKey.shifted(todayKey, by: -(checkDays - 1), calendar: calendar)
        var checkCount = 0
        let routines: [DailyRoutine] = (0..<count).map { index in
            let routine = DailyRoutine(
                title: "基线习惯 \(index)",
                sortOrder: index,
                isEnabled: index % 10 != 3,
                createdDayKey: created,
                weekdayMask: WeekdayMask.all,
                remindMinutes: index % 5 == 0 ? 480 : nil,
                deletedAt: index % 20 == 19 ? Date(timeIntervalSince1970: 4) : nil,
                tagIDs: index % 3 == 0 ? tagIDs : "",
                pausedOnDayKey: index % 10 == 3 ? todayKey : nil
            )
            context.insert(routine)
            if routine.deletedAt == nil {
                for offset in 0..<checkDays {
                    let skipped = offset % 9 == 0
                    context.insert(
                        RoutineCheck(
                            dayKey: DayKey.shifted(todayKey, by: -offset, calendar: calendar),
                            isDone: skipped || offset % 3 != 2,
                            isSkipped: skipped,
                            routine: routine
                        )
                    )
                    checkCount += 1
                }
            }
            return routine
        }
        return (routines, checkCount)
    }

    private static func insertDiaries(
        count: Int,
        todayKey: String,
        calendar: Calendar,
        liveTagIDs: String,
        privateTag: TagItem,
        vault: PrivacyVault,
        context: ModelContext
    ) throws -> [DiaryEntry] {
        var diaries: [DiaryEntry] = []
        for index in 0..<count {
            let entry = DiaryEntry(
                text: "合成手记 \(index) 关键词baseline",
                dayKey: DayKey.shifted(todayKey, by: -(index % 21), calendar: calendar),
                createdAt: Date(timeIntervalSince1970: Double(1_000 + index)),
                deletedAt: index % 10 == 9 ? Date(timeIntervalSince1970: 5) : nil,
                tagIDs: index % 5 == 0 ? liveTagIDs : ""
            )
            context.insert(entry)
            if index < 3 {
                entry.tagIDs = TagIDList.encode([privateTag.id])
                try DiaryContent.write("私密合成正文 \(index)", to: entry, protect: true, vault: vault)
            }
            diaries.append(entry)
        }
        return diaries
    }

    private static func insertAttachments(
        count: Int, todos: [TodoItem], routines: [DailyRoutine], diaries: [DiaryEntry], context: ModelContext
    ) -> (total: Int, deleted: Int) {
        let liveRoutine = routines.first { $0.deletedAt == nil }
        let liveDiary = diaries.first { $0.deletedAt == nil }
        let owners: [(AttachmentOwner, UUID)] = todos.prefix(count).enumerated().map { index, todo in
            if index % 3 == 1, let routine = liveRoutine { return (.routine, routine.id) }
            if index % 3 == 2, let diary = liveDiary { return (.diary, diary.id) }
            return (.todo, todo.id)
        }
        var deleted = 0
        for (index, owner) in owners.enumerated() {
            let item = AttachmentItem(
                ownerKind: owner.0.rawValue,
                ownerID: owner.1,
                filename: "synthetic-\(index).png",
                deletedAt: index == 0 || index % 10 == 9 ? Date(timeIntervalSince1970: 6) : nil
            )
            if item.deletedAt != nil { deleted += 1 }
            context.insert(item)
        }
        return (owners.count, deleted)
    }

    private struct GraphInput {
        var scale: Int
        var store: String
        var seedMs: Double
        var todayKey: String
        var todos: [TodoItem]
        var subtasks: Int
        var routines: [DailyRoutine]
        var checkCount: Int
        var diaries: [DiaryEntry]
        var tags: [TagItem]
        var attachments: (total: Int, deleted: Int)
    }

    private static func makeGraph(_ input: GraphInput) -> Phase1Graph {
        let info = ProcessInfo.processInfo
        let liveRoutines = input.routines.filter { $0.deletedAt == nil }
        return Phase1Graph(
            scale: input.scale,
            store: input.store,
            seedMs: Phase1Clock.roundMs(input.seedMs),
            todayKey: input.todayKey,
            todos: input.todos.count,
            deletedTodos: input.todos.filter { $0.deletedAt != nil }.count,
            subtasks: input.subtasks,
            routines: input.routines.count,
            deletedRoutines: input.routines.count - liveRoutines.count,
            disabledRoutines: liveRoutines.filter { !$0.isEnabled }.count,
            checks: input.checkCount,
            diaries: input.diaries.count,
            deletedDiaries: input.diaries.filter { $0.deletedAt != nil }.count,
            privateDiaries: min(3, input.diaries.count),
            tags: input.tags.count,
            deletedTags: input.tags.filter { $0.deletedAt != nil }.count,
            attachments: input.attachments.total,
            deletedAttachments: input.attachments.deleted,
            os: info.operatingSystemVersionString,
            processorCount: info.processorCount,
            physicalMemoryBytes: info.physicalMemory,
            buildConfiguration: "Debug"
        )
    }
}
