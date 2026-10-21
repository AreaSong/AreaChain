import Foundation
import Testing
@testable import AreaChain

/// 合并批 M-3 B、C：直接动作只做纯解析；集合不含 trash.restore（走独立确认）。合并批 M-4 起含手记小窗会话的
/// 保存／重载／舍弃（复用 DiaryEditorSession）与普通手记复制。
@Suite struct CommandSystemActionTests {
    @Test func everyDeclaredCommandParsesAndExistsInCatalog() throws {
        let catalog = CommandCatalog.standard
        for raw in CommandSystemAction.commands {
            let command = try #require(catalog.command(id: .init(rawValue: raw)), "\(raw)")
            #expect(CommandOriginalPage.route(for: command.id) == nil, "\(raw) 不能同时在原页面对照里")
        }
        // 合并批 M-4：diaryWindow.save 不再留空（复用小窗会话保存，不另写正文）；复制缺省整篇。
        #expect(CommandSystemAction.commands.isSuperset(of: ["diaryWindow.save", "diary.save", "diary.reload", "diary.discard",
                                                             "diary.copy"]))
        #expect(try CommandSystemAction(command: .init(rawValue: "diaryWindow.save"), arguments: []) == .diarySave(window: true))
        #expect(try CommandSystemAction(command: .init(rawValue: "diary.save"), arguments: []) == .diarySave(window: false))
        #expect(try CommandSystemAction(command: .init(rawValue: "diary.copy"), arguments: []) == .diaryCopy(.record))
        #expect(try CommandSystemAction(command: .init(rawValue: "diary.copy"), arguments: [
            .init(parameter: .section, operation: .assign, value: .choice("notes")),
        ]) == .diaryCopy(.notes))
        #expect(throws: CommandPageIssue.invalidArguments) {
            try CommandSystemAction(command: .init(rawValue: "diary.copy"), arguments: [
                .init(parameter: .section, operation: .assign, value: .choice("body")),
            ])
        }
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
