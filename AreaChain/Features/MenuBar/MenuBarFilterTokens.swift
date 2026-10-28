import SwiftUI

/// 底栏已生效筛选的胶囊（修复批 M-7F 恢复删开关前的旧底栏）：每个可单独移除，移除只写回 `BoardFilterSession`
/// 这一份筛选；统一搜索结果随页面自动条件派生更新（`UnifiedSearchController.refreshTodayPageFilter`）。
/// 胶囊条目、文字、图标与移除规则沿旧 `FooterBar.activeTokens`，外观沿旧 `MenuBarSearchField.tokenChip`。
struct MenuBarFilterTokens: View {
    var filters: Binding<BoardFilters>
    var tags: [TagItem]

    @Environment(\.locale) private var locale

    private struct Token: Identifiable {
        let id: String
        let title: String
        var icon: String?
        var dotColor: Color?
        let remove: (BoardFilter) -> BoardFilter
    }

    /// 菜单栏统一搜索页面固定为今日任务，只有任务筛选作用于结果，因此只列任务页签的筛选。
    private var filter: BoardFilter { filters.wrappedValue.tasks }

    private var tokens: [Token] {
        var tokens: [Token] = []
        if filter.dateScope != .all {
            tokens.append(.init(id: "date", title: filter.dateScope.title(locale: locale), icon: "calendar") {
                $0.withDateScope(.all)
            })
        }
        if filter.priorityScope != .all || filter.isHighPriorityOnly {
            let mark = BoardFilterChoices.priorityMark(filter)
            tokens.append(.init(id: "priority", title: filter.priorityTitle(locale: locale), icon: mark.icon,
                                dotColor: mark.dot) {
                var next = $0.withPriorityScope(.all)
                next.isHighPriorityOnly = false
                return next
            })
        }
        if filter.reminderScope != .all {
            tokens.append(.init(id: "reminder", title: filter.reminderScope.title(locale: locale), icon: "bell") {
                $0.withReminderScope(.all)
            })
        }
        if let bundleID = filter.bundleID {
            tokens.append(.init(id: "bundle", title: BundleDisplay.name(for: bundleID), icon: "app") { $0.withBundle(nil) })
        }
        if let id = filter.tagID {
            if id == BoardFilter.noneID {
                tokens.append(.init(id: "tag", title: L10n.string("filter.tag.none", locale: locale), icon: "tag") {
                    $0.withTag(nil)
                })
            } else if let tag = tags.first(where: { $0.id == id }) {
                tokens.append(.init(id: "tag", title: "#" + tag.name, dotColor: DiaryTagChrome.color(for: tag.name)) {
                    $0.withTag(nil)
                })
            }
        }
        return tokens
    }

    var body: some View {
        let tokens = tokens
        if !tokens.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(tokens) { chip($0) }
                }
                .padding(.vertical, 1)
            }
            .fixedSize(horizontal: false, vertical: true)
            // 横向滚动区默认可被压到零宽；先于搜索框取宽（上限 150pt），搜索框仍保留自己的最小宽度。
            .frame(maxWidth: 150)
            .layoutPriority(1)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("menubar.filter.tokens")
        }
    }

    private func chip(_ token: Token) -> some View {
        DaybookChip(tint: DaybookPalette.accent.base, isSelected: true) {
            HStack(spacing: 2) {
                if let dotColor = token.dotColor {
                    DaybookStatusDot(color: dotColor, size: 4.5)
                } else if let icon = token.icon {
                    Image(systemName: icon)
                }
                Text(token.title)
                    .lineLimit(1)
                Button {
                    filters.wrappedValue.tasks = token.remove(filters.wrappedValue.tasks)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 6.5, weight: .bold)) // token-exempt: 芯片内移除角标小于 9pt
                        .frame(width: 9, height: 9)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain) // control: 芯片内的移除角标
                // 标签不含条件文字：否则与筛选浮层里同名选项重名，按名称找控件会不唯一；条件名放在提示里。
                .accessibilityLabel(Text("filter.token.remove"))
                .accessibilityHint(Text(verbatim: token.title))
                .help(Text("filter.token.remove"))
                .accessibilityIdentifier("menubar.filter.token.remove." + token.id)
            }
        }
    }
}
