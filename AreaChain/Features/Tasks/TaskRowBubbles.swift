import SwiftUI

// MARK: - Backward Compatibility Typealiases & Bridges to Theme Layer

public enum TaskTitleTruncation {
    /// 在菜单栏弹窗（~380pt 宽）的单行展示下，判定标题是否真正容易被尾部截断。
    /// ASCII 字符按 0.55 权重，全角/中文按 1.0 权重。
    /// 在标题优先展开（layoutPriority 1）下，单行可完整容纳约 20 个汉字或 36 个英文字符。
    static func isTruncated(_ title: String, threshold: Double = 20.0) -> Bool {
        let weighted = title.reduce(0.0) { sum, char in
            sum + (char.isASCII ? 0.55 : 1.0)
        }
        return weighted > threshold
    }
}

public typealias TaskTitleBubble = RowTitleBubble

public typealias TaskNoteBubble = RowNoteBubble
