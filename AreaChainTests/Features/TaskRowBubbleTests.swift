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

        // 超长英文与数字（如用户遇到的数字串）应判定为截断
        #expect(TaskTitleTruncation.isTruncated("11111111111111111111111111111111111"))
        #expect(TaskTitleTruncation.isTruncated("123123123112312312311231231"))
    }
}
