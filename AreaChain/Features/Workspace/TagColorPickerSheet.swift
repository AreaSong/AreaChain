import AppKit
import SwiftUI

/// 应用内 Daybook 风格标签调色盘弹窗：支持 2D 色相/饱和度拖拽取色、明度调节、快捷色板、HEX 输入与可选命名。
struct TagColorPickerSheet: View {
    @Environment(\.locale) private var locale

    var previewTagName: String
    var initialToken: String = "#3B82F6"
    var onCancel: () -> Void
    var onConfirm: (String, String) -> Void

    @State private var hue: Double = 0.58
    @State private var saturation: Double = 0.76
    @State private var brightness: Double = 0.92
    @State private var hexInput: String = "#3B82F6"
    @State private var customName: String = ""
    @State private var hexFocused = false
    @State private var nameFocused = false

    private static let quickSwatches: [String] = [
        "#E05A47", "#D94E8F", "#A855F7", "#6366F1",
        "#0EA5E9", "#14B8A6", "#22C55E", "#84CC16",
        "#EAB308", "#F97316", "#8D5B4C", "#64748B"
    ]

    private var currentHex: String {
        if let normalized = TagColorToken.normalizedHex(hexInput) {
            return normalized
        }
        let rgb = Self.hsbToRGB(h: hue, s: saturation, b: brightness)
        return TagColorToken.hexString(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    private var previewColor: Color {
        DaybookPalette.tagMark(name: previewTagName, token: currentHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            headerSection
            hueSaturationCanvas
            brightnessSection
            quickSwatchesSection
            inputsSection
            footerSection
        }
        .padding(DaybookSpacing.page)
        .frame(width: 360)
        .onAppear {
            applyHexToHSB(initialToken)
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: DaybookSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("tags.color.custom.title")
                    .font(DaybookType.body.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)
                Text("tags.color.custom.subtitle")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            Spacer(minLength: DaybookSpacing.xs)
            HStack(spacing: 6) {
                DaybookStatusDot(color: previewColor, size: 10)
                DiaryTagPill(
                    name: previewTagName.isEmpty ? "Tag" : previewTagName,
                    colorToken: currentHex
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .daybookSurface(.row)
        }
    }

    private var hueSaturationCanvas: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                Canvas { context, canvasSize in
                    let cols = 48
                    let rows = 24
                    let cellW = canvasSize.width / CGFloat(cols)
                    let cellH = canvasSize.height / CGFloat(rows)
                    for col in 0..<cols {
                        for row in 0..<rows {
                            let h = Double(col) / Double(cols - 1)
                            let s = 1.0 - (Double(row) / Double(rows - 1))
                            let rgb = Self.hsbToRGB(h: h, s: s, b: brightness)
                            let rect = CGRect(
                                x: CGFloat(col) * cellW,
                                y: CGFloat(row) * cellH,
                                width: ceil(cellW),
                                height: ceil(cellH)
                            )
                            let cellColor = Color(nsColor: NSColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)) // token-exempt: 调色盘连续色阶渲染
                            context.fill(Path(rect), with: .color(cellColor))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
                        .strokeBorder(DaybookPalette.border.subtle, lineWidth: 1)
                )

                pickerThumb(in: size)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clampedX = min(max(0, value.location.x), max(size.width, 1))
                        let clampedY = min(max(0, value.location.y), max(size.height, 1))
                        hue = Double(clampedX / max(size.width, 1))
                        saturation = 1.0 - Double(clampedY / max(size.height, 1))
                        syncHexFromHSB()
                    }
            )
        }
        .frame(height: 132)
        .accessibilityIdentifier("tags.color.custom.canvas")
    }

    private func pickerThumb(in size: CGSize) -> some View {
        let x = CGFloat(hue) * size.width
        let y = CGFloat(1.0 - saturation) * size.height
        return Circle() // token-exempt: 调色盘取色准星
            .fill(previewColor)
            .frame(width: 16, height: 16)
            .overlay(
                Circle().strokeBorder(DaybookPalette.fill.page, lineWidth: 2) // token-exempt: 调色盘取色准星内环
            )
            .overlay(
                Circle().strokeBorder(DaybookPalette.border.strong, lineWidth: 0.8) // token-exempt: 调色盘取色准星外环
            )
            .position(x: x, y: y)
            .allowsHitTesting(false)
    }

    private var brightnessSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("tags.color.custom.brightness")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                Spacer()
                Text(verbatim: "\(Int((brightness * 100).rounded()))%")
                    .font(DaybookType.caption.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.tertiary)
            }
            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let darkRGB = Self.hsbToRGB(h: hue, s: saturation, b: 0.25)
                let brightRGB = Self.hsbToRGB(h: hue, s: saturation, b: 1.0)
                let darkColor = Color(nsColor: NSColor(srgbRed: darkRGB.r, green: darkRGB.g, blue: darkRGB.b, alpha: 1)) // token-exempt: 调色盘明度暗端
                let brightColor = Color(nsColor: NSColor(srgbRed: brightRGB.r, green: brightRGB.g, blue: brightRGB.b, alpha: 1)) // token-exempt: 调色盘明度亮端
                let progress = CGFloat((brightness - 0.25) / 0.75)
                ZStack(alignment: .leading) {
                    Capsule() // token-exempt: 调色盘明度轨道
                        .fill(LinearGradient(colors: [darkColor, brightColor], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 10)
                        .overlay(Capsule().strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.8)) // token-exempt: 明度轨道描边
                    Circle() // token-exempt: 明度滑块圆钮
                        .fill(previewColor)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(DaybookPalette.fill.page, lineWidth: 2)) // token-exempt: 明度滑块内环
                        .offset(x: min(max(0, progress * (width - 14)), width - 14))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = min(max(0, value.location.x / width), 1)
                            brightness = 0.25 + Double(ratio) * 0.75
                            syncHexFromHSB()
                        }
                )
            }
            .frame(height: 16)
        }
    }

    private var quickSwatchesSection: some View {
        HStack(spacing: 8) {
            ForEach(Self.quickSwatches, id: \.self) { swatch in
                let selected = currentHex == swatch
                Button {
                    applyHexToHSB(swatch)
                } label: {
                    DaybookStatusDot(color: DaybookPalette.tagMark(token: swatch), size: 16)
                        .overlay(
                            Circle() // token-exempt: 快捷色点选中环
                                .strokeBorder(selected ? DaybookPalette.text.primary : Color.clear, lineWidth: 1.5)
                                .frame(width: 20, height: 20)
                        )
                }
                .buttonStyle(.plain) // control: 调色盘快捷色点按钮
                .accessibilityLabel(Text(verbatim: swatch))
            }
        }
    }

    private var inputsSection: some View {
        HStack(spacing: DaybookSpacing.sm) {
            DaybookInputShell(kind: .composer, focused: hexFocused) {
                DaybookStatusDot(color: previewColor, size: 10)
            } field: {
                DaybookTextField(
                    text: $hexInput,
                    placeholder: "#RRGGBB",
                    fontSize: 12,
                    focus: $hexFocused,
                    onSubmit: submitColor,
                    allowsShiftNewline: false
                )
                .onChange(of: hexInput) { _, next in
                    if let normalized = TagColorToken.normalizedHex(next) {
                        applyHexToHSB(normalized, updateText: false)
                    }
                }
                .accessibilityIdentifier("tags.color.custom.hex")
            }
            .frame(width: 128)

            DaybookInputShell(kind: .composer, focused: nameFocused) {
                Image(systemName: "tag")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.tertiary)
            } field: {
                DaybookTextField(
                    text: $customName,
                    placeholder: L10n.string("tags.color.custom.name.placeholder", locale: locale),
                    fontSize: 12,
                    focus: $nameFocused,
                    onSubmit: submitColor,
                    allowsShiftNewline: false
                )
                .accessibilityIdentifier("tags.color.custom.name")
            }
        }
    }

    private var footerSection: some View {
        HStack {
            Spacer()
            Button("alert.cancel", action: onCancel)
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            Button("tags.color.custom.save", action: submitColor)
                .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                .accessibilityIdentifier("tags.color.custom.submit")
        }
    }

    private func submitColor() {
        onConfirm(currentHex, customName.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func syncHexFromHSB() {
        let rgb = Self.hsbToRGB(h: hue, s: saturation, b: brightness)
        hexInput = TagColorToken.hexString(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    private func applyHexToHSB(_ raw: String, updateText: Bool = true) {
        let targetHex: String
        if let normalized = TagColorToken.normalizedHex(raw) {
            targetHex = normalized
        } else {
            targetHex = "#3B82F6"
        }
        if updateText { hexInput = targetHex }
        guard let rgb = TagColorToken.rgbComponents(of: targetHex) else { return }
        let nsColor = NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1.0)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        hue = Double(h)
        saturation = Double(s)
        brightness = max(0.25, Double(b))
    }

    private static func hsbToRGB(h: Double, s: Double, b: Double) -> (r: Double, g: Double, b: Double) {
        let color = NSColor(hue: CGFloat(min(max(h, 0), 1)),
                            saturation: CGFloat(min(max(s, 0), 1)),
                            brightness: CGFloat(min(max(b, 0), 1)),
                            alpha: 1.0)
        let rgb = color.usingColorSpace(.sRGB) ?? color
        return (Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent))
    }
}
