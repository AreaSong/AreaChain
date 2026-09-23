import SwiftUI

/// 状态栏弹窗标签栏组件
struct DaybookSegmentedBar: View {
    @Binding var selection: BoardTab
    var tasksCount: Int = 0
    var diariesCount: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var sliderAnimation

    var body: some View {
        HStack(spacing: 2) {
            ForEach(BoardTab.allCases) { item in
                tabButton(item)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
                .fill(DaybookTheme.ink.opacity(0.06)) // token-exempt: 6% 墨色没有对应令牌
        )
    }

    private func tabButton(_ item: BoardTab) -> some View {
        let isSelected = selection == item
        let ink = isSelected ? DaybookTheme.ink : DaybookTheme.muted
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                selection = item
            }
        } label: {
            Text(LocalizedStringKey(item.titleKey))
                .font(DaybookType.body.weight(isSelected ? .semibold : .medium))
                .frame(minWidth: 36)
                .padding(.horizontal, 12)
                .padding(.vertical, 4.5)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                                .fill(DaybookTheme.paper)
                                .daybookElevation(.raised)
                                .matchedGeometryEffect(id: "SliderBackground", in: sliderAnimation)
                        }
                    }
                )
                .foregroundStyle(ink)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 分段切换滑块，非按钮语义
        .accessibilityLabel(LocalizedStringKey(item.titleKey))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .help(item == .tasks ? Text("任务 (⌘←)") : Text("手记 (⌘→)"))
    }
}
