import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized)
struct ActionCLIParserTests {
    private var sampleMetadata: [ActionMetadataDescriptor] {
        [
            ActionMetadataDescriptor(
                id: "task.move",
                titleKey: "action.task.move",
                englishTitle: "Move Task Date",
                chineseTitle: "移动待办日期",
                commandNames: ["move", "mv", "移动", "改期"],
                iconName: "calendar",
                category: .task,
                parameters: [
                    ActionParameterSpec(
                        id: "date",
                        englishName: "Date",
                        chineseName: "目标日期",
                        required: true,
                        allowedValues: ["today", "tomorrow", "next-week"]
                    ),
                ],
                permissionLevel: .normal,
                riskLevel: .direct,
                recordsUndo: true
            ),
            ActionMetadataDescriptor(
                id: "task.create",
                titleKey: "action.task.create",
                englishTitle: "Create Task",
                chineseTitle: "新建待办",
                commandNames: ["task", "t", "待办", "新建待办"],
                iconName: "plus.circle",
                category: .task,
                parameters: [],
                permissionLevel: .normal,
                riskLevel: .direct,
                recordsUndo: true
            ),
            ActionMetadataDescriptor(
                id: "settings.theme",
                titleKey: "action.settings.theme",
                englishTitle: "Switch Appearance Theme",
                chineseTitle: "切换外观主题",
                commandNames: ["theme", "外观", "主题"],
                iconName: "paintbrush",
                category: .settings,
                parameters: [
                    ActionParameterSpec(
                        id: "mode",
                        englishName: "Mode",
                        chineseName: "模式",
                        required: true,
                        allowedValues: ["system", "light", "dark"]
                    ),
                ],
                permissionLevel: .normal,
                riskLevel: .direct,
                recordsUndo: true
            ),
        ]
    }

    @Test func contractPermissionOrderAndDiffFormatting() {
        #expect(ActionPermissionLevel.normal < ActionPermissionLevel.privacy)
        #expect(ActionPermissionLevel.privacy < ActionPermissionLevel.system)
        #expect(ActionPermissionLevel.normal < ActionPermissionLevel.system)

        let diff = ActionDiff(
            actionID: "task.move",
            actionTitle: "移动待办日期",
            targetTitle: "买牛奶",
            changes: [
                ActionFieldChange(field: "日期", before: "2026-11-05", after: "2026-11-06"),
            ],
            isSensitive: false
        )
        #expect(diff.formattedSummary == "买牛奶：日期 2026-11-05 → 2026-11-06")
        #expect(diff.formattedSummary(isVaultUnlocked: false) == "买牛奶：日期 2026-11-05 → 2026-11-06")

        let sensitiveDiff = ActionDiff(
            actionID: "diary.edit",
            actionTitle: "编辑手记",
            targetTitle: "私密日记标题",
            changes: [
                ActionFieldChange(field: "正文", before: "旧摘要", after: "新摘要"),
            ],
            isSensitive: true
        )
        #expect(sensitiveDiff.formattedSummary(isVaultUnlocked: true) == "私密日记标题：正文 旧摘要 → 新摘要")
        #expect(sensitiveDiff.formattedSummary(isVaultUnlocked: false) == ActionDiff.redactedPlaceholder)
        #expect(!sensitiveDiff.matches(keyword: "私密日记标题", isVaultUnlocked: false))
        #expect(sensitiveDiff.matches(keyword: "私密日记标题", isVaultUnlocked: true))
    }

    @Test func parseSlashCommandWithOptionsFlagsAndInlineNLP() {
        let input = "/task 买牛奶 !p1 @15:30 #采购 --date=2026-11-06 --confirm // 记得看保质期"
        let parsed = ActionCLIParser.parse(input)

        guard case .command(let args) = parsed else {
            Issue.record("预期解析为 .command")
            return
        }
        #expect(args.commandName == "task")
        #expect(args.targetQuery == nil)
        #expect(args.positional == ["买牛奶"])
        #expect(args.option("date") == "2026-11-06")
        #expect(args.hasFlag("confirm"))
        #expect(args.inlineNLP.cleanText == "买牛奶")
        #expect(args.inlineNLP.tags == ["采购"])
        #expect(args.inlineNLP.remindMinutes == 15 * 60 + 30)
        #expect(args.inlineNLP.timeLabel == "15:30")
        #expect(args.inlineNLP.isImportant)
        #expect(args.inlineNLP.isUrgent)
        #expect(args.inlineNLP.hasPriorityToken)
        #expect(args.inlineNLP.notes == "记得看保质期")
    }

    @Test func parsePipelineSyntaxAndQuotedPositionalArguments() {
        let parsed = ActionCLIParser.parse("买牛奶 > move tomorrow --confirm")
        guard case .pipeline(let args) = parsed else {
            Issue.record("预期解析为 .pipeline")
            return
        }
        #expect(args.targetQuery == "买牛奶")
        #expect(args.commandName == "move")
        #expect(args.positional == ["tomorrow"])
        #expect(args.hasFlag("confirm"))

        let quoted = ActionCLIParser.parse(#"/task "买牛奶 2盒" --tag="家庭 采购""#)
        guard case .command(let quotedArgs) = quoted else {
            Issue.record("预期解析为 .command")
            return
        }
        #expect(quotedArgs.commandName == "task")
        #expect(quotedArgs.positional == ["买牛奶 2盒"])
        #expect(quotedArgs.option("tag") == "家庭 采购")
    }

    @Test func matchActionsByCommandAliasAndTitleInSearchMode() {
        let byShort = ActionCLIParser.matchActions(query: "mv", in: sampleMetadata)
        #expect(byShort.first?.id == "task.move")

        let byChinese = ActionCLIParser.matchActions(query: "改期", in: sampleMetadata)
        #expect(byChinese.first?.id == "task.move")

        let byTitle = ActionCLIParser.matchActions(query: "外观主题", in: sampleMetadata)
        #expect(byTitle.first?.id == "settings.theme")
    }

    @Test func tabCompletionsForCommandNamesPipelineAndAllowedValues() {
        let cmdCompletions = ActionCLIParser.completions(for: "/mo", in: sampleMetadata)
        #expect(cmdCompletions.contains { $0.completedInput == "/move " && $0.actionID == "task.move" })

        let pipeCompletions = ActionCLIParser.completions(for: "买牛奶 > mo", in: sampleMetadata)
        #expect(pipeCompletions.contains { $0.completedInput == "买牛奶 > move " })

        let posValueCompletions = ActionCLIParser.completions(for: "/move tom", in: sampleMetadata)
        #expect(posValueCompletions.contains {
            $0.kind == .parameterValue && $0.completedInput == "/move tomorrow"
        })

        let optNameCompletions = ActionCLIParser.completions(for: "/theme --m", in: sampleMetadata)
        #expect(optNameCompletions.contains {
            $0.kind == .parameterName && $0.completedInput == "/theme --mode="
        })

        let optValueCompletions = ActionCLIParser.completions(for: "/theme --mode=da", in: sampleMetadata)
        #expect(optValueCompletions.contains {
            $0.kind == .parameterValue && $0.completedInput == "/theme --mode=dark"
        })
    }
}
