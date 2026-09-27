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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        fixture.calendar = calendar
        fixture.client.normalize = { content in
            content.normalizedForScheduling(calendar: fixture.calendar) ?? content
        }
        fixture.tasks = todos.map { todo in
            CalendarLocalItem(
                id: todo.id,
                state: CalendarLocalState(
                    content: CalendarContent(title: todo.title, dayKey: todo.dayKey, remindMinutes: todo.remindMinutes),
                    isPublished: todo.deletedAt == nil && !todo.isDone
                ),
                eventID: ""
            )
        }
        let before = Phase1Clock.probe()
        _ = await fixture.engine.synchronize { true }
        let after = Phase1Clock.probe()
        let timing = Phase1Clock.delta(before, after)
        guard fixture.client.batchCount > 0 else {
            throw Phase1ContractError.message("假日历 synchronize 没有 apply，写入路径未热起来")
        }
        try Phase1Measure.writeSingle(
            scenario: "fanout.calendarFakeSynchronize",
            corpus: corpus,
            timing: timing,
            work: Phase1Work(rows: fixture.tasks.count, fetchCalls: 0, computeWallMs: timing.wallMs),
            extraCalls: [
                "authorize": fixture.client.authorizationCount,
                "calendarID": fixture.client.calendarCount,
                "applyBatches": fixture.client.batchCount,
                "create": fixture.client.createCount,
                "didSave": fixture.didSaveCount
            ],
            notes: "CalendarSyncEngine.synchronize + FakeCalendarClient。computeWall≈wall；不是 EventKit。",
            memory: Phase1MemoryMark(
                rssBefore: before.rss,
                rssAfter: after.rss,
                rssPeakBefore: before.rssPeak,
                rssPeakAfter: after.rssPeak,
                rssLoopMax: max(before.rss, after.rss),
                footprintBefore: before.footprint,
                footprintAfter: after.footprint
            )
        )
    }

    private static func measureSnapshots(_ corpus: Phase1Corpus) throws {
        try assertOrdinaryExportOmitsPrivateDiaries(corpus)
        try Phase1Measure.record(
            scenario: "snapshot.exportOrdinaryJSON",
            corpus: corpus,
            notes: "fetchWall=七表 SnapshotImportState；computeWall=makeSnapshot+encode。resultRows 是排除私密后的手记条数。"
        ) {
            try Phase1Work.splitting(fetchCalls: 7, fetch: {
                try SnapshotImportState(context: corpus.context)
            }, compute: { state in
                let snapshot = SyncPort.makeSnapshot(
                    routines: state.routines,
                    checks: state.checks,
                    todos: state.todos,
                    diaries: state.diaries,
                    tags: state.tags,
                    attachments: state.attachments
                )
                _ = try SyncPort.encode(snapshot)
                return snapshot.diaries.count
            })
        }
        let snapshot = try encodeOrdinary(corpus).0
        try Phase1Measure.record(
            scenario: "snapshot.validateExisting",
            corpus: corpus,
            notes: "对已生成快照做 validate：另一次 SnapshotImportState 七表 fetch，不含 encode。"
        ) {
            try SnapshotImportState(context: corpus.context).validate(snapshot)
            return Phase1Work(rows: snapshot.todos.count, fetchCalls: 7)
        }
        let samples = corpus.graph.scale >= 10_000 ? 3 : Phase1Measure.samples
        try Phase1Measure.record(
            scenario: "snapshot.importApplyEmpty",
            corpus: corpus,
            notes: "每次向新的空内存库 apply。SnapshotImportState 7 次 + checks upsert 的 DailyRoutine fetch。不改 corpus。",
            samples: samples
        ) {
            let schema = Schema(AreaChainSchema.models)
            let empty = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            try SnapshotImporter.apply(snapshot, context: empty.mainContext)
            return Phase1Work(rows: snapshot.todos.count, fetchCalls: 8)
        }
    }

    private static func assertOrdinaryExportOmitsPrivateDiaries(_ corpus: Phase1Corpus) throws {
        let exported = Set(try encodeOrdinary(corpus).0.diaries.map(\.id))
        guard corpus.privateDiaryIDs.isDisjoint(with: exported) else {
            throw Phase1ContractError.message("普通 JSON 导出了私密手记")
        }
        guard !corpus.privateDiaryIDs.isEmpty else {
            throw Phase1ContractError.message("语料缺少私密手记，无法核对导出过滤")
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
            notes: "PrivateBackupCapture.capture：七表 + 每条明文手记 DiaryContent.read 再 fetch 标签。附件只有元数据。Fake 金库。"
        ) {
            let captured = try PrivateBackupCapture.capture(context: corpus.context, vault: corpus.vault)
            let plaintextReads = corpus.graph.diaries - corpus.graph.privateDiaries
            return Phase1Work(rows: captured.manifest.snapshot.todos.count, fetchCalls: 7 + plaintextReads)
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
        let before = Phase1Clock.probe()
        try await PrivateBackupService.restore(
            from: url, password: "phase1-backup-pass", environment: destination.environment
        )
        let after = Phase1Clock.probe()
        let timing = Phase1Clock.delta(before, after)
        try Phase1Measure.writeSingle(
            scenario: "backup.restore.smallFixture",
            corpus: corpus,
            timing: timing,
            work: Phase1Work(rows: 1, fetchCalls: 0, computeWallMs: timing.wallMs),
            extraCalls: [:],
            notes: "独立 PrivacyFixture 小库导出再恢复，不是 100 条全图。不含真实钥匙串。未再拆 IO/算法。",
            memory: Phase1MemoryMark(
                rssBefore: before.rss,
                rssAfter: after.rss,
                rssPeakBefore: before.rssPeak,
                rssPeakAfter: after.rssPeak,
                rssLoopMax: max(before.rss, after.rss),
                footprintBefore: before.footprint,
                footprintAfter: after.footprint
            )
        )
    }
}
