import AppKit
import Foundation
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
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
        // 850 + 207.5 = 1057.5, 超出 57.5pt, 应平移 -57.5pt
        #expect(placement.bubbleShiftX == -57.5)
        // 箭头在气泡内的 padding: 8 - (-57.5) = 65.5
        let arrowPadding: CGFloat = max(8, min(186, 8 - placement.bubbleShiftX))
        // 箭头中心的世界坐标: (iconX - 2.5 + bubbleShiftX) + (arrowPadding + 3.5) 必须恒等于图标几何中心 (iconX + 9.0)
        let arrowCenterGlobalX = iconX - 2.5 + placement.bubbleShiftX + arrowPadding + 3.5
        #expect(arrowCenterGlobalX == iconX + 9.0, "箭头中心必须精准对准图标几何中心")

        // 场景 2: 极端靠右，平移量受 178pt 上限保护，不可造成箭头脱离
        let extremeIconX: CGFloat = 1300
        let extremePlacement = RowBubblePlacement.calculate(
            globalPoint: CGPoint(x: extremeIconX, y: 300),
            wideHost: true,
            hostMaxX: 1350
        )
        #expect(extremePlacement.bubbleShiftX >= -178, "平移幅度不可超过箭头可补偿上限 178pt")

        // 场景 3: 菜单栏小窗口 (popover) 长标题场景：即使长文本被排版撑大到 460pt，气泡右边缘也必须严格受限在窗口安全边界 (368pt) 之内
        let popoverLongTitleIconX: CGFloat = 295
        let popoverPlacement = RowBubblePlacement.calculate(
            globalPoint: CGPoint(x: popoverLongTitleIconX, y: 150),
            wideHost: false,
            hostMaxX: 460 // 模拟未被严格截断的行宽
        )
        let bubbleRightInWindow = popoverLongTitleIconX - 2.5 + popoverPlacement.bubbleShiftX + 210
        #expect(bubbleRightInWindow <= 368, "菜单栏气泡右边缘必须严格限制在窗口边界 368pt 内，绝不可被窗口裁剪")
        let popoverArrowPadding = max(8, min(186, 8 - popoverPlacement.bubbleShiftX))
        let popoverArrowCenter = popoverLongTitleIconX - 2.5 + popoverPlacement.bubbleShiftX + popoverArrowPadding + 3.5
        #expect(popoverArrowCenter == popoverLongTitleIconX + 9.0, "长标题左移后小三角仍必须严格对准图标中心")
    }

    @Test(arguments: [false, true])
    func taskRowMultilineTitleBubbleAvoidsRowOverlapAndExpandsSurface(lower: Bool) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }

        let taskID = UUID()
        let longTitle = String(repeating: "1", count: 160)
        let state = TaskRowState(
            identity: TaskRowIdentityState(id: taskID, title: longTitle, isResident: true),
            schedule: TaskRowScheduleState(remindMinutes: 540)
        )
        let window = support.window(
            VStack {
                if lower { Spacer().frame(height: 300) }
                TaskRow(state: state, dispatch: { _ in })
                    .frame(width: 316)
                Spacer()
            }
            .padding(32),
            size: NSSize(width: 380, height: 540)
        )
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)

        let titleRegion = try #require(Self.findTitleRegion(taskID, in: window.contentView))
        let titleRect = titleRegion.convert(titleRegion.bounds, to: nil)
        titleRegion.onHover?(true)
        try await Task.sleep(for: .milliseconds(380))
        try await SystemPageHost.settle(window)

        let bubbleView = try #require(DiaryTitleHoverFixture.regions(window.contentView).first)
        let bubbleRect = bubbleView.convert(bubbleView.bounds, to: nil)
        #expect(abs(bubbleRect.width - 260) < 1, "超长多行任务标题气泡宽度应固定为 260pt")
        #expect(bubbleRect.height > 60, "多行任务标题气泡背景必须随折行高度撑开，不能坍缩成单行高度")
        // titleRegion 含上下各 -6pt 扩展边距，实际单行文字位于 titleRect.insetBy(dx: 0, dy: 6)
        let textRect = titleRect.insetBy(dx: 0, dy: 6)
        if lower {
            #expect(bubbleRect.minY >= textRect.maxY, "向上展开的气泡底边必须位于标题文字上方，不能遮挡当前行标题")
        } else {
            #expect(bubbleRect.maxY <= textRect.minY, "向下展开的气泡顶边必须位于标题文字下方，不能遮挡当前行标题")
        }
    }

    @Test
    func adjacentTaskRowHoverExcludesPreviousBubbleWithoutOverlap() async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }

        let id1 = UUID()
        let id2 = UUID()
        let title1 = String(repeating: "首行长任务标题 ", count: 10)
        let title2 = String(repeating: "次行长任务标题 ", count: 10)
        let state1 = TaskRowState(
            identity: TaskRowIdentityState(id: id1, title: title1),
            schedule: TaskRowScheduleState()
        )
        let state2 = TaskRowState(
            identity: TaskRowIdentityState(id: id2, title: title2),
            schedule: TaskRowScheduleState()
        )

        let window = support.window(
            VStack(spacing: 2) {
                TaskRow(state: state1, dispatch: { _ in }).frame(width: 316)
                TaskRow(state: state2, dispatch: { _ in }).frame(width: 316)
                Spacer()
            }
            .padding(32),
            size: NSSize(width: 380, height: 540)
        )
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)

        let region1 = try #require(Self.findTitleRegion(id1, in: window.contentView))
        let region2 = try #require(Self.findTitleRegion(id2, in: window.contentView))

        // 1. 悬停第二行
        region2.onHover?(true)
        try await Task.sleep(for: .milliseconds(380))
        try await SystemPageHost.settle(window)

        let bubblesAfterSecond = DiaryTitleHoverFixture.regions(window.contentView)
        #expect(bubblesAfterSecond.count == 1, "第二行应展开气泡")

        // 2. 模拟鼠标快速移到第一行
        region1.onHover?(true)
        try await Task.sleep(for: .milliseconds(380))
        try await SystemPageHost.settle(window)

        let bubblesAfterFirst = DiaryTitleHoverFixture.regions(window.contentView)
        #expect(bubblesAfterFirst.count == 1, "切换到第一行后，旧行气泡必须排他关闭，屏幕上绝不能出现两个气泡并存重叠")
    }

    private static func findTitleRegion(_ id: UUID, in view: NSView?) -> BoardRowPointerView? {
        guard let view else { return nil }
        if let region = view as? BoardRowPointerView,
           region.identifier?.rawValue == id.uuidString,
           region.onHover != nil {
            return region
        }
        return view.subviews.lazy.compactMap { findTitleRegion(id, in: $0) }.first
    }
}
