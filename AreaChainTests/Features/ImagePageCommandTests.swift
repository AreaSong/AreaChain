import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 合并批 M-2 C（服务层）：image.browse 沿 2E 的图片口径（附件中心可见）分组列出；image.preview 只接普通图片。
@Suite(.serialized) @MainActor struct ImagePageCommandTests {
    typealias Fixture = WorkspacePageCommandTests.Fixture

    private func browse(_ f: Fixture, _ kind: String?) throws -> WorkspacePageSnapshot {
        let arguments = kind.map { [CommandArgument(parameter: .kind, operation: .assign, value: .choice($0))] } ?? []
        let draft = f.draft("image.browse", arguments)
        return try f.pages.apply(f.pages.prepare(draft), draft: draft).after
    }

    @Test func browseListsVisibleImagesByOwnerKind() throws {
        let f = try Fixture(page: .dashboard)
        let secret = DiaryEntry(text: "私密", dayKey: "2026-10-20")
        secret.isPrivate = true
        let rows = [AttachmentItem(ownerKind: "todo", ownerID: f.todo.id, filename: "待办图.png", createdAt: Date(timeIntervalSince1970: 20)),
                    AttachmentItem(ownerKind: "routine", ownerID: f.routine.id, filename: "习惯图.png", createdAt: Date(timeIntervalSince1970: 30)),
                    AttachmentItem(ownerKind: "diary", ownerID: secret.id, filename: "私密图.png"),
                    AttachmentItem(ownerKind: "todo", ownerID: UUID(), filename: "孤儿图.png")]
        f.context.insert(secret)
        rows.forEach { f.context.insert($0) }
        try f.context.save()
        #expect(try browse(f, nil) == .results(["习惯图.png", "待办图.png"], total: 2))
        #expect(try browse(f, "todo") == .results(["待办图.png"], total: 1))
        #expect(try browse(f, "diary") == .results([], total: 0))
        // 与 2E 的同一判定：私密手记的图与孤儿图都不可浏览。
        let owners = AttachmentAccess.ownerIndex(todos: [f.todo], routines: [f.routine], diaries: [secret])
        #expect(rows.filter { AttachmentAccess.canBrowse($0, owners: owners, tags: []) }.count == 2)
        #expect(!f.context.hasChanges)
    }

    @Test func previewOnlyTakesOrdinaryImages() throws {
        let f = try Fixture(page: .dashboard)
        let ordinary = AttachmentItem(ownerKind: "todo", ownerID: f.todo.id, filename: "普通图.png")
        let sealed = AttachmentItem(ownerKind: "todo", ownerID: f.todo.id, filename: "加密图.png")
        sealed.privacyVaultID = UUID()
        f.context.insert(ordinary)
        f.context.insert(sealed)
        try f.context.save()
        let open = f.draft("image.preview", targets: [.init(type: .image, id: ordinary.id)])
        let preview = try f.pages.prepare(open)
        #expect(preview.before == .results(["普通图.png"], total: 1) && preview.page == nil)
        #expect(try f.pages.imageOwner(.init(type: .image, id: ordinary.id)) == .init(type: .todo, id: f.todo.id))
        #expect(throws: CommandPageIssue.protectedContent) {
            try f.pages.prepare(f.draft("image.preview", targets: [.init(type: .image, id: sealed.id)]))
        }
    }
}
