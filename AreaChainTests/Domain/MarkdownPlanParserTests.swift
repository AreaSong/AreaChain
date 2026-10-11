import Foundation
import Testing
@testable import AreaChain

struct MarkdownPlanParserTests {
    @Test func markdownPlanParsesTodosSubtasksRoutinesAndDiariesWithInlineSyntax() throws {
        let workTagID = UUID()
        let existingWorkTag = ExportedTag(id: workTagID, name: "工作", sortOrder: 0)
        let markdown = """
        ---
        title: Weekly Plan
        ---
        # 2026-10-12 #冲刺

        - [ ] 下午3点半 核心架构评审 !p1 #工作 #新专题 // 准备基准对比表
          > 提前发邮件给参会人
          - [ ] 核对性能报告 #测试
          - [x] 预约会议室 #密码
              - [ ] 二级缩进步骤自动降级进备注
        - [x] 整理发布清单 !重要 @09:15

        ## 重复事项 #习惯标签
        - [ ] 每日晨会复盘 @09:00 !p2 #工作 [repeat: workdays]
          > 控制在 15 分钟内
        - [ ] 夜跑 5 公里 @20:00 #运动 [repeat: mon,wed,fri] [paused]

        ## 灵感手记
        - 今天产生了一个关于多格式语法导入的新灵感 // 支持已有标签复用与缺失标签默认创建 #自定义手记签 [pinned] [day: 2026-10-13]
        """

        let draft = try MarkdownPlanParser.parseMarkdown(markdown, defaultDayKey: "2026-10-11")
        #expect(draft.todos.count == 2)
        #expect(draft.routines.count == 2)
        #expect(draft.diaries.count == 1)

        let context = PlanCompileContext(
            existingTags: [existingWorkTag],
            defaultDayKey: "2026-10-11",
            now: Date(timeIntervalSince1970: 1_760_000_000)
        )
        let snapshot = try PlanSnapshotCompiler.compile(draft, context: context)

        // 1. 验证标签：已有「工作」直接复用（不在新导出标签列表里重复创建），缺失的标签自动创建
        let newTagNames = Set(snapshot.tags.map(\.name))
        #expect(!newTagNames.contains("工作"))
        #expect(newTagNames.contains("冲刺"))
        #expect(newTagNames.contains("新专题"))
        #expect(newTagNames.contains("测试"))
        #expect(newTagNames.contains("习惯标签"))
        #expect(newTagNames.contains("运动"))
        #expect(newTagNames.contains("自定义手记签"))
        #expect(newTagNames.contains(DiaryMemoTags.idea))
        #expect(!newTagNames.contains(DiaryMemoTags.password))

        let tagIDByName = Dictionary(
            uniqueKeysWithValues: ([existingWorkTag] + snapshot.tags).map { ($0.name, $0.id) }
        )

        // 2. 验证第一条待办与单层子任务、二级缩进转备注
        let firstTodo = try #require(snapshot.todos.first)
        #expect(firstTodo.title == "核心架构评审")
        #expect(firstTodo.dayKey == "2026-10-12")
        #expect(!firstTodo.isDone)
        #expect(firstTodo.remindMinutes == 15 * 60 + 30)
        #expect(firstTodo.isImportant && firstTodo.isUrgent)
        #expect(firstTodo.notes.contains("准备基准对比表"))
        #expect(firstTodo.notes.contains("提前发邮件给参会人"))
        #expect(firstTodo.notes.contains("二级缩进步骤自动降级进备注"))
        #expect(TagIDList.contains(firstTodo.tagIDs, workTagID))
        #expect(TagIDList.contains(firstTodo.tagIDs, try #require(tagIDByName["冲刺"])))
        #expect(TagIDList.contains(firstTodo.tagIDs, try #require(tagIDByName["新专题"])))

        #expect(firstTodo.subtasks.count == 2)
        #expect(firstTodo.subtasks[0].title == "核对性能报告")
        #expect(!firstTodo.subtasks[0].isDone)
        #expect(TagIDList.contains(firstTodo.subtasks[0].tagIDs, try #require(tagIDByName["测试"])))
        // 子任务上的 #密码 不会挂成待办侧标签
        #expect(firstTodo.subtasks[1].isDone)
        #expect(TagIDList.parse(firstTodo.subtasks[1].tagIDs).isEmpty)

        // 3. 验证重复事项周期掩码与内嵌语法
        let firstRoutine = try #require(snapshot.routines.first)
        #expect(firstRoutine.title == "每日晨会复盘")
        #expect(firstRoutine.isEnabled)
        #expect(firstRoutine.weekdayMask == WeekdayMask.workdays)
        #expect(firstRoutine.remindMinutes == 9 * 60)
        #expect(firstRoutine.isImportant && !firstRoutine.isUrgent)
        #expect(firstRoutine.notes == "控制在 15 分钟内")
        #expect(TagIDList.contains(firstRoutine.tagIDs, workTagID))

        let secondRoutine = snapshot.routines[1]
        #expect(secondRoutine.title == "夜跑 5 公里")
        #expect(!secondRoutine.isEnabled)
        #expect(WeekdayMask.contains(secondRoutine.weekdayMask, weekday: 2)) // 周一
        #expect(WeekdayMask.contains(secondRoutine.weekdayMask, weekday: 4)) // 周三
        #expect(WeekdayMask.contains(secondRoutine.weekdayMask, weekday: 6)) // 周五
        #expect(!WeekdayMask.contains(secondRoutine.weekdayMask, weekday: 3)) // 周二未选中

        // 4. 验证灵感手记
        let diary = try #require(snapshot.diaries.first)
        #expect(diary.dayKey == "2026-10-13")
        #expect(diary.isPinned)
        #expect(diary.text.contains("今天产生了一个关于多格式语法导入的新灵感"))
        #expect(diary.text.contains("支持已有标签复用与缺失标签默认创建"))
        #expect(TagIDList.contains(diary.tagIDs, try #require(tagIDByName["自定义手记签"])))
        #expect(TagIDList.contains(diary.tagIDs, try #require(tagIDByName[DiaryMemoTags.idea])))
    }

    @Test func lightweightJSONParsesInlineSyntaxAndCreatesMissingTags() throws {
        let existingID = UUID()
        let existingTag = ExportedTag(id: existingID, name: "研发", sortOrder: 0)
        let json = """
        {
          "dayKey": "2026-10-15",
          "tags": ["全局新标签"],
          "todos": [
            {
              "title": "上午10点 联调接口 !p3 #研发 #接口新签 // 核对返回码",
              "subtasks": [
                "准备 Mock 数据 #测试子签",
                "[x] 确认鉴权头"
              ]
            }
          ],
          "routines": [
            {
              "title": "晚间复盘 @21:30 !p2 #研发 #复盘新签",
              "weekdays": [1, 2, 3, 4, 5]
            }
          ],
          "diaries": [
            {
              "title": "架构思考",
              "text": "轻量 JSON 免去手写 UUID 的负担 #手记新签",
              "pinned": true
            }
          ]
        }
        """

        let draft = try MarkdownPlanParser.parseJSON(Data(json.utf8), defaultDayKey: "2026-10-11")
        let snapshot = try PlanSnapshotCompiler.compile(
            draft,
            context: PlanCompileContext(existingTags: [existingTag], defaultDayKey: "2026-10-11")
        )

        #expect(snapshot.todos.count == 1)
        #expect(snapshot.routines.count == 1)
        #expect(snapshot.diaries.count == 1)

        let todo = snapshot.todos[0]
        #expect(todo.title == "联调接口")
        #expect(todo.dayKey == "2026-10-15")
        #expect(todo.remindMinutes == 10 * 60)
        #expect(!todo.isImportant && todo.isUrgent)
        #expect(todo.notes == "核对返回码")
        #expect(TagIDList.contains(todo.tagIDs, existingID))
        #expect(todo.subtasks.count == 2)
        #expect(todo.subtasks[1].isDone)

        let routine = snapshot.routines[0]
        #expect(routine.weekdayMask == WeekdayMask.workdays)
        #expect(routine.remindMinutes == 21 * 60 + 30)

        let createdNames = Set(snapshot.tags.map(\.name))
        #expect(!createdNames.contains("研发"))
        #expect(createdNames.contains("全局新标签"))
        #expect(createdNames.contains("接口新签"))
        #expect(createdNames.contains("测试子签"))
        #expect(createdNames.contains("复盘新签"))
        #expect(createdNames.contains("手记新签"))
    }
}
