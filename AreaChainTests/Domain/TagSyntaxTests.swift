import Foundation
import Testing
@testable import AreaChain

struct TagSyntaxTests {
    @Test func recognizesTheConfirmedExampleAndMultipleTags() {
        let text = "#今日 今天很开心\n#生活 #今日 #Work #work"
        #expect(TagSyntax.names(in: text) == ["今日", "生活", "Work"])
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        #expect(parsed.cleanTitle == "今天很开心")
        #expect(parsed.tagNames == ["今日", "生活", "Work"])
        #expect(parsed.notes == "#生活 #今日 #Work #work")
    }

    @Test func quotesRoundTripNamesWithSpacesAndUnicode() {
        let names = ["项目 A", "C++", "café", "旅行计划", "with \"quotes\""]
        for name in names {
            #expect(TagSyntax.names(in: TagSyntax.spelling(for: name)) == [name])
        }
        #expect(TagSyntax.normalizedName("ＷＯＲＫ") == TagSyntax.normalizedName("work"))
    }

    @Test func linksEscapesAndCodeRemainLiteral() {
        let text = "C# foo#bar https://example.com/#anchor name@example.com \\#原文\n"
            + "\u{0060}#行内\u{0060}\n\u{0060}\u{0060}\u{0060}swift\n#代码\n\u{0060}\u{0060}\u{0060}\n#真实"
        #expect(TagSyntax.names(in: text) == ["真实"])
        #expect(TagSyntax.removingTags(from: text).contains("\\#原文"))
        #expect(TagSyntax.removingTags(from: text).contains("#代码"))
        #expect(TagSyntax.names(in: "# 标题 ## 二级标题").isEmpty)
    }

    @Test func taskTagsRespectExistingDiaryClassificationBoundary() {
        #expect(TagSyntax.names(in: "#密码 #今日 #小巧思 #日记", includesDiaryTags: false) == ["今日"])
        #expect(TagSyntax.names(in: "#密码 #今日") == ["密码", "今日"])
    }

    @Test func quotedNamesAreTrimmedBeforeDeduplicationAndClassification() {
        let text = "#\" 今日 \" #今日 #\" 密码 \" #\" 小巧思 \" #\" 日记 \" #\"   \""
        #expect(TagSyntax.names(in: text) == ["今日", "密码", "小巧思", "日记"])
        #expect(TagSyntax.names(in: text, includesDiaryTags: false) == ["今日"])
        #expect(TagSyntax.uniqueNames([" 今日 ", "今日", " Work ", "work", " "]) == ["今日", "Work"])
    }

    @Test(arguments: [1, 2, 3, 4])
    func codeDelimitersProtectTagsPriorityAndTime(width: Int) {
        let delimiter = String(repeating: "\u{0060}", count: width)
        let literal = "\(delimiter) #代码 !p1 @18:00 \(delimiter)"
        let parsed = NaturalLanguageParser.parseTaskCapture("说明 \(literal) #真实")
        #expect(parsed.tagNames == ["真实"])
        #expect(!parsed.hasPriorityToken && parsed.remindMinutes == nil)
        #expect(parsed.cleanTitle == "说明 \(literal)")
        let cursor = ("说明 \(delimiter) #代码" as NSString).length
        #expect(SyntaxAutocompleteEngine.detectTrigger(in: parsed.rawInput, cursorLocation: cursor) == nil)
    }

    @Test func innerBackticksAndMarkdownLinksRemainLiteral() {
        let literal = "说明 \u{0060}\u{0060} 单个 \u{0060} #代码 !p1 @18:00 \u{0060}\u{0060}"
        let links = "[说明](#章节) [手册](docs/#页码)"
        for input in [literal, links] {
            let parsed = NaturalLanguageParser.parseTaskCapture(input + " #真实")
            #expect(parsed.tagNames == ["真实"])
            #expect(!parsed.hasPriorityToken && parsed.remindMinutes == nil)
            #expect(parsed.cleanTitle == input)
        }
        let incomplete = "[说明](#章"
        #expect(SyntaxAutocompleteEngine.detectTrigger(in: incomplete, cursorLocation: (incomplete as NSString).length) == nil)
    }

    @Test func syntaxOnlyTitlesKeepTheirInputRatherThanBecomingEmpty() {
        #expect(TagSyntax.title(from: "#今日") == "#今日")
        let parsed = NaturalLanguageParser.parseTaskCapture("#今日 #生活")
        #expect(parsed.cleanTitle == "")
        #expect(parsed.tagNames == ["今日", "生活"])
    }

    @Test func attributesDoNotConsumeLiteralCopiesInCodeOrWords() {
        let parsed = NaturalLanguageParser.parseTaskCapture(
            "讨论 A!p1 \u{0060}!p1 @10:00\u{0060} !p1 @10:00"
        )
        #expect(parsed.cleanTitle == "讨论 A!p1 \u{0060}!p1 @10:00\u{0060}")
        #expect(parsed.remindMinutes == 600)
        #expect(parsed.isImportant && parsed.isUrgent)
        let notes = NaturalLanguageParser.parseTaskNotes("下午3点开会\n#今日\n@18:00 !p2")
        #expect(notes.remindMinutes == 1080)
        #expect(notes.tagNames == ["今日"])
        #expect(notes.isImportant && !notes.isUrgent)
        #expect(NaturalLanguageParser.parseTaskNotes("下午3点开会").remindMinutes == nil)
    }

    @Test func completionSharesBoundariesAndSupportsQuotedNames() throws {
        for input in ["C#", "a#标签", "\\#原文", "https://x/#片段", "\u{0060}#代码"] {
            #expect(SyntaxAutocompleteEngine.detectTrigger(in: input, cursorLocation: (input as NSString).length) == nil)
        }
        let text = "#\"项目 A"
        let trigger = try #require(SyntaxAutocompleteEngine.detectTrigger(in: text, cursorLocation: (text as NSString).length))
        let candidates = SyntaxAutocompleteEngine.candidates(for: trigger, availableTags: ["项目 Alpha"], context: .tags)
        #expect(candidates.contains { $0.insertText == "#\"项目 Alpha\" " })
        #expect(candidates.first?.subtitle == "syntax.tag.create.on.save")
    }

    @Test func tagOnlyContextsNeverSuggestUnownedAttributes() {
        for context in [SyntaxInputContext.tags, .taskTags, .tagSearch] {
            for kind in [SyntaxTriggerKind.priority, .time] {
                let trigger = SyntaxTrigger(kind: kind, query: "", range: NSRange(location: 0, length: 1))
                #expect(SyntaxAutocompleteEngine.candidates(for: trigger, context: context).isEmpty)
            }
        }
        let trigger = SyntaxTrigger(kind: .tag, query: "不存在", range: NSRange(location: 0, length: 4))
        #expect(SyntaxAutocompleteEngine.candidates(for: trigger, context: .tagSearch).allSatisfy { !$0.isCreation })
    }
}
