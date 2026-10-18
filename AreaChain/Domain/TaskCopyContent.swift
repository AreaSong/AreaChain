import Foundation

/// 任务行复制与 todo.copy 共用的唯一内容规则；标题保持原文，备注沿原行的修剪口径。
enum TaskCopySection: String, CaseIterable, Equatable, Sendable {
    case record, title, notes
}

enum TaskCopyContent {
    /// 完整备注优先；空白备注视为没有备注，回退文字只供旧行呈现的摘要来源使用。
    static func notes(_ notes: String?, fallback: String? = nil) -> String? {
        for candidate in [notes, fallback] {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    /// 返回 nil 表示该模式没有可复制内容；调用方不能因此写入空剪贴板。
    static func text(_ section: TaskCopySection, title: String, notes: String?) -> String? {
        switch section {
        case .record: return notes.map { title + "\n" + $0 } ?? title
        case .title: return title
        case .notes: return notes
        }
    }
}
