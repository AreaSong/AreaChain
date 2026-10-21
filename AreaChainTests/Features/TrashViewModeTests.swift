import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized, .tags(.backgroundWindow))
@MainActor
struct TrashViewModeTests {
    private static var retainedContainers: [ModelContainer] = []
    private static let deletedDate = Date(timeIntervalSince1970: 1_728_000_000)

    @Test func trashRowExtractsTodoRoutineAndTagDetails() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let tag = TagItem(
            name: "架构",
            sortOrder: 0,
            deletedAt: Self.deletedDate,
            colorToken: "amber",
            isPrivateDiary: true
        )
        let todo = TodoItem(
            title: "整理回收站视图",
            dayKey: "2026-10-13",
            deletedAt: Self.deletedDate,
            tagIDs: tag.id.uuidString,
            isImportant: true,
            isUrgent: false,
            notes: "补充双栏、网格与列表三种模式"
        )
        let cascadedSubtask = SubtaskItem(title: "核对附件缩略图", isDone: true, sortOrder: 0, todo: todo)
        cascadedSubtask.deletedAt = Self.deletedDate
        let earlierDeletedSubtask = SubtaskItem(
            title: "早已单独删除的子项",
            isDone: false,
            sortOrder: 1,
            deletedAt: Self.deletedDate.addingTimeInterval(-120),
            todo: todo
        )
        let routine = DailyRoutine(
            title: "每日复盘",
            sortOrder: 0,
            isEnabled: false,
            createdDayKey: "2026-10-01",
            weekdayMask: WeekdayMask.workdays,
            deletedAt: Self.deletedDate,
            notes: "记录今日进展与阻碍"
        )

        context.insert(tag)
        context.insert(todo)
        context.insert(cascadedSubtask)
        context.insert(earlierDeletedSubtask)
        context.insert(routine)

        let todoRow = try #require(TrashRow.todo(todo, attachments: [], tags: [tag]))
        #expect(todoRow.section == TrashSection.todo)
        #expect(todoRow.canRestore)
        if case .todo(let detail) = todoRow.detail {
            #expect(detail.notes == "补充双栏、网格与列表三种模式")
            #expect(detail.quadrantSlot == QuadrantSlot.important)
            #expect(detail.subtasks.count == 1)
            #expect(detail.subtasks.first?.title == "核对附件缩略图")
            #expect(detail.subtasks.first?.isDone == true)
            #expect(detail.tags.map { $0.name } == ["架构"])
        } else {
            Issue.record("Expected todo detail")
        }

        let routineRow = try #require(TrashRow.resident(routine, attachments: [], tags: [tag]))
        #expect(routineRow.section == TrashSection.routine)
        if case .routine(let detail) = routineRow.detail {
            #expect(detail.notes == "记录今日进展与阻碍")
            #expect(detail.weekdayMask == WeekdayMask.workdays)
            #expect(!detail.isEnabled)
        } else {
            Issue.record("Expected routine detail")
        }

        let tagRow = try #require(TrashRow.tag(tag))
        #expect(tagRow.section == TrashSection.tag)
        if case .tag(let detail) = tagRow.detail {
            #expect(detail.colorToken == "amber")
            #expect(detail.isPrivateDiary)
        } else {
            Issue.record("Expected tag detail")
        }
    }

    @Test func trashRowMasksPrivateDiaryAndAttachmentDetails() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let locale = Locale(identifier: "zh-Hans")

        let publicDiary = DiaryEntry(
            text: "公开手记首行\n第二行详细内容",
            dayKey: "2026-10-13",
            deletedAt: Self.deletedDate
        )
        let privateDiary = DiaryEntry(
            text: "不应泄露的明文",
            dayKey: "2026-10-13",
            deletedAt: Self.deletedDate
        )
        DiaryPrivacy.assign(privateDiary, isPrivate: true)
        privateDiary.encryptedText = Data([1, 2, 3])
        privateDiary.privacyVaultID = UUID()

        let publicAttachment = AttachmentItem(
            ownerKind: AttachmentOwner.diary.rawValue,
            ownerID: publicDiary.id,
            filename: "public-shot.png",
            deletedAt: Self.deletedDate
        )
        let privateAttachment = AttachmentItem(
            ownerKind: AttachmentOwner.diary.rawValue,
            ownerID: privateDiary.id,
            filename: "secret-shot.png",
            deletedAt: Self.deletedDate
        )
        privateAttachment.privacyVaultID = privateDiary.privacyVaultID

        context.insert(publicDiary)
        context.insert(privateDiary)
        context.insert(publicAttachment)
        context.insert(privateAttachment)

        let publicDiaryRow = try #require(TrashRow.diary(publicDiary, attachments: [], tags: { [] }, locale: locale))
        if case .diary(let detail) = publicDiaryRow.detail {
            #expect(!detail.isPrivateProvider())
            #expect(detail.fullTextProvider().contains("第二行详细内容"))
        } else {
            Issue.record("Expected public diary detail")
        }

        let privateDiaryRow = try #require(TrashRow.diary(privateDiary, attachments: [], tags: { [] }, locale: locale))
        #expect(privateDiaryRow.displayTitle == L10n.string("diary.private.title", locale: locale))
        if case .diary(let detail) = privateDiaryRow.detail {
            #expect(detail.isPrivateProvider())
            #expect(!detail.fullTextProvider().contains("不应泄露的明文"))
            #expect(detail.tagsProvider().isEmpty)
        } else {
            Issue.record("Expected private diary detail")
        }

        let publicAttachmentRow = try #require(TrashRow.attachment(
            publicAttachment,
            ownerDeleted: true,
            ownerTitle: "公开手记首行",
            isPrivate: false
        ))
        #expect(!publicAttachmentRow.canRestore)
        if case .attachment(let detail) = publicAttachmentRow.detail {
            #expect(!detail.isPrivate)
            #expect(detail.reference.filename == "public-shot.png")
            #expect(detail.ownerTitle == "公开手记首行")
            #expect(detail.ownerDeleted)
        } else {
            Issue.record("Expected public attachment detail")
        }

        let privateAttachmentRow = try #require(TrashRow.attachment(
            privateAttachment,
            ownerDeleted: false,
            ownerTitle: nil,
            isPrivate: true,
            titleProvider: { L10n.string("diary.private.attachment", locale: locale) }
        ))
        #expect(privateAttachmentRow.displayTitle == L10n.string("diary.private.attachment", locale: locale))
        if case .attachment(let detail) = privateAttachmentRow.detail {
            #expect(detail.isPrivate)
            #expect(detail.ownerTitle == nil)
        } else {
            Issue.record("Expected private attachment detail")
        }
    }

    @Test func categoryFilterAndViewModeContractsHold() {
        #expect(TrashViewMode.allCases == [.split, .grid, .list])
        #expect(TrashCategoryFilter.all.section == nil)
        #expect(TrashCategoryFilter.todo.section == TrashSection.todo)
        #expect(TrashCategoryFilter.routine.section == TrashSection.routine)
        #expect(TrashCategoryFilter.diary.section == TrashSection.diary)
        #expect(TrashCategoryFilter.attachment.section == TrashSection.attachment)
        #expect(TrashCategoryFilter.tag.section == TrashSection.tag)
    }

    @Test(arguments: [ColorScheme.light, .dark], [false, true])
    func trashPageRendersControlBarAndItemsWithoutOverflow(scheme: ColorScheme, minimumSize: Bool) async throws {
        let container = try makePopulatedTrashContainer()
        let size = minimumSize ? NSSize(width: 900, height: 620) : NSSize(width: 1120, height: 740)
        let window = SystemPageHost.window(
            TrashPage(),
            container: container,
            scheme: scheme,
            locale: "zh-Hans",
            size: size
        )
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)

        let view = try #require(window.contentView)
        let contentSize = window.contentRect(forFrameRect: window.frame).size
        #expect(view.bounds.width <= contentSize.width + 1)
        #expect(view.bounds.height <= window.frame.height + 1)
        #expect(view.bounds.width > 0 && view.bounds.height > 0)

        let identifiers = NativeSyntaxUI.identifiers(in: window)
        #expect(identifiers.contains("trash.filter.all"))
        #expect(identifiers.contains("trash.filter.todo"))
        #expect(identifiers.contains("trash.viewMode.picker"))
    }

    private func makeContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retainedContainers.append(container)
        return container
    }

    private func makePopulatedTrashContainer() throws -> ModelContainer {
        let container = try makeContainer()
        let context = container.mainContext
        let tag = TagItem(name: "发布", sortOrder: 0, deletedAt: Self.deletedDate, colorToken: "amber")
        let todo = TodoItem(
            title: "验证回收站多视图切换",
            dayKey: "2026-10-13",
            deletedAt: Self.deletedDate,
            tagIDs: tag.id.uuidString,
            isImportant: true,
            isUrgent: true,
            notes: "检查双栏、网格和列表在深浅色下的排版"
        )
        let subtask = SubtaskItem(title: "核对详情面板", isDone: true, sortOrder: 0, todo: todo)
        subtask.deletedAt = Self.deletedDate
        let diary = DiaryEntry(
            text: "回收站手记内容预览测试\n包含多行正文以确保摘要与详情都能显示。",
            dayKey: "2026-10-13",
            deletedAt: Self.deletedDate
        )
        context.insert(tag)
        context.insert(todo)
        context.insert(subtask)
        context.insert(diary)
        try context.save()
        return container
    }
}
