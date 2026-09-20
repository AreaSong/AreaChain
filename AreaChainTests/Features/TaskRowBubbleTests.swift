import Foundation
import Testing
@testable import AreaChain

@Suite
struct TaskRowBubbleTests {
    @Test func titleTruncationDetectsLengthCorrectly() {
        // 短标题不应触发截断判定
        #expect(!TaskTitleTruncation.isTruncated("买牛奶"))
        #expect(!TaskTitleTruncation.isTruncated("Hello"))
        #expect(!TaskTitleTruncation.isTruncated("1234567890"))

        // 临界与超长中文标题应判定为截断
        #expect(TaskTitleTruncation.isTruncated("这是一个很长很长需要换行显示的今日待办任务"))

        // 超长英文与数字（真正超出单行容量）应判定为截断
        #expect(TaskTitleTruncation.isTruncated("11111111111111111111111111111111111111111111"))
        // 能够在单行完整显示的字符（如 27 位数字）不应判定为截断
        #expect(!TaskTitleTruncation.isTruncated("123123123112312312311231231"))
    }
}
