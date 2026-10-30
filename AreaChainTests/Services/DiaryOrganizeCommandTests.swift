import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// J2：记录置顶、改日、普通标签直接执行（沿原仓储与原菜单）；加私密标签拒绝并引导到原手记页；
/// 受保护手记打开原手记页且不读正文；“私密”标记、显示、遮罩只在原页面对照里。
@Suite(.serialized) @MainActor struct DiaryOrganizeCommandTests {
    static func targets(_ entries: [DiaryEntry]) -> [CommandObjectReference] { entries.map { .init(type: .diary, id: $0.id) } }

    @Test func pinnedAndMoveUseTheOriginalRepositoryOnFixedTargets() throws {
        let f = try TaskSimpleFixture(diary: true)
        let entries = try (0..<2).map { try DiaryBodyCommandTests.diary(f, "置顶\($0)") }
        let (accepted, facts) = try f.run("diary.pinned", targets: Self.targets(entries), single: false, arguments: [f.enabled(true)])
        #expect(facts.state == .saved && f.count("save") == 1 && entries.allSatisfy(\.isPinned))
        #expect(accepted.preview.before.changes(to: accepted.preview.after).map(\.field) == ["pinned", "pinned"])
        let g = try TaskSimpleFixture(diary: true)
        let moved = try DiaryBodyCommandTests.diary(g, "改日")
        let (_, moveFacts) = try g.run("diary.move", targets: Self.targets([moved]), single: false,
                                       arguments: [g.day(TaskSimpleFixture.yesterday)])
        #expect(moveFacts.state == .saved && moved.dayKey == TaskSimpleFixture.yesterday)
    }

    @Test(arguments: [0, 1, 2])
    func protectedTargetsOpenTheOriginalPageWithoutReading(_ variant: Int) throws {
        for (command, argument) in [("diary.pinned", CommandArgument(parameter: .enabled, operation: .assign, value: .boolean(true))),
                                    ("diary.move", .init(parameter: .day, operation: .assign, value: .day(TaskSimpleFixture.yesterday))),
                                    ("diary.tags", .init(parameter: .tags, operation: .clear, value: nil))] {
            let f = try TaskSimpleFixture(diary: true)
            let entry = try DiaryBodyCommandTests.protectedEntry(f, variant)
            try f.queue(command, targets: Self.targets([entry]), single: false, arguments: [argument])
            #expect(throws: CommandSimpleIssue.invalidTarget(.protectedDiary)) { try f.preview() }
            #expect(!entry.isPinned && entry.dayKey == TaskSimpleFixture.today && f.count("save") == 0)
        }
    }

    /// 普通标签加减与整体替换沿原菜单的 toggleTag；要加私密标签整条拒绝（隐私转换只在原手记页）。
    @Test func tagsChangeOrdinaryTagsAndRefusePrivateOnes() throws {
        let f = try TaskSimpleFixture(diary: true)
        let work = try f.insert(TagItem(name: "工作", sortOrder: 0))
        let home = try f.insert(TagItem(name: "家庭", sortOrder: 1))
        let secret = try f.insert(TagItem(name: "私密", sortOrder: 2, isPrivateDiary: true))
        let entry = try DiaryBodyCommandTests.diary(f, "标签", tags: [work])
        let descriptor = try #require(CommandCatalog.standard.command(id: .init(rawValue: "diary.tags")))
        #expect(descriptor.availability == .declared && descriptor.queue == .eligibleAfterWiring)
        #expect(f.adapter.supports(descriptor.id) && !f.adapter.needsConfirmation(descriptor.id))
        let (_, added) = try f.run("diary.tags", targets: Self.targets([entry]), single: false,
                                   arguments: [.init(parameter: .tags, operation: .add, value: .tags([home.id]))])
        #expect(added.state == .saved && Set(TagIDList.parse(entry.tagIDs)) == [work.id, home.id])
        for operation in [CommandFieldOperation.add, .replaceAll] {
            let g = try TaskSimpleFixture(diary: true)
            let gWork = try g.insert(TagItem(name: "工作", sortOrder: 0))
            let gSecret = try g.insert(TagItem(name: "私密", sortOrder: 1, isPrivateDiary: true))
            let plain = try DiaryBodyCommandTests.diary(g, "不加私密", tags: [gWork])
            try g.queue("diary.tags", targets: Self.targets([plain]), single: false,
                        arguments: [.init(parameter: .tags, operation: operation, value: .tags([gSecret.id]))])
            #expect(throws: CommandSimpleIssue.invalidTarget(.diaryPrivateTag)) { try g.preview() }
            #expect(plain.tagIDs == gWork.id.uuidString && !plain.hasProtectedContent && g.count("save") == 0)
        }
        let h = try TaskSimpleFixture(diary: true)
        let hWork = try h.insert(TagItem(name: "工作", sortOrder: 0))
        let plain = try DiaryBodyCommandTests.diary(h, "移除", tags: [hWork])
        let (_, removed) = try h.run("diary.tags", targets: Self.targets([plain]), single: false,
                                     arguments: [.init(parameter: .tags, operation: .remove, value: .tags([hWork.id]))])
        #expect(removed.state == .saved && plain.tagIDs.isEmpty)
        _ = secret
    }

    /// “私密”标记、显示、遮罩只在 CommandOriginalPage 里，骨架不装配。
    @Test func privacyMarkRevealAndMaskStayOnTheOriginalPage() throws {
        let f = try TaskSimpleFixture(diary: true)
        for id in ["diary.privateMark", "diary.reveal", "diary.mask"] {
            #expect(CommandOriginalPage.route(for: .init(rawValue: id))?.destination == .page("diary"))
            #expect(!f.adapter.supports(.init(rawValue: id)))
        }
    }
}
