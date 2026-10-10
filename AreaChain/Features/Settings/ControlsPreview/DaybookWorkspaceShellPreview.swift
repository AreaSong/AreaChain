import SwiftUI

/// 工作台公用骨架预览（以「今日」为例，内部不填具体业务内容，仅使用颜色占位符展示布局与层级）。
struct DaybookWorkspaceShellPreview: View {
    @State private var showHeaderRealText = true

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            HStack {
                Text(verbatim: "工作台公用骨架预览（今日为例 · 颜色占位符）")
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookPalette.text.primary)
                Spacer()
                Button(showHeaderRealText ? "切换：顶栏也用纯色块" : "切换：顶栏显示公用文字") {
                    showHeaderRealText.toggle()
                }
                .buttonStyle(DaybookButtonStyle(.subtle, size: .compact))
                .accessibilityIdentifier("preview.workspace.shell.toggle")
            }

            HStack(spacing: 0) {
                sidebarShellPlaceholder
                    .frame(width: 200)

                detailShellPlaceholder
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 460)
            .background(Color(nsColor: .windowBackgroundColor)) // token-exempt: 模拟工作台窗口原生系统灰底
            .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.panel, style: .continuous)
                    .strokeBorder(DaybookPalette.border.default, lineWidth: DaybookMetrics.Stroke.regular)
            )
            .accessibilityIdentifier("preview.workspace.shell")
        }
    }

    // MARK: - 左侧：公用双层内嵌侧边栏（颜色占位）

    private var sidebarShellPlaceholder: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(.ultraThinMaterial) // token-exempt: 侧边栏外层毛玻璃占位

            VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                HStack(spacing: DaybookSpacing.xs) {
                    DaybookStatusDot(color: DaybookPalette.status.danger, size: 10)
                    DaybookStatusDot(color: DaybookPalette.status.warning, size: 10)
                    DaybookStatusDot(color: DaybookPalette.status.success, size: 10)
                }
                .padding(.top, DaybookSpacing.sm)
                .padding(.leading, DaybookSpacing.sm)
                .padding(.bottom, DaybookSpacing.xs)

                VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                    placeholderBlock(color: DaybookPalette.text.secondary.opacity(0.18), width: 36, height: 10, radius: DaybookRadius.xxs) // token-exempt: 占位色块透明度
                        .padding(.leading, DaybookSpacing.xs)
                    placeholderBlock(color: DaybookPalette.text.secondary.opacity(0.12), height: 28, radius: DaybookRadius.regular) // token-exempt: 占位色块透明度

                    placeholderBlock(color: DaybookPalette.text.secondary.opacity(0.18), width: 36, height: 10, radius: DaybookRadius.xxs) // token-exempt: 占位色块透明度
                        .padding(.leading, DaybookSpacing.xs)
                        .padding(.top, DaybookSpacing.xs)
                    placeholderBlock(color: DaybookPalette.accent.base.opacity(0.22), height: 28, radius: DaybookRadius.regular) // token-exempt: 占位色块透明度
                    placeholderBlock(color: DaybookPalette.text.secondary.opacity(0.12), height: 28, radius: DaybookRadius.regular) // token-exempt: 占位色块透明度
                    placeholderBlock(color: DaybookPalette.text.secondary.opacity(0.12), height: 28, radius: DaybookRadius.regular) // token-exempt: 占位色块透明度

                    placeholderBlock(color: DaybookPalette.text.secondary.opacity(0.18), width: 36, height: 10, radius: DaybookRadius.xxs) // token-exempt: 占位色块透明度
                        .padding(.leading, DaybookSpacing.xs)
                        .padding(.top, DaybookSpacing.xs)
                    placeholderBlock(color: DaybookPalette.text.secondary.opacity(0.12), height: 28, radius: DaybookRadius.regular) // token-exempt: 占位色块透明度
                    placeholderBlock(color: DaybookPalette.text.secondary.opacity(0.12), height: 28, radius: DaybookRadius.regular) // token-exempt: 占位色块透明度
                }
                .padding(.horizontal, DaybookSpacing.xs)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.panel, style: .continuous)
                    .fill(DaybookPalette.fill.page.opacity(0.75)) // token-exempt: 内胆毛玻璃叠色
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.panel, style: .continuous)
                    .strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.5)
            )
            .padding(.leading, DaybookSpacing.xs)
            .padding(.top, DaybookSpacing.xs)
            .padding(.bottom, DaybookSpacing.xs)
            .padding(.trailing, DaybookSpacing.xxs)
        }
        .overlay(alignment: .trailing) {
            DaybookDivider(axis: .vertical, opacity: 0.35)
        }
    }

    // MARK: - 右侧：公用顶栏 + 今日内容区颜色占位

    private var detailShellPlaceholder: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerShellPlaceholder
                .padding(.horizontal, DaybookSpacing.page)
                .frame(height: 50)

            VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                placeholderBlock(
                    color: DaybookPalette.accent.base.opacity(0.14), // token-exempt: 占位色块透明度
                    height: DaybookMetrics.inputHeight,
                    radius: DaybookMetrics.Radius.inputComposer
                )

                HStack(spacing: DaybookSpacing.xs) {
                    placeholderBlock(color: DaybookPalette.status.warning.opacity(0.22), width: 72, height: 24, radius: DaybookRadius.small) // token-exempt: 占位色块透明度
                    Spacer()
                    placeholderBlock(color: DaybookPalette.status.info.opacity(0.20), width: 68, height: 24, radius: DaybookRadius.small) // token-exempt: 占位色块透明度
                    placeholderBlock(color: DaybookPalette.status.info.opacity(0.20), width: 76, height: 24, radius: DaybookRadius.small) // token-exempt: 占位色块透明度
                    placeholderBlock(color: DaybookPalette.status.info.opacity(0.20), width: 68, height: 24, radius: DaybookRadius.small) // token-exempt: 占位色块透明度
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<4, id: \.self) { index in
                        HStack(spacing: DaybookSpacing.sm) {
                            DaybookStatusDot(color: DaybookPalette.status.success.opacity(0.35), size: 16) // token-exempt: 占位圆点透明度
                            placeholderBlock(
                                color: DaybookPalette.status.success.opacity(0.18), // token-exempt: 占位色块透明度
                                height: 16,
                                radius: DaybookRadius.xxs
                            )
                            placeholderBlock(
                                color: DaybookPalette.text.secondary.opacity(0.15), // token-exempt: 占位色块透明度
                                width: 56,
                                height: 16,
                                radius: DaybookRadius.xxs
                            )
                        }
                        .padding(.horizontal, DaybookSpacing.md)
                        .frame(height: DaybookMetrics.rowHeight)

                        if index < 3 {
                            DaybookDivider(opacity: 0.35)
                                .padding(.leading, 38)
                        }
                    }
                }
                .padding(.vertical, DaybookSpacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.card, style: .continuous)
                        .fill(DaybookPalette.fill.page)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DaybookRadius.card, style: .continuous)
                        .strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.5)
                )

                placeholderBlock(
                    color: DaybookPalette.text.secondary.opacity(0.14), // token-exempt: 占位色块透明度
                    width: 120,
                    height: 20,
                    radius: DaybookRadius.xxs
                )
                .padding(.top, DaybookSpacing.xxs)

                Spacer(minLength: 0)
            }
            .padding(DaybookSpacing.page)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var headerShellPlaceholder: some View {
        if showHeaderRealText {
            HStack(spacing: DaybookSpacing.md) {
                VStack(alignment: .leading, spacing: DaybookSpacing.xxs) {
                    Text("workspace.today.title")
                        .font(DaybookType.body.weight(.semibold))
                        .foregroundStyle(DaybookPalette.text.primary)
                    Text(verbatim: "10月10日 周六")
                        .font(DaybookType.micro)
                        .foregroundStyle(DaybookPalette.text.secondary)
                }
                Spacer()
                HStack(spacing: DaybookSpacing.xxs) {
                    Image(systemName: "magnifyingglass")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                    Text("workspace.search.placeholder")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                    Text(verbatim: "⌘F")
                        .font(DaybookType.micro)
                        .foregroundStyle(DaybookPalette.text.secondary)
                }
                Spacer()
                HStack(spacing: DaybookSpacing.sm) {
                    Label("workspace.recurring.menu", systemImage: "repeat")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.primary)
                    Text(verbatim: "0/3")
                        .font(DaybookType.caption.monospacedDigit())
                        .foregroundStyle(DaybookPalette.text.secondary)
                    Image(systemName: "sidebar.trailing")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                }
            }
        } else {
            HStack(spacing: DaybookSpacing.md) {
                placeholderBlock(color: DaybookPalette.status.warning.opacity(0.28), width: 96, height: 28, radius: DaybookRadius.small) // token-exempt: 占位色块透明度
                Spacer()
                placeholderBlock(color: DaybookPalette.accent.base.opacity(0.22), width: 220, height: 28, radius: DaybookRadius.small) // token-exempt: 占位色块透明度
                Spacer()
                placeholderBlock(color: DaybookPalette.status.success.opacity(0.25), width: 140, height: 28, radius: DaybookRadius.small) // token-exempt: 占位色块透明度
            }
        }
    }

    private func placeholderBlock(color: Color, width: CGFloat? = nil, height: CGFloat, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous) // token-exempt: 颜色占位色块
            .fill(color) // token-exempt: 颜色占位色块填充
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
    }
}
