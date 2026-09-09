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

    @Test func countsProjectsTagsAndAttachments() {
        let existingProject = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let snapshot = ExportSnapshot(
            exportedAt: Date(timeIntervalSince1970: 1),
            routines: [],
            checks: [],
            todos: [],
            diaries: [],
            projects: [
                ExportedProject(id: existingProject, name: "工作", sortOrder: 0),
                ExportedProject(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    name: "生活",
                    sortOrder: 1
                )
            ],
            tags: [
                ExportedTag(
                    id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    name: "急",
                    sortOrder: 0
                )
            ],
            attachments: [
                ExportedAttachment(
                    id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                    ownerKind: AttachmentOwner.todo.rawValue,
                    ownerID: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                    filename: "a.png",
                    createdAt: Date(timeIntervalSince1970: 2)
                )
            ]
        )
        let preview = ImportPreviewing.preview(
            snapshot,
            existing: ExistingIDs(
                routines: [],
                todos: [],
                diaries: [],
                checks: [],
                projects: [existingProject],
                tags: [],
                attachments: []
            )
        )
        #expect(preview.projectsNew == 1)
        #expect(preview.projectsUpdate == 1)
        #expect(preview.tagsNew == 1)
        #expect(preview.attachmentsNew == 1)
        #expect(preview.totalWrites == 4)
        let chinese = preview.summary(locale: Locale(identifier: "zh-Hans"))
        #expect(chinese.contains("项目"))
        #expect(chinese.contains("标签"))
        #expect(chinese.contains("附件"))
    }
}
