import SwiftUI

/// 按日分组的搜索命中。工作台顶栏和菜单栏底栏共用分组，打开方式和行外观由调用方决定。
struct BoardSearchHitGroups: View {
    var hits: [BoardSearchHit]
    var presentation: BoardSearchHitRow.Presentation = .list
    var sectionSpacing: CGFloat = 14
    var rowSpacing: CGFloat = 6
    var isSelected: (BoardSearchHit) -> Bool = { _ in false }
    var isHighlighted: (BoardSearchHit) -> Bool = { _ in false }
    var open: (BoardSearchHit) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        let groups = BoardSearch.grouped(hits)
        VStack(alignment: .leading, spacing: sectionSpacing) {
            ForEach(groups, id: \.dayKey) { group in
                VStack(alignment: .leading, spacing: rowSpacing) {
                    Text(DayKey.displayName(group.dayKey, locale: locale))
                        .font(DaybookType.caption.weight(.semibold))
                        .foregroundStyle(DaybookPalette.text.secondary)
                    ForEach(group.items) { hit in
                        BoardSearchHitRow(
                            hit: hit,
                            presentation: presentation,
                            isSelected: isSelected(hit),
                            isHighlighted: isHighlighted(hit),
                            action: { open(hit) }
                        )
                    }
                }
            }
        }
    }
}

/// 搜索命中行。列表和菜单栏用紧凑文字，工作台用卡片并带选中标记。打开方式由调用方决定。
struct BoardSearchHitRow: View {
    enum Presentation {
        case list
        case workspace
    }

    var hit: BoardSearchHit
    var presentation: Presentation = .list
    var isSelected = false
    var isHighlighted = false
    var action: () -> Void

    var body: some View {
        switch presentation {
        case .list:
            Button(action: action) {
                listLabel.contentShape(Rectangle())
            }
            .buttonStyle(DaybookButtonStyle(.quiet))
            .help(hit.title)
        case .workspace:
            Button(action: action) {
                workspaceLabel.contentShape(Rectangle())
            }
            .buttonStyle(.plain) // control: 搜索结果整行点击区
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
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(isHighlighted ? DaybookPalette.fill.hover : Color.clear, in: RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
    }

    private var workspaceLabel: some View {
        HStack(alignment: .center, spacing: 10) {
            kindText
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(DaybookPalette.accent.fill)) // token-exempt: 搜索种类胶囊
            titleText(lineLimit: 2)
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "chevron.right")
                    .font(DaybookType.caption.weight(.bold))
                    .foregroundStyle(DaybookPalette.accent.base)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            isHighlighted && !isSelected ? DaybookPalette.fill.hover : Color.clear,
            in: RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
        )
        .daybookSurface(.row, isSelected: isSelected, configure: { $0.radius = DaybookRadius.regular })
    }

    private var kindText: some View {
        Text(LocalizedStringKey(hit.kind.titleKey))
            .font(DaybookType.badge.weight(.semibold))
            .foregroundStyle(DaybookPalette.accent.base)
    }

    private func titleText(lineLimit: Int) -> some View {
        Text(hit.title)
            .font(DaybookType.body)
            .foregroundStyle(DaybookPalette.text.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(lineLimit)
    }
}
