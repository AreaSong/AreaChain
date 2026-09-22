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
        // 与手记行同一加权规则：27 位数字已超过阈值
        #expect(TaskTitleTruncation.isTruncated("123123123112312312311231231"))
        #expect(TaskTitleTruncation.isTruncated("买牛奶") == RowTitleTruncation.isTruncated("买牛奶"))
    }

    @Test func rowTitleBubbleTriggersCopyCallback() {
        var copiedText: String?
        let bubble = RowTitleBubble(title: "测试完整长标题", growsUpward: false, onCopy: {
            copiedText = "测试完整长标题"
        })

        #expect(bubble.title == "测试完整长标题")
        bubble.onCopy?()
        #expect(copiedText == "测试完整长标题")
    }

    @Test func rowNoteBubbleTriggersCopyCallback() {
        var copiedNote: String?
        let bubble = RowNoteBubble(note: "这里是详细手记或任务备注内容", growsUpward: true, bubbleShiftX: -10, onCopy: {
            copiedNote = "这里是详细手记或任务备注内容"
        })

        #expect(bubble.note == "这里是详细手记或任务备注内容")
        bubble.onCopy?()
        #expect(copiedNote == "这里是详细手记或任务备注内容")
    }
}
