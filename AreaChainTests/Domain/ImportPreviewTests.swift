import Foundation
import Testing
@testable import AreaChain

struct ImportPreviewTests {
    @Test func splitsNewAndUpdate() {
        let existingTodo = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let snapshot = ExportSnapshot(
            exportedAt: Date(timeIntervalSince1970: 1),
            routines: [
                ExportedRoutine(
                    id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                    title: "新例行",
                    sortOrder: 0,
                    isEnabled: true,
                    createdDayKey: "2026-09-01"
                )
            ],
            checks: [],
            todos: [
                ExportedTodo(
                    id: existingTodo,
                    title: "覆盖",
                    isDone: false,
                    dayKey: "2026-09-07",
                    createdAt: Date(timeIntervalSince1970: 2)
                )
            ],
            diaries: []
        )
        let preview = ImportPreviewing.preview(
            snapshot,
            existing: ExistingIDs(
                routines: [],
                todos: [existingTodo],
                diaries: [],
                checks: []
            )
        )
        #expect(preview.routinesNew == 1)
        #expect(preview.routinesUpdate == 0)
        #expect(preview.todosNew == 0)
        #expect(preview.todosUpdate == 1)
        #expect(preview.totalWrites == 2)
        let chinese = preview.summary(locale: Locale(identifier: "zh-Hans"))
        #expect(chinese.contains("例行"))
        #expect(chinese.contains("新增 1"))
        let english = preview.summary(locale: Locale(identifier: "en"))
        #expect(english.contains("Routines"))
        #expect(english.contains("new 1"))
    }
}
