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
    @Environment(\.locale) private var locale

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
        .frame(width: DaybookMetrics.Window.popoverWidth - 24)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .fill(DaybookPalette.fill.page)
                .daybookElevation(.floating)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .stroke(DaybookPalette.border.default.opacity(0.6), lineWidth: 0.8) // token-exempt: 60% 分隔线没有对应令牌
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
                .foregroundStyle(DaybookPalette.accent.base)

            Text(context == .search ? "syntax.search.title" : "syntax.guide.title")
                .font(DaybookType.subtitle.weight(.bold))
                .foregroundStyle(DaybookPalette.text.primary)

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
            attributeSyntaxItems
            if context == .capture {
                captureSyntaxItems
            }
        }
    }

    @ViewBuilder
    private var attributeSyntaxItems: some View {
        // 1. # 标签分类
        syntaxRow(
            token: "#",
            title: "syntax.guide.tag",
            exampleSnippet: L10n.string("syntax.example.tag.snippet", locale: locale),
            exampleText: Text(LocalizedStringKey("syntax.example.tag.text1"))
                + Text(LocalizedStringKey("syntax.example.tag.token1")).foregroundStyle(DaybookPalette.tagDefault).bold()
                + Text(LocalizedStringKey("syntax.example.common.or"))
                + Text(LocalizedStringKey("syntax.example.tag.token2")).foregroundStyle(DaybookPalette.tagDefault).bold()
                + Text(LocalizedStringKey("syntax.example.tag.text2")),
            color: DaybookPalette.tagDefault
        )

        // 2. ! 四象限优先级
        syntaxRow(
            token: "!",
            title: "syntax.guide.priority",
            exampleSnippet: L10n.string("syntax.example.priority.snippet", locale: locale),
            exampleText: Text(LocalizedStringKey("syntax.example.priority.text1"))
                + Text("!p1").foregroundStyle(DaybookPalette.status.danger).bold()
                + Text(LocalizedStringKey("syntax.example.common.or"))
                + Text("!p2").foregroundStyle(DaybookPalette.status.pending).bold()
                + Text(LocalizedStringKey("syntax.example.priority.text2")),
            color: DaybookPalette.status.danger
        )

        // 3. @ 时刻提醒
        if context.supportsTaskAttributes {
            syntaxRow(
                token: "@",
                title: "syntax.guide.time",
                exampleSnippet: L10n.string("syntax.example.time.snippet", locale: locale),
                exampleText: Text(LocalizedStringKey("syntax.example.time.text1"))
                    + Text("@10:00").foregroundStyle(DaybookPalette.accent.base).bold()
                    + Text(LocalizedStringKey("syntax.example.time.text2")),
                color: DaybookPalette.accent.base
            )
        }
    }

    @ViewBuilder
    private var captureSyntaxItems: some View {
        // 4. ⌘↩ 直接存入手记
        syntaxRow(
            token: "⌘↩",
            title: "syntax.guide.diary",
            exampleSnippet: L10n.string("syntax.example.diary.snippet", locale: locale),
            exampleText: Text(LocalizedStringKey("syntax.example.diary.text1"))
                + Text("⌘↵").foregroundStyle(DaybookPalette.accent.base).bold()
                + Text(LocalizedStringKey("syntax.example.diary.text2")),
            color: DaybookPalette.accent.base
        )

        // 5. ⇧↩ 换行输入备注
        syntaxRow(
            token: "⇧↩",
            title: "syntax.guide.note",
            exampleSnippet: L10n.string("syntax.example.note.snippet", locale: locale),
            exampleText: Text(LocalizedStringKey("syntax.example.note.text1"))
                + Text("⇧↵").foregroundStyle(DaybookPalette.text.primary).bold()
                + Text(LocalizedStringKey("syntax.example.note.text2")),
            color: DaybookPalette.text.secondary
        )
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
                    syntaxRowHoveredView(exampleText: exampleText)
                } else {
                    syntaxRowDefaultView(token: token, title: title, color: color)
                }
            }
            .frame(height: 22)
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                    .fill(isHovered ? DaybookPalette.accent.base.opacity(0.06) : Color.clear) // token-exempt: 6% 印章底没有对应令牌
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

    private func syntaxRowHoveredView(exampleText: Text) -> some View {
        HStack(alignment: .center, spacing: 4) {
            exampleText
                .font(.system(size: 10.5, design: .monospaced)) // token-exempt: 等宽范例，kbd 是 8.5pt
                .foregroundStyle(DaybookPalette.text.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            HStack(spacing: 2) {
                Text("syntax.guide.try")
                    .font(.system(size: 8.5, weight: .semibold)) // token-exempt: 小于 9pt，kbd 是等宽
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 8.5)) // token-exempt: 小于 9pt，kbd 是等宽
            }
            .foregroundStyle(DaybookPalette.accent.base)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(DaybookPalette.accent.fill)
            )
        }
        .transition(.opacity)
    }

    private func syntaxRowDefaultView(token: String, title: String, color: Color) -> some View {
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
                .foregroundStyle(DaybookPalette.text.primary)

            Spacer(minLength: 0)
        }
        .transition(.opacity)
    }

    // MARK: - 底部总复杂范例（常驻展示，点击一键注入输入框试用）

    private var complexExampleBar: some View {
        Button {
            onSelectExample?(L10n.string("syntax.example.complex.snippet", locale: locale))
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(DaybookType.badge)
                        .foregroundStyle(DaybookPalette.status.pending.opacity(0.9)) // token-exempt: 90% 待办橙没有对应令牌

                    (Text(LocalizedStringKey("syntax.example.complex.title"))
                        + Text(LocalizedStringKey("syntax.example.tag.token1")).foregroundStyle(DaybookPalette.tagDefault).bold()
                        + Text(" ")
                        + Text("!p1").foregroundStyle(DaybookPalette.status.danger).bold()
                        + Text(" ")
                        + Text("@15:30").foregroundStyle(DaybookPalette.accent.base).bold())
                        .font(.system(size: 11, weight: .medium, design: .monospaced)) // token-exempt: 等宽范例，kbd 是 8.5pt
                        .foregroundStyle(DaybookPalette.text.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    HStack(spacing: 2) {
                        Text("syntax.guide.try")
                            .font(.system(size: 8.5, weight: .semibold)) // token-exempt: 小于 9pt，kbd 是等宽
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 8.5)) // token-exempt: 小于 9pt，kbd 是等宽
                    }
                    .foregroundStyle(DaybookPalette.accent.base)
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(DaybookPalette.accent.fill)
                    )
                }

                HStack(spacing: 4) {
                    Text("syntax.guide.example")
                        .font(DaybookType.micro)
                        .foregroundStyle(DaybookPalette.text.secondary)

                    Spacer(minLength: 0)

                    Text("Esc")
                        .font(DaybookType.kbd.weight(.bold))
                        .foregroundStyle(DaybookPalette.text.secondary.opacity(0.8)) // token-exempt: 80% 次要色没有对应令牌
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
