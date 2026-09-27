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

    @Test func fetchRoutineIncludesSoftDeletedAndMissesUnknown() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let live = try repo.addRoutine(title: "Live")
        let trashed = try repo.addRoutine(title: "Trashed")
        try repo.deleteRoutine(id: trashed.id, soft: true)

        #expect(try repo.fetchRoutine(id: live.id)?.id == live.id)
        #expect(try repo.fetchRoutine(id: trashed.id)?.deletedAt != nil)
        #expect(try repo.fetchRoutine(id: UUID()) == nil)
        try repo.restoreRoutine(id: trashed.id)
        #expect(try repo.fetchRoutine(id: trashed.id)?.deletedAt == nil)
    }

    @Test func fetchRoutinesHonorsDisabledDeletedEmptyAndSort() throws {
        let (container, repo) = try makeRepo()
        _ = container
        #expect(try repo.fetchRoutines(includeDisabled: true, includeDeleted: true).isEmpty)

        let first = try repo.addRoutine(title: "First", sortOrder: 0)
        let disabled = try repo.addRoutine(title: "Disabled", sortOrder: 1)
        let second = try repo.addRoutine(title: "Second", sortOrder: 2)
        try repo.setRoutineEnabled(id: disabled.id, enabled: false, todayKey: "2026-09-10")
        let trashed = try repo.addRoutine(title: "Trashed", sortOrder: 3)
        try repo.deleteRoutine(id: trashed.id, soft: true)

        let liveIncludingDisabled = try repo.fetchRoutines(includeDisabled: true, includeDeleted: false)
        #expect(liveIncludingDisabled.map(\.id) == [first.id, disabled.id, second.id])
        let enabledLive = try repo.fetchRoutines(includeDisabled: false, includeDeleted: false)
        #expect(enabledLive.map(\.id) == [first.id, second.id])
        let enabledIncludingDeleted = try repo.fetchRoutines(includeDisabled: false, includeDeleted: true)
        #expect(enabledIncludingDeleted.map(\.id) == [first.id, second.id, trashed.id])
        let withDeletedIDs = try repo.fetchRoutines(includeDisabled: true, includeDeleted: true).map(\.id)
        #expect(withDeletedIDs == [first.id, disabled.id, second.id, trashed.id])
        let defaultLive = try repo.fetchRoutines()
        #expect(defaultLive.map(\.id) == [first.id, disabled.id, second.id])
    }

    @Test func fetchChecksHonorsDayBoundaryRoutineScopeAndEmpty() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let day = "2026-09-10"
        let before = "2026-09-09"
        let after = "2026-09-11"
        let owner = try repo.addRoutine(title: "Owner")
        let other = try repo.addRoutine(title: "Other")
        try repo.toggleRoutine(id: owner.id, dayKey: day)
        try repo.toggleRoutine(id: owner.id, dayKey: after)
        try repo.toggleRoutine(id: other.id, dayKey: day)

        let byDay = try repo.fetchChecks(for: day)
        #expect(Set(byDay.map { $0.routine?.id }) == Set([owner.id, other.id]))
        #expect(byDay.allSatisfy { $0.dayKey == day })
        #expect(try repo.fetchChecks(for: before).isEmpty)
        #expect(try repo.fetchChecks(for: "2026-09-12").isEmpty)

        let byOwner = try repo.fetchChecks(for: owner.id)
        #expect(Set(byOwner.map(\.dayKey)) == Set([day, after]))
        #expect(byOwner.allSatisfy { $0.routine?.id == owner.id })
        #expect(try repo.fetchChecks(for: UUID()).isEmpty)
    }

    @Test func markRoutineDoneKeepsSkipFlagAndDoesNotDuplicate() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let routine = try repo.addRoutine(title: "Mark")
        let day = "2026-09-10"
        try repo.skipRoutine(id: routine.id, dayKey: day)
        try repo.markRoutineDone(id: routine.id, dayKey: day)
        try repo.markRoutineDone(id: routine.id, dayKey: day)
        let checks = try repo.fetchChecks(for: routine.id)
        #expect(checks.count == 1)
        #expect(checks.first?.isDone == true)
        #expect(checks.first?.isSkipped == true)

        try repo.toggleRoutine(id: routine.id, dayKey: day)
        try repo.toggleRoutine(id: routine.id, dayKey: day)
        let toggled = try repo.fetchChecks(for: routine.id)
        #expect(toggled.count == 1)
        #expect(toggled.first?.isDone == true)
        #expect(toggled.first?.isSkipped == false)
    }

    @Test func batchOperationsSkipMissingDeletedAndKeepTags() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let live = try repo.addRoutine(title: "Live")
        let neighbor = try repo.addRoutine(title: "Neighbor")
        let disabled = try repo.addRoutine(title: "Disabled")
        try repo.setRoutineEnabled(id: disabled.id, enabled: false, todayKey: "2026-09-10")
        let trashed = try repo.addRoutine(title: "Trashed")
        try repo.deleteRoutine(id: trashed.id, soft: true)
        let missing = UUID()
        let day = "2026-09-10"
        let tagID = UUID()

        try repo.batchSetRoutineChecks(ids: [], markDone: true, on: day)
        try repo.batchApplyTag(ids: [], tagID: tagID, present: true)
        try repo.batchToggleTag(ids: [], tagID: tagID)
        try repo.batchTrashRoutines(ids: [])
        #expect(try repo.fetchChecks(for: day).isEmpty)

        try repo.batchSetRoutineChecks(ids: [live.id, disabled.id, trashed.id, missing], markDone: true, on: day)
        let dayChecks = try repo.fetchChecks(for: day)
        let dayOwnerIDs = Set(dayChecks.map { $0.routine?.id })
        #expect(dayOwnerIDs == Set([live.id, disabled.id]))
        #expect(dayChecks.allSatisfy { $0.isDone && !$0.isSkipped })
        #expect(try repo.fetchChecks(for: trashed.id).isEmpty)

        try repo.batchSetRoutineChecks(ids: [live.id], markDone: false, on: day)
        let unmarked = try #require(try repo.fetchChecks(for: live.id).first { $0.dayKey == day })
        #expect(!unmarked.isDone && !unmarked.isSkipped)
        try repo.batchSetRoutineChecks(ids: [live.id], markDone: false, on: day)
        #expect((try repo.fetchChecks(for: live.id)).filter { $0.dayKey == day }.count == 1)

        try repo.batchApplyTag(ids: [live.id, trashed.id, missing], tagID: tagID, present: true)
        #expect(TagIDList.contains(live.tagIDs, tagID))
        #expect(!TagIDList.contains(trashed.tagIDs, tagID))
        #expect(!TagIDList.contains(neighbor.tagIDs, tagID))
        try repo.batchApplyTag(ids: [live.id], tagID: tagID, present: false)
        #expect(!TagIDList.contains(live.tagIDs, tagID))
        try repo.batchToggleTag(ids: [live.id, neighbor.id], tagID: tagID)
        #expect(TagIDList.contains(live.tagIDs, tagID) && TagIDList.contains(neighbor.tagIDs, tagID))

        try repo.replaceTagIDs(id: live.id, tagIDs: TagIDList.encode([tagID]))
        #expect(live.tagIDs == TagIDList.encode([tagID]))
        try repo.toggleTag(id: live.id, tagID: tagID)
        #expect(!TagIDList.contains(live.tagIDs, tagID))

        let previousStamp = try #require(trashed.deletedAt)
        try repo.batchTrashRoutines(ids: [neighbor.id, trashed.id, missing])
        #expect(live.deletedAt == nil)
        #expect(neighbor.deletedAt != nil)
        #expect(trashed.deletedAt == previousStamp)
        let remainingLive = try repo.fetchRoutines(includeDisabled: true, includeDeleted: false)
        #expect(remainingLive.map(\.id) == [live.id, disabled.id])
    }

    @Test func blankTitleDoesNotInsertAndRepeatInvalidUpdateKeepsOriginal() throws {
        let (container, repo) = try makeRepo()
        _ = container
        #expect(throws: RepositoryError.self) { try repo.addRoutine(title: "   ") }
        #expect(try repo.fetchRoutines(includeDisabled: true, includeDeleted: true).isEmpty)

        let routine = try repo.addRoutine(title: "Keep")
        #expect(throws: RepositoryError.self) { try repo.updateRoutine(id: routine.id, title: "   ", notes: nil) }
        #expect(throws: RepositoryError.self) { try repo.updateRoutine(id: routine.id, title: "   ", notes: nil) }
        #expect(try repo.fetchRoutine(id: routine.id)?.title == "Keep")
        #expect(try repo.fetchRoutines(includeDisabled: true, includeDeleted: true).count == 1)
    }
}
