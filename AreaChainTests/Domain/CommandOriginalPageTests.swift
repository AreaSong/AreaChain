import Foundation
import Testing
@testable import AreaChain

/// 合并批 M-3 A：“在原页面完成”对照只有一处，覆盖用户决策 1、2 列出的全部指令，且不含直接执行的两条。
@Suite struct CommandOriginalPageTests {
    static let expected: [String: [String]] = [
        "G2": ["tag.delete", "tag.cleanup"],
        "C3": ["clipboard.delete", "clipboard.prune", "clipboard.empty"],
        "C4": ["clipboard.recording", "clipboard.skipNext", "clipboard.ignoreApp"],
        "C5": ["clipboard.ignoreUniversal", "clipboard.limit", "clipboard.interval", "clipboard.searchMode",
               "clipboard.position", "clipboard.clickAction", "clipboard.plainText", "clipboard.sound",
               "clipboard.unignoreApp", "clipboard.addPattern", "clipboard.removePattern", "clipboard.addType",
               "clipboard.removeType"],
        "A1": ["image.pick", "image.paste", "image.capture"],
        "S2": ["setting.login", "setting.loginSettings"],
        "S3": ["notification.status", "notification.request", "notification.test", "notification.settings"],
        "S4": ["notification.complete", "notification.snooze", "notification.open"],
        "S5": ["calendarSync.enabled", "calendarSync.status", "calendarSync.retry", "calendarSync.settings",
               "calendarSync.conflicts", "calendarSync.openLocal"],
        "S6": ["setting.icloud"],
        "S7": ["shortcut.record", "shortcut.reset", "shortcut.resetAll", "shortcut.cancel"],
        "D1": ["trash.delete", "trash.empty"],
        "D4": ["recovery.status", "recovery.resetQuit"],
        "N6": ["help.syntax", "help.page", "help.example"],
        "N7": ["support.version", "support.about", "support.discussion", "support.suggestion", "support.issue",
               "support.repository", "support.license"],
    ]

    @Test func tableCoversExactlyTheDecidedCommands() throws {
        var wanted = Set(Self.expected.values.flatMap { $0 })
        let catalog = CommandCatalog.standard
        // P1～P4 除 privacy.lock 外全部；D2、D3 全部。
        wanted.formUnion(catalog.entries.map(\.id.rawValue).filter {
            ($0.hasPrefix("privacy.") && $0 != "privacy.lock") || $0.hasPrefix("data.") || $0.hasPrefix("backup.")
        })
        let rows = CommandOriginalPage.all
        #expect(Set(rows.map(\.command.rawValue)) == wanted)
        #expect(rows.count == Set(rows.map(\.command)).count, "同一指令只能登记一次")
        #expect(CommandOriginalPage.route(for: .init(rawValue: "privacy.lock")) == nil)
        #expect(CommandOriginalPage.route(for: .init(rawValue: "trash.restore")) == nil)
        for row in rows {
            let command = try #require(catalog.command(id: row.command), "\(row.command.rawValue) 不在目录里")
            // 覆盖的 §8 行与对照分组一致，避免把别的功能误塞进对照。
            let features = Set(command.coverage.map(\.feature.rawValue))
            let group = Self.expected.first { $0.value.contains(row.command.rawValue) }?.key
            if let group { #expect(features.contains(group), "\(row.command.rawValue) 应覆盖 \(group)") }
        }
    }

    @Test func destinationsAreRealPagesAndCopyIsBilingual() throws {
        let strings = try Self.strings()
        for row in CommandOriginalPage.all {
            if case .page(let raw, _) = row.destination {
                #expect(WorkspaceTab(rawValue: raw) != nil, "\(row.command.rawValue) 的目标页 \(raw) 不存在")
            }
            for key in [row.noteKey] + (row.sectionKey.map { [$0] } ?? []) {
                let localizations = (strings[key] as? [String: Any])?["localizations"] as? [String: Any]
                #expect(localizations?["en"] != nil && localizations?["zh-Hans"] != nil, "\(key) 缺少双语")
            }
            if case .useInstead(let commands) = row.destination {
                #expect(!commands.isEmpty && commands.allSatisfy { CommandCatalog.standard.command(id: $0) != nil })
            }
        }
    }

    @Test func markingComesOnlyFromTheTable() throws {
        let catalog = CommandCatalog.standard
        let marked = Set(catalog.entries.filter(\.completesOnOriginalPage).map(\.id))
        let finishing = Set(CommandOriginalPage.all.filter(\.finishesOnPage).map(\.command))
        #expect(marked == finishing)
        // 导航本身、帮助与通知横幅改用入口不标“在原页面完成”。
        for id in ["notification.open", "help.syntax", "help.page", "help.example", "notification.complete", "notification.snooze"] {
            #expect(try #require(catalog.command(id: .init(rawValue: id))).completesOnOriginalPage == false)
        }
        // 标记不改目录原有的可用性与入列规则。
        let delete = try #require(catalog.command(id: .init(rawValue: "tag.delete")))
        #expect(delete.queue == .excluded && delete.hazards.contains(.permanentDeletion))
        #expect(WorkspaceTab.tags.helpKeyName == "tags.page.subtitle" && WorkspaceTab.settings.helpKeyName == nil)
    }

    static func strings() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "AreaChain/Resources/Localizable.xcstrings")
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        return try #require(root?["strings"] as? [String: Any])
    }
}
