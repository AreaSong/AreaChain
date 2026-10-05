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
    @State private var enabledSample = true
    @State private var disabledSample = false
    @State private var checkedSample = true
    @State private var taskDone = false
    @State private var subtaskDone = true
    @State private var detailSubtaskDone = false
    @State private var pickerSample = ClipboardSearchMode.mixed
    @State private var segmentSample = 1
    @State private var otherSegmentSample = 2
    @State private var verbatimSample = 0
    @State private var integerSample = 200
    @State private var decimalSample = 0.35
    @State private var integerLower = 20
    @State private var integerUpper = 999
    @State private var decimalLower = 0.1
    @State private var decimalUpper = 2.0
    @State private var dateSample = "2026-09-18"
    @State private var timeSample: Int? = 720
    @State private var emptyTimeSample: Int?

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
                VStack(alignment: .leading, spacing: DaybookSpacing.lg) {
                    staticCardSamples
                    DaybookFloatingSurfaceSamples()
                    DaybookSecureInputSamples()
                    DaybookFormInputSamples()
                    DaybookWeekdaySamples()
                    dateSamples
                    timeSamples
                    segmentedSamples
                    pickerSamples
                    completionSamples
                    stepperSamples
                    toggleSamples
                    checkboxSamples
                    buttonGrid
                }
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

    private var staticCardSamples: some View {
        HStack(spacing: DaybookSpacing.md) {
            Text(verbatim: "Static card · 静态卡片")
                .padding(10).daybookStaticCardSurface()
            Text(verbatim: "Interactive card · 悬停卡片")
                .padding(10).daybookSurface(.card)
        }
        .accessibilityIdentifier("controls.static.cards")
    }

    private var dateSamples: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("day.date").font(DaybookType.title)
            DaybookDatePicker(selection: $dateSample, todayKey: "2026-09-18")
            DaybookDatePicker(selection: .constant("2028-02-29"), todayKey: "2028-02-28").disabled(true)
            DaybookDateCellSamples { dateSample = $0 }
            DaybookHabitDateCellSamples()
            DaybookWeekHeaderSamples()
            Button("dev.controls.toggle.external") {
                dateSample = dateSample == "2026-09-18" ? "2028-02-29" : "2026-09-18"
            }.buttonStyle(DaybookButtonStyle(.quiet))
        }
    }

    private var timeSamples: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("dev.controls.time").font(DaybookType.title)
            HStack(alignment: .top) {
                DaybookTimePicker(longLabels ? "dev.controls.time.long" : "row.time", minutes: $timeSample)
                DaybookTimePicker("row.time", minutes: $emptyTimeSample)
                DaybookTimePicker("row.time", minutes: .constant(0)).disabled(true)
            }
            Button("dev.controls.toggle.external") { timeSample = timeSample == 720 ? 1439 : 720 }
                .buttonStyle(DaybookButtonStyle(.quiet))
                .accessibilityIdentifier("preview.time.external")
        }
    }

    private var segmentedSamples: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("dev.controls.segments").font(DaybookType.title)
            DaybookSegmentedControl(selection: $segmentSample, options: segmentOptions)
            DaybookSegmentedControl(selection: $otherSegmentSample, options: segmentOptions)
            DaybookSegmentedControl(selection: .constant(1), options: segmentOptions).disabled(true)
        }
    }

    private var segmentOptions: [DaybookSegmentOption<Int>] {
        [.init(1, longLabels ? "dev.controls.picker.long" : "tab.tasks"), .init(2, "tab.diary")]
    }

    private var pickerSamples: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("dev.controls.pickers").font(DaybookType.title)
            DaybookPicker("clipboard.searchMode", selection: $pickerSample, options: pickerOptions)
            DaybookPicker("clipboard.searchMode", selection: .constant(ClipboardSearchMode.exact), options: pickerOptions)
                .disabled(true)
            DaybookPicker("dev.controls.picker.long", selection: $pickerSample, options: [
                .init(.mixed, "dev.controls.picker.long"), .init(.exact, "clipboard.searchMode.exact"),
                .init(.regex, "clipboard.searchMode.regex")
            ])
            DaybookPicker("tags.merge.pickTarget", selection: $verbatimSample, options: [
                .init(0, verbatim: "common.save"), .init(1, verbatim: "中文 · English # & 🏷️"),
                .init(2, verbatim: String(repeating: "合成的长标签 Synthetic long tag · ", count: 4))
            ])
            Button("dev.controls.toggle.external") { pickerSample = pickerSample == .mixed ? .regex : .mixed }
                .buttonStyle(DaybookButtonStyle(.quiet))
                .accessibilityIdentifier("preview.picker.external")
        }
    }

    private var pickerOptions: [DaybookPickerOption<ClipboardSearchMode>] {
        [.init(.mixed, "clipboard.searchMode.mixed"), .init(.exact, "clipboard.searchMode.exact"),
         .init(.regex, "clipboard.searchMode.regex")]
    }

    private var completionSamples: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("dev.controls.completion").font(DaybookType.title)
            HStack(spacing: DaybookSpacing.md) {
                ModernCheckbox(isDone: taskDone) { taskDone.toggle(); actions += 1 }
                    .accessibilityIdentifier("preview.completion.task")
                ModernCheckbox(isDone: subtaskDone, presentation: .inlineSubtask) { subtaskDone.toggle(); actions += 1 }
                    .accessibilityIdentifier("preview.completion.subtask")
                ModernCheckbox(isDone: detailSubtaskDone, presentation: .detailSubtask) { detailSubtaskDone.toggle(); actions += 1 }
                    .accessibilityIdentifier("preview.completion.detailSubtask")
                Text("dev.controls.sample")
            }
            HStack(spacing: DaybookSpacing.md) {
                ForEach([false, true], id: \.self) { done in
                    ModernCheckbox(isDone: done) {}.disabled(true)
                    ModernCheckbox(isDone: done, presentation: .inlineSubtask) {}.disabled(true)
                    ModernCheckbox(isDone: done, presentation: .detailSubtask) {}.disabled(true)
                }
                Button("dev.controls.toggle.external") { taskDone.toggle(); subtaskDone.toggle(); detailSubtaskDone.toggle() }
                    .buttonStyle(DaybookButtonStyle(.quiet))
                    .accessibilityIdentifier("preview.completion.external")
            }
        }
    }

    private var stepperSamples: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("dev.controls.steppers").font(DaybookType.title)
            DaybookStepper(value: $integerSample, in: 20...999, step: 10) {
                if longLabels { Text("dev.controls.stepper.longLabel") } else { Text("clipboard.limit \(integerSample)") }
            }
            DaybookStepper(value: $decimalSample, in: 0.1...2, step: 0.1) {
                Text(L10n.format("clipboard.interval", locale: Locale(identifier: localeID), decimalSample))
            }
            DaybookStepper(value: $integerLower, in: 20...999, step: 10) { Text("clipboard.limit \(integerLower)") }
            DaybookStepper(value: $integerUpper, in: 20...999, step: 10) { Text("clipboard.limit \(integerUpper)") }
            DaybookStepper(value: $decimalLower, in: 0.1...2, step: 0.1) {
                Text(L10n.format("clipboard.interval", locale: Locale(identifier: localeID), decimalLower))
            }
            DaybookStepper(value: $decimalUpper, in: 0.1...2, step: 0.1) {
                Text(L10n.format("clipboard.interval", locale: Locale(identifier: localeID), decimalUpper))
            }
            DaybookStepper(value: .constant(200), in: 20...999, step: 10) { Text("clipboard.limit \(200)") }.disabled(true)
            Button("dev.controls.toggle.external") {
                integerSample = integerSample == 25 ? 995 : 25
                decimalSample = decimalSample == 0.35 ? 1.95 : 0.35
            }.buttonStyle(DaybookButtonStyle(.quiet))
        }
    }

    private var toggleSamples: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("dev.controls.toggles").font(DaybookType.title)
            Toggle(longLabels ? "dev.controls.toggle.longLabel" : "residents.enabled", isOn: $enabledSample)
                .toggleStyle(DaybookToggleStyle())
            HStack(spacing: DaybookSpacing.md) {
                Toggle("dev.controls.toggle.hidden", isOn: $disabledSample)
                    .toggleStyle(DaybookToggleStyle(hiddenLabel: "dev.controls.toggle.hidden"))
                    .labelsHidden()
                    .help("dev.controls.toggle.hidden")
                Toggle("residents.enabled", isOn: .constant(true))
                    .toggleStyle(DaybookToggleStyle()).disabled(true)
                Toggle("residents.enabled", isOn: .constant(false))
                    .toggleStyle(DaybookToggleStyle(hiddenLabel: "residents.enabled")).labelsHidden().disabled(true)
                Button("dev.controls.toggle.external") {
                    enabledSample.toggle()
                    disabledSample.toggle()
                }.buttonStyle(DaybookButtonStyle(.quiet))
            }
            Text("dev.controls.toggle.motion").font(DaybookType.caption)
        }
    }

    private var checkboxSamples: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("dev.controls.checkboxes").font(DaybookType.title)
            Toggle(isOn: $checkedSample) {
                Label("dev.controls.checkbox.longLabel", systemImage: checkedSample ? "lock" : "tag")
            }.toggleStyle(DaybookToggleStyle(.checkbox))
                .accessibilityIdentifier("preview.checkbox")
            ForEach([false, true], id: \.self) { selected in
                Toggle("dev.controls.sample", isOn: .constant(selected))
                    .toggleStyle(DaybookToggleStyle(.checkbox)).disabled(true)
            }
            Toggle("dev.controls.sample", isOn: Binding(get: { !checkedSample }, set: { checkedSample = !$0 }))
                .toggleStyle(DaybookToggleStyle(.checkbox))
            Button("dev.controls.toggle.external") { checkedSample.toggle() }
                .buttonStyle(DaybookButtonStyle(.quiet))
                .accessibilityIdentifier("preview.checkbox.external")
        }
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
