import Foundation
import Testing
@testable import AreaChain

struct NaturalLanguageParserTests {
    @Test func parsesTimeAndTagAndPriority() {
        let input = "下午3点半 团队周会 #工作 !重要"
        let parsed = NaturalLanguageParser.parse(input)
        #expect(parsed.cleanTitle == "团队周会")
        #expect(parsed.remindMinutes == 15 * 60 + 30)
        #expect(parsed.tagName == "工作")
        #expect(parsed.isImportant == true)
        #expect(parsed.isUrgent == false)
        #expect(parsed.hasTokens == true)
    }

    @Test func parsesAtTimeSyntax() {
        let input = "修复登录Bug @10:15 #开发 !p1"
        let parsed = NaturalLanguageParser.parse(input)
        #expect(parsed.cleanTitle == "修复登录Bug")
        #expect(parsed.remindMinutes == 10 * 60 + 15)
        #expect(parsed.tagName == "开发")
        #expect(parsed.isImportant == true)
        #expect(parsed.isUrgent == true)
    }

    @Test func parsesEveningTimeAndUrgent() {
        let input = "晚上8点 跑步打卡 #健康 !紧急"
        let parsed = NaturalLanguageParser.parse(input)
        #expect(parsed.cleanTitle == "跑步打卡")
        #expect(parsed.remindMinutes == 20 * 60)
        #expect(parsed.tagName == "健康")
        #expect(parsed.isImportant == false)
        #expect(parsed.isUrgent == true)
    }

    @Test func plainInputWithoutTokens() {
        let input = "纯普通待办事项"
        let parsed = NaturalLanguageParser.parse(input)
        #expect(parsed.cleanTitle == "纯普通待办事项")
        #expect(parsed.remindMinutes == nil)
        #expect(parsed.tagName == nil)
        #expect(parsed.isImportant == false)
        #expect(parsed.isUrgent == false)
        #expect(parsed.hasTokens == false)
    }

    @Test func parsesMultiLineInputIntoTitleAndNotes() {
        let input = "周会准备 #工作 !重要\n需要统计本周各模块数据\nhttps://example.com/sheet"
        let parsed = NaturalLanguageParser.parse(input)
        #expect(parsed.cleanTitle == "周会准备")
        #expect(parsed.tagName == "工作")
        #expect(parsed.isImportant == true)
        #expect(parsed.notes == "需要统计本周各模块数据\nhttps://example.com/sheet")
    }

    @Test func parsesP4AndShowsPriorityToken() {
        let parsed = NaturalLanguageParser.parse("整理桌面 !p4")
        #expect(parsed.cleanTitle == "整理桌面")
        #expect(parsed.isImportant == false)
        #expect(parsed.isUrgent == false)
        #expect(parsed.hasPriorityToken == true)
        #expect(parsed.hasTokens == true)
        #expect(parsed.priorityLabel == "quadrant.rest")
    }

    @Test func chineseHourDoesNotEatTitleDigits() {
        let parsed = NaturalLanguageParser.parse("修复3点问题")
        #expect(parsed.cleanTitle == "修复3点问题")
        #expect(parsed.remindMinutes == nil)
    }

    @Test func chineseNoonFollowedByHeStillParsesHour() {
        let parsed = NaturalLanguageParser.parse("中午12点和产品经理吃午饭 !p2 #工作")
        #expect(parsed.remindMinutes == 12 * 60)
        #expect(parsed.tagName == "工作")
        #expect(parsed.isImportant == true)
        #expect(parsed.isUrgent == false)
        #expect(parsed.cleanTitle == "和产品经理吃午饭")
    }

    @Test func afternoonHourGluedToVerbStillParses() {
        let parsed = NaturalLanguageParser.parse("下午3点开会")
        #expect(parsed.remindMinutes == 15 * 60)
        #expect(parsed.cleanTitle == "开会")
    }

    @Test func afternoonHourGluedToWentiDoesNotParse() {
        let parsed = NaturalLanguageParser.parse("下午3点问题")
        #expect(parsed.remindMinutes == nil)
        #expect(parsed.cleanTitle == "下午3点问题")
    }
}
