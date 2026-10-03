import SwiftUI

/// 菜单栏兼容入口；计数继续由宿主使用，不在分段上显示。
struct DaybookSegmentedBar: View {
    @Binding var selection: BoardTab
    var tasksCount: Int = 0
    var diariesCount: Int = 0

    var body: some View {
        DaybookSegmentedControl(selection: $selection, options: BoardTab.allCases.map {
            DaybookSegmentOption($0, String.LocalizationValue($0.titleKey),
                                 help: String.LocalizationValue($0.helpKey))
        })
    }
}
