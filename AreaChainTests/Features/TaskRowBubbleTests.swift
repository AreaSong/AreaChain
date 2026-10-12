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

    @Test func rowNoteBubblePlacementKeepsArrowAlignedWithIcon() {
        // 场景 1: 工作台大屏右侧，有明确 hostMaxX
        let iconX: CGFloat = 850
        let hostMaxX: CGFloat = 1000
        let placement = RowBubblePlacement.calculate(
            globalPoint: CGPoint(x: iconX, y: 300),
            wideHost: true,
            hostMaxX: hostMaxX
        )
        #expect(placement.growsUpward == true)
        // 850 + 202 = 1052, 超出 52pt, 应平移 -52pt
        #expect(placement.bubbleShiftX == -52)
        // 箭头在气泡内的 padding: 8 - (-52) = 60
        let arrowPadding: CGFloat = max(8, min(186, 8 - placement.bubbleShiftX))
        // 箭头的世界坐标: iconX - 8 + bubbleShiftX + arrowPadding 必须恒等于 iconX
        let arrowGlobalX = iconX - 8 + placement.bubbleShiftX + arrowPadding
        #expect(arrowGlobalX == iconX, "箭头绝对位置必须精准对准图标")

        // 场景 2: 极端靠右，平移量受 178pt 上限保护，不可造成箭头脱离
        let extremeIconX: CGFloat = 1300
        let extremePlacement = RowBubblePlacement.calculate(
            globalPoint: CGPoint(x: extremeIconX, y: 300),
            wideHost: true,
            hostMaxX: 1350
        )
        #expect(extremePlacement.bubbleShiftX >= -178, "平移幅度不可超过箭头可补偿上限 178pt")
    }
}
