import SwiftUI

struct DashboardHeatmapSection: View {
    var cells: [DashboardHeatmapDay]
    var hasCompletions: Bool
    var locale: Locale
    var navigation: WorkspaceNavigation

    var body: some View {
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

    private var columns: [[DashboardHeatmapDay]] {
        stride(from: 0, to: cells.count, by: 7).map { start in
            Array(cells[start..<min(start + 7, cells.count)])
        }
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
        .frame(width: DaybookMetrics.Heatmap.cell, height: DaybookMetrics.Heatmap.cell)
        .clipped()
        .disabled(cell.isPaddingCell)
        .accessibilityIdentifier(cell.isPaddingCell ? "dashboard.heat.pad" : "dashboard.heat.\(cell.dayKey)")
        .accessibilityLabel(Text(cellLabel(cell)))
        .accessibilityHidden(cell.isPaddingCell)
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
