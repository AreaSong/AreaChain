import SwiftUI

/// 搜索命中行。列表和菜单栏用紧凑文字，工作台用卡片并带选中标记。打开方式由调用方决定。
struct BoardSearchHitRow: View {
    enum Presentation {
        case list
        case workspace
    }

    var hit: BoardSearchHit
    var presentation: Presentation = .list
    var isSelected = false
    var action: () -> Void

    var body: some View {
        switch presentation {
        case .list:
            Button(action: action) {
                listLabel.contentShape(Rectangle())
            }
            .buttonStyle(DaybookQuietButtonStyle())
            .help(hit.title)
        case .workspace:
            Button(action: action) {
                workspaceLabel.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(hit.title)
        }
    }

    private var listLabel: some View {
        HStack(alignment: .top, spacing: 8) {
            kindText
                .frame(width: 36, alignment: .leading)
            titleText(lineLimit: 3)
            Spacer(minLength: 0)
        }
    }

    private var workspaceLabel: some View {
        HStack(alignment: .center, spacing: 10) {
            kindText
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(DaybookTheme.stamp.opacity(0.12)))
            titleText(lineLimit: 2)
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DaybookTheme.stamp)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: WorkspaceStyle.cardRadius)
                .fill(isSelected ? WorkspaceStyle.selection : WorkspaceStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkspaceStyle.cardRadius)
                .strokeBorder(isSelected ? DaybookTheme.stamp.opacity(0.4) : WorkspaceStyle.border, lineWidth: 0.8)
        )
    }

    private var kindText: some View {
        Text(LocalizedStringKey(hit.kind.titleKey))
            .font(DaybookType.badge.weight(.semibold))
            .foregroundStyle(DaybookTheme.stamp)
    }

    private func titleText(lineLimit: Int) -> some View {
        Text(hit.title)
            .font(DaybookType.body)
            .foregroundStyle(DaybookTheme.ink)
            .multilineTextAlignment(.leading)
            .lineLimit(lineLimit)
    }
}
