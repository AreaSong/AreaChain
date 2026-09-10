import SwiftUI

@Observable
@MainActor
final class SyntaxAutocompleteState {
    var isActive: Bool = false
    var trigger: SyntaxTrigger? = nil
    var candidates: [SyntaxCandidate] = []
    var selectedIndex: Int = 0

    func update(text: String, cursorLocation: Int, availableTags: [String] = []) {
        guard let detected = SyntaxAutocompleteEngine.detectTrigger(in: text, cursorLocation: cursorLocation) else {
            dismiss()
            return
        }

        let items = SyntaxAutocompleteEngine.candidates(for: detected, availableTags: availableTags)
        guard !items.isEmpty else {
            dismiss()
            return
        }

        trigger = detected
        candidates = items
        selectedIndex = max(0, min(selectedIndex, items.count - 1))
        isActive = true
    }

    func selectPrevious() {
        guard !candidates.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + candidates.count) % candidates.count
    }

    func selectNext() {
        guard !candidates.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % candidates.count
    }

    func selectedCandidate() -> SyntaxCandidate? {
        guard isActive, !candidates.isEmpty, selectedIndex >= 0, selectedIndex < candidates.count else {
            return nil
        }
        return candidates[selectedIndex]
    }

    func dismiss() {
        isActive = false
        trigger = nil
        candidates = []
        selectedIndex = 0
    }
}

struct SyntaxAutocompletePopup: View {
    @Bindable var state: SyntaxAutocompleteState
    var onCommit: (SyntaxCandidate) -> Void

    var body: some View {
        if state.isActive && !state.candidates.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                candidateList
                Divider()
                    .background(DaybookTheme.rule.opacity(0.5))
                footerGuide
            }
            .frame(width: 240)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(DaybookTheme.paper)
                    .shadow(color: DaybookTheme.ink.opacity(0.12), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .stroke(DaybookTheme.rule.opacity(0.7), lineWidth: 0.7)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
        }
    }

    private var candidateList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(state.candidates.enumerated()), id: \.element.id) { index, item in
                        candidateRow(item, isSelected: index == state.selectedIndex)
                            .id(item.id)
                            .onTapGesture {
                                onCommit(item)
                            }
                    }
                }
                .padding(4)
            }
            .frame(maxHeight: 180)
            .onChange(of: state.selectedIndex) { _, newIndex in
                if newIndex >= 0 && newIndex < state.candidates.count {
                    withAnimation(DaybookMotion.interactive) {
                        proxy.scrollTo(state.candidates[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    private func candidateRow(_ item: SyntaxCandidate, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            iconView(for: item)
                .frame(width: 16, height: 16)

            Text(item.title)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(DaybookTheme.ink)

            Spacer(minLength: 4)

            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.muted)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isSelected ? DaybookTheme.stamp.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func iconView(for item: SyntaxCandidate) -> some View {
        switch item.kind {
        case .tag:
            if item.isCreation {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(DaybookTheme.stamp)
            } else {
                Image(systemName: "tag.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(nsColor: .systemIndigo))
            }
        case .priority:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(priorityColor(for: item.title))
        case .time:
            Image(systemName: "clock.fill")
                .font(.system(size: 10))
                .foregroundStyle(DaybookTheme.stamp)
        }
    }

    private func priorityColor(for title: String) -> Color {
        switch title {
        case "!p1": return DaybookTheme.destructive
        case "!p2": return Color.orange
        case "!p3": return Color.blue
        default: return DaybookTheme.muted
        }
    }

    private var footerGuide: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Text("↑↓")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 2.5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 2.5).fill(DaybookTheme.ink.opacity(0.06)))
                Text("切换")
                    .font(.system(size: 9))
                    .foregroundStyle(DaybookTheme.muted)
            }
            HStack(spacing: 3) {
                Text("⇥ / ↵")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 2.5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 2.5).fill(DaybookTheme.ink.opacity(0.06)))
                Text("补全")
                    .font(.system(size: 9))
                    .foregroundStyle(DaybookTheme.muted)
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                Text("Esc")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 2.5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 2.5).fill(DaybookTheme.ink.opacity(0.06)))
                Text("关闭")
                    .font(.system(size: 9))
                    .foregroundStyle(DaybookTheme.muted)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(DaybookTheme.ink.opacity(0.02))
    }
}

/// 快捷语法速查指南弹窗组件
struct SyntaxCheatSheetPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider().background(DaybookTheme.rule.opacity(0.4))
            syntaxList
            Divider().background(DaybookTheme.rule.opacity(0.4))
            footer
        }
        .padding(12)
        .frame(width: 270)
        .background(DaybookTheme.paper)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DaybookTheme.stamp)
            Text("快捷语法指南")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DaybookTheme.ink)
            Spacer(minLength: 0)
        }
    }

    private var syntaxList: some View {
        VStack(alignment: .leading, spacing: 7) {
            cheatRow(token: "#", title: "标签分类", desc: "键入 # 选标签，回车新建", color: Color(nsColor: .systemIndigo))
            cheatRow(token: "!", title: "四象限优先级", desc: "!p1~p4 快速设重要与紧急", color: DaybookTheme.destructive)
            cheatRow(token: "@", title: "时刻提醒", desc: "@15:30 或预设常用时刻", color: DaybookTheme.stamp)
            cheatRow(token: "⌘↩", title: "保存至日记", desc: "跳过待办直接存入随笔", color: DaybookTheme.stamp)
            cheatRow(token: "⇧↩", title: "换行备注", desc: "输入多行任务详情说明", color: DaybookTheme.muted)
        }
    }

    private func cheatRow(token: String, title: String, desc: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(token)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .fill(color.opacity(0.12))
                )
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DaybookTheme.ink)
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(DaybookTheme.muted)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Image(systemName: "keyboard")
                .font(.system(size: 9.5))
                .foregroundStyle(DaybookTheme.muted)
            Text("适用于随手记、行内编辑与全局搜索")
                .font(.system(size: 9.5))
                .foregroundStyle(DaybookTheme.muted)
        }
    }
}
