import Foundation
import Testing
@testable import AreaChain

struct NaturalLanguageParserAdversarialTests {
    // MARK: - 1. Negative Lookaheads & Boundary Discrimination
    @Test func negativeLookaheadPreventsFalseTimeMatches() {
        // "修复3点问题" should NOT extract 3:00 as reminder
        let p1 = NaturalLanguageParser.parse("修复3点问题")
        #expect(p1.remindMinutes == nil)
        #expect(p1.cleanTitle == "修复3点问题")

        // Other false hour keywords: 缺陷, 建议, 经验, 理由, 变化
        let p2 = NaturalLanguageParser.parse("排查4点缺陷")
        #expect(p2.remindMinutes == nil)
        #expect(p2.cleanTitle == "排查4点缺陷")

        let p3 = NaturalLanguageParser.parse("提出5点建议")
        #expect(p3.remindMinutes == nil)
        #expect(p3.cleanTitle == "提出5点建议")

        let p4 = NaturalLanguageParser.parse("总结2点经验")
        #expect(p4.remindMinutes == nil)
        #expect(p4.cleanTitle == "总结2点经验")

        let p5 = NaturalLanguageParser.parse("陈述3点理由")
        #expect(p5.remindMinutes == nil)
        #expect(p5.cleanTitle == "陈述3点理由")
    }

    @Test func chineseTimeWithPeriodAndNegativeLookahead() {
        // With period + "问题" -> should NOT match
        let p1 = NaturalLanguageParser.parse("下午3点问题")
        #expect(p1.remindMinutes == nil)
        #expect(p1.cleanTitle == "下午3点问题")

        let p2 = NaturalLanguageParser.parse("早上8点问题")
        #expect(p2.remindMinutes == nil)
        #expect(p2.cleanTitle == "早上8点问题")

        let p3 = NaturalLanguageParser.parse("中午12点问题")
        #expect(p3.remindMinutes == nil)
        #expect(p3.cleanTitle == "中午12点问题")

        let p4 = NaturalLanguageParser.parse("晚上9点问题")
        #expect(p4.remindMinutes == nil)
        #expect(p4.cleanTitle == "晚上9点问题")
    }

    @Test func chineseTimeWithPeriodAndValidActionMatches() {
        // With period + action verb -> should match
        let p1 = NaturalLanguageParser.parse("下午3点开会")
        #expect(p1.remindMinutes == 15 * 60)
        #expect(p1.cleanTitle == "开会")

        let p2 = NaturalLanguageParser.parse("早上8点打卡")
        #expect(p2.remindMinutes == 8 * 60)
        #expect(p2.cleanTitle == "打卡")

        let p3 = NaturalLanguageParser.parse("上午10点半讨论方案")
        #expect(p3.remindMinutes == 10 * 60 + 30)
        #expect(p3.cleanTitle == "讨论方案")

        let p4 = NaturalLanguageParser.parse("中午12点聚餐")
        #expect(p4.remindMinutes == 12 * 60)
        #expect(p4.cleanTitle == "聚餐")

        let p5 = NaturalLanguageParser.parse("晚上8点15分看书")
        #expect(p5.remindMinutes == 20 * 60 + 15)
        #expect(p5.cleanTitle == "看书")

        let p6 = NaturalLanguageParser.parse("早上12点测试") // 12am -> 0:00
        #expect(p6.remindMinutes == 0)
        #expect(p6.cleanTitle == "测试")
    }

    @Test func bareChineseHourWithPunctuationOrPrepositionMatches() {
        // Punctuation delimiter
        let p1 = NaturalLanguageParser.parse("3点，去买菜")
        #expect(p1.remindMinutes == 3 * 60)
        #expect(p1.cleanTitle == "，去买菜")

        // Preposition delimiters: 和, 跟, 与, 在, 去, 到, 给, 把, 从, 向
        let p2 = NaturalLanguageParser.parse("3点去买菜")
        #expect(p2.remindMinutes == 3 * 60)
        #expect(p2.cleanTitle == "去买菜")

        let p3 = NaturalLanguageParser.parse("3点在会议室讨论")
        #expect(p3.remindMinutes == 3 * 60)
        #expect(p3.cleanTitle == "在会议室讨论")

        let p4 = NaturalLanguageParser.parse("3点到公司")
        #expect(p4.remindMinutes == 3 * 60)
        #expect(p4.cleanTitle == "到公司")

        let p5 = NaturalLanguageParser.parse("3点向领导汇报")
        #expect(p5.remindMinutes == 3 * 60)
        #expect(p5.cleanTitle == "向领导汇报")

        // Space delimiter
        let p6 = NaturalLanguageParser.parse("3点 开会")
        #expect(p6.remindMinutes == 3 * 60)
        #expect(p6.cleanTitle == "开会")
    }

    // MARK: - 2. Multiline Titles & Notes
    @Test func multilineSplitsFirstLineAsTitleAndRemainderAsNotes() {
        let input = """
        完成需求评审 #工作 !p1 @14:00
        - 补充架构图
        - 确认测试边界
        https://example.com/doc
        """
        let parsed = NaturalLanguageParser.parse(input)
        #expect(parsed.cleanTitle == "完成需求评审")
        #expect(parsed.tagName == "工作")
        #expect(parsed.isImportant == true)
        #expect(parsed.isUrgent == true)
        #expect(parsed.remindMinutes == 14 * 60)
        #expect(parsed.notes == "- 补充架构图\n- 确认测试边界\nhttps://example.com/doc")
    }

    @Test func multilinePreservesTokensInNotesWithoutParsingThem() {
        let input = """
        第一行标题
        第二行备注包含 #忽略标签 !p2 @16:00
        第三行备注包含更多信息
        """
        let parsed = NaturalLanguageParser.parse(input)
        #expect(parsed.cleanTitle == "第一行标题")
        #expect(parsed.tagName == nil)
        #expect(parsed.isImportant == false)
        #expect(parsed.isUrgent == false)
        #expect(parsed.remindMinutes == nil)
        #expect(parsed.notes.contains("#忽略标签"))
        #expect(parsed.notes.contains("!p2"))
        #expect(parsed.notes.contains("@16:00"))
    }

    @Test func emptyAndWhitespaceInputsHandleSafely() {
        let empty = NaturalLanguageParser.parse("")
        #expect(empty.cleanTitle == "")
        #expect(empty.notes == "")
        #expect(empty.hasTokens == false)

        let spacesOnly = NaturalLanguageParser.parse("     ")
        #expect(spacesOnly.cleanTitle == "     ")
        #expect(spacesOnly.notes == "")

        let tokenOnly = NaturalLanguageParser.parse("#工作 !p1 @10:00")
        #expect(tokenOnly.tagName == "工作")
        #expect(tokenOnly.isImportant == true)
        #expect(tokenOnly.isUrgent == true)
        #expect(tokenOnly.remindMinutes == 10 * 60)
        // When all tokens consumed, fallback keeps original title
        #expect(tokenOnly.cleanTitle == "#工作 !p1 @10:00")
    }

    // MARK: - 3. Priority Parsing Matrix
    @Test func priorityParsingAllFourQuadrantsChinese() {
        // Important & Urgent
        let iu1 = NaturalLanguageParser.parse("任务 !重要紧急")
        #expect(iu1.isImportant == true && iu1.isUrgent == true)
        #expect(iu1.priorityLabel == "quadrant.iu")

        let iu2 = NaturalLanguageParser.parse("任务 !紧急重要")
        #expect(iu2.isImportant == true && iu2.isUrgent == true)
        #expect(iu2.priorityLabel == "quadrant.iu")

        let iu3 = NaturalLanguageParser.parse("任务 !重要且紧急")
        #expect(iu3.isImportant == true && iu3.isUrgent == true)
        #expect(iu3.priorityLabel == "quadrant.iu")

        // Important, Not Urgent
        let i1 = NaturalLanguageParser.parse("任务 !重要")
        #expect(i1.isImportant == true && i1.isUrgent == false)
        #expect(i1.priorityLabel == "quadrant.i")

        let i2 = NaturalLanguageParser.parse("任务 !重要不紧急")
        #expect(i2.isImportant == true && i2.isUrgent == false)
        #expect(i2.priorityLabel == "quadrant.i")

        // Urgent, Not Important
        let u1 = NaturalLanguageParser.parse("任务 !紧急")
        #expect(u1.isImportant == false && u1.isUrgent == true)
        #expect(u1.priorityLabel == "quadrant.u")

        let u2 = NaturalLanguageParser.parse("任务 !不重要紧急")
        #expect(u2.isImportant == false && u2.isUrgent == true)
        #expect(u2.priorityLabel == "quadrant.u")
    }

    @Test func priorityParsingPNotationCaseInsensitive() {
        // Lowercase
        let p1 = NaturalLanguageParser.parse("任务 !p1")
        #expect(p1.isImportant == true && p1.isUrgent == true && p1.hasPriorityToken)
        #expect(p1.priorityLabel == "quadrant.iu")

        let p2 = NaturalLanguageParser.parse("任务 !p2")
        #expect(p2.isImportant == true && p2.isUrgent == false && p2.hasPriorityToken)
        #expect(p2.priorityLabel == "quadrant.i")

        let p3 = NaturalLanguageParser.parse("任务 !p3")
        #expect(p3.isImportant == false && p3.isUrgent == true && p3.hasPriorityToken)
        #expect(p3.priorityLabel == "quadrant.u")

        let p4 = NaturalLanguageParser.parse("任务 !p4")
        #expect(p4.isImportant == false && p4.isUrgent == false && p4.hasPriorityToken)
        #expect(p4.priorityLabel == "quadrant.rest")

        // Uppercase
        let bigP1 = NaturalLanguageParser.parse("任务 !P1")
        #expect(bigP1.isImportant == true && bigP1.isUrgent == true)

        let bigP2 = NaturalLanguageParser.parse("任务 !P2")
        #expect(bigP2.isImportant == true && bigP2.isUrgent == false)

        let bigP3 = NaturalLanguageParser.parse("任务 !P3")
        #expect(bigP3.isImportant == false && bigP3.isUrgent == true)

        let bigP4 = NaturalLanguageParser.parse("任务 !P4")
        #expect(bigP4.isImportant == false && bigP4.isUrgent == false)
    }

    @Test func nonPriorityExclamationsAreIgnored() {
        let p = NaturalLanguageParser.parse("紧急警告! !p5 请立刻处理")
        #expect(p.hasPriorityToken == false)
        #expect(p.isImportant == false)
        #expect(p.isUrgent == false)
        #expect(p.priorityLabel == nil)
        #expect(p.cleanTitle == "紧急警告! !p5 请立刻处理")
    }

    // MARK: - 4. Preset Tag Skipping: Task vs Diary
    @Test func parseTaskCaptureSkipsAllPresetTags() {
        // Single preset tags skipped in task capture
        let p1 = NaturalLanguageParser.parseTaskCapture("备忘 #密码")
        #expect(p1.tagName == nil)
        #expect(p1.cleanTitle == "备忘 #密码")

        let p2 = NaturalLanguageParser.parseTaskCapture("创意 #小巧思")
        #expect(p2.tagName == nil)
        #expect(p2.cleanTitle == "创意 #小巧思")

        let p3 = NaturalLanguageParser.parseTaskCapture("记录 #日记")
        #expect(p3.tagName == nil)
        #expect(p3.cleanTitle == "记录 #日记")

        // Multiple presets skipped in task capture
        let p4 = NaturalLanguageParser.parseTaskCapture("记录 #密码 #小巧思 #日记")
        #expect(p4.tagName == nil)
        #expect(p4.cleanTitle == "记录 #密码 #小巧思 #日记")
    }

    @Test func parseTaskCaptureSkipsPresetsAndCapturesUserTag() {
        // Preset before user tag
        let p1 = NaturalLanguageParser.parseTaskCapture("整理账户 #密码 #安全")
        #expect(p1.tagName == "安全")
        #expect(p1.cleanTitle == "整理账户 #密码")

        // User tag before preset
        let p2 = NaturalLanguageParser.parseTaskCapture("记录想法 #工作 #小巧思")
        #expect(p2.tagName == "工作")
        #expect(p2.cleanTitle == "记录想法 #小巧思")
    }

    @Test func parseDiaryConsumesPresetTags() {
        // In diary parsing, preset tags are consumed
        let p1 = NaturalLanguageParser.parse("家里路由器 #密码")
        #expect(p1.tagName == "密码")
        #expect(p1.cleanTitle == "家里路由器")

        let p2 = NaturalLanguageParser.parse("随想灵感 #小巧思")
        #expect(p2.tagName == "小巧思")
        #expect(p2.cleanTitle == "随想灵感")

        let p3 = NaturalLanguageParser.parse("今日随笔 #日记")
        #expect(p3.tagName == "日记")
        #expect(p3.cleanTitle == "今日随笔")
    }

    // MARK: - 5. Standard Clock Formats & Invalid Formats
    @Test func standardClockFormatsAndBoundaries() {
        let p1 = NaturalLanguageParser.parse("早会 @09:30")
        #expect(p1.remindMinutes == 9 * 60 + 30)
        #expect(p1.timeLabel == "09:30")

        let p2 = NaturalLanguageParser.parse("深夜回顾 23:59")
        #expect(p2.remindMinutes == 23 * 60 + 59)
        #expect(p2.timeLabel == "23:59")

        let p3 = NaturalLanguageParser.parse("午夜 00:00")
        #expect(p3.remindMinutes == 0)
        #expect(p3.timeLabel == "00:00")

        // Invalid hour or minute should not parse
        let p4 = NaturalLanguageParser.parse("错误时间 25:00")
        #expect(p4.remindMinutes == nil)

        let p5 = NaturalLanguageParser.parse("错误分钟 12:60")
        #expect(p5.remindMinutes == nil)
    }
}
