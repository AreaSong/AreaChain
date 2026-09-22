import AppKit
import SwiftUI

// MARK: - L0 原始值（从 DaybookTheme.swift 原样搬入）

enum DaybookSwatch {
    static let inkLight = (0.12, 0.12, 0.14)
    static let inkDark = (0.96, 0.96, 0.98)
    static let mutedLight = (0.40, 0.41, 0.45)
    static let mutedDark = (0.70, 0.71, 0.75)
    static let ruleLight = (0.86, 0.88, 0.92)
    static let ruleDark = (0.24, 0.25, 0.28)
    static let stampLight = (0.08, 0.35, 0.76)
    static let stampDark = (0.38, 0.68, 1.0)
    static let paperLight = (0.98, 0.98, 0.99)
    static let paperDark = (0.12, 0.12, 0.13)
    static let doneLight = (0.40, 0.42, 0.45)
    static let doneDark = (0.68, 0.70, 0.74)
    static let destructiveLight = (0.78, 0.16, 0.14)
    static let destructiveDark = (0.98, 0.52, 0.48)
    static let checkmarkLight = (1.0, 1.0, 1.0)
    static let checkmarkDark = (0.08, 0.08, 0.10)
    static let tagLight = (0.10, 0.46, 0.24)
    static let tagDark = (0.28, 0.78, 0.48)
}

// MARK: - L1 语义色
// 页面（AreaChain/Features）以后只允许引用这里的名字：不得对颜色乘 opacity，不得直接用 Color.orange 等系统色。
// 基准 = 菜单栏浮层任务页现状（用户决定）。聚焦色是 ink 35% 灰描边，不是蓝色。

enum DaybookPalette {
    struct Text {
        let primary: Color
        let secondary: Color
        let tertiary: Color
        let disabled: Color
        let done: Color
        let onAccent: Color
    }

    struct Fill {
        let page: Color
        let surface: Color
        let subtle: Color
        let hover: Color
        let press: Color
        let selection: Color
        let scrim: Color
    }

    struct Border {
        let `default`: Color
        let subtle: Color
        let strong: Color
        let focus: Color
        let selection: Color
    }

    struct Status {
        let pending: Color
        let success: Color
        let danger: Color
    }

    struct Accent {
        let base: Color
        let fill: Color
        let border: Color
    }

    static let text = Text(
        primary: DaybookTheme.ink,
        secondary: DaybookTheme.muted,
        tertiary: alpha("palette.text.tertiary", DaybookSwatch.mutedLight, DaybookSwatch.mutedDark, 0.75),
        disabled: alpha("palette.text.disabled", DaybookSwatch.mutedLight, DaybookSwatch.mutedDark, 0.45),
        done: DaybookTheme.done,
        onAccent: Color.daybook(name: "palette.text.onAccent", light: .white, dark: .white)
    )

    static let fill = Fill(
        page: DaybookTheme.paper,
        surface: DaybookTheme.surface,
        subtle: alpha("palette.fill.subtle", DaybookSwatch.inkLight, DaybookSwatch.inkDark, 0.03),
        hover: DaybookTheme.hoverFill,
        press: DaybookTheme.pressFill,
        selection: DaybookTheme.cardSelectionFill,
        scrim: Color.daybook(
            name: "palette.fill.scrim",
            light: NSColor.black.withAlphaComponent(0.001),
            dark: NSColor.black.withAlphaComponent(0.001)
        )
    )

    static let border = Border(
        default: DaybookTheme.rule,
        subtle: DaybookTheme.cardBorder,
        strong: alpha("palette.border.strong", DaybookSwatch.inkLight, DaybookSwatch.inkDark, 0.35),
        focus: alpha("palette.border.focus", DaybookSwatch.inkLight, DaybookSwatch.inkDark, 0.35),
        selection: DaybookTheme.cardSelectionStroke
    )

    static let status = Status(
        pending: Color(nsColor: .systemOrange),
        success: Color(nsColor: .systemGreen),
        danger: DaybookTheme.destructive
    )

    static let accent = Accent(
        base: DaybookTheme.stamp,
        fill: alpha("palette.accent.fill", DaybookSwatch.stampLight, DaybookSwatch.stampDark, 0.12),
        border: alpha("palette.accent.border", DaybookSwatch.stampLight, DaybookSwatch.stampDark, 0.35)
    )

    /// 手记预置标签色。来源：Features/Diary/DiaryNoteCard.swift 的 DiaryTagChrome（P5 再把消费者迁过来，本阶段不动它）。
    enum DiaryPreset {
        static let password = Color(nsColor: .systemRed)
        static let idea = Color(nsColor: .systemOrange)
        static let journal = Color(nsColor: .systemBlue)
    }

    static func diaryPreset(forTagName name: String) -> Color {
        if DiaryMemoTags.isPasswordName(name) { return DiaryPreset.password }
        if name == DiaryMemoTags.idea { return DiaryPreset.idea }
        if name == DiaryMemoTags.journal { return DiaryPreset.journal }
        return accent.base
    }

    private static func alpha(
        _ name: String, _ light: (Double, Double, Double), _ dark: (Double, Double, Double), _ alpha: CGFloat
    ) -> Color {
        Color.daybook(
            name: name,
            light: NSColor.daybook(light).withAlphaComponent(alpha),
            dark: NSColor.daybook(dark).withAlphaComponent(alpha)
        )
    }

    // MARK: - 语法色彩体系（输入框、预览胶囊、补全弹窗统一）
    enum Syntax {
        // Tag 标签（森林绿 / 鼠尾草绿）
        static let tag = Color.daybook(
            name: "daybook.syntax.tag",
            swatch: DaybookSwatch.tagLight,
            dark: DaybookSwatch.tagDark
        )
        static let tagNS = NSColor.daybook(
            name: "daybook.syntax.tag",
            swatch: DaybookSwatch.tagLight,
            dark: DaybookSwatch.tagDark
        )
        static let tagFill = Color.daybook(
            name: "daybook.syntax.tagFill",
            light: NSColor.daybook(DaybookSwatch.tagLight).withAlphaComponent(0.12),
            dark: NSColor.daybook(DaybookSwatch.tagDark).withAlphaComponent(0.16)
        )
        static let tagSubtleFill = Color.daybook(
            name: "daybook.syntax.tagSubtleFill",
            light: NSColor.daybook(DaybookSwatch.tagLight).withAlphaComponent(0.08),
            dark: NSColor.daybook(DaybookSwatch.tagDark).withAlphaComponent(0.10)
        )
        static let tagStroke = Color.daybook(
            name: "daybook.syntax.tagStroke",
            light: NSColor.daybook(DaybookSwatch.tagLight).withAlphaComponent(0.25),
            dark: NSColor.daybook(DaybookSwatch.tagDark).withAlphaComponent(0.35)
        )
        static let tagBadgeFill = Color.daybook(
            name: "daybook.syntax.tagBadgeFill",
            light: NSColor.daybook(DaybookSwatch.tagLight).withAlphaComponent(0.16),
            dark: NSColor.daybook(DaybookSwatch.tagDark).withAlphaComponent(0.20)
        )

        // Time 时间（Daybook 印章蓝）
        static let time = DaybookTheme.stamp
        static let timeNS = NSColor(DaybookTheme.stamp)
        static let timeFill = DaybookTheme.stamp.opacity(0.12)

        // Priority 优先级
        static let p1 = Color(nsColor: .systemRed)
        static let p1NS = NSColor.systemRed
        static let p1Fill = Color(nsColor: .systemRed).opacity(0.12)

        static let p2 = Color(nsColor: .systemOrange)
        static let p2NS = NSColor.systemOrange
        static let p2Fill = Color(nsColor: .systemOrange).opacity(0.12)

        static let p3 = Color(nsColor: .systemBlue)
        static let p3NS = NSColor.systemBlue
        static let p3Fill = Color(nsColor: .systemBlue).opacity(0.12)

        static let p4 = DaybookTheme.muted
        static let p4NS = NSColor(DaybookTheme.muted)
        static let p4Fill = DaybookTheme.muted.opacity(0.10)

        static func priorityColor(isImportant: Bool, isUrgent: Bool) -> Color {
            if isImportant && isUrgent { return p1 }
            if isImportant { return p2 }
            if isUrgent { return p3 }
            return p4
        }

        static func priorityColorNS(isImportant: Bool, isUrgent: Bool) -> NSColor {
            if isImportant && isUrgent { return p1NS }
            if isImportant { return p2NS }
            if isUrgent { return p3NS }
            return p4NS
        }

        static func priorityColor(for titleOrLabel: String) -> Color {
            switch titleOrLabel.lowercased() {
            case "!p1", "quadrant.iu", "p1": return p1
            case "!p2", "quadrant.i", "p2": return p2
            case "!p3", "quadrant.u", "p3": return p3
            default: return p4
            }
        }

        static func priorityFill(for titleOrLabel: String) -> Color {
            switch titleOrLabel.lowercased() {
            case "!p1", "quadrant.iu", "p1": return p1Fill
            case "!p2", "quadrant.i", "p2": return p2Fill
            case "!p3", "quadrant.u", "p3": return p3Fill
            default: return p4Fill
            }
        }
    }
}
