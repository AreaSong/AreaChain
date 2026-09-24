import SwiftUI

/// 本阶段只接通导航的页面壳。不提供保存、统计或完成操作。
struct WorkspaceSectionPlaceholderView: View {
    var tab: WorkspaceTab

    var body: some View {
        DaybookPage(title: tab.titleKey, systemImage: tab.iconName) {
            VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                Image(systemName: tab.iconName)
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookPalette.accent.base)
                    .accessibilityHidden(true)
                Text("workspace.section.placeholder.body")
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
