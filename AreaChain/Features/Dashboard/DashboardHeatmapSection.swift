import SwiftUI

enum DashboardHeatmapLayout {
    static let daysPerColumn = 7

    static func columns(from cells: [DashboardHeatmapDay]) -> [[DashboardHeatmapDay]] {
        guard !cells.isEmpty else { return [] }
        return stride(from: 0, to: cells.count, by: daysPerColumn).map { start in
            Array(cells[start..<min(start + daysPerColumn, cells.count)])
        }
    }

    static func hasCompletions(_ cells: [DashboardHeatmapDay]) -> Bool {
        cells.contains { !$0.isPaddingCell && $0.completedCount > 0 }
    }
}

struct DashboardHeatmapSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var cells: [DashboardHeatmapDay]
    var hasCompletions: Bool
    var locale: Locale
    var navigation: WorkspaceNavigation

    @State private var selectedCellDayKey: String? = nil

    private var isEnglish: Bool {
        locale.language.languageCode?.identifier == "en"
    }

    private var activeDaysCount: Int {
        cells.filter { !$0.isPaddingCell && $0.completedCount > 0 }.count
    }

    private var totalCompletedCount: Int {
        cells.filter { !$0.isPaddingCell }.reduce(0) { $0 + $1.completedCount }
    }

    private var totalDaysCount: Int {
        max(cells.filter { !$0.isPaddingCell }.count, 1)
    }

    private var activeRate: Double {
        Double(activeDaysCount) / Double(totalDaysCount)
    }

    private var headerBadgeText: String {
        isEnglish
            ? "\(activeDaysCount)d active · \(totalCompletedCount) done"
            : "活跃 \(activeDaysCount) 天 · 累计 \(totalCompletedCount) 项"
    }

    var body: some View {
        let columns = DashboardHeatmapLayout.columns(from: cells)
        let monthLabels = makeMonthLabels(columns: columns)
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            heatmapGridContainer(columns: columns, monthLabels: monthLabels)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("dashboard.heatmap")
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("dashboard.heatmap.title")
                .font(DaybookType.caption.weight(.semibold))
                .foregroundStyle(DaybookPalette.text.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            legend
            Text(verbatim: headerBadgeText)
                .font(DaybookType.badge.monospacedDigit())
                .foregroundStyle(DaybookPalette.text.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 热力图头部统计胶囊
                        .fill(DaybookPalette.fill.hover)
                )
        }
        .frame(height: 20)
        .padding(.horizontal, 4)
    }

    private func heatmapGridContainer(
        columns: [[DashboardHeatmapDay]],
        monthLabels: [Int: String]
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            weekdayAxis
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    monthAxisRow(columnsCount: columns.count, labels: monthLabels)
                    HStack(alignment: .top, spacing: DaybookMetrics.Heatmap.gap) {
                        ForEach(columns.indices, id: \.self) { index in
                            VStack(spacing: DaybookMetrics.Heatmap.gap) {
                                ForEach(columns[index]) { cell in
                                    heatmapCell(cell)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 118)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous) // control: 热力图纯白微浮内衬底板
                .fill(DaybookPalette.fill.surface)
        )
    }

    private var weekdayAxis: some View {
        let labels = isEnglish
            ? ["", "M", "", "W", "", "F", ""]
            : ["", "一", "", "三", "", "五", ""]
        return VStack(alignment: .trailing, spacing: DaybookMetrics.Heatmap.gap) {
            Color.clear
                .frame(width: 14, height: 13)
            ForEach(0..<7, id: \.self) { row in
                Text(verbatim: labels[row])
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.tertiary)
                    .frame(width: 14, height: DaybookMetrics.Heatmap.cell, alignment: .trailing)
            }
        }
        .accessibilityHidden(true)
    }

    private func monthAxisRow(columnsCount: Int, labels: [Int: String]) -> some View {
        let step = DaybookMetrics.Heatmap.cell + DaybookMetrics.Heatmap.gap
        return ZStack(alignment: .leading) {
            Color.clear
                .frame(width: CGFloat(max(columnsCount, 1)) * step, height: 13)
            ForEach(labels.keys.sorted(), id: \.self) { colIndex in
                if let text = labels[colIndex] {
                    Text(verbatim: text)
                        .font(DaybookType.badge)
                        .foregroundStyle(DaybookPalette.text.tertiary)
                        .lineLimit(1)
                        .fixedSize()
                        .offset(x: CGFloat(colIndex) * step)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func makeMonthLabels(columns: [[DashboardHeatmapDay]]) -> [Int: String] {
        var result: [Int: String] = [:]
        var lastMonth = ""
        var lastPlacedCol = -4
        let enMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        for (colIdx, col) in columns.enumerated() {
            guard let firstReal = col.first(where: { !$0.isPaddingCell }) else { continue }
            let parts = firstReal.dayKey.split(separator: "-")
            guard parts.count == 3 else { continue }
            let ym = "\(parts[0])-\(parts[1])"
            if ym != lastMonth {
                lastMonth = ym
                if colIdx - lastPlacedCol >= 3, let m = Int(parts[1]), (1...12).contains(m) {
                    result[colIdx] = isEnglish ? enMonths[m - 1] : "\(m)月"
                    lastPlacedCol = colIdx
                }
            }
        }
        return result
    }

    private var legend: some View {
        HStack(spacing: 3) {
            Text("dashboard.heatmap.legend.less")
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.tertiary)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: DaybookRadius.xxs) // control: 热力图图例色块
                    .fill(DaybookPalette.heatmap.color(for: level))
                    .frame(width: 9, height: 9)
                    .accessibilityLabel(Text(levelLabel(level)))
            }
            Text("dashboard.heatmap.legend.more")
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.tertiary)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func heatmapCell(_ cell: DashboardHeatmapDay) -> some View {
        let isSelected = selectedCellDayKey == cell.dayKey
        return Button {
            guard !cell.isPaddingCell else { return }
            let isCmd = DashboardCommandKeyMonitor.isCommandDown || DashboardCommandKeyMonitor.shared.isCommandPressed
            if isCmd {
                selectedCellDayKey = nil
                navigation.inspectBoard(cell.dayKey)
            } else {
                selectedCellDayKey = isSelected ? nil : cell.dayKey
            }
        } label: {
            RoundedRectangle(cornerRadius: DaybookRadius.xxs) // control: 热力图日期单元格
                .fill(cell.isPaddingCell ? Color.clear : DaybookPalette.heatmap.color(for: cell.intensityLevel))
                .overlay(
                    RoundedRectangle(cornerRadius: DaybookRadius.xxs)
                        .strokeBorder(isSelected ? DaybookPalette.accent.base : Color.clear, lineWidth: 1)
                )
                .frame(width: DaybookMetrics.Heatmap.cell, height: DaybookMetrics.Heatmap.cell)
                .scaleEffect(isSelected ? 1.25 : 1.0)
                .animation(DaybookMotion.interactive(reduceMotion), value: isSelected)
        }
        .buttonStyle(.plain) // control: 热力图轻量单元格按钮
        .onHover { hovering in
            if hovering {
                DashboardCommandKeyMonitor.shared.sync()
            }
        }
        .help(previewHelp(cell))
        .frame(width: DaybookMetrics.Heatmap.cell, height: DaybookMetrics.Heatmap.cell)
        .disabled(cell.isPaddingCell)
        .accessibilityIdentifier(cell.isPaddingCell ? "dashboard.heat.pad" : "dashboard.heat.\(cell.dayKey)")
        .accessibilityLabel(Text(cellLabel(cell)))
        .accessibilityHidden(cell.isPaddingCell)
        .dashboardCommandPopover(
            isPresented: Binding(
                get: { selectedCellDayKey == cell.dayKey },
                set: { if !$0 { selectedCellDayKey = nil } }
            ),
            arrowEdge: .top
        ) {
            heatmapHUD(cell)
        }
    }

    private func heatmapHUD(_ cell: DashboardHeatmapDay) -> some View {
        let dateTitle = cell.isPaddingCell ? "" : DayKey.displayName(cell.dayKey, locale: locale)
        let summaryText = isEnglish
            ? "Completed \(cell.completedCount)/\(cell.scheduledCount) · Skipped \(cell.skippedCount)"
            : "完成 \(cell.completedCount)/\(cell.scheduledCount) 项 · 跳过 \(cell.skippedCount) 项"
        return DashboardHUDCard(
            icon: "calendar.badge.checkmark",
            title: dateTitle,
            subtitle: summaryText,
            items: cell.previewTitles.map {
                .init(
                    symbol: "checkmark.circle.fill",
                    symbolColor: DaybookPalette.status.success,
                    title: $0,
                    trailing: nil
                )
            },
            emptyText: isEnglish ? "No completed items on this day" : "当日没有已完成记录",
            actionTitle: isEnglish ? "Open in Calendar" : "在日历中打开当天",
            onAction: {
                selectedCellDayKey = nil
                DashboardNavigation.openCalendar(
                    dayKey: cell.dayKey, isPadding: cell.isPaddingCell, navigation: navigation
                )
            }
        )
    }

    private func previewHelp(_ cell: DashboardHeatmapDay) -> String {
        guard !cell.isPaddingCell, cell.completedCount > 0 else { return "" }
        var lines = cell.previewTitles
        let extra = cell.completedCount - lines.count
        if extra > 0 {
            lines.append(L10n.format("dashboard.heatmap.more", locale: locale, extra))
        }
        return lines.joined(separator: "\n")
    }

    private func cellLabel(_ cell: DashboardHeatmapDay) -> String {
        guard !cell.isPaddingCell else { return "" }
        var text = L10n.format(
            "dashboard.heatmap.cell",
            locale: locale,
            DayKey.displayName(cell.dayKey, locale: locale),
            cell.completedCount,
            cell.scheduledCount,
            levelLabel(cell.intensityLevel)
        )
        if cell.skippedCount > 0 {
            text += L10n.format("dashboard.heatmap.skipped", locale: locale, cell.skippedCount)
        }
        return text
    }

    private func levelLabel(_ level: Int) -> String {
        L10n.format("dashboard.heatmap.level", locale: locale, level)
    }
}
