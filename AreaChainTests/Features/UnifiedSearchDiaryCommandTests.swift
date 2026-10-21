import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// 合并批 M-4：手记小窗会话的保存／重载／舍弃（复用 DiaryEditorSession，只作用于已打开的小窗）、普通手记复制
/// （PrivateClipboard，隔离剪贴板）、受保护目标改为打开原手记页，以及“私密”标记／显示／遮罩只打开原手记页。
/// 沿 M-3 的隔离导航夹具与 SystemCommandFakes；合成内存库，不退出、不写真实剪贴板。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchDiaryCommandTests {
    @Test func diaryWindowSessionSaveReloadAndDiscardReuseTheSession() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        let fakes = SystemCommandFakes()
        defer { fakes.closeAll() }
        let pages = fakes.install(fixture)
        let plain = DiaryEntry(text: "m4 plain diary", dayKey: fixture.day)
        let secret = DiaryEntry(text: "m4 secret diary", dayKey: fixture.day)
        secret.isPrivate = true
        fixture.context.insert(plain)
        fixture.context.insert(secret)
        try fixture.context.save()
        try await fixture.start(focus: .background)
        try pages.openDiaryWindow(.init(type: .diary, id: plain.id))
        let window = try #require(fakes.windows.openControllers.first)
        #expect(throws: CommandPageIssue.nothingToCancel) { try pages.diaryWindow(entry: .init(type: .diary, id: secret.id)) }
        #expect(try pages.diaryWindow(entry: .init(type: .diary, id: plain.id)) === window)
        // 保存沿小窗的 save；没有未保存内容只说明。
        window.session.text += " edited"
        try await fixture.go("/window/diary/save")
        #expect(fixture.controller.navigationMessage == "unified.system.diary.saved" && plain.text == "m4 plain diary edited")
        try await fixture.go("/window/diary/save")
        #expect(fixture.controller.navigationMessage == "unified.system.diary.nothingToSave")
        // 重载：没有未保存内容时直接取最新；有未保存内容时保留原有确认（前置小窗，草稿不动）。
        plain.text = "m4 external"
        try fixture.context.save()
        #expect(pages.reloadDiarySession(window) == .reloaded && window.session.text == "m4 external")
        window.session.text = "m4 local draft"
        #expect(pages.reloadDiarySession(window) == .needsConfirmation && window.session.text == "m4 local draft")
        // 保存失败（手记已被移到回收站）：不报成功，草稿仍在会话里。
        plain.deletedAt = .now
        try fixture.context.save()
        #expect(pages.saveDiarySession(window) == .failed && window.session.text == "m4 local draft")
        #expect(fixture.controller.navigationMessage != "unified.system.diary.saved")
        plain.deletedAt = nil
        try fixture.context.save()
        // 舍弃沿小窗自己的关闭：有未保存内容时出现原有确认，取消后窗口仍在。
        #expect(pages.discardDiarySession(window) == .closeRequested)
        let sheet = try #require(window.window.attachedSheet)
        window.window.endSheet(sheet, returnCode: .alertThirdButtonReturn)
        try await fixture.settle()
        #expect(fakes.windows.openControllers.count == 1)
        // 受保护会话不在指令里保存：前置小窗，由用户在那里解锁后操作；不写库。
        let protected = fakes.windows.open(entry: secret, context: fixture.context, activate: false)
        let saves = fixture.saves
        #expect(pages.saveDiarySession(protected) == .protected && pages.reloadDiarySession(protected) == .protected)
        #expect(fixture.saves == saves && secret.text == "m4 secret diary")
    }

    @Test func copyFollowsTheCardAndProtectedNotesOpenTheNotesPage() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        let fakes = SystemCommandFakes()
        let pages = fakes.install(fixture)
        let board = NSPasteboard(name: .init("com.areachain.m4.copy." + UUID().uuidString))
        defer { board.releaseGlobally() }
        pages.system?.pasteboard = board
        let plain = DiaryEntry(text: "m4 标题\nm4 备注第一行\n第二行", dayKey: fixture.day)
        let single = DiaryEntry(text: "m4 只有一行", dayKey: fixture.day)
        let secret = DiaryEntry(text: "m4 secret copy", dayKey: fixture.day)
        secret.isPrivate = true
        for entry in [plain, single, secret] { fixture.context.insert(entry) }
        try fixture.context.save()
        for section in DiaryCopyContent.Section.allCases {
            try pages.copyDiary(.init(type: .diary, id: plain.id), section: section)
            #expect(board.string(forType: .string) == DiaryCopyContent.text(section, from: plain.text))
            #expect(board.string(forType: PrivateClipboard.marker) == nil, "普通手记不带隐私标记，与卡片一致")
        }
        #expect(throws: CommandPageIssue.nothingToCancel) { try pages.copyDiary(.init(type: .diary, id: single.id), section: .notes) }
        let before = board.changeCount
        #expect(throws: CommandPageIssue.protectedContent) { try pages.copyDiary(.init(type: .diary, id: secret.id), section: .record) }
        #expect(board.changeCount == before && board.string(forType: .string) != secret.text)
        // 受保护时改为打开原手记页：与简单面板的“打开原手记页”同一导航。
        try await fixture.start(focus: .background)
        fixture.controller.openDiaryOriginalPage(fixture.controller.buffer)
        await fixture.controller.navigationTask?.value
        try await fixture.settle()
        #expect(fixture.router.mounted("page.diary") && fixture.controller.returnSearch != nil)
    }

    /// 决策 3：“私密”标记、显示、遮罩只导航到原手记页，不建草稿、不写数据。
    @Test func privacyMarkRevealAndMaskOnlyOpenTheNotesPage() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        let fakes = SystemCommandFakes()
        _ = fakes.install(fixture)
        try await fixture.start(focus: .background)
        for id in ["diary.privateMark", "diary.reveal", "diary.mask"] {
            let route = try #require(CommandOriginalPage.route(for: .init(rawValue: id)))
            #expect(route.destination == .page("diary") && route.finishesOnPage)
            let command = try #require(CommandCatalog.standard.command(id: .init(rawValue: id)))
            #expect(command.completesOnOriginalPage)
            try await fixture.go(command.path)
            #expect(fixture.router.mounted("page.diary"), "\(id)")
            #expect(fixture.controller.navigationMessage == "unified.originalPage.displayed")
            #expect(fixture.controller.operations?.active == nil)
            try await fixture.back()
        }
        #expect(fixture.saves == 0 && !fixture.context.hasChanges)
    }
}
