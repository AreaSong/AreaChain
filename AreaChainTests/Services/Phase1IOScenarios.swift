import Foundation
import SwiftData
@testable import AreaChain

@MainActor
enum Phase1IOScenarios {
    static func run(on corpus: Phase1Corpus) async throws {
        try await measureCalendar(corpus)
        try measureSnapshots(corpus)
        try measureBackupCapture(corpus)
        if corpus.graph.scale == 100, corpus.graph.store == "memory" {
            try await measureBackupRestore(corpus)
        }
    }

    private static func measureCalendar(_ corpus: Phase1Corpus) async throws {
        let todos = try corpus.tasks.fetchAllTodos(includeDeleted: false).filter { $0.remindMinutes != nil }
        let fixture = CalendarSyncFixture()
        fixture.tasks = todos.map { todo in
            CalendarLocalItem(
                id: todo.id,
                state: CalendarLocalState(
                    content: CalendarContent(title: todo.title, dayKey: todo.dayKey, remindMinutes: todo.remindMinutes),
                    isPublished: false
                ),
                eventID: ""
            )
        }
        let start = ProcessInfo.processInfo.systemUptime
        _ = await fixture.engine.synchronize { true }
        let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1_000
        try Phase1Measure.writeSingle(
            scenario: "fanout.calendarFakeSynchronize",
            corpus: corpus,
            elapsedMs: elapsed,
            fetchCalls: 0,
            resultRows: fixture.tasks.count,
            extraCalls: [
                "authorize": fixture.client.authorizationCount,
                "calendarID": fixture.client.calendarCount,
                "applyBatches": fixture.client.batchCount,
                "create": fixture.client.createCount,
                "didSave": fixture.didSaveCount
            ],
            notes: "CalendarSyncEngine.synchronize + FakeCalendarClient。不是 EventKit；生产 CalendarSync.refreshIfEnabled 在 XCTest 被跳过。单次，p50/p95 等于该次。"
        )
    }

    private static func measureSnapshots(_ corpus: Phase1Corpus) throws {
        try Phase1Measure.record(
            scenario: "snapshot.exportOrdinaryJSON",
            corpus: corpus,
            fetchCalls: 7,
            resultRows: 0,
            notes: "SnapshotImportState 七表 fetch + SyncPort.makeSnapshot + encode。普通 JSON 排除私密手记。"
        ) {
            try encodeOrdinary(corpus).1
        }
        try Phase1Measure.record(
            scenario: "snapshot.validateExisting",
            corpus: corpus,
            fetchCalls: 7,
            resultRows: 0,
            notes: "对当前库生成的快照做 validate，不写入。"
        ) {
            let snapshot = try encodeOrdinary(corpus).0
            try SnapshotImportState(context: corpus.context).validate(snapshot)
            return snapshot.todos.count
        }
        let snapshot = try encodeOrdinary(corpus).0
        let samples = corpus.graph.scale >= 10_000 ? 3 : Phase1Measure.samples
        try Phase1Measure.record(
            scenario: "snapshot.importApplyEmpty",
            corpus: corpus,
            fetchCalls: 8,
            resultRows: snapshot.todos.count,
            notes: "每次向新的空内存库 apply。含 checks upsert 的额外 DailyRoutine fetch。不改 corpus。",
            samples: samples
        ) {
            let schema = Schema(AreaChainSchema.models)
            let empty = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            try SnapshotImporter.apply(snapshot, context: empty.mainContext)
            return try empty.mainContext.fetchCount(FetchDescriptor<TodoItem>())
        }
    }

    private static func encodeOrdinary(_ corpus: Phase1Corpus) throws -> (ExportSnapshot, Int) {
        let state = try SnapshotImportState(context: corpus.context)
        let snapshot = SyncPort.makeSnapshot(
            routines: state.routines,
            checks: state.checks,
            todos: state.todos,
            diaries: state.diaries,
            tags: state.tags,
            attachments: state.attachments
        )
        let data = try SyncPort.encode(snapshot)
        return (snapshot, data.count)
    }

    private static func measureBackupCapture(_ corpus: Phase1Corpus) throws {
        try Phase1Measure.record(
            scenario: "backup.capture",
            corpus: corpus,
            fetchCalls: 7,
            resultRows: 0,
            notes: "PrivateBackupCapture.capture：七表 + 解密私密正文。附件只有元数据。Fake 金库。"
        ) {
            try PrivateBackupCapture.capture(context: corpus.context, vault: corpus.vault).manifest.snapshot.todos.count
        }
    }

    private static func measureBackupRestore(_ corpus: Phase1Corpus) async throws {
        let source = try await PrivacyFixture.make(password: "phase1-backup-source")
        let destination = try await PrivacyFixture.make(password: "phase1-backup-dest")
        defer {
            source.cleanup()
            destination.cleanup()
        }
        let tag = try source.tag()
        _ = try source.repository.addDiary(text: "PHASE1_RESTORE_PRIVATE", dayKey: corpus.todayKey, tagIDs: [tag.id])
        source.context.insert(TodoItem(title: "恢复基线待办", dayKey: corpus.todayKey))
        try source.context.save()
        let url = source.root.appending(path: "phase1.areachainbackup")
        _ = try await PrivateBackupService.export(
            to: url, password: "phase1-backup-pass", environment: source.environment
        )
        let start = ProcessInfo.processInfo.systemUptime
        try await PrivateBackupService.restore(
            from: url, password: "phase1-backup-pass", environment: destination.environment
        )
        let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1_000
        try Phase1Measure.writeSingle(
            scenario: "backup.restore.smallFixture",
            corpus: corpus,
            elapsedMs: elapsed,
            fetchCalls: 0,
            resultRows: 1,
            extraCalls: [:],
            notes: "独立 PrivacyFixture 小库导出再恢复，不是 100 条全图。不含真实钥匙串。单次。"
        )
    }
}
