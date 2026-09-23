//
//  SyntaxHelpCard.swift
//  AreaChain
//
//  Created by Antigravity on 2026-09-10.
//

import SwiftUI

/// 快捷输入语法伴随气泡卡片（平时纯净单项介绍，悬停原地切换真实范例，底部常驻全能综合复杂范例）
struct SyntaxExpandableCard: View {
    @Binding var isExpanded: Bool
    var context: SyntaxInputContext = .capture
    var onSelectToken: (String) -> Void
    var onSelectExample: ((String) -> Void)? = nil

    @State private var hoveredToken: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            DaybookDivider(opacity: 0.35)
                .padding(.horizontal, 12)

            syntaxItemsList
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

            DaybookDivider(opacity: 0.35)
                .padding(.horizontal, 12)

            complexExampleBar
                .padding(.horizontal, 10)
                .padding(.vertical, 6.5)
        }
        .frame(width: DaybookTheme.popoverWidth - 24)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .fill(DaybookTheme.paper)
                .daybookElevation(.floating)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .stroke(DaybookTheme.rule.opacity(0.6), lineWidth: 0.8) // token-exempt: 60% 分隔线没有对应令牌
        )
        .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous))
        .onExitCommand {
            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                isExpanded = false
            }
        }
    }

    // MARK: - 顶栏

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(DaybookType.subtitle.weight(.semibold))
                .foregroundStyle(DaybookTheme.stamp)

            Text(context == .search ? "syntax.search.title" : "syntax.guide.title")
                .font(DaybookType.subtitle.weight(.bold))
                .foregroundStyle(DaybookTheme.ink)

            Spacer(minLength: 0)

            DaybookIconButton(systemName: "xmark", label: "common.close", size: .inline) {
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isExpanded = false
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: - 单项语法列表（悬停原地平滑替换为单项范例）

    private var syntaxItemsList: some View {
        VStack(alignment: .leading, spacing: 3.5) {
            // 1. # 标签分类
            syntaxRow(
                token: "#",
                title: "标签分类",
                exampleSnippet: "写周报 #工作",
                exampleText: Text("写周报 ")
                    + Text("#工作").foregroundStyle(Color(nsColor: .systemIndigo)).bold() // token-exempt: 没有靛蓝令牌
                    + Text("  或  ")
                    + Text("#生活").foregroundStyle(Color(nsColor: .systemIndigo)).bold() // token-exempt: 没有靛蓝令牌
                    + Text(" 买牛奶"),
                color: Color(nsColor: .systemIndigo) // token-exempt: 没有靛蓝令牌
            )

            // 2. ! 四象限优先级
            syntaxRow(
                token: "!",
                title: "四象限优先级",
                exampleSnippet: "修线上Bug !p1",
                exampleText: Text("修线上Bug ")
                    + Text("!p1").foregroundStyle(DaybookTheme.destructive).bold()
                    + Text("  或  ")
                    + Text("!p2").foregroundStyle(DaybookPalette.status.pending).bold()
                    + Text(" 整理书架"),
                color: DaybookTheme.destructive
            )

            // 3. @ 时刻提醒
            if context.supportsTaskAttributes {
                syntaxRow(
                    token: "@",
                    title: "时刻提醒",
                    exampleSnippet: "开晨会 @10:00",
                    exampleText: Text("开晨会 ")
                        + Text("@10:00").foregroundStyle(DaybookTheme.stamp).bold()
                        + Text("  或  明天下午 散步"),
                    color: DaybookTheme.stamp
                )
            }

            // 4. ⌘↩ 直接存入手记
            if context == .capture {
                syntaxRow(
                    token: "⌘↩",
                    title: "直接存入手记",
                    exampleSnippet: "随时记录灵感闪念",
                    exampleText: Text("随时记录灵感 ")
                        + Text("⌘↵").foregroundStyle(DaybookTheme.stamp).bold()
                        + Text(" 直接存入今日手记"),
                    color: DaybookTheme.stamp
                )

                // 5. ⇧↩ 换行输入备注
                syntaxRow(
                    token: "⇧↩",
                    title: "换行输入备注",
                    exampleSnippet: "首行待办标题\n换行输入详细备注",
                    exampleText: Text("首行标题 ")
                        + Text("⇧↵").foregroundStyle(DaybookTheme.ink).bold()
                        + Text(" 换行转备注 (悬停清单查看)"),
                    color: DaybookTheme.muted
                )
            }
        }
    }

    private func syntaxRow(
        token: String,
        title: String,
        exampleSnippet: String,
        exampleText: Text,
        color: Color
    ) -> some View {
        let isHovered = hoveredToken == token

        return Button {
            if let onSelectExample {
                onSelectExample(exampleSnippet)
            } else {
                onSelectToken(token)
            }
        } label: {
            ZStack(alignment: .leading) {
                if isHovered {
                    // 悬停聚焦态：整条直接替换为完整真实范例 + 填入试用
                    HStack(alignment: .center, spacing: 4) {
                        exampleText
                            .font(.system(size: 10.5, design: .monospaced)) // token-exempt: 等宽范例，kbd 是 8.5pt
                            .foregroundStyle(DaybookTheme.ink)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        HStack(spacing: 2) {
                            Text("填入试用")
                                .font(.system(size: 8.5, weight: .semibold)) // token-exempt: 小于 9pt，kbd 是等宽
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 8.5)) // token-exempt: 小于 9pt，kbd 是等宽
                        }
                        .foregroundStyle(DaybookTheme.stamp)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(DaybookPalette.accent.fill)
                        )
                    }
                    .transition(.opacity)
                } else {
                    // 默认未聚焦态：极致干净素雅，仅展示符号徽标与条例名称
                    HStack(alignment: .center, spacing: 8) {
                        Text(token)
                            .font(.system(size: 11, weight: .bold, design: .monospaced)) // token-exempt: 等宽符号，kbd 是 8.5pt
                            .foregroundStyle(color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                                    .fill(color.opacity(0.14)) // token-exempt: 符号色 14% 不是印章色
                            )
                            .frame(width: 32, alignment: .center)

                        Text(LocalizedStringKey(title))
                            .font(DaybookType.caption.weight(.semibold))
                            .foregroundStyle(DaybookTheme.ink)

                        Spacer(minLength: 0)
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: 22)
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous) // token-exempt: 5pt 与 xs、small 都差 1pt
                    .fill(isHovered ? DaybookTheme.stamp.opacity(0.06) : Color.clear) // token-exempt: 6% 印章底没有对应令牌
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 语法条目悬停替换正文
        .onHover { hovering in
            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                hoveredToken = hovering ? token : nil
            }
        }
    }

    // MARK: - 底部总复杂范例（常驻展示，点击一键注入输入框试用）

    private var complexExampleBar: some View {
        Button {
            onSelectExample?("重构核心模块 #工作 !p1 @15:30")
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(DaybookType.badge)
                        .foregroundStyle(DaybookPalette.status.pending.opacity(0.9)) // token-exempt: 90% 待办橙没有对应令牌

                    (Text("重构核心模块 ")
                        + Text("#工作").foregroundStyle(Color(nsColor: .systemIndigo)).bold() // token-exempt: 没有靛蓝令牌
                        + Text(" ")
                        + Text("!p1").foregroundStyle(DaybookTheme.destructive).bold()
                        + Text(" ")
                        + Text("@15:30").foregroundStyle(DaybookTheme.stamp).bold())
                        .font(.system(size: 11, weight: .medium, design: .monospaced)) // token-exempt: 等宽范例，kbd 是 8.5pt
                        .foregroundStyle(DaybookTheme.ink)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    HStack(spacing: 2) {
                        Text("填入试用")
                            .font(.system(size: 8.5, weight: .semibold)) // token-exempt: 小于 9pt，kbd 是等宽
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 8.5)) // token-exempt: 小于 9pt，kbd 是等宽
                    }
                    .foregroundStyle(DaybookTheme.stamp)
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(DaybookPalette.accent.fill)
                    )
                }

                HStack(spacing: 4) {
                    Text("综合范例：全属性完整待办 · 顺序自由，点击一键试用")
                        .font(DaybookType.micro)
                        .foregroundStyle(DaybookTheme.muted)

                    Spacer(minLength: 0)

                    Text("Esc")
                        .font(DaybookType.kbd.weight(.bold))
                        .foregroundStyle(DaybookTheme.muted.opacity(0.8)) // token-exempt: 80% 次要色没有对应令牌
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .daybookSurface(.card, configure: { $0.radius = DaybookRadius.small })
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 语法范例卡片
    }
}
