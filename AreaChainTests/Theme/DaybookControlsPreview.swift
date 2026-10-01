#if DEBUG
import SwiftUI
@testable import AreaChain

/// 仅供隔离测试窗口装配；不读取偏好、数据库或系统服务。
struct DaybookControlsPreview: View {
    @State private var localeID = "zh-Hans"
    @State private var dark = false
    @State private var disabled = false
    @State private var reduceMotion = false
    @State private var longLabels = false
    @State private var actions = 0

    private let sizes: [DaybookButtonSize] = [.regular, .compact, .inline]
    private let variants: [(String, DaybookButtonVariant)] = [
        ("quiet", .quiet), ("subtle", .subtle), ("prominent", .prominent),
        ("destructive", .destructive), ("active", .active),
        ("pill", .pill(tint: DaybookPalette.accent.base))
    ]

    init(localeID: String = "zh-Hans", dark: Bool = false, longLabels: Bool = false) {
        _localeID = State(initialValue: localeID)
        _dark = State(initialValue: dark)
        _longLabels = State(initialValue: longLabels)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            controls
            ScrollView {
                buttonGrid
                .disabled(disabled)
                .padding(DaybookSpacing.xs)
            }
            HStack(spacing: DaybookSpacing.md) {
                CommandReturnButton(enabled: !disabled, label: "common.save") { actions += 1 }
                    // 注册仅属于本地展示宿主，与生产控件的职责相同。
                    .keyboardShortcut(.return, modifiers: .command)
                Text("dev.controls.actions")
                Text(verbatim: String(actions)).monospacedDigit()
            }
            Text("dev.controls.instructions").font(DaybookType.caption)
        }
        .font(DaybookType.body)
        .padding(DaybookSpacing.page)
        .background(DaybookPalette.fill.page)
        .environment(\.locale, Locale(identifier: localeID))
        .environment(\.daybookButtonReduceMotionPreview, reduceMotion)
        .preferredColorScheme(dark ? .dark : .light)
    }

    private var buttonGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: DaybookSpacing.lg, verticalSpacing: DaybookSpacing.sm) {
            GridRow {
                Text("dev.controls.variant")
                ForEach(sizes.indices, id: \.self) { sizeIndex in
                    let size = sizes[sizeIndex]
                    Text(verbatim: String(describing: size))
                }
            }
            ForEach(variants.indices, id: \.self) { index in
                GridRow {
                    Text(verbatim: variants[index].0)
                    ForEach(sizes.indices, id: \.self) { sizeIndex in
                        let size = sizes[sizeIndex]
                        Button(role: variants[index].1 == .destructive ? .destructive : nil) { actions += 1 } label: {
                            Text(longLabels ? "dev.controls.longLabel" : "common.save")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(DaybookButtonStyle(variants[index].1, size: size))
                    }
                }
            }
            iconRow("icon", active: false)
            iconRow("iconActive", active: true)
            iconRow("iconDestructive", role: .destructive)
            menuRow(fitsLabel: true)
            menuRow(fitsLabel: false)
            menuRow(fitsLabel: false, active: true)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("dev.controls.title").font(DaybookType.title)
            HStack {
                Picker("dev.controls.language", selection: $localeID) {
                    Text(verbatim: "简体中文").tag("zh-Hans")
                    Text(verbatim: "English").tag("en")
                }.frame(maxWidth: 220)
                Toggle("dev.controls.dark", isOn: $dark)
            }
            HStack {
                Toggle("dev.controls.disabled", isOn: $disabled)
                Toggle("dev.controls.reduceMotion", isOn: $reduceMotion)
                Toggle("dev.controls.longLabels", isOn: $longLabels)
            }
        }
    }

    private func iconRow(_ name: String, active: Bool = false, role: ButtonRole? = nil) -> some View {
        GridRow {
            Text(verbatim: name)
            ForEach(sizes.indices, id: \.self) { sizeIndex in
                let size = sizes[sizeIndex]
                DaybookIconButton(systemName: role == .destructive ? "trash" : "star",
                                  label: "dev.controls.sample", size: size, role: role, isActive: active) { actions += 1 }
            }
        }
    }

    private func menuRow(fitsLabel: Bool, active: Bool = false) -> some View {
        GridRow {
            Text(verbatim: fitsLabel ? "Menu label" : (active ? "Menu active" : "Menu icon"))
            ForEach(sizes.indices, id: \.self) { sizeIndex in
                let size = sizes[sizeIndex]
                Menu {
                    Button("common.save") { actions += 1 }
                    Button("alert.trash.move", role: .destructive) { actions += 1 }
                } label: {
                    Group {
                        if fitsLabel {
                            Label("dev.controls.sample", systemImage: "ellipsis")
                        } else {
                            Image(systemName: "ellipsis").font(size.iconFont)
                        }
                    }
                    .daybookMenuLabel(size: size, isActive: active, fitsLabel: fitsLabel)
                }
                .accessibilityLabel("dev.controls.sample")
                .help("dev.controls.sample")
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }
}

#endif
