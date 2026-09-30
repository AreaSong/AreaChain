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
    var cells: [DashboardHeatmapDay]
    var hasCompletions: Bool
    var locale: Locale
    var navigation: WorkspaceNavigation

    var body: some View {
        let columns = DashboardHeatmapLayout.columns(from: cells)
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            DaybookSectionHeader(title: "dashboard.heatmap.title", icon: "square.grid.3x3")
            if !hasCompletions {
                Text("dashboard.heatmap.empty")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ScrollView(.horizontal, showsIndicators: false) {
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
            legend
            Text("dashboard.heatmap.hint")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("dashboard.heatmap")
    }

    private var legend: some View {
        HStack(spacing: DaybookSpacing.xs) {
            Text("dashboard.heatmap.legend.less")
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.secondary)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: DaybookRadius.xxs)
                    .fill(DaybookPalette.heatmap.color(for: level))
                    .frame(width: DaybookMetrics.Heatmap.cell, height: DaybookMetrics.Heatmap.cell)
                    .accessibilityLabel(Text(levelLabel(level)))
            }
            Text("dashboard.heatmap.legend.more")
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.secondary)
        }
    }

    private func heatmapCell(_ cell: DashboardHeatmapDay) -> some View {
        Button {
            DashboardNavigation.openCalendar(
                dayKey: cell.dayKey, isPadding: cell.isPaddingCell, navigation: navigation
            )
        } label: {
            RoundedRectangle(cornerRadius: DaybookRadius.xxs)
                .fill(cell.isPaddingCell ? Color.clear : DaybookPalette.heatmap.color(for: cell.intensityLevel))
                .frame(width: DaybookMetrics.Heatmap.cell, height: DaybookMetrics.Heatmap.cell)
        }
        .buttonStyle(DaybookButtonStyle(.quiet, size: .inline))
        .help(previewHelp(cell))
        .frame(width: DaybookMetrics.Heatmap.cell, height: DaybookMetrics.Heatmap.cell)
        .clipped()
        .disabled(cell.isPaddingCell)
        .accessibilityIdentifier(cell.isPaddingCell ? "dashboard.heat.pad" : "dashboard.heat.\(cell.dayKey)")
        .accessibilityLabel(Text(cellLabel(cell)))
        .accessibilityHidden(cell.isPaddingCell)
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
