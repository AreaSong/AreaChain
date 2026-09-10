import AppKit
import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
struct MilestoneM2AdversarialTests {

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - 1. FirstLaunchSeeder Adversarial Tests

    @Test func seederExecutesWhenEmptyAndIsStrictlyIdempotent() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let defaults = UserDefaults.standard
        let originalValue = defaults.object(forKey: FirstLaunchSeeder.defaultsKey)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: FirstLaunchSeeder.defaultsKey)
            } else {
                defaults.removeObject(forKey: FirstLaunchSeeder.defaultsKey)
            }
        }

        // Scenario A: First launch (defaults false, DB empty)
        defaults.set(false, forKey: FirstLaunchSeeder.defaultsKey)
        FirstLaunchSeeder.seedIfNeeded(container: container)

        let routinesAfterFirst = try context.fetch(FetchDescriptor<DailyRoutine>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        ))
        #expect(routinesAfterFirst.count == 2)
        #expect(routinesAfterFirst[0].sortOrder == 0)
        #expect(routinesAfterFirst[0].weekdaysOnly == true)
        #expect(routinesAfterFirst[1].sortOrder == 1)
        #expect(routinesAfterFirst[1].weekdaysOnly == false)
        #expect(defaults.bool(forKey: FirstLaunchSeeder.defaultsKey) == true)

        // Scenario B: Second launch (defaults true, DB has 2 items)
        FirstLaunchSeeder.seedIfNeeded(container: container)
        let routinesAfterSecond = try context.fetch(FetchDescriptor<DailyRoutine>())
        #expect(routinesAfterSecond.count == 2, "Idempotency violated: duplicate routines seeded on second launch")

        // Scenario C: Third launch with manual seedIfNeeded(context:existingCount:)
        FirstLaunchSeeder.seedIfNeeded(context: context, existingCount: 2)
        let routinesAfterThird = try context.fetch(FetchDescriptor<DailyRoutine>())
        #expect(routinesAfterThird.count == 2, "Idempotency violated: duplicate routines seeded on direct context call")
    }

    @Test func seederRespectsExistingDataWhenUserDefaultsWasCleared() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let defaults = UserDefaults.standard
        let originalValue = defaults.object(forKey: FirstLaunchSeeder.defaultsKey)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: FirstLaunchSeeder.defaultsKey)
            } else {
                defaults.removeObject(forKey: FirstLaunchSeeder.defaultsKey)
            }
        }

        // User already has existing routines (e.g. from sync or previous version), but defaults key was cleared
        context.insert(DailyRoutine(title: "Custom Habit", sortOrder: 0))
        try context.save()

        defaults.set(false, forKey: FirstLaunchSeeder.defaultsKey)
        FirstLaunchSeeder.seedIfNeeded(container: container)

        let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        #expect(routines.count == 1, "Should not inject seed routines into an existing user database")
        #expect(routines.first?.title == "Custom Habit")
        #expect(defaults.bool(forKey: FirstLaunchSeeder.defaultsKey) == true, "Should set defaults key when existing data detected")
    }

    @Test func seederDoesNotResurrectRoutinesIfUserDeletedAll() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let defaults = UserDefaults.standard
        let originalValue = defaults.object(forKey: FirstLaunchSeeder.defaultsKey)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: FirstLaunchSeeder.defaultsKey)
            } else {
                defaults.removeObject(forKey: FirstLaunchSeeder.defaultsKey)
            }
        }

        // User previously ran app (defaultsKey == true) and intentionally deleted all routines (count == 0)
        defaults.set(true, forKey: FirstLaunchSeeder.defaultsKey)
        FirstLaunchSeeder.seedIfNeeded(container: container)

        let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        #expect(routines.isEmpty, "Should NOT re-seed routines when user intentionally deleted all routines")
    }

    @Test func seederScopeConfirmationOnlySeedsHabitsAndCatalogSeedsPresetTags() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let defaults = UserDefaults.standard
        let originalValue = defaults.object(forKey: FirstLaunchSeeder.defaultsKey)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: FirstLaunchSeeder.defaultsKey)
            } else {
                defaults.removeObject(forKey: FirstLaunchSeeder.defaultsKey)
            }
        }

        defaults.set(false, forKey: FirstLaunchSeeder.defaultsKey)
        FirstLaunchSeeder.seedIfNeeded(container: container)

        // Verify FirstLaunchSeeder ONLY creates DailyRoutines, not projects or tags
        let projects = try context.fetch(FetchDescriptor<ProjectItem>())
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        #expect(projects.isEmpty, "FirstLaunchSeeder must not create dummy projects")
        #expect(tags.isEmpty, "FirstLaunchSeeder does not directly seed tags")

        // Verify preset tags are seeded via CatalogRepository
        let catalogRepo = SwiftDataCatalogRepository(context: context)
        try catalogRepo.ensurePresetTags()
        let seededTags = try catalogRepo.fetchTags(includeDeleted: false)
        #expect(Set(seededTags.map(\.name)) == Set(DiaryMemoTags.presets))
    }

    // MARK: - 2. AppWindows.workspaceViewProvider Tests

    @Test func workspaceViewProviderRegistrationAndLifecycle() {
        let originalProvider = AppWindows.workspaceViewProvider
        defer { AppWindows.workspaceViewProvider = originalProvider }

        // Test custom registration
        var evaluationCount = 0
        AppWindows.workspaceViewProvider = {
            evaluationCount += 1
            return AnyView(Text("Test Workspace View \(evaluationCount)"))
        }

        #expect(AppWindows.workspaceViewProvider != nil)
        let generatedView = AppWindows.workspaceViewProvider?()
        #expect(generatedView != nil)
        #expect(evaluationCount == 1)

        let secondGeneratedView = AppWindows.workspaceViewProvider?()
        #expect(secondGeneratedView != nil)
        #expect(evaluationCount == 2)
    }

    // MARK: - 3. StatusItemController.popoverViewProvider Tests

    @Test func statusItemControllerPopoverViewProviderGeneratesFreshViews() throws {
        let controller = StatusItemController.shared
        let originalProvider = controller.popoverViewProvider
        defer { controller.popoverViewProvider = originalProvider }

        var callCount = 0
        controller.popoverViewProvider = {
            callCount += 1
            return AnyView(Text("Popover Call \(callCount)"))
        }

        #expect(controller.popoverViewProvider != nil)
        _ = controller.popoverViewProvider?()
        #expect(callCount == 1)

        _ = controller.popoverViewProvider?()
        #expect(callCount == 2, "Each provider invocation must generate a fresh view to prevent stale view retention")
    }

    @Test func statusItemControllerToggleSafetyWhenUnattached() {
        let controller = StatusItemController.shared
        // Toggling before attach or when status item / container is nil must not crash
        controller.toggle()
        controller.close()
    }

    // MARK: - 4. AttachmentPicker & AttachmentActions Backward Compatibility Tests

    @Test func attachmentPickerProvidesFullBackwardCompatibilityForAttachmentActions() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let ownerID = UUID()

        // Verify AttachmentActions is identical type to AttachmentPicker
        #expect(AttachmentActions.self == AttachmentPicker.self)

        // Verify trash method
        let attachment = AttachmentItem(
            id: UUID(),
            ownerKind: AttachmentOwner.todo.rawValue,
            ownerID: ownerID,
            filename: "photo.png",
            createdAt: .now
        )
        context.insert(attachment)
        #expect(attachment.deletedAt == nil)

        AttachmentActions.trash(attachment)
        #expect(attachment.deletedAt != nil, "AttachmentActions.trash must stamp deletedAt")

        // Test AttachmentStore instance vs static proxy equivalence
        let root = FileManager.default.temporaryDirectory.appending(path: "att-compat-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let sampleData = Data([0x01, 0x02, 0x03, 0x04])
        let attID = UUID()

        // Call via static proxy
        let savedItem = try AttachmentStore.save(
            data: sampleData,
            filename: "test.bin",
            ownerKind: .todo,
            ownerID: ownerID,
            context: context,
            root: root,
            id: attID
        )
        #expect(savedItem.id == attID)
        #expect(AttachmentStore.loadData(id: attID, root: root) == sampleData)

        // Call via instance method
        let store = AttachmentStore.shared
        #expect(store.loadData(id: attID, root: root) == sampleData)

        // Purge via instance method
        store.purge(ownerID: ownerID, attachments: [savedItem], context: context, root: root)
        #expect(store.loadData(id: attID, root: root) == nil)
    }

    @Test func attachmentPickerWithMockStorage() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let ownerID = UUID()

        final class MockStorage: AttachmentStorageProtocol, @unchecked Sendable {
            var savedData: [UUID: Data] = [:]
            var removedIDs: Set<UUID> = []

            func directory(fileManager: FileManager) -> URL { URL(fileURLWithPath: "/tmp") }
            func fileURL(id: UUID, root: URL?) -> URL { URL(fileURLWithPath: "/tmp/\(id.uuidString)") }
            func save(
                data: Data,
                filename: String,
                ownerKind: AttachmentOwner,
                ownerID: UUID,
                context: ModelContext,
                root: URL?,
                id: UUID,
                createdAt: Date
            ) throws -> AttachmentItem {
                savedData[id] = data
                let item = AttachmentItem(id: id, ownerKind: ownerKind.rawValue, ownerID: ownerID, filename: filename, createdAt: createdAt)
                context.insert(item)
                return item
            }
            func loadData(id: UUID, root: URL?) -> Data? { savedData[id] }
            func image(id: UUID, root: URL?) -> NSImage? { nil }
            func removeFile(id: UUID, root: URL?) { removedIDs.insert(id) }
            func purge(ownerID: UUID, attachments: [AttachmentItem], context: ModelContext, root: URL?) {}
            func resetDirectory(fileManager: FileManager) throws {}
        }

        let mockStore = MockStorage()
        let fakeData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let id = UUID()
        let item = try mockStore.save(
            data: fakeData,
            filename: "mock.png",
            ownerKind: .diary,
            ownerID: ownerID,
            context: context,
            root: nil,
            id: id,
            createdAt: .now
        )
        #expect(mockStore.savedData[id] == fakeData)
        #expect(item.ownerID == ownerID)
    }
}
