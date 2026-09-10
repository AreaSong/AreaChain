import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct SwiftDataRoutineRepositoryTests {
    private func makeRepo() throws -> (ModelContainer, SwiftDataRoutineRepository) {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, SwiftDataRoutineRepository(container: container))
    }

    @Test func missingRoutineThrowsNotFound() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let nonExistentID = UUID()

        #expect(throws: RepositoryError.self) { try repo.updateRoutine(id: nonExistentID, title: "x", notes: nil) }
        #expect(throws: RepositoryError.self) {
            try repo.setRoutineEnabled(id: nonExistentID, enabled: false, todayKey: "2026-09-10")
        }
        #expect(throws: RepositoryError.self) { try repo.setWeekdayMask(id: nonExistentID, mask: 127) }
        #expect(throws: RepositoryError.self) { try repo.setRemind(id: nonExistentID, minutes: 10) }
        #expect(throws: RepositoryError.self) {
            try repo.setPriority(id: nonExistentID, isImportant: true, isUrgent: false)
        }
        #expect(throws: RepositoryError.self) { try repo.setProject(id: nonExistentID, projectID: UUID()) }
        #expect(throws: RepositoryError.self) { try repo.toggleTag(id: nonExistentID, tagID: UUID()) }
        #expect(throws: RepositoryError.self) { try repo.toggleRoutine(id: nonExistentID, dayKey: "2026-09-10") }
        #expect(throws: RepositoryError.self) { try repo.skipRoutine(id: nonExistentID, dayKey: "2026-09-10") }
        #expect(throws: RepositoryError.self) { try repo.deleteRoutine(id: nonExistentID, soft: true) }
        #expect(throws: RepositoryError.self) { try repo.restoreRoutine(id: nonExistentID) }
        #expect(throws: RepositoryError.self) { try repo.purgeRoutine(id: nonExistentID) }
    }

    @Test func blankRoutineTitleThrowsInvalidArgument() throws {
        let (container, repo) = try makeRepo()
        _ = container
        #expect(throws: RepositoryError.self) { try repo.addRoutine(title: "   ") }
        #expect(throws: RepositoryError.self) { try repo.addRoutine(title: "\n\t") }

        let routine = try repo.addRoutine(title: "Morning Routine")
        #expect(throws: RepositoryError.self) {
            try repo.updateRoutine(id: routine.id, title: "   ", notes: nil)
        }
    }

    @Test func routineCheckTogglesAndSkips() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let routine = try repo.addRoutine(title: "Workout")
        let day = "2026-09-10"

        try repo.toggleRoutine(id: routine.id, dayKey: day)
        var checks = try repo.fetchChecks(for: routine.id)
        #expect(checks.count == 1)
        #expect(checks.first?.isDone == true && checks.first?.isSkipped == false)

        try repo.toggleRoutine(id: routine.id, dayKey: day)
        checks = try repo.fetchChecks(for: routine.id)
        #expect(checks.first?.isDone == false && checks.first?.isSkipped == false)

        try repo.skipRoutine(id: routine.id, dayKey: day)
        checks = try repo.fetchChecks(for: routine.id)
        #expect(checks.first?.isDone == true && checks.first?.isSkipped == true)

        try repo.toggleRoutine(id: routine.id, dayKey: day)
        checks = try repo.fetchChecks(for: routine.id)
        #expect(checks.first?.isDone == false && checks.first?.isSkipped == false)
    }

    @Test func routineReEnablingBridgesSkipsAccordingToMask() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let params = CreateRoutineParams(
            title: "Work Habits",
            weekdaysOnly: true,
            createdDayKey: "2026-09-04"
        )
        let routine = try repo.addRoutine(params)
        try repo.toggleRoutine(id: routine.id, dayKey: "2026-09-04")

        try repo.setRoutineEnabled(id: routine.id, enabled: false, todayKey: "2026-09-04")
        #expect(!routine.isEnabled)
        #expect(routine.pausedOnDayKey == "2026-09-04")

        try repo.setRoutineEnabled(id: routine.id, enabled: true, todayKey: "2026-09-08")
        #expect(routine.isEnabled)
        #expect(routine.pausedOnDayKey == nil)

        let checks = try repo.fetchChecks(for: routine.id)
        let checkDays = Set(checks.map(\.dayKey))
        #expect(checkDays.contains("2026-09-04"))
        #expect(!checkDays.contains("2026-09-05"))
        #expect(!checkDays.contains("2026-09-06"))
        #expect(checkDays.contains("2026-09-07"))

        let monCheck = try #require(checks.first(where: { $0.dayKey == "2026-09-07" }))
        #expect(monCheck.isDone && monCheck.isSkipped)

        let countBefore = checks.count
        try repo.setRoutineEnabled(id: routine.id, enabled: true, todayKey: "2026-09-09")
        let countAfter = (try repo.fetchChecks(for: routine.id)).count
        #expect(countAfter == countBefore)
    }

    @Test func softDeleteAndRestoreRoutineAttachments() throws {
        let (container, repo) = try makeRepo()
        let routine = try repo.addRoutine(title: "Read Book")
        let attachment = AttachmentItem(
            ownerKind: AttachmentOwner.routine.rawValue,
            ownerID: routine.id,
            filename: "notes.pdf"
        )
        container.mainContext.insert(attachment)
        try container.mainContext.save()

        try repo.deleteRoutine(id: routine.id, soft: true)
        let stamp = try #require(routine.deletedAt)
        #expect(attachment.deletedAt == stamp)

        try repo.restoreRoutine(id: routine.id)
        #expect(routine.deletedAt == nil)
        #expect(attachment.deletedAt == nil)

        try repo.purgeRoutine(id: routine.id)
        let attachments = try container.mainContext.fetch(FetchDescriptor<AttachmentItem>())
        #expect(attachments.isEmpty)
    }

    @Test func reorderRoutinesAndSortingStability() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let r1 = try repo.addRoutine(title: "R1", sortOrder: 0)
        let r2 = try repo.addRoutine(title: "R2", sortOrder: 1)
        let r3 = try repo.addRoutine(title: "R3", sortOrder: 2)

        try repo.reorderRoutines(orderedIDs: [r3.id, r1.id, r2.id])
        #expect(r3.sortOrder == 0)
        #expect(r1.sortOrder == 1)
        #expect(r2.sortOrder == 2)

        let fetched = try repo.fetchRoutines(includeDisabled: true, includeDeleted: false)
        #expect(fetched.map(\.id) == [r3.id, r1.id, r2.id])

        try repo.reorderRoutines(from: IndexSet(integer: 0), to: 3)
        let reindexed = try repo.fetchRoutines(includeDisabled: true, includeDeleted: false)
        #expect(reindexed.map(\.id) == [r1.id, r2.id, r3.id])
    }

    @Test func streakCalculationIntegration() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let routine = try repo.addRoutine(CreateRoutineParams(title: "Streak Habit", createdDayKey: "2026-09-01"))
        try repo.toggleRoutine(id: routine.id, dayKey: "2026-09-08")
        try repo.toggleRoutine(id: routine.id, dayKey: "2026-09-09")
        try repo.toggleRoutine(id: routine.id, dayKey: "2026-09-10")

        let streak = try repo.calculateStreak(for: routine.id, todayKey: "2026-09-10", calendar: .current)
        #expect(streak.currentStreak == 3)
        #expect(streak.bestStreak >= 3)

        let missingStreak = try repo.calculateStreak(for: UUID(), todayKey: "2026-09-10", calendar: .current)
        #expect(missingStreak.currentStreak == 0 && missingStreak.bestStreak == 0)
    }
}
