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

        // 2～4. 分节验证待办与子任务、重复事项、灵感手记
        try expectFirstTodo(snapshot, tagIDByName: tagIDByName, workTagID: workTagID)
        try expectRoutines(snapshot, workTagID: workTagID)
        try expectDiary(snapshot, tagIDByName: tagIDByName)
    }

    /// 第一条待办与单层子任务、二级缩进转备注；拆出只为控制测试函数长度，断言不变。
    private func expectFirstTodo(_ snapshot: ExportSnapshot, tagIDByName: [String: UUID], workTagID: UUID) throws {
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
    }

    /// 重复事项周期掩码与内嵌语法。
    private func expectRoutines(_ snapshot: ExportSnapshot, workTagID: UUID) throws {
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
    }

    /// 灵感手记。
    private func expectDiary(_ snapshot: ExportSnapshot, tagIDByName: [String: UUID]) throws {
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

    @Test func markdownTablesAndOrderedListsParseIntoRoutinesTodosAndSubtasks() throws {
        let markdown = """
        # 2026年10月11日训练计划 #健身

        ## 一、 每周训练总览日程
        | 周期 | 模块定位 | 训练场地 | 核心目标与内容 |
        | --- | --- | --- | --- |
        | **周一** | **推（Push）** | 健身房 | 胸大肌、三角肌中束 |
        | **周二** | **休息日** | 宿舍 | 保证睡眠 |

        ### 训练日 A：周一【推日 · Push】
        | 序号 | 训练环节 | 动作 / 项目名称 | 组数 × 次数 / 时长 | 组间休息 | 技术要点与安全红线 |
        | :---: | --- | --- | :---: | :---: | --- |
        | **1** | 全身升温 | 跑步机慢走 | 3 分钟 | — | 微出汗即停 |
        | **2** | 正式力量 | **坐姿器械推胸** | 4 组 × 10~12 次 | 60~90 秒 | 挺胸沉肩 |

        ## 今日任务
        1. 购买训练水杯 @14:00 !p2
           - 对比容量与材质
        """

        let draft = try MarkdownPlanParser.parseMarkdown(markdown, defaultDayKey: "2026-10-10")
        let snapshot = try PlanSnapshotCompiler.compile(
            draft,
            context: PlanCompileContext(defaultDayKey: "2026-10-10")
        )

        #expect(snapshot.routines.count == 2)
        #expect(snapshot.routines[0].title == "推（Push）")
        #expect(snapshot.routines[0].isEnabled)
        #expect(WeekdayMask.contains(snapshot.routines[0].weekdayMask, weekday: 2))
        #expect(snapshot.routines[0].notes.contains("健身房"))
        #expect(!snapshot.routines[1].isEnabled)

        #expect(snapshot.todos.count == 2)
        let workoutTodo = snapshot.todos[0]
        #expect(workoutTodo.dayKey == "2026-10-11")
        #expect(workoutTodo.title.contains("训练日 A：周一"))
        #expect(workoutTodo.subtasks.count == 2)
        #expect(workoutTodo.subtasks[0].title.contains("跑步机慢走"))
        #expect(workoutTodo.subtasks[1].title.contains("坐姿器械推胸"))
        #expect(workoutTodo.notes.contains("挺胸沉肩"))

        let orderedTodo = snapshot.todos[1]
        #expect(orderedTodo.title == "购买训练水杯")
        #expect(orderedTodo.remindMinutes == 14 * 60)
        #expect(orderedTodo.subtasks.count == 1)
        #expect(orderedTodo.subtasks[0].title == "对比容量与材质")
    }

    @Test func extremeEdgeCaseSyntaxAndFlatListAutoPromotion() throws {
        // 覆盖：外层 ```markdown 围栏、相对日期（# 明天 / 【日期：后天】）、全角语法（！p1 / ＠15：30 / ＃"核心 项目" / ／／ 备注）、
        // 截止时间（【截止：18:30】）、URL 与行内代码防误伤、无章节混排自动分流为 Routine 与 Diary
        let fencedMarkdown = """
        ```markdown
        # 明天 ＃冲刺

        - [ ] 评审 https://example.com/doc#v1 接口 ＠15：30 ！p1 ＃"核心 项目" 【截止：18:30】 ／／ 核对 `#raw_code` 与 \\#1 编号
        - [ ] 跨日提交验收报告 !p2 【日期：后天】
        - [ ] 每日站会同步 ＠09：15 ＃"核心 项目" 【周期：工作日】
        - 架构灵感：无章节也能直接识别为置顶手记 // 自动分流不丢内容 #小巧思 【置顶】
        ```
        """

        let draft = try MarkdownPlanParser.parseMarkdown(fencedMarkdown, defaultDayKey: "2026-10-11")
        let snapshot = try PlanSnapshotCompiler.compile(
            draft,
            context: PlanCompileContext(defaultDayKey: "2026-10-11")
        )

        #expect(snapshot.todos.count == 2)
        #expect(snapshot.routines.count == 1)
        #expect(snapshot.diaries.count == 1)

        let firstTodo = snapshot.todos[0]
        #expect(firstTodo.dayKey == "2026-10-12") // "明天" -> 2026-10-12
        #expect(firstTodo.remindMinutes == 15 * 60 + 30)
        #expect(firstTodo.dueMinutes == 18 * 60 + 30)
        #expect(firstTodo.isImportant && firstTodo.isUrgent)
        #expect(firstTodo.title.contains("https://example.com/doc#v1"))
        #expect(firstTodo.notes.contains("`#raw_code`"))
        #expect(firstTodo.notes.contains("#1"))

        let secondTodo = snapshot.todos[1]
        #expect(secondTodo.dayKey == "2026-10-13") // "后天" -> 2026-10-13

        let routine = snapshot.routines[0]
        #expect(routine.title == "每日站会同步")
        #expect(routine.weekdayMask == WeekdayMask.workdays)
        #expect(routine.remindMinutes == 9 * 60 + 15)

        let diary = snapshot.diaries[0]
        #expect(diary.isPinned)
        #expect(diary.dayKey == "2026-10-12")
        #expect(diary.text.contains("无章节也能直接识别为置顶手记"))

        let tagNames = Set(snapshot.tags.map(\.name))
        #expect(tagNames.contains("冲刺"))
        #expect(tagNames.contains("核心 项目"))
        #expect(!tagNames.contains("v1"))
        #expect(!tagNames.contains("raw_code"))

        // 验证外层 ```json 围栏 + 字段别名 (tasks / habits / notes)
        let fencedJSON = """
        ```json
        {
          "date": "明天",
          "tasks": [{ "title": "别名任务 !p1 #工作" }],
          "habits": [{ "title": "别名习惯 @08:00", "schedule": "每天" }],
          "notes": [{ "content": "别名手记 #小巧思", "pinned": true }]
        }
        ```
        """
        let jsonDraft = try MarkdownPlanParser.parseJSON(Data(fencedJSON.utf8), defaultDayKey: "2026-10-11")
        #expect(jsonDraft.todos.count == 1 && jsonDraft.todos[0].dayKey == "2026-10-12")
        #expect(jsonDraft.routines.count == 1 && jsonDraft.routines[0].weekdayMask == WeekdayMask.all)
        #expect(jsonDraft.diaries.count == 1 && jsonDraft.diaries[0].isPinned)
    }
}
