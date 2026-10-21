import Foundation

/// 合并批 M-4 D：手记复制内容的唯一规则（同 TaskCopyContent）。整篇是读出的原文；标题与备注沿手记卡片行的
/// 首行／其余拆分（首行为空时整段作标题、没有备注）。只用于普通手记的明文，受保护手记不在这里取正文。
enum DiaryCopyContent {
    enum Section: String, CaseIterable, Equatable {
        case record, title, notes
    }

    /// 卡片行显示与复制共用的拆分：mainText 是标题（或唯一一行），note 是其余（空时为 nil）。
    static func split(_ text: String) -> (mainText: String, note: String?) {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let newlineIndex = raw.firstIndex(of: "\n") else { return (raw, nil) }
        let firstLine = String(raw[..<newlineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let rest = String(raw[raw.index(after: newlineIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if firstLine.isEmpty { return (rest, nil) }
        return (firstLine, rest.isEmpty ? nil : rest)
    }

    /// 要复制的文字；备注为空时没有可复制的内容（nil），与卡片行只在有备注时提供复制一致。
    static func text(_ section: Section, from text: String) -> String? {
        switch section {
        case .record: return text
        case .title: return split(text).mainText
        case .notes: return split(text).note
        }
    }
}
