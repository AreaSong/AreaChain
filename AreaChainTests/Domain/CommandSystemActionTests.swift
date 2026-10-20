import Foundation
import Testing
@testable import AreaChain

/// 合并批 M-3 B、C：直接动作只做纯解析；集合不含 diaryWindow.save（写正文，归 M-4）与 trash.restore（走独立确认）。
@Suite struct CommandSystemActionTests {
    @Test func everyDeclaredCommandParsesAndExistsInCatalog() throws {
        let catalog = CommandCatalog.standard
        for raw in CommandSystemAction.commands {
            let command = try #require(catalog.command(id: .init(rawValue: raw)), "\(raw)")
            #expect(CommandOriginalPage.route(for: command.id) == nil, "\(raw) 不能同时在原页面对照里")
        }
        #expect(!CommandSystemAction.commands.contains("diaryWindow.save"))
        #expect(!CommandSystemAction.commands.contains("trash.restore"))
        #expect(CommandSystemAction.commands.contains("privacy.lock"))
        #expect(try CommandSystemAction(command: .init(rawValue: "stats.trend"), arguments: []) == .stats(.trend, day: nil))
        #expect(try CommandSystemAction(command: .init(rawValue: "stats.today"), arguments: [
            .init(parameter: .day, operation: .assign, value: .day("2026-10-07")),
        ]) == .stats(.today, day: "2026-10-07"))
        #expect(try CommandSystemAction(command: .init(rawValue: "diaryWindow.pinned"), arguments: []) == .diaryPinned(nil))
        #expect(try CommandSystemAction(command: .init(rawValue: "overlay.mode"), arguments: [
            .init(parameter: .mode, operation: .assign, value: .choice("diaries")),
        ]) == .overlayMode("diaries"))
        #expect(throws: CommandPageIssue.invalidArguments) {
            try CommandSystemAction(command: .init(rawValue: "stats.openDay"), arguments: [])
        }
        #expect(throws: CommandPageIssue.invalidArguments) {
            try CommandSystemAction(command: .init(rawValue: "app.quit"), arguments: [
                .init(parameter: .day, operation: .assign, value: .day("2026-10-07")),
            ])
        }
    }
}
