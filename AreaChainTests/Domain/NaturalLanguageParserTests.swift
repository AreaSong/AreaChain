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

    @Test func diaryParseConsumesPresetHashtag() {
        let parsed = NaturalLanguageParser.parse("wifi #密码")
        #expect(parsed.tagName == "密码")
        #expect(parsed.cleanTitle == "wifi")
    }

    @Test func taskCaptureKeepsPresetHashtagInTitle() {
        let parsed = NaturalLanguageParser.parseTaskCapture("买菜 #密码")
        #expect(parsed.tagName == nil)
        #expect(parsed.cleanTitle == "买菜 #密码")
        #expect(parsed.hasTokens == false)
    }

    @Test func taskCaptureSkipsPresetThenTakesNextTag() {
        let parsed = NaturalLanguageParser.parseTaskCapture("买菜 #密码 #工作")
        #expect(parsed.tagName == "工作")
        #expect(parsed.cleanTitle == "买菜 #密码")
        #expect(parsed.hasTokens == true)
    }

    @Test func tokenOnlyDetection() {
        let onlyTime = NaturalLanguageParser.parseTaskCapture("@01:00")
        #expect(onlyTime.hasTokens == true)
        #expect(onlyTime.hasContentTitle == false)
        #expect(onlyTime.isTokenOnly == true)
        #expect(onlyTime.remindMinutes == 60)
        #expect(onlyTime.cleanTitle == "")

        let onlyTag = NaturalLanguageParser.parseTaskCapture("#123")
        #expect(onlyTag.hasTokens == true)
        #expect(onlyTag.hasContentTitle == false)
        #expect(onlyTag.isTokenOnly == true)
        #expect(onlyTag.tagName == "123")
        #expect(onlyTag.cleanTitle == "")

        let timeAndTag = NaturalLanguageParser.parseTaskCapture("@01:00 #工作 !p1")
        #expect(timeAndTag.hasTokens == true)
        #expect(timeAndTag.hasContentTitle == false)
        #expect(timeAndTag.isTokenOnly == true)
        #expect(timeAndTag.cleanTitle == "")

        let timeWithContent = NaturalLanguageParser.parseTaskCapture("@01:00 团队开会")
        #expect(timeWithContent.hasTokens == true)
        #expect(timeWithContent.hasContentTitle == true)
        #expect(timeWithContent.isTokenOnly == false)
        #expect(timeWithContent.cleanTitle == "团队开会")
    }

    @Test func extractHighlightTokensDetection() {
        let text = "@01:00 团队开会 #工作 !p1"
        let tokens = NaturalLanguageParser.extractHighlightTokens(in: text)
        #expect(tokens.count == 3)

        // 验证各 token 类型
        let hasTime = tokens.contains { token in
            if case .time(let m) = token.kind { return m == 60 }
            return false
        }
        let hasTag = tokens.contains { token in
            if case .tag(let name) = token.kind { return name == "工作" }
            return false
        }
        let hasPriority = tokens.contains { token in
            if case .priority(let imp, let urg, _) = token.kind { return imp && urg }
            return false
        }

        #expect(hasTime == true)
        #expect(hasTag == true)
        #expect(hasPriority == true)
    }

    @Test func parsesSingleLineNoteWithSlash() {
        let input = "买咖啡 // 要脱脂大杯"
        let parsed = NaturalLanguageParser.parse(input)
        #expect(parsed.cleanTitle == "买咖啡")
        #expect(parsed.notes == "要脱脂大杯")
        #expect(parsed.hasTokens == false)
    }

    @Test func parsesSingleLineNoteWithFullWidthSlash() {
        let input = "写周报 ／／ 记得同步项目进度"
        let parsed = NaturalLanguageParser.parse(input)
        #expect(parsed.cleanTitle == "写周报")
        #expect(parsed.notes == "记得同步项目进度")
    }

    @Test func parsesHybridAttributesBeforeAndAfterNote() {
        let input = "买咖啡 @14:00 // 要脱脂大杯 #日常 !p1"
        let parsed = NaturalLanguageParser.parse(input)
        #expect(parsed.cleanTitle == "买咖啡")
        #expect(parsed.notes == "要脱脂大杯")
        #expect(parsed.remindMinutes == 14 * 60)
        #expect(parsed.tagName == "日常")
        #expect(parsed.isImportant == true)
        #expect(parsed.isUrgent == true)
    }

    @Test func extractsHighlightTokensWithNote() {
        let text = "买咖啡 // 要脱脂 @14:00 大杯"
        let tokens = NaturalLanguageParser.extractHighlightTokens(in: text)
        let hasNote = tokens.contains { token in
            if case .note = token.kind { return true }
            return false
        }
        let hasTime = tokens.contains { token in
            if case .time(let m) = token.kind { return m == 14 * 60 }
            return false
        }
        #expect(hasNote == true)
        #expect(hasTime == true)
    }
}
