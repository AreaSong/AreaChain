import SwiftUI

// MARK: - Backward Compatibility Typealiases & Bridges to Theme Layer

public enum TaskTitleTruncation {
    /// 任务行与手记行共用 `RowTitleTruncation` 的加权规则。
    static func isTruncated(_ title: String, threshold: Double = 14.0) -> Bool {
        RowTitleTruncation.isTruncated(title, threshold: threshold)
    }
}

public typealias TaskTitleBubble = RowTitleBubble

public typealias TaskNoteBubble = RowNoteBubble
