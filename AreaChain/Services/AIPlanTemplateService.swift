import Foundation
import SwiftData

/// 生成 AreaChain AI 计划模板包 (.zip)，并将外部 .md / .json 计划统一编译为 ExportSnapshot。
enum AIPlanTemplateService {
    struct TemplateEntry: Equatable, Sendable {
        var path: String
        var content: String
    }

    /// 仅提取未删除、非私密、非手记预设三分类的公开标签名，供 AI 模板参考。
    static func publicTagNames(from tags: [TagItem]) -> [String] {
        Catalog.liveTaskTags(tags)
            .filter { !$0.isPrivateDiary }
            .map(\.name)
    }

    static func makeTemplateZipData(
        publicTagNames: [String],
        todayKey: String = DayKey.today()
    ) -> Data {
        let entries = templateEntries(publicTagNames: publicTagNames, todayKey: todayKey)
        return ZipStoredWriter.archive(entries: entries)
    }

    static func templateEntries(
        publicTagNames: [String],
        todayKey: String = DayKey.today()
    ) -> [TemplateEntry] {
        let cleanTags = TagSyntax.uniqueNames(publicTagNames)
        return [
            TemplateEntry(path: "areachain-ai-kit/README.md", content: makeReadmeMarkdown()),
            TemplateEntry(
                path: "areachain-ai-kit/SKILL.md",
                content: makeSkillMarkdown(publicTags: cleanTags, todayKey: todayKey)
            ),
            TemplateEntry(
                path: "areachain-ai-kit/templates/plan-template.md",
                content: makeMarkdownTemplate(todayKey: todayKey)
            ),
            TemplateEntry(
                path: "areachain-ai-kit/templates/plan-template.json",
                content: makeJSONTemplate(todayKey: todayKey)
            )
        ]
    }

    @MainActor
    static func decodeSnapshot(
        from data: Data,
        fileExtension: String,
        context: ModelContext,
        defaultDayKey: String = DayKey.today(),
        now: Date = .now
    ) throws -> ExportSnapshot {
        let ext = fileExtension.lowercased()
        if ext == "json" || (ext.isEmpty && looksLikeJSON(data)) {
            if let snapshot = try? SyncPort.decode(data) {
                return snapshot
            }
            let draft = try MarkdownPlanParser.parseJSON(data, defaultDayKey: defaultDayKey)
            let compileContext = try makeCompileContext(in: context, defaultDayKey: defaultDayKey, now: now)
            return try PlanSnapshotCompiler.compile(draft, context: compileContext)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw PlanImportError.invalidFormat
        }
        let draft = try MarkdownPlanParser.parseMarkdown(text, defaultDayKey: defaultDayKey)
        let compileContext = try makeCompileContext(in: context, defaultDayKey: defaultDayKey, now: now)
        return try PlanSnapshotCompiler.compile(draft, context: compileContext)
    }

    @MainActor
    private static func makeCompileContext(
        in context: ModelContext,
        defaultDayKey: String,
        now: Date
    ) throws -> PlanCompileContext {
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        let exportedTags = tags.map {
            ExportedTag(
                id: $0.id,
                name: $0.name,
                sortOrder: $0.sortOrder,
                deletedAt: $0.deletedAt,
                colorToken: $0.colorToken
            )
        }
        var maxOrdersByDay: [String: Int] = [:]
        for todo in todos {
            let current = maxOrdersByDay[todo.dayKey] ?? -1
            if todo.sortOrder > current {
                maxOrdersByDay[todo.dayKey] = todo.sortOrder
            }
        }
        let maxRoutineOrder = routines.map(\.sortOrder).max() ?? -1
        let dismissed = Set(
            DiaryMemoTags.presets
                .filter { DiaryPresetRetention.isDismissed($0) }
                .map { TagSyntax.normalizedName($0) }
        )
        let privateTagKeys = Set(
            tags.filter { $0.isPrivateDiary || DiaryMemoTags.isPasswordName($0.name) }
                .map { TagSyntax.normalizedName($0.name) }
                .filter { !$0.isEmpty }
        )
        return PlanCompileContext(
            existingTags: exportedTags,
            existingTodoMaxOrders: maxOrdersByDay,
            existingRoutineMaxOrder: maxRoutineOrder,
            dismissedDiaryPresets: dismissed,
            privateDiaryTagNames: privateTagKeys,
            defaultDayKey: defaultDayKey,
            now: now
        )
    }

    private static func looksLikeJSON(_ data: Data) -> Bool {
        guard let str = String(data: data.prefix(64), encoding: .utf8) else { return false }
        return str.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{")
    }

    // MARK: - 模板文案生成

    private static func makeReadmeMarkdown() -> String {
        """
        # AreaChain AI 计划与手记生成工具包 (AI Plan Kit)

        本压缩包帮助你用任意 AI 助手（Claude、ChatGPT、Cursor、Antigravity 等）快速生成符合 AreaChain 语法规范的**待办事项、重复习惯与灵感手记**，并一键导回 AreaChain。

        ## 包含文件

        1. `SKILL.md`：符合 Agent Skill 标准的核心语法与领域规则说明。你可以将它直接发送给 AI，或放入 `.agents/skills/areachain-planner/SKILL.md`。
        2. `templates/plan-template.md`：人类与 AI 双可读的 Markdown 计划示例模板。
        3. `templates/plan-template.json`：免 UUID 的轻量结构化 JSON 计划示例模板。

        ## 三步使用方法

        1. **交给 AI**：将 `SKILL.md`（或任一模板文件）拖入 AI 对话框，告诉 AI 你的目标（例如：「参考这份规范，帮我拆解下周的产品发布待办、每日运动习惯和复盘手记，输出一个 `.md` 文件」）。
        2. **内嵌语法自动识别**：无论使用 `.md` 还是 `.json`，只要在标题或正文里写上 `#标签`、`!p1`~`!p4`（四象限优先级）、`@15:30`（提醒时刻）、`// 备注`，AreaChain 都会在导入时自动识别。
        3. **预览确认与一键导入**：打开 AreaChain 工作台「系统 -> 数据与备份」，点击「导入计划 (.md / .json)」，在弹出的**结构化识别预览窗口**中核对识别出的待办、子任务、重复事项、手记与标签（含新增/复用标签与私密手记加锁标识），\
        点击「确认导入」即可落库并一键跳转到对应日期。
        """
    }

    private static func makeSkillMarkdown(publicTags: [String], todayKey: String) -> String {
        let tagListText = publicTags.isEmpty
            ? "（当前暂无已有公开标签，可直接按需编写 `#新标签`）"
            : publicTags.map { TagSyntax.spelling(for: $0) }.joined(separator: "、")
        // 各节之间原本就是一个空行；按节拆开只为控制函数长度，拼接结果逐字不变。
        return [
            skillIntroduction,
            skillSyntaxSection(tagListText: tagListText),
            skillDomainSection(todayKey: todayKey),
            skillMarkdownExample(todayKey: todayKey),
            skillJSONExample(todayKey: todayKey),
            skillAdvancedSection(todayKey: todayKey)
        ].joined(separator: "\n\n")
    }

    private static var skillIntroduction: String {
        """
        ---
        name: areachain-planner
        description: "根据用户目标生成可直接导入 AreaChain 的结构化计划（支持 .md 与轻量 .json），覆盖一次性待办、单层子任务、重复事项与灵感手记。"
        ---

        # AreaChain 计划与手记生成规范 (SKILL)

        当用户要求制定计划、拆解任务、安排习惯或整理手记并导入 AreaChain 时，请严格按照本规范输出 `.md` 或 `.json` 文件。
        """
    }

    private static func skillSyntaxSection(tagListText: String) -> String {
        """
        ## 1. 核心内嵌语法（Markdown 与 JSON 通用）

        AreaChain 导入器会对标题与正文自动执行自然语言解析：
        - **四象限优先级**：`!p1`（重要且紧急）、`!p2`（重要不紧急）、`!p3`（紧急不重要）、`!p4`（其余）；也支持 `!重要且紧急`、`!重要`、`!紧急`。
        - **提醒时刻**：`@09:30`、`@15:00` 或中文时刻（如 `下午3点半`）。
        - **标签语法**：`#标签名`（多个标签用空格分隔，带空格标签写成 `#"项目 A"`）。
          - **本机已有公开标签（请优先复用）**：\(tagListText)
          - **新标签默认创建**：如果现有标签不满足需求，你可以直接编写当前没有的 `#新标签`，AreaChain 导入时会自动创建该标签。
          - **分类隔离约束**：`#密码`、`#小巧思`、`#日记` 是手记专属分类，**不要**挂在待办或重复事项上。
        - **备注切分**：在标题行末尾使用 `// 备注内容`（或在 Markdown 下一行使用缩进 `> 备注`）写入长文本备注。
        """
    }

    private static func skillDomainSection(todayKey: String) -> String {
        """
        ## 2. 领域结构与单层子任务约束

        - **一次性待办 (`Todo`)**：归属于具体民事日期 `YYYY-MM-DD`（未指定时默认归入导入当天，参考基准日：`\(todayKey)`；也兼容 `2026年10月11日` 或 `2026/10/11` 标题日期）。支持标准复选框 `- [ ]`、普通列表 `- `、有序列表 `1. ` 及 Markdown 动作表格。
        - **子任务 (`Subtask`) 严格仅支持一层**：
          - 每个待办下可包含若干第一层子任务（缩进 `- [ ] 子任务 #子标签`）。
          - **严禁生成二级或更深层级的嵌套子任务**；更细的执行步骤请写成所属待办下的 `> 备注说明`。
        - **重复事项 (`Routine`)**：放在 `## 重复事项`（或 `## Routines`）章节下，用 `[repeat: daily]`（每天）、`[repeat: workdays]`（工作日）或 `[repeat: mon,wed,fri]`（指定星期）声明周期；\
        也支持周计划 Markdown 表格（第一列为星期一～星期日）。
        - **灵感手记 (`Diary`)**：放在 `## 灵感手记`（或 `## Diaries`）章节下，支持 `#小巧思`、`#日记`、`#密码` 及自定义标签，可用 `[pinned]` 标记置顶、用 `[day: YYYY-MM-DD]` 指定归属日。
          - **私密手记免密投递加锁**：若手记带有 `#密码` 或用户在 AreaChain 中设为「私密手记」的标签，导入时无需输入密码即可直接入库并**自动加锁隐藏**（查看或编辑时才需验证密码/Touch ID）。注意：请勿将真实明文敏感密码直接发给不受信任的外部云端模型。
        """
    }

    private static func skillMarkdownExample(todayKey: String) -> String {
        """
        ## 3. 标准 Markdown 输出格式示例 (`.md`)

        ```markdown
        # \(todayKey)

        - [ ] 下午3点 核心架构评审 !p1 #工作 // 准备性能对比基准表
          - [ ] 整理基准测试报告 #文档
          - [x] 预约会议室与投影设备
        - [ ] 阅读技术专著第 3 章 !p2 @20:30 #阅读
          > 重点记录并发模型与内存边界章节的思考

        ## 重复事项
        - [ ] 写日报与明日规划 @18:00 !p2 #工作 [repeat: workdays]
        - [ ] 有氧夜跑 5 公里 @20:00 #运动 [repeat: mon,wed,fri]

        ## 灵感手记
        - 关于模块化重构的思考 // 把高频变化的解析器留在纯领域层，零 UI 依赖更易测试 #小巧思 [pinned]
        ```
        """
    }

    private static func skillJSONExample(todayKey: String) -> String {
        """
        ## 4. 轻量 JSON 输出格式示例 (`.json`，免 UUID)

        ```json
        {
          "dayKey": "\(todayKey)",
          "todos": [
            {
              "dayKey": "\(todayKey)",
              "title": "下午3点 核心架构评审 !p1 #工作 // 准备性能对比基准表",
              "subtasks": [
                "整理基准测试报告 #文档",
                "[x] 预约会议室与投影设备"
              ]
            }
          ],
          "routines": [
            {
              "title": "写日报与明日规划 @18:00 !p2 #工作",
              "repeat": "workdays"
            }
          ],
          "diaries": [
            {
              "text": "关于模块化重构的思考 // 把高频变化的解析器留在纯领域层 #小巧思",
              "isPinned": true
            }
          ]
        }
        ```
        """
    }

    private static func skillAdvancedSection(todayKey: String) -> String {
        """
        ## 5. 高阶与特殊写法全兼容说明

        AreaChain 解析器内置了对各类特殊写法与复杂排版的自动容错：
        - **相对日期与行内跨日**：标题或行内支持 `# 今天`、`# 明天`、`# 后天` 及 `[day: 明天]` / `【日期：\(todayKey)】`，可在同一列表内跨日排程；支持 `[due: 18:00]` / `【截止：18:00】` 设置截止时刻。
        - **无章节混排自动分流**：即便不写 `## 重复事项` 或 `## 灵感手记` 章节，只要列表项带有 `[repeat: ...]` / `【周期：...】` 会自动识别为**重复事项**；无复选框列表项带有 `#小巧思`、`#日记`、\
        `#密码` 或 `[pinned]` / `【置顶】` 会自动识别为**灵感手记**。
        - **Markdown 表格智能拆解**：
          - 第一列为「周一～周日」的表格 $\rightarrow$ 自动转为按对应星期启用的**重复事项**（含「休息」字样的行自动设为停用）。
          - 含「环节/动作/组数/时长/要点」等列的表格 $\rightarrow$ 自动合并为**待办与子任务**，技术要点自动转入备注。
        - **全角符号与复杂文本防误伤**：
          - 自动兼容全角 `＃标签`、`！p1`、`＠09：30`、`／／ 备注` 与中文方括号 `【...】`。
          - 带空格标签使用双引号 `#"项目 A"`；URL（如 `https://example.com/doc#v1`）与行内代码（`` `#literal` ``）中的 `//`、`#` 不会被误判为备注或标签；如需输出字面符号可用反斜杠转义（`\\#`、`\\@`、`\\!`、`\\//`）。
          - JSON 同样兼容顶层任务数组 `[...]` 以及常见字段别名（`tasks`/`items`、`habits`、`notes`/`memos`）。
        """
    }

    private static func makeMarkdownTemplate(todayKey: String) -> String {
        let tomorrowKey = DayKey.shifted(todayKey, by: 1)
        return """
        # \(todayKey)

        - [ ] 下午3点 核心方案评审 !p1 #工作 // 准备好架构演进图与测试指标
          - [ ] 核对核心模块测试覆盖率 #测试
          - [x] 整理会议议程文档
        - [ ] 晚间深度阅读 45 分钟 !p2 @21:00 #成长
          > 记录关键章节摘要与行动启发

        # \(tomorrowKey)

        - [ ] 跟进评审反馈并落地拆分任务 !p2 @10:00 #工作

        ## 重复事项

        - [ ] 每日晨间规划 @09:00 !p2 #工作 [repeat: workdays]
        - [ ] 核心体能训练 @19:30 #运动 [repeat: mon,wed,fri]

        ## 灵感手记

        - 结构化计划导入灵感 // 用 AI 生成 Markdown 清单再一键导入，省去逐条录入的繁琐 #小巧思 [pinned]
        """
    }

    private static func makeJSONTemplate(todayKey: String) -> String {
        """
        {
          "dayKey": "\(todayKey)",
          "todos": [
            {
              "dayKey": "\(todayKey)",
              "title": "下午3点 核心方案评审 !p1 #工作 // 准备好架构演进图与测试指标",
              "subtasks": [
                "核对核心模块测试覆盖率 #测试",
                "[x] 整理会议议程文档"
              ]
            },
            {
              "dayKey": "\(todayKey)",
              "title": "晚间深度阅读 45 分钟 !p2 @21:00 #成长",
              "notes": "记录关键章节摘要与行动启发"
            }
          ],
          "routines": [
            {
              "title": "每日晨间规划 @09:00 !p2 #工作",
              "repeat": "workdays"
            },
            {
              "title": "核心体能训练 @19:30 #运动",
              "repeat": "mon,wed,fri"
            }
          ],
          "diaries": [
            {
              "text": "结构化计划导入灵感 // 用 AI 生成清单再一键导入，省去逐条录入的繁琐 #小巧思",
              "dayKey": "\(todayKey)",
              "isPinned": true
            }
          ]
        }
        """
    }
}

/// 纯内存 ZIP Stored (Method 0) 归档构造器，不产生磁盘临时目录与外部进程调用。
enum ZipStoredWriter {
    static func archive(entries: [AIPlanTemplateService.TemplateEntry]) -> Data {
        var body = Data()
        var centralDirectory = Data()
        for entry in entries {
            let pathData = Data(entry.path.utf8)
            let contentData = Data(entry.content.utf8)
            let crc = crc32(contentData)
            let offset = UInt32(body.count)
            let size = UInt32(contentData.count)
            appendLocalHeader(to: &body, pathData: pathData, crc: crc, size: size)
            body.append(contentData)
            appendCentralHeader(
                to: &centralDirectory,
                pathData: pathData,
                crc: crc,
                size: size,
                localOffset: offset
            )
        }
        let cdOffset = UInt32(body.count)
        let cdSize = UInt32(centralDirectory.count)
        body.append(centralDirectory)
        appendEndOfCentralDirectory(
            to: &body,
            entryCount: UInt16(entries.count),
            cdSize: cdSize,
            cdOffset: cdOffset
        )
        return body
    }

    private static func appendLocalHeader(
        to data: inout Data,
        pathData: Data,
        crc: UInt32,
        size: UInt32
    ) {
        data.appendUInt32LE(0x0403_4b50)
        data.appendUInt16LE(20)
        data.appendUInt16LE(0x0800) // UTF-8 文件名标记
        data.appendUInt16LE(0) // Method 0: Stored
        data.appendUInt16LE(0)
        data.appendUInt16LE(0x0021)
        data.appendUInt32LE(crc)
        data.appendUInt32LE(size)
        data.appendUInt32LE(size)
        data.appendUInt16LE(UInt16(pathData.count))
        data.appendUInt16LE(0)
        data.append(pathData)
    }

    private static func appendCentralHeader(
        to data: inout Data,
        pathData: Data,
        crc: UInt32,
        size: UInt32,
        localOffset: UInt32
    ) {
        data.appendUInt32LE(0x0201_4b50)
        data.appendUInt16LE(20)
        data.appendUInt16LE(20)
        data.appendUInt16LE(0x0800)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0x0021)
        data.appendUInt32LE(crc)
        data.appendUInt32LE(size)
        data.appendUInt32LE(size)
        data.appendUInt16LE(UInt16(pathData.count))
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt32LE(0)
        data.appendUInt32LE(localOffset)
        data.append(pathData)
    }

    private static func appendEndOfCentralDirectory(
        to data: inout Data,
        entryCount: UInt16,
        cdSize: UInt32,
        cdOffset: UInt32
    ) {
        data.appendUInt32LE(0x0605_4b50)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt16LE(entryCount)
        data.appendUInt16LE(entryCount)
        data.appendUInt32LE(cdSize)
        data.appendUInt32LE(cdOffset)
        data.appendUInt16LE(0)
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = (crc >> 8) ^ crcTable[index]
        }
        return crc ^ 0xffff_ffff
    }

    private static let crcTable: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? (0xedb8_8320 ^ (c >> 1)) : (c >> 1)
        }
        return c
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
