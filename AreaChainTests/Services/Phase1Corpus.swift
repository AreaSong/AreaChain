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
    let diskRoot: URL?

    private init(
        container: ModelContainer,
        graph: Phase1Graph,
        vault: PrivacyVault,
        todayKey: String,
        probeTodoID: UUID,
        probeRoutineID: UUID,
        probeDiaryID: UUID,
        probeTagID: UUID,
        batchIDs: Set<UUID>,
        diskRoot: URL?
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
        self.diskRoot = diskRoot
        self.tasks = SwiftDataTaskRepository(context: context, container: container)
        self.routines = SwiftDataRoutineRepository(context: context, container: container)
        self.diaries = SwiftDataDiaryRepository(context: context, container: container, vault: vault)
        self.catalog = SwiftDataCatalogRepository(context: context, container: container)
    }

    func cleanup() {
        if let diskRoot {
            try? FileManager.default.removeItem(at: diskRoot)
        }
    }

    func freshContext() -> ModelContext {
        ModelContext(container)
    }

    static func make(scale: Int, onDisk: Bool = false) async throws -> Phase1Corpus {
        let schema = Schema(AreaChainSchema.models)
        let diskRoot: URL?
        let configuration: ModelConfiguration
        if onDisk {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-phase1-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            diskRoot = root
            configuration = ModelConfiguration("Phase1", schema: schema, url: root.appendingPathComponent("store"), cloudKitDatabase: .none)
        } else {
            diskRoot = nil
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        }
        let container = try ModelContainer(for: schema, configurations: configuration)
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        try await vault.create(password: "phase1-synthetic-only", systemUnlock: false)
        let seeded = try seed(scale: scale, container: container, vault: vault, store: onDisk ? "disk" : "memory")
        return Phase1Corpus(
            container: container,
            graph: seeded.graph,
            vault: vault,
            todayKey: seeded.todayKey,
            probeTodoID: seeded.probeTodoID,
            probeRoutineID: seeded.probeRoutineID,
            probeDiaryID: seeded.probeDiaryID,
            probeTagID: seeded.probeTagID,
            batchIDs: seeded.batchIDs,
            diskRoot: diskRoot
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
    }

    // swiftlint:disable:next function_body_length
    private static func seed(scale: Int, container: ModelContainer, vault: PrivacyVault, store: String) throws -> Seeded {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let todayKey = "2026-09-27"
        let context = container.mainContext
        let started = ProcessInfo.processInfo.systemUptime
        let routineCount = min(40, max(8, scale / 50))
        let checkDays = min(90, max(14, scale / 40))
        let diaryCount = max(12, scale / 10)
        let tagCount = min(40, max(8, scale / 50))
        let subtaskCount = max(10, scale / 5)
        let attachmentCount = max(6, scale / 20)

        var tags: [TagItem] = []
        for index in 0..<tagCount {
            let tag = TagItem(name: "基线标签\(index)", sortOrder: index)
            if index == 0 { tag.isPrivateDiary = true }
            if index == tagCount - 1 { tag.deletedAt = Date(timeIntervalSince1970: 1) }
            context.insert(tag)
            tags.append(tag)
        }
        let liveTag = tags[1 % tags.count]
        let privateTag = tags[0]
        let tagIDs = TagIDList.encode([liveTag.id])

        var todos: [TodoItem] = []
        todos.reserveCapacity(scale)
        for index in 0..<scale {
            let day = DayKey.shifted(todayKey, by: -(index % 14), calendar: calendar)
            let todo = TodoItem(
                title: "基线待办 \(index)",
                isDone: index % 10 == 0,
                dayKey: day,
                createdAt: Date(timeIntervalSince1970: Double(index)),
                remindMinutes: index % 10 == 1 ? 600 : nil,
                deletedAt: index % 10 == 9 ? Date(timeIntervalSince1970: 2) : nil,
                tagIDs: index % 4 == 0 ? tagIDs : "",
                isImportant: index % 7 == 0,
                notes: index % 11 == 0 ? "备注 \(index)" : ""
            )
            context.insert(todo)
            todos.append(todo)
        }
        let liveTodos = todos.filter { $0.deletedAt == nil }
        for index in 0..<subtaskCount {
            let parent = liveTodos[index % liveTodos.count]
            let sub = SubtaskItem(
                title: "子任务 \(index)",
                isDone: index % 5 == 0,
                sortOrder: index,
                deletedAt: index % 10 == 9 ? Date(timeIntervalSince1970: 3) : nil,
                todo: parent
            )
            context.insert(sub)
        }

        var routines: [DailyRoutine] = []
        var checkCount = 0
        let created = DayKey.shifted(todayKey, by: -(checkDays - 1), calendar: calendar)
        for index in 0..<routineCount {
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
            routines.append(routine)
            guard routine.deletedAt == nil else { continue }
            for offset in 0..<checkDays {
                let key = DayKey.shifted(todayKey, by: -offset, calendar: calendar)
                let skipped = offset % 9 == 0
                let done = skipped || offset % 3 != 2
                context.insert(RoutineCheck(dayKey: key, isDone: done, isSkipped: skipped, routine: routine))
                checkCount += 1
            }
        }

        var diaries: [DiaryEntry] = []
        var privateDiaries = 0
        for index in 0..<diaryCount {
            let day = DayKey.shifted(todayKey, by: -(index % 21), calendar: calendar)
            let entry = DiaryEntry(
                text: "合成手记 \(index) 关键词baseline",
                dayKey: day,
                createdAt: Date(timeIntervalSince1970: Double(1_000 + index)),
                deletedAt: index % 10 == 9 ? Date(timeIntervalSince1970: 5) : nil,
                tagIDs: index % 5 == 0 ? tagIDs : ""
            )
            context.insert(entry)
            if index < 3 {
                entry.tagIDs = TagIDList.encode([privateTag.id])
                try DiaryContent.write("私密合成正文 \(index)", to: entry, protect: true, vault: vault)
                privateDiaries += 1
            }
            diaries.append(entry)
        }

        var deletedAttachments = 0
        let owners: [(AttachmentOwner, UUID)] = liveTodos.prefix(attachmentCount).enumerated().map { index, todo in
            if index % 3 == 1, let routine = routines.first(where: { $0.deletedAt == nil }) {
                return (.routine, routine.id)
            }
            if index % 3 == 2, let diary = diaries.first(where: { $0.deletedAt == nil }) {
                return (.diary, diary.id)
            }
            return (.todo, todo.id)
        }
        for (index, owner) in owners.enumerated() {
            let item = AttachmentItem(
                ownerKind: owner.0.rawValue,
                ownerID: owner.1,
                filename: "synthetic-\(index).png",
                deletedAt: index == 0 || index % 10 == 9 ? Date(timeIntervalSince1970: 6) : nil
            )
            if item.deletedAt != nil { deletedAttachments += 1 }
            context.insert(item)
        }

        try context.save()
        let seedMs = (ProcessInfo.processInfo.systemUptime - started) * 1_000
        let info = ProcessInfo.processInfo
        let probeTodo = liveTodos[0]
        let probeRoutine = routines.first { $0.deletedAt == nil }!
        let probeDiary = diaries.first { $0.deletedAt == nil && !$0.hasProtectedContent }!
        let batchSize = min(100, max(8, liveTodos.count / 10))
        let graph = Phase1Graph(
            scale: scale,
            store: store,
            seedMs: Phase1Clock.roundMs(seedMs),
            todayKey: todayKey,
            todos: todos.count,
            deletedTodos: todos.filter { $0.deletedAt != nil }.count,
            subtasks: subtaskCount,
            routines: routines.count,
            deletedRoutines: routines.filter { $0.deletedAt != nil }.count,
            disabledRoutines: routines.filter { $0.deletedAt == nil && !$0.isEnabled }.count,
            checks: checkCount,
            diaries: diaries.count,
            deletedDiaries: diaries.filter { $0.deletedAt != nil }.count,
            privateDiaries: privateDiaries,
            tags: tags.count,
            deletedTags: tags.filter { $0.deletedAt != nil }.count,
            attachments: owners.count,
            deletedAttachments: deletedAttachments,
            os: info.operatingSystemVersionString,
            processorCount: info.processorCount,
            physicalMemoryBytes: info.physicalMemory,
            buildConfiguration: "Debug"
        )
        return Seeded(
            graph: graph,
            todayKey: todayKey,
            probeTodoID: probeTodo.id,
            probeRoutineID: probeRoutine.id,
            probeDiaryID: probeDiary.id,
            probeTagID: liveTag.id,
            batchIDs: Set(liveTodos.prefix(batchSize).map(\.id))
        )
    }
}
