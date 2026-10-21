import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 合并批 M-4 D（J3）：转今天任务沿原规则、走共用独立确认、只能单项、重试不重复创建；回收走共用确认；
/// 受保护或敏感手记拒绝且不读正文。
@Suite(.serialized) @MainActor struct DiaryActionCommandTests {
    @Test func toTodoFollowsTheCardRuleAfterConfirmation() throws {
        let f = try TaskSimpleFixture(diary: true)
        let tag = try f.insert(TagItem(name: "工作", sortOrder: 0))
        let entry = try DiaryBodyCommandTests.diary(f, "  首行标题 #工作\n其余做备注\n第三行  ", tags: [tag])
        let descriptor = try #require(CommandCatalog.standard.command(id: .init(rawValue: "diary.toTodo")))
        #expect(f.adapter.needsConfirmation(descriptor.id))
        try f.queue("diary.toTodo", targets: [.init(type: .diary, id: entry.id)])
        let accepted = try f.accept()
        #expect(throws: CommandSimpleIssue.confirmationRequired) { try f.submit(accepted) }
        let facts = try DiaryBodyCommandTests.confirmAndSubmit(f, accepted)
        #expect(facts.state == .saved && f.count("save") == 1)
        let creation = try #require(facts.creation)
        let todo = try #require(try f.stored(TodoItem.self).first { $0.id == creation.id })
        let expected = try #require(DiaryWriteService.todoText(from: entry.text))
        #expect(todo.title == expected.title && todo.notes == expected.notes && todo.title == "首行标题 #工作")
        #expect(todo.dayKey == TaskSimpleFixture.today && todo.tagIDs.isEmpty && todo.sourceBundleID == "com.areachain.m4.test")
        #expect(try f.stored(DiaryEntry.self).count == 1 && entry.deletedAt == nil, "保留原手记")
        #expect(f.adapter.openTarget(facts) == .init(object: creation, parent: nil, viewingTrash: false))
        // 只能单项：多项计划按独立确认拒绝（目录要求独立确认）。
        let multi = try #require(CommandCatalog.standard.command(id: .init(rawValue: "diary.toTodo")))
        #expect(multi.interactions.contains(.independentConfirmation) && multi.batch == .singleOnly)
    }

    /// 保存后提交抛错（结果未知）：只读核对认出新待办已在库里；同一身份不能再建第二个。
    @Test func unknownResultIsVerifiedAndRetryDoesNotDuplicate() throws {
        let f = try TaskSimpleFixture(diary: true)
        let entry = try DiaryBodyCommandTests.diary(f, "未知结果\n备注")
        f.saveMode = .throwAfter
        try f.queue("diary.toTodo", targets: [.init(type: .diary, id: entry.id)])
        let facts = try DiaryBodyCommandTests.confirmAndSubmit(f, f.accept())
        #expect(facts.state == .unknown)
        #expect(try f.verify().outcome == .applied)
        let creation = try #require(facts.creation)
        f.saveMode = .normal
        #expect(throws: (any Error).self) {
            try f.diaries.tasks(f.context).addTodo(.init(title: "重试", dayKey: TaskSimpleFixture.today, creationID: creation.id))
        }
        f.context.rollback()
        #expect(try f.stored(TodoItem.self).filter { $0.id == creation.id }.count == 1)
    }

    @Test(arguments: [0, 1, 2])
    func protectedNotesAreNotConvertedOrTrashed(_ variant: Int) throws {
        for command in ["diary.toTodo", "diary.trash"] {
            let f = try TaskSimpleFixture(diary: true)
            let entry = try DiaryBodyCommandTests.protectedEntry(f, variant)
            try f.queue(command, targets: [.init(type: .diary, id: entry.id)])
            #expect(throws: CommandSimpleIssue.invalidTarget(.protectedDiary)) { try f.preview() }
            #expect(try f.stored(TodoItem.self).isEmpty && entry.deletedAt == nil && f.count("save") == 0)
        }
    }

    @Test func trashNeedsConfirmationAndCascadesToImages() throws {
        let f = try TaskSimpleFixture(diary: true)
        let entry = try DiaryBodyCommandTests.diary(f, "回收")
        try f.insert(AttachmentItem(ownerKind: "diary", ownerID: entry.id, filename: "附图.png"))
        let descriptor = try #require(CommandCatalog.standard.command(id: .init(rawValue: "diary.trash")))
        #expect(f.adapter.supports(descriptor.id) && f.adapter.needsConfirmation(descriptor.id))
        try f.queue("diary.trash", targets: [.init(type: .diary, id: entry.id)])
        let accepted = try f.accept()
        #expect(accepted.preview.after.notices.map(\.title) == ["1"], "确认面板列出随之回收的图片数")
        #expect(throws: CommandSimpleIssue.confirmationRequired) { try f.submit(accepted) }
        let facts = try DiaryBodyCommandTests.confirmAndSubmit(f, accepted)
        #expect(facts.state == .saved && entry.deletedAt != nil)
        #expect(try f.stored(AttachmentItem.self).allSatisfy { $0.deletedAt != nil })
    }
}
