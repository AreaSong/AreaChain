import AppKit
import SwiftData
import SwiftUI

/// 状态栏弹窗底部信息栏
struct FooterBar: View {
    var tab: BoardTab = .tasks
    var filter: Binding<BoardFilter>? = nil
    var diaryFilterTagID: Binding<UUID?>? = nil
    var tags: [TagItem] = []
    var diaryCount: Int = 0
    var completedCount: Int = 0
    var totalCount: Int = 0

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isFilterExpanded = false
    @State private var hoverWorkItem: DispatchWorkItem? = nil
    @FocusState private var filterFocused: Bool

    private var activeTags: [TagItem] {
        tab == .tasks ? Catalog.liveTaskTags(tags) : Catalog.liveTags(tags)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // 常态底栏
            HStack(spacing: 8) {
                filterTriggerCapsule
                    .onHover { hovering in
                        handleFilterHover(hovering)
                    }

                Spacer(minLength: 4)

                HStack(spacing: 6) {
                    rightMetricBadge
                    workspaceMenuButton
                }
            }

            // Hover 展开横向抽屉（覆盖右侧内容）
            if isFilterExpanded {
                horizontalFilterDrawer
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                    .zIndex(10)
            }
        }
        .frame(height: 24)
        .animation(DaybookMotion.interactive(reduceMotion), value: isFilterExpanded)
        .onDisappear {
            hoverWorkItem?.cancel()
            hoverWorkItem = nil
        }
        .onExitCommand { collapseDrawer() }
    }

    // MARK: - 触发入口胶囊

    private var filterTriggerCapsule: some View {
        let highPriority = tab == .tasks && filter?.wrappedValue.isHighPriorityOnly == true
        let tagID = tab == .tasks ? filter?.wrappedValue.tagID : diaryFilterTagID?.wrappedValue
        let tag = activeTags.first { $0.id == tagID }
        let active = tab == .tasks ? filter?.wrappedValue.isActive == true : tagID != nil
        let title = highPriority ? L10n.string("filter.highPriority", locale: locale)
            : (tag.map { "#\($0.name)" } ?? L10n.string("filter.label", locale: locale))
        return HStack(spacing: 3.5) {
            Button {
                isFilterExpanded.toggle()
                if isFilterExpanded { DispatchQueue.main.async { filterFocused = true } }
            } label: {
                HStack(spacing: 3.5) {
                    Image(systemName: highPriority ? "star.fill" : "line.3.horizontal.decrease")
                        .font(.system(size: 9, weight: .medium))
                    Text(title).font(.system(size: 10.5, weight: .medium)).lineLimit(1)
                    Image(systemName: isFilterExpanded ? "chevron.left" : "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .accessibilityLabel("filter.label")
            .accessibilityValue(isFilterExpanded ? Text("filter.expanded") : Text("filter.collapsed"))
            .help("filter.open.help")
            if active {
                Button(action: clearFilter) {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("filter.all")
            }
        }
        .foregroundStyle(highPriority ? Color.orange : (active ? DaybookTheme.stamp : DaybookTheme.muted))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(active ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.ink.opacity(0.04)))
        .overlay(Capsule().strokeBorder(DaybookTheme.rule.opacity(0.4), lineWidth: 0.6))
    }

    // MARK: - 横向滑动抽屉

    private var horizontalFilterDrawer: some View {
        HStack(spacing: 5) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(DaybookTheme.stamp)
                .padding(.leading, 6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    allFilterChip
                    if tab == .tasks {
                        highPriorityChip
                    }
                    ForEach(activeTags) { tag in
                        tagChip(tag)
                    }
                }
                .padding(.vertical, 1)
                .padding(.trailing, 4)
            }

            Button {
                collapseDrawer()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(DaybookTheme.ink.opacity(0.05)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
            .help("filter.collapse")
        }
        .frame(maxWidth: .infinity, maxHeight: 25, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(DaybookTheme.paper)
                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(DaybookTheme.rule.opacity(0.65), lineWidth: 0.7)
        )
        .onHover { hovering in
            handleFilterHover(hovering)
        }
    }

    // MARK: - Filter Chips

    private var allFilterChip: some View {
        let isAllSelected: Bool = {
            if tab == .tasks {
                return filter?.wrappedValue.isActive != true
            } else {
                return diaryFilterTagID?.wrappedValue == nil
            }
        }()

        return Button {
            clearFilter()
            collapseDrawer()
        } label: {
            Text(L10n.string("filter.all", locale: locale))
                .font(.system(size: 10, weight: isAllSelected ? .semibold : .regular))
                .foregroundStyle(isAllSelected ? DaybookTheme.ink : DaybookTheme.muted)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(
                    Capsule().fill(isAllSelected ? DaybookTheme.ink.opacity(0.10) : DaybookTheme.ink.opacity(0.03))
                )
                .overlay(
                    Capsule().strokeBorder(isAllSelected ? DaybookTheme.rule.opacity(0.8) : DaybookTheme.rule.opacity(0.3), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .focused($filterFocused)
    }

    private var highPriorityChip: some View {
        let isSelected = (filter?.wrappedValue.isHighPriorityOnly == true)

        return Button {
            if let f = filter {
                f.wrappedValue = f.wrappedValue.withHighPriority(!isSelected)
            }
            collapseDrawer()
        } label: {
            HStack(spacing: 2.5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 8.5))
                Text("filter.highPriority")
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Color.orange : DaybookTheme.muted)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(
                Capsule().fill(isSelected ? Color.orange.opacity(0.12) : DaybookTheme.ink.opacity(0.03))
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.orange.opacity(0.5) : DaybookTheme.rule.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func tagChip(_ tag: TagItem) -> some View {
        let isSelected: Bool = {
            if tab == .tasks {
                return filter?.wrappedValue.tagID == tag.id
            } else {
                return diaryFilterTagID?.wrappedValue == tag.id
            }
        }()

        return Button {
            if tab == .tasks {
                if let f = filter {
                    let next = (f.wrappedValue.tagID == tag.id) ? nil : tag.id
                    f.wrappedValue = f.wrappedValue.withTag(next)
                }
            } else {
                if let df = diaryFilterTagID {
                    df.wrappedValue = (df.wrappedValue == tag.id) ? nil : tag.id
                }
            }
            collapseDrawer()
        } label: {
            Text("#\(tag.name)")
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : DaybookTheme.muted)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(
                    Capsule().fill(isSelected ? DaybookTheme.stamp : DaybookTheme.ink.opacity(0.03))
                )
                .overlay(
                    Capsule().strokeBorder(isSelected ? DaybookTheme.stamp : DaybookTheme.rule.opacity(0.3), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 右侧度量徽标

    @ViewBuilder
    private var rightMetricBadge: some View {
        switch tab {
        case .tasks:
            if totalCount > 0 {
                todayProgressBadge
            }
        case .diary:
            diaryMetricBadge
        }
    }

    private var diaryMetricBadge: some View {
        HStack(spacing: 3.5) {
            Image(systemName: "book.pages")
                .font(.system(size: 9.5, weight: .medium))
            Text(L10n.format("footer.diary.count", locale: locale, diaryCount))
                .font(.system(size: 10, weight: .medium, design: .rounded))
        }
        .foregroundStyle(DaybookTheme.muted)
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(DaybookTheme.ink.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(DaybookTheme.rule.opacity(0.3), lineWidth: 0.6)
        )
        .help(L10n.format("footer.diary.help", locale: locale, diaryCount))
    }

    private var todayProgressBadge: some View {
        let progress = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
        let percentage = Int((progress * 100).rounded())

        return HStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(DaybookTheme.rule.opacity(0.4), lineWidth: 1.8)
                    .frame(width: 11, height: 11)
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        percentage == 100 ? DaybookTheme.stamp : Color.orange.opacity(0.85),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 11, height: 11)
            }

            Text("\(percentage)%")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(DaybookTheme.muted)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(DaybookTheme.ink.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(DaybookTheme.rule.opacity(0.3), lineWidth: 0.6)
        )
        .help(L10n.format("footer.progress.help", locale: locale, completedCount, totalCount, percentage))
    }

    private var workspaceMenuButton: some View {
        Menu {
            Button {
                AppWindows.openWorkspace(tab: .settings)
            } label: {
                Label("window.settings", systemImage: "gearshape")
            }
            Divider()
            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("footer.quit", systemImage: "power")
            }
        } label: {
            Image(systemName: "macwindow")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(DaybookTheme.muted)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(DaybookTheme.ink.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(DaybookTheme.rule.opacity(0.35), lineWidth: 0.6)
                )
                .contentShape(Rectangle())
        } primaryAction: {
            AppWindows.openWorkspace(tab: tab == .diary ? .diary : .today)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(DaybookQuietButtonStyle())
        .help("window.workspace")
        .accessibilityLabel("window.workspace")
    }

    // MARK: - Actions & Helpers

    private func handleFilterHover(_ hovering: Bool) {
        if hovering {
            hoverWorkItem?.cancel()
            hoverWorkItem = nil
            if !isFilterExpanded {
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isFilterExpanded = true
                }
            }
        } else {
            let task = DispatchWorkItem {
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isFilterExpanded = false
                }
            }
            hoverWorkItem = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: task)
        }
    }

    private func collapseDrawer() {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            isFilterExpanded = false
        }
    }

    private func clearFilter() {
        if tab == .tasks {
            filter?.wrappedValue = BoardFilter()
        } else {
            diaryFilterTagID?.wrappedValue = nil
        }
    }
}
