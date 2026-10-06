import SwiftUI

/// 尺寸令牌，单份。基准 = 菜单栏浮层任务页现值（用户决定：菜单栏与工作台统一尺寸）。
/// 页面不得写字面高度 / 圆角 / 描边；需要不同尺寸时在基座组件的 configure 闭包里改，同一改法出现两次就升级为 variant。
enum DaybookMetrics {
    enum WeekdayPicker {
        static let diameter: CGFloat = 25
        static let spacing: CGFloat = 4
        static let titleSpacing: CGFloat = 6
    }

    enum DatePicker {
        static let width: CGFloat = 252
        static let cellHeight: CGFloat = 24
    }

    enum WeekBoard {
        // 原任务行含优先级、时间和 48pt 操作区时，240pt 仅剩 5pt 标题；280pt 保留 45pt。
        static let minimumColumnWidth: CGFloat = 280
        static let columnSpacing: CGFloat = 8
    }

    enum WeekHeader {
        static let lineSpacing: CGFloat = 2
    }

    enum MonthGrid {
        // 内容最小高度，不包含 DaybookButtonSize.regular 的内边距，也不限制文字撑高。
        static let regularContentHeight: CGFloat = 52
        static let compactContentHeight: CGFloat = 28
        static let annotationSpacing: CGFloat = 2
        static let annotationSize: CGFloat = 9
    }

    enum HabitMonthGrid {
        static let minimumContentHeight: CGFloat = 22
        static let columnSpacing: CGFloat = 4
        static let rowSpacing: CGFloat = 4
        static let headingSpacing: CGFloat = 6
    }

    /// 完成标记的真实宿主基线；不与表单方形 Checkbox 或普通按钮点击区混用。
    enum Completion {
        static let task = DaybookCompletionGeometry(circle: 17, hit: 20, border: 1.5, check: 1.8, offset: 0.5)
        static let inlineSubtask = DaybookCompletionGeometry(circle: 12, hit: 14, border: 1.2, check: 1.4, offset: 0)
        // 详情保留 SF Symbol 固有框；12pt 字号在当前原生基线中命中框为 12×12。
        static let detailSubtaskSymbolSize = DaybookType.subtitleSize
    }

    enum Stepper {
        static let labelSpacing: CGFloat = DaybookSpacing.sm
        static let buttonSpacing: CGFloat = DaybookSpacing.xs
    }
    enum Segmented {
        static let spacing: CGFloat = 2
        static let inset: CGFloat = 3
        static let minimumLabelWidth: CGFloat = 36
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 4.5
    }
    enum Picker {
        static let labelSpacing: CGFloat = DaybookSpacing.sm
    }
    enum TimePicker {
        static let minimumWidth: CGFloat = 156
        static let popoverPadding: CGFloat = 12
        static let popoverMinimumWidth: CGFloat = 180
    }
    static let inputHeight: CGFloat = 34
    static let controlHeight: CGFloat = 28
    static let rowHeight: CGFloat = 36
    static let chipHeight: CGFloat = 18

    enum Hit {
        static let regular: CGFloat = 28
        static let compact: CGFloat = 22
        static let inline: CGFloat = 18
    }

    enum Toggle {
        static let width: CGFloat = 34
        static let height: CGFloat = 20
        static let thumb: CGFloat = 16
        static let inset: CGFloat = 2
    }

    enum Checkbox {
        static let side: CGFloat = 18
        static let radius: CGFloat = 4
        static let checkStroke: CGFloat = 1.5
    }

    enum Radius {
        static let inputComposer: CGFloat = 8
        static let inputSearch: CGFloat = 6
        static let inputEditor: CGFloat = 6
        static let control: CGFloat = 6
        static let panel: CGFloat = 8
        static let card: CGFloat = 10
        static let inline: CGFloat = 4
    }

    enum Stroke {
        static let hairline: CGFloat = 0.5
        static let regular: CGFloat = 0.6
        static let focus: CGFloat = 0.9
        static let emphasis: CGFloat = 1.0
    }

    enum Heatmap {
        static let cell: CGFloat = 11
        static let gap: CGFloat = 3
        static let trendHeight: CGFloat = 72
    }

    enum Window {
        static let popoverWidth: CGFloat = 380
        static let popoverMinHeight: CGFloat = 280
        static let popoverMaxHeight: CGFloat = 490
        static let popoverHeight: CGFloat = 490
        static let popoverSize = CGSize(width: popoverWidth, height: popoverHeight)
        static let workspaceSize = CGSize(width: 960, height: 640)
        static let workspaceMinSize = CGSize(width: 780, height: 500)
    }

    static func inputInsets(_ kind: DaybookInputKind) -> EdgeInsets {
        switch kind {
        case .composer: EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)
        case .search: EdgeInsets(top: 4, leading: 7, bottom: 4, trailing: 7)
        case .editor: EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        }
    }
}

struct DaybookCompletionGeometry {
    let circle: CGFloat
    let hit: CGFloat
    let border: CGFloat
    let check: CGFloat
    let offset: CGFloat
}
