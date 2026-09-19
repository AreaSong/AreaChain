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

            Divider()
                .background(DaybookTheme.rule.opacity(0.35))
                .padding(.horizontal, 12)

            syntaxItemsList
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

            Divider()
                .background(DaybookTheme.rule.opacity(0.35))
                .padding(.horizontal, 12)

            complexExampleBar
                .padding(.horizontal, 10)
                .padding(.vertical, 6.5)
        }
        .frame(width: DaybookTheme.popoverWidth - 24)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .fill(DaybookTheme.paper)
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .stroke(DaybookTheme.rule.opacity(0.6), lineWidth: 0.8)
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DaybookTheme.stamp)

            Text(context == .search ? "syntax.search.title" : "syntax.guide.title")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(DaybookTheme.ink)

            Spacer(minLength: 0)

            Button {
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isExpanded = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(width: 18, height: 18)
                    .background(
                        Circle()
                            .fill(DaybookTheme.ink.opacity(0.06))
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("dialog.cancel")
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
                    + Text("#工作").foregroundStyle(Color(nsColor: .systemIndigo)).bold()
                    + Text("  或  ")
                    + Text("#生活").foregroundStyle(Color(nsColor: .systemIndigo)).bold()
                    + Text(" 买牛奶"),
                color: Color(nsColor: .systemIndigo)
            )

            // 2. ! 四象限优先级
            syntaxRow(
                token: "!",
                title: "四象限优先级",
                exampleSnippet: "修线上Bug !p1",
                exampleText: Text("修线上Bug ")
                    + Text("!p1").foregroundStyle(DaybookTheme.destructive).bold()
                    + Text("  或  ")
                    + Text("!p2").foregroundStyle(Color.orange).bold()
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
                    exampleText: Text("首行待办标题 ")
                        + Text("⇧↵").foregroundStyle(DaybookTheme.ink).bold()
                        + Text(" 换行输入详细备注"),
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
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(DaybookTheme.ink)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        HStack(spacing: 2) {
                            Text("填入试用")
                                .font(.system(size: 8.5, weight: .semibold))
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 8.5))
                        }
                        .foregroundStyle(DaybookTheme.stamp)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(DaybookTheme.stamp.opacity(0.12))
                        )
                    }
                    .transition(.opacity)
                } else {
                    // 默认未聚焦态：极致干净素雅，仅展示符号徽标与条例名称
                    HStack(alignment: .center, spacing: 8) {
                        Text(token)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                    .fill(color.opacity(0.14))
                            )
                            .frame(width: 32, alignment: .center)

                        Text(LocalizedStringKey(title))
                            .font(.system(size: 11.5, weight: .semibold))
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
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? DaybookTheme.stamp.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                        .font(.system(size: 10))
                        .foregroundStyle(Color.orange.opacity(0.9))

                    (Text("重构核心模块 ")
                        + Text("#工作").foregroundStyle(Color(nsColor: .systemIndigo)).bold()
                        + Text(" ")
                        + Text("!p1").foregroundStyle(DaybookTheme.destructive).bold()
                        + Text(" ")
                        + Text("@15:30").foregroundStyle(DaybookTheme.stamp).bold())
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DaybookTheme.ink)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    HStack(spacing: 2) {
                        Text("填入试用")
                            .font(.system(size: 8.5, weight: .semibold))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 8.5))
                    }
                    .foregroundStyle(DaybookTheme.stamp)
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(DaybookTheme.stamp.opacity(0.12))
                    )
                }

                HStack(spacing: 4) {
                    Text("综合范例：全属性完整待办 · 顺序自由，点击一键试用")
                        .font(.system(size: 9.5))
                        .foregroundStyle(DaybookTheme.muted)

                    Spacer(minLength: 0)

                    Text("Esc")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(DaybookTheme.muted.opacity(0.8))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DaybookTheme.ink.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(DaybookTheme.rule.opacity(0.35), lineWidth: 0.6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
