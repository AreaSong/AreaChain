import Foundation
import Testing
@testable import AreaChain

struct CommandGuideSectionTests {
    private let catalog = CommandCatalog.standard

    @Test func sectionsCoverEveryCommandExactlyOnce() {
        let sections = catalog.guideSections()
        let listed = sections.flatMap(\.commands).map(\.id)
        let expected = catalog.entries.filter { ![.group, .scope].contains($0.category) }.map(\.id)
        #expect(listed.count == expected.count, "每条指令只出现一次")
        #expect(Set(listed) == Set(expected))
        #expect(Set(listed).count == listed.count)
        #expect(sections.allSatisfy { !$0.commands.isEmpty })
        #expect(sections.flatMap(\.commands).allSatisfy { ![.group, .scope].contains($0.category) })
    }

    @Test func commandsGoToTheirTopmostAncestor() throws {
        let sections = catalog.guideSections()
        let root = try #require(catalog.command(path: "/"))
        for section in sections {
            if let top = section.top {
                #expect(top.parentID == root.id && [.group, .scope].contains(top.category), "\(top.id.rawValue)")
                #expect(section.commands.allSatisfy { $0.path.hasPrefix(top.path + "/") }, "\(top.id.rawValue)")
            } else {
                #expect(section.commands.allSatisfy { $0.parentID == root.id }, "其他组只收直接挂在根下的指令")
            }
        }
        let other = try #require(sections.last)
        #expect(other.top == nil && other.commands.map(\.id.rawValue).contains("app.quit"))
        let batch = try #require(sections.first { $0.top?.path == "/tasks" })
        #expect(batch.commands.contains { $0.id.rawValue == "batch.move" }, "/tasks/batch 下的指令归入任务范围")
    }

    @Test(arguments: ["en", "zh-Hans"]) func everySectionHasLocalizedName(language: String) {
        let locale = Locale(identifier: language)
        for section in catalog.guideSections() {
            let name = L10n.format(section.nameKey, locale: locale)
            #expect(!name.isEmpty && name != section.nameKey, "\(section.id) 缺少 \(language) 名称")
        }
    }
}
