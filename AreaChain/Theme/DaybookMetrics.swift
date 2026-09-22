import SwiftUI

/// 尺寸令牌，单份。基准 = 菜单栏浮层任务页现值（用户决定：菜单栏与工作台统一尺寸）。
/// 页面不得写字面高度 / 圆角 / 描边；需要不同尺寸时在基座组件的 configure 闭包里改，同一改法出现两次就升级为 variant。
enum DaybookMetrics {
    static let inputHeight: CGFloat = 34
    static let controlHeight: CGFloat = 28
    static let rowHeight: CGFloat = 36
    static let chipHeight: CGFloat = 18

    enum Hit {
        static let regular: CGFloat = 28
        static let compact: CGFloat = 22
        static let inline: CGFloat = 18
    }

    enum Radius {
        static let inputComposer: CGFloat = 8
        static let inputSearch: CGFloat = 10
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

    static func inputInsets(_ kind: DaybookInputKind) -> EdgeInsets {
        switch kind {
        case .composer: EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)
        case .search: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        case .editor: EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        }
    }
}
