import Foundation
import Testing
@testable import AreaChain

struct WorkspaceAttachmentSearchTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test func filenameUsesTextKeywordsOnly() {
        #expect(WorkspaceAttachmentQuery.matches(filename: "Quarter Report.pdf", query: "report #家 !p1"))
        #expect(WorkspaceAttachmentQuery.matches(filename: "Quarter Report.pdf", query: "report #家"))
        #expect(WorkspaceAttachmentQuery.matches(filename: "Quarter Report.pdf", query: "report @15:30"))
        #expect(WorkspaceAttachmentQuery.matches(filename: "Quarter Report.pdf", query: "quarter report"))
        #expect(!WorkspaceAttachmentQuery.matches(filename: "notes.pdf", query: "report #家"))
        #expect(!WorkspaceAttachmentQuery.matches(filename: "Quarter Report.pdf", query: "#家"))
        #expect(!WorkspaceAttachmentQuery.matches(filename: "Quarter Report.pdf", query: "!p1"))
        #expect(!WorkspaceAttachmentQuery.matches(filename: "Quarter Report.pdf", query: "   "))
        #expect(!WorkspaceAttachmentQuery.matches(filename: "#家.txt", query: "#家"))
    }

    @Test func attachmentOpensOnTheOwnerDay() {
        let today = "2026-09-07"
        let todoID = UUID()
        let routineID = UUID()
        let todo = TodoSnapshot(id: todoID, title: "周五", isDone: false, dayKey: "2026-09-11")
        let weekend = RoutineSnapshot(
            id: routineID, title: "周末", sortOrder: 0, isEnabled: true,
            createdDayKey: "2026-09-01", weekdayMask: 1 | 64
        )
        let todoTarget = WorkspaceAttachmentQuery.inspectionTarget(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: todoID,
            todos: [todo], routines: [weekend], todayKey: today, calendar: calendar
        )
        #expect(todoTarget?.id == todoID)
        #expect(todoTarget?.dayKey == "2026-09-11")

        #expect(!DayBoardLogic.isRoutineDue(weekend, on: today, calendar: calendar))
        let routineTarget = WorkspaceAttachmentQuery.inspectionTarget(
            ownerKind: AttachmentOwner.routine.rawValue, ownerID: routineID,
            todos: [todo], routines: [weekend], todayKey: today, calendar: calendar
        )
        #expect(routineTarget?.id == routineID)
        #expect(routineTarget?.dayKey == AgendaProjection.inspectionDay(
            for: weekend, todayKey: today, calendar: calendar
        ))
        #expect(routineTarget?.dayKey != today)

        #expect(WorkspaceAttachmentQuery.inspectionTarget(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: todoID,
            todos: [TodoSnapshot(id: todoID, title: "删", isDone: false, dayKey: today, deletedAt: Date())],
            routines: [], todayKey: today, calendar: calendar
        ) == nil)
        #expect(WorkspaceAttachmentQuery.inspectionTarget(
            ownerKind: AttachmentOwner.diary.rawValue, ownerID: UUID(),
            todos: [todo], routines: [weekend], todayKey: today, calendar: calendar
        ) == nil)
    }
}
