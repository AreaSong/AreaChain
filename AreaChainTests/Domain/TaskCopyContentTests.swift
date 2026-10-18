import Foundation
import Testing
@testable import AreaChain

/// 旧 TaskRow.copyTask / fullNoteText 的逐字副本，只作对照预言，不被生产代码引用。
private enum LegacyTaskRowCopy {
    static func fullNote(notes: String?, note: String?) -> String? {
        if let notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return notes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return note.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    static func record(title: String, notes: String?, note: String?) -> String {
        var content = title
        if let full = fullNote(notes: notes, note: note), !full.isEmpty { content += "\n" + full }
        return content
    }
}

@Suite struct TaskCopyContentTests {
    struct Sample: Sendable, CustomTestStringConvertible {
        let title: String
        let notes: String?
        let note: String?
        var testDescription: String { "title:\(title.count) notes:\(notes?.count ?? -1) note:\(note?.count ?? -1)" }
    }

    static let samples: [Sample] = [
        .init(title: "写周报", notes: nil, note: nil),
        .init(title: "写周报", notes: "", note: nil),
        .init(title: "写周报", notes: " \n\t ", note: nil),
        .init(title: "  首尾空白标题  ", notes: "  备注首尾空白  ", note: nil),
        .init(title: "多行", notes: "第一行\n\n第二行\r\n第三行\n", note: nil),
        .init(title: "Emoji 👩🏽‍💻🇨🇳", notes: "组合字符 e\u{301} 和 한국어 ﷺ", note: nil),
        .init(title: "回退摘要", notes: "   ", note: "  摘要来源  "),
        .init(title: "完整备注优先", notes: "完整", note: "摘要"),
        .init(title: "", notes: "空标题仍保留换行", note: nil),
        .init(title: "\u{200B}零宽标题", notes: "\u{00A0}不换行空格\u{00A0}", note: nil),
    ]

    @Test(arguments: samples) func recordMatchesLegacyTaskRowByteForByte(sample: Sample) {
        let notes = TaskCopyContent.notes(sample.notes, fallback: sample.note)
        #expect(notes == LegacyTaskRowCopy.fullNote(notes: sample.notes, note: sample.note))
        let record = TaskCopyContent.text(.record, title: sample.title, notes: notes)
        let legacy = LegacyTaskRowCopy.record(title: sample.title, notes: sample.notes, note: sample.note)
        #expect(record == legacy)
        #expect(record.map { Array($0.utf8) } == Array(legacy.utf8))
    }

    @Test(arguments: samples) func titleAndNotesSectionsMatchRowBubbles(sample: Sample) {
        let notes = TaskCopyContent.notes(sample.notes, fallback: sample.note)
        // 标题气泡原样复制 state.title，不修剪；备注气泡复制修剪后的完整备注。
        #expect(TaskCopyContent.text(.title, title: sample.title, notes: notes) == sample.title)
        #expect(TaskCopyContent.text(.notes, title: sample.title, notes: notes)
            == LegacyTaskRowCopy.fullNote(notes: sample.notes, note: sample.note))
    }

    @Test func emptyNotesCannotProduceNotesCopyButRecordFallsBackToTitle() {
        for blank in [nil, "", " ", "\n\n", "\t \r\n"] as [String?] {
            let notes = TaskCopyContent.notes(blank)
            #expect(notes == nil)
            #expect(TaskCopyContent.text(.notes, title: "T", notes: notes) == nil)
            #expect(TaskCopyContent.text(.record, title: "T", notes: notes) == "T")
        }
    }

    @Test func multilineNotesKeepInnerLayoutAndTrimOnlyEdges() {
        let notes = TaskCopyContent.notes("\n  a\n\n  b  \n")
        #expect(notes == "a\n\n  b")
        #expect(TaskCopyContent.text(.record, title: "T", notes: notes) == "T\na\n\n  b")
    }

    @Test func catalogSectionChoicesAreTheRuleModes() throws {
        let command = try #require(CommandCatalog.standard.command(id: .init(rawValue: "todo.copy")))
        let parameter = try #require(command.parameters.first { $0.id == .section })
        guard case .choice(let choices) = parameter.type else { Issue.record("section 不是 choice"); return }
        #expect(choices.map(\.value) == TaskCopySection.allCases.map(\.rawValue))
    }
}
