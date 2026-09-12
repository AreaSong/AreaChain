//
//  SyntaxHelpCard.swift
//  AreaChain
//
//  Created by Antigravity on 2026-09-10.
//

import SwiftUI

/// 快捷语法自展开卡片（聚焦时为轻量小条，点击后原地平铺展开为大卡片）
struct SyntaxExpandableCard: View {
    @Binding var isExpanded: Bool
    var onSelectToken: (String) -> Void

    @State private var hoveredToken: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            if isExpanded {
                VStack(spacing: 0) {
                    Divider().background(DaybookTheme.rule.opacity(0.45))
                        .padding(.horizontal, 12)
                    
                    syntaxList
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    
                    Divider().background(DaybookTheme.rule.opacity(0.45))
                        .padding(.horizontal, 12)
                        
                    footer
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: 324)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DaybookTheme.paper)
                .shadow(color: Color.black.opacity(isExpanded ? 0.12 : 0.08), radius: isExpanded ? 12 : 4, x: 0, y: isExpanded ? 4 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DaybookTheme.rule.opacity(0.68), lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .animation(DaybookMotion.interactive, value: isExpanded)
        .onExitCommand {
            if isExpanded {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    isExpanded = false
                }
            }
        }
    }

    // MARK: - 统一顶栏（聚焦或展开始终保持在顶部）

    private var headerBar: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DaybookTheme.stamp)
                
                Text("快捷语法指南")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DaybookTheme.ink)
                    
                if !isExpanded {
                    Spacer(minLength: 4)
                    HStack(spacing: 4) {
                        miniBadge("#", color: Color(nsColor: .systemIndigo))
                        miniBadge("!", color: DaybookTheme.destructive)
                        miniBadge("@", color: DaybookTheme.stamp)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Text(LocalizedStringKey(isExpanded ? "收起" : "展开"))
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9.5, weight: .bold))
                }
                .foregroundStyle(DaybookTheme.stamp)
                .padding(.horizontal, isExpanded ? 6 : 0)
                .padding(.vertical, isExpanded ? 3 : 0)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isExpanded ? DaybookTheme.stamp.opacity(0.12) : Color.clear)
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func miniBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(color.opacity(0.18))
            )
            .fixedSize()
    }

    private var syntaxList: some View {
        VStack(alignment: .leading, spacing: 4) {
            syntaxRow(token: "#", title: "标签分类", desc: "键入 # 选已有标签，回车新建", color: Color(nsColor: .systemIndigo))
            syntaxRow(token: "!", title: "四象限优先级", desc: "!p1 ~ !p4 快速设定重要与紧急", color: DaybookTheme.destructive)
            syntaxRow(token: "@", title: "时刻提醒", desc: "@15:30 或预设时刻定时通知", color: DaybookTheme.stamp)
            syntaxRow(token: "⌘↩", title: "直接存入日记", desc: "跳过待办直接存入今日随笔", color: DaybookTheme.stamp)
            syntaxRow(token: "⇧↩", title: "换行输入备注", desc: "Shift + 回车换行，输入详情说明", color: DaybookTheme.muted)
        }
    }

    private func syntaxRow(token: String, title: String, desc: String, color: Color) -> some View {
        let isHovered = hoveredToken == token

        return Button {
            onSelectToken(token)
        } label: {
            HStack(alignment: .center, spacing: 9) {
                Text(token)
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2.5)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(color.opacity(0.16))
                    )
                    .frame(width: 38, alignment: .center)

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(LocalizedStringKey(title))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(DaybookTheme.ink)
                        .lineLimit(1)
                    Text(LocalizedStringKey(desc))
                        .font(.system(size: 10.5))
                        .foregroundStyle(DaybookTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if isHovered {
                    HStack(spacing: 2) {
                        Text("点击填入")
                            .font(.system(size: 10, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(DaybookTheme.stamp)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? DaybookTheme.stamp.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            withAnimation(DaybookMotion.interactive) {
                hoveredToken = hovered ? token : nil
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Image(systemName: "keyboard")
                .font(.system(size: 10))
                .foregroundStyle(DaybookTheme.muted)
            Text("适用于随手记、行内编辑与全局搜索")
                .font(.system(size: 10))
                .foregroundStyle(DaybookTheme.muted)
            Spacer(minLength: 0)
            Text("Esc 收起")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(DaybookTheme.muted.opacity(0.8))
        }
    }
}
