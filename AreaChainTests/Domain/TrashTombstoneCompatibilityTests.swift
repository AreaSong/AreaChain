import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct TrashTombstoneCompatibilityTests {
    private typealias Fixture = TrashFixture

    @Test func restorationDescriptionsRetainExistingCapabilitiesAndAreNotAuthorization() {
        var input = Fixture.family()
        input.routines = [Fixture.routine()]
        input.diaries = [Fixture.diary()]
        input.tags = [.init(id: Fixture.parentID, name: "日记", deletedAt: Fixture.date)]
        let result = TrashTombstoneReader.read(input)
        for object in result.objects {
            #expect(object.restoration.requiresFreshBusinessValidation)
            #expect(!object.restoration.provesFileAvailability)
            switch object.id.type {
            case .todo, .routine, .diary, .tag: #expect(object.restoration.independent == .existingEntry)
            case .subtask: #expect(object.restoration.independent == .notProvided)
            case .image: #expect(object.restoration.independent == .requiresLiveOwner(Fixture.ref(.todo)))
            default: Issue.record("unexpected kind")
            }
        }
        #expect(result.objects.filter { [.diary, .image].contains($0.id.type) }
            .allSatisfy { $0.restoration.requiresProtectionCheck })
        #expect(input.tags?[0].isDiaryPreset == true)
    }

    @Test func pureReaderAgreesWithMemoryTrashRowsWithoutInvokingTheirClosures() throws {
        let container = try ModelContainer(for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let todo = TodoItem(id: Fixture.parentID, title: "合成任务", dayKey: "2026-10-02", deletedAt: Fixture.date)
        let routine = DailyRoutine(title: "合成习惯", sortOrder: 0, createdDayKey: "2026-10-02")
        let diary = DiaryEntry(text: "合成正文", dayKey: "2026-10-02", deletedAt: Fixture.date)
        let tag = TagItem(name: "合成标签", sortOrder: 0)
        routine.deletedAt = Fixture.date
        tag.deletedAt = Fixture.date
        let image = AttachmentItem(id: Fixture.imageID, ownerKind: "todo", ownerID: todo.id,
                                   filename: "synthetic.png", deletedAt: Fixture.date)
        context.insert(todo)
        context.insert(routine)
        context.insert(diary)
        context.insert(tag)
        context.insert(image)
        var input = Fixture.input()
        input.todos = [todo.snapshot]
        input.routines = [routine.snapshot]
        input.diaries = [diary.snapshot]
        input.tags = [.init(id: tag.id, name: tag.name, deletedAt: tag.deletedAt)]
        input.images = [Fixture.image()]
        let before = TrashTombstoneReader.read(input)
        #expect(before.objects.count == 5)
        #expect(TrashRow.todo(todo, attachments: [image])?.canRestore == true)
        #expect(TrashRow.resident(routine, attachments: [])?.canRestore == true)
        #expect(TrashRow.diary(diary, attachments: [], tags: { [] }, locale: input.locale)?.canRestore == true)
        #expect(TrashRow.tag(tag)?.canRestore == true)
        #expect(TrashRow.attachment(image, ownerDeleted: true)?.canRestore == false)
        #expect(todo.deletedAt == Fixture.date && image.deletedAt == Fixture.date)
        // 仅改合成内存事实，验证父已恢复状态；不调用恢复闭包或读取文件。
        todo.deletedAt = nil
        input.todos = [todo.snapshot]
        let after = TrashTombstoneReader.read(input)
        #expect(TrashRow.todo(todo, attachments: [image]) == nil)
        let owners = AttachmentAccess.ownerIndex(todos: [todo], routines: [], diaries: [])
        #expect(TrashRow.attachment(image, ownerDeleted: !owners.ownerIsLive(.init(kind: .todo, id: todo.id)))?.canRestore == true)
        #expect(after.objects.first { $0.id.type == .image }?.restoration.independent == .existingEntry)
        #expect(!AttachmentAccess.canBrowse(image, owners: owners, tags: []))
    }

    @Test func liveOnlyImageReaderStillExcludesTombstonesAndDeletedOwners() {
        let input = Fixture.family()
        let owners = ImageOwnerSnapshots(todos: input.todos, routines: [], diaries: [])
        let request = ImageAssociationRequest(images: input.images, owners: owners, privacy: input.privacy,
            coverage: .init(owners: .init(types: [.todo: .completeIncludingDeleted]),
                associations: .init(types: [.todo: .completeIncludingDeleted]),
                imageIdentities: .init(allIDs: .completeIncludingDeleted)))
        #expect(ImageAssociationReader.read(request).images.isEmpty)
        #expect(TrashTombstoneReader.read(input).objects.contains { $0.id.type == .image })
        #expect(input.todos?[0].deletedAt == Fixture.date)
        #expect(input.images?[0].deletedAt == Fixture.date)
    }

    @Test func ordinaryTodoSnapshotDoesNotSupplyDeletedChildCoverage() throws {
        let container = try ModelContainer(for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let todo = TodoItem(id: Fixture.parentID, title: "合成", dayKey: "2026-10-02", deletedAt: Fixture.date)
        let child = SubtaskItem(title: "合成子项", sortOrder: 0, todo: todo)
        child.deletedAt = Fixture.date
        context.insert(todo)
        context.insert(child)
        #expect(todo.snapshot.subtasks.isEmpty)
        var input = Fixture.input()
        input.todos = [todo.snapshot]
        input.subtasks = [try #require(child.snapshot)]
        let result = TrashTombstoneReader.read(input)
        #expect(result.visibleMemberCount == 1)
        #expect(result.objects.first { $0.id.type == .subtask }?.relation == .cascaded(parent: Fixture.ref(.todo)))
    }

    @Test func memoryRoutineRestorePreservesChecksAndEnabledState() throws {
        let container = try ModelContainer(for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let routine = DailyRoutine(title: "合成习惯", sortOrder: 0, isEnabled: false,
            createdDayKey: "2026-10-02", deletedAt: Fixture.date, pausedOnDayKey: "2026-10-02")
        let check = RoutineCheck(dayKey: "2026-10-01", isDone: true, isSkipped: true, routine: routine)
        let same = AttachmentItem(ownerKind: "routine", ownerID: routine.id, filename: "same.png", deletedAt: Fixture.date)
        let prior = AttachmentItem(ownerKind: "routine", ownerID: routine.id,
            filename: "prior.png", deletedAt: Fixture.date.addingTimeInterval(-1))
        context.insert(routine)
        context.insert(check)
        context.insert(same)
        context.insert(prior)
        try context.save()
        let before = check.snapshot
        try SwiftDataRoutineRepository(container: container).restoreRoutine(id: routine.id)
        #expect(routine.deletedAt == nil && same.deletedAt == nil)
        #expect(prior.deletedAt != nil)
        #expect(!routine.isEnabled && routine.pausedOnDayKey == "2026-10-02")
        #expect(check.snapshot == before)
        #expect(try context.fetchCount(FetchDescriptor<RoutineCheck>()) == 1)
    }

    @Test func memoryPrivateDiaryRestoreDoesNotDecryptOrGrantImageAccess() throws {
        let container = try ModelContainer(for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let diary = DiaryEntry(text: "", dayKey: "2026-10-02", deletedAt: Fixture.date)
        DiaryPrivacy.assign(diary, isPrivate: true)
        diary.encryptedText = Data([1, 2, 3])
        diary.privacyVaultID = UUID()
        let image = AttachmentItem(ownerKind: "diary", ownerID: diary.id,
            filename: "synthetic-protected.png", deletedAt: Fixture.date)
        image.privacyVaultID = diary.privacyVaultID
        context.insert(diary)
        context.insert(image)
        try context.save()
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        let repo = SwiftDataDiaryRepository(context: context, container: container, vault: vault)
        try repo.restoreDiary(id: diary.id)
        #expect(diary.deletedAt == nil && image.deletedAt == nil)
        #expect(diary.encryptedText == Data([1, 2, 3]) && diary.text.isEmpty && diary.isPrivate)
        #expect(vault.state == .unconfigured)
        #expect(!AttachmentAccess.canBrowse(image, todos: [], routines: [], diaries: [diary], tags: []))
    }
}
