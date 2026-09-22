# 任务：AreaChain 设计系统收敛 · 阶段 P4a（表面基座）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 严格按步骤顺序执行；每个"检查点"必须跑通再进下一步；修不好就停下来问我。
2. 代码块**原样粘贴**；替换用精确字符串定位，行号只是提示。
3. 只改本文列出的文件。
4. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
5. 先读 `AGENTS.md`，再读 `.cursor/plans/design-system.md` 第 0、1、2、5 节和「P4a」段，再读本文。
6. 没写清楚的取舍 → 用提问工具问我，复述我的回答，我说"对"才继续。
7. 做完不宣布"通过"。验收由另一个对话按 `design-system-P4a-verify.md` 做。
8. **不要新增** variant。不要改 `.shadow(color:`（那是 P4b）。不要改象限选择格、搜索命中行、附件结果行、语法范例卡的自绘（也是 P4b）。

## 背景

现在「卡片 / 行」有三套修饰符：`modernCard`（有阴影）、`modernRow`（悬停只改底）、`daybookCardStyle`（自带内边距和悬停）。`DaybookGroupedCard` 在 P1 之后已经只是一个 `VStack(spacing: 4)`，不再画白卡。

本阶段建唯一的 `daybookSurface`，把这三套和分组容器换掉。

**视觉（用户已确认）：**

- `.row`：与现在的 `modernRow` 一致。未悬停无底无边；悬停 `DaybookTheme.hoverFill`、不描边；选中 `DaybookTheme.cardSelectionFill` + `DaybookTheme.cardSelectionStroke` 1pt。无阴影。默认圆角 `DaybookRadius.small`（6）。
- `.card`：与现在的 `modernCard` 的填充和描边一致，**去掉阴影**。默认圆角 `DaybookRadius.medium`（10）。调用点原来传了 `DaybookRadius.small` 的，用 `configure` 保留 6。选中描边从 1.5pt 收到 `DaybookMetrics.Stroke.emphasis`（1pt）。
- `.panel`：纸底、圆角 8、`DaybookPalette.border.default`、`daybookElevation(.floating)`。本阶段只实现并测试，不迁移现有浮层。
- `.banner`：`DaybookPalette.fill.subtle` 底、`DaybookPalette.border.faint` 边、圆角 8、内边距 10。只给锁定草稿提示框用。

修饰符自己监听悬停，并和参数 `isHovered` 取或。这样原来自己传 `isHovered` 的行，和原来靠修饰符内部悬停的回收站卡片，都还能高亮。

## 开始前必读

1. `AreaChain/Theme/ModernComponents.swift` 第 163–309 行（`ModernCardModifier`、`modernCard`、`modernRow`、`DaybookGroupedCard`、`ModernRowModifier`）。
2. `AreaChain/Theme/DaybookChrome.swift` 第 154–204 行（`daybookCardStyle`、`DaybookCardModifier`）。
3. `AreaChain/Theme/DaybookElevation.swift` 全文。
4. `AreaChain/Features/Diary/DiaryPage.swift` 第 301–318 行（锁定草稿提示框）。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/TaskRowInteractionTests --only-testing AreaChainTests/DiarySummaryRowTests --only-testing AreaChainTests/WorkspaceRenderingTests
```

---

## 步骤 1：新建 `AreaChain/Theme/DaybookSurface.swift`

```swift
import SwiftUI

/// 列表行、卡片、浮层面板、提示条的唯一外壳。颜色不可在调用点重载；圆角、内边距、最小高度可以。
enum DaybookSurfaceVariant: Equatable {
    case row
    case card
    case panel
    case banner
}

struct DaybookSurfaceConfiguration: Equatable {
    var radius: CGFloat
    var minHeight: CGFloat?
    var padding: EdgeInsets

    static func standard(for variant: DaybookSurfaceVariant) -> DaybookSurfaceConfiguration {
        switch variant {
        case .row:
            DaybookSurfaceConfiguration(radius: DaybookRadius.small, minHeight: nil, padding: EdgeInsets())
        case .card:
            DaybookSurfaceConfiguration(radius: DaybookRadius.medium, minHeight: nil, padding: EdgeInsets())
        case .panel:
            DaybookSurfaceConfiguration(radius: DaybookMetrics.Radius.panel, minHeight: nil, padding: EdgeInsets())
        case .banner:
            DaybookSurfaceConfiguration(
                radius: DaybookMetrics.Radius.inputComposer,
                minHeight: nil,
                padding: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
            )
        }
    }
}

private struct DaybookSurfaceModifier: ViewModifier {
    var variant: DaybookSurfaceVariant
    var isHovered: Bool
    var isSelected: Bool
    var configure: ((inout DaybookSurfaceConfiguration) -> Void)?
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let config = configuration
        let shape = RoundedRectangle(cornerRadius: config.radius, style: .continuous)
        content
            .padding(config.padding)
            .frame(minHeight: config.minHeight)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(border, lineWidth: borderWidth))
            .daybookElevation(elevation)
            .onHover { hovering = $0 }
            .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
            .animation(DaybookMotion.interactive(reduceMotion), value: isHovered)
            .animation(DaybookMotion.interactive(reduceMotion), value: isSelected)
    }

    private var configuration: DaybookSurfaceConfiguration {
        var config = DaybookSurfaceConfiguration.standard(for: variant)
        configure?(&config)
        return config
    }

    private var highlighted: Bool { isHovered || hovering }

    private var fill: Color {
        switch variant {
        case .row:
            if isSelected { return DaybookTheme.cardSelectionFill }
            if highlighted { return DaybookTheme.hoverFill }
            return .clear
        case .card:
            if isSelected { return DaybookTheme.cardSelectionFill }
            if highlighted { return DaybookTheme.cardSurfaceHover }
            return DaybookTheme.cardSurface
        case .panel:
            return DaybookPalette.fill.page
        case .banner:
            return DaybookPalette.fill.subtle
        }
    }

    private var border: Color {
        switch variant {
        case .row:
            if isSelected { return DaybookTheme.cardSelectionStroke }
            return .clear
        case .card:
            if isSelected { return DaybookTheme.stamp.opacity(0.85) }
            if highlighted { return DaybookTheme.cardBorderHover }
            return DaybookTheme.cardBorder
        case .panel:
            return DaybookPalette.border.default
        case .banner:
            return DaybookPalette.border.faint
        }
    }

    private var borderWidth: CGFloat {
        switch variant {
        case .row:
            return isSelected ? DaybookMetrics.Stroke.emphasis : 0
        case .card:
            return isSelected ? DaybookMetrics.Stroke.emphasis : 0.8
        case .panel:
            return 0.7
        case .banner:
            return DaybookMetrics.Stroke.regular
        }
    }

    private var elevation: DaybookElevation {
        variant == .panel ? .floating : .flat
    }
}

extension View {
    func daybookSurface(
        _ variant: DaybookSurfaceVariant,
        isHovered: Bool = false,
        isSelected: Bool = false,
        configure: ((inout DaybookSurfaceConfiguration) -> Void)? = nil
    ) -> some View {
        modifier(DaybookSurfaceModifier(
            variant: variant,
            isHovered: isHovered,
            isSelected: isSelected,
            configure: configure
        ))
    }
}
```

检查点：`./scripts/build.sh` 通过。

---

## 步骤 2：替换调用点

### 2.1 行：`.modernRow` → `.daybookSurface(.row)`

三处都去掉 `cornerRadius:`（默认已经是 6），`isHovered` / `isSelected` 原样保留。

- `AreaChain/Features/Tasks/TaskRow.swift`：

```swift
        .modernRow(
            cornerRadius: DaybookRadius.small,
            isHovered: isHovered,
            isSelected: state.isSelected
        )
```

→

```swift
        .daybookSurface(.row, isHovered: isHovered, isSelected: state.isSelected)
```

- `AreaChain/Features/Diary/DiarySummaryRow.swift`：同样替换，`isSelected: isSelected || isHighlighted` 保持。`.frame(minHeight: 46)` **不要动**。后面那个置顶描边 overlay 不要动。
- `AreaChain/Theme/LiveDiaryComposerPreview.swift`：同样替换，`isSelected: false` 保持。文件头注释里的「悬停呈现 modernRow 浅灰高亮」改成「悬停呈现 daybookSurface(.row) 浅灰高亮」。它下面的 `.shadow` **不要动**。

### 2.2 卡片：`.modernCard` → `.daybookSurface(.card)`

原来传 `DaybookRadius.small` 的，加 `configure`。原来传 `DaybookRadius.medium` 的，用默认圆角，不加 configure。

- `TaskDetailHeaderSection.swift`、`TaskDetailScheduleSection.swift`、`TaskDetailClassificationSection.swift`、`QuadrantPage.swift` 第 159 行，这四处：

```swift
.modernCard(cornerRadius: DaybookRadius.small)
```

→

```swift
.daybookSurface(.card, configure: { $0.radius = DaybookRadius.small })
```

- `ResidentsPage.swift`：

```swift
.modernCard(cornerRadius: DaybookRadius.small, isSelected: isSelected)
```

→

```swift
.daybookSurface(.card, isSelected: isSelected, configure: { $0.radius = DaybookRadius.small })
```

- `QuadrantPage.swift` 第 86 行：

```swift
.modernCard(cornerRadius: DaybookRadius.medium, isHovered: isTargeted, isSelected: isTargeted)
```

→

```swift
.daybookSurface(.card, isHovered: isTargeted, isSelected: isTargeted)
```

`QuadrantPage.swift:162` 的 `// control:` 注释不要改。

### 2.3 回收站卡片

`AreaChain/Features/Trash/TrashPage.swift`：

```swift
.daybookCardStyle(padding: EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 12))
```

→

```swift
.daybookSurface(.card, configure: {
    $0.radius = DaybookRadius.small
    $0.padding = EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 12)
})
```

### 2.4 分组容器

`DaybookGroupedCard` 现在只是 `VStack(alignment: .leading, spacing: 4)`。六处都把开头的 `DaybookGroupedCard {` 换成 `VStack(alignment: .leading, spacing: 4) {`。右花括号不用改。

文件：`AreaChain/Features/Tasks/DayBoardSections.swift`（3 处）、`AreaChain/Features/Workspace/WorkspaceFilteredListView.swift`（3 处）。

### 2.5 锁定草稿提示框

`AreaChain/Features/Diary/DiaryPage.swift` 里，把

```swift
            .font(DaybookType.caption)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: DaybookMetrics.Radius.inputComposer, style: .continuous).fill(DaybookPalette.fill.subtle)) // token-exempt: 锁定草稿提示框，P4 迁 daybookSurface(.banner)
            .overlay(RoundedRectangle(cornerRadius: DaybookMetrics.Radius.inputComposer, style: .continuous).stroke(DaybookPalette.border.faint, lineWidth: DaybookMetrics.Stroke.regular)) // token-exempt: 同上
```

替换为

```swift
            .font(DaybookType.caption)
            .daybookSurface(.banner)
```

`.padding(10)` 必须删掉，banner 自己带 10pt 内边距。

检查点：

```bash
rg -n 'modernCard|modernRow|daybookCardStyle|DaybookGroupedCard' AreaChain AreaChainTests
./scripts/build.sh
```

第一条预期只剩 `ModernComponents.swift` 和 `DaybookChrome.swift` 里的定义。

---

## 步骤 3：删除旧定义

- `AreaChain/Theme/ModernComponents.swift`：删除 `ModernCardModifier`、`modernCard`、`modernRow`、`DaybookGroupedCard`、`ModernRowModifier`，以及它们的 MARK 注释。**保留** `modernFocusRing`、`ModernCheckbox`、`PillBadge`、`ModernTaskTitle`。
- `AreaChain/Theme/DaybookChrome.swift`：删除 `daybookCardStyle` 函数和 `DaybookCardModifier` 整个 struct。`daybookHoverReveal` 保留。

检查点：

```bash
rg -n 'modernCard|modernRow|daybookCardStyle|DaybookGroupedCard|ModernCardModifier|ModernRowModifier|DaybookCardModifier' AreaChain AreaChainTests
./scripts/build.sh
```

第一条预期零输出。

---

## 步骤 4：新建 `AreaChainTests/Theme/DaybookSurfaceTests.swift`

```swift
import SwiftUI
import Testing
@testable import AreaChain

struct DaybookSurfaceTests {
    @Test func standardConfigurationFollowsTheBaseline() {
        let row = DaybookSurfaceConfiguration.standard(for: .row)
        #expect(row.radius == DaybookRadius.small)
        #expect(row.minHeight == nil)
        #expect(row.padding == EdgeInsets())

        let card = DaybookSurfaceConfiguration.standard(for: .card)
        #expect(card.radius == DaybookRadius.medium)

        let panel = DaybookSurfaceConfiguration.standard(for: .panel)
        #expect(panel.radius == DaybookMetrics.Radius.panel)

        let banner = DaybookSurfaceConfiguration.standard(for: .banner)
        #expect(banner.radius == DaybookMetrics.Radius.inputComposer)
        #expect(banner.padding.top == 10)
        #expect(banner.padding.leading == 10)
    }

    @Test func configureCanChangeRadiusWithoutChangingTheVariantDefault() {
        var card = DaybookSurfaceConfiguration.standard(for: .card)
        card.radius = DaybookRadius.small
        #expect(card.radius == DaybookRadius.small)
        #expect(DaybookSurfaceConfiguration.standard(for: .card).radius == DaybookRadius.medium)
    }
}
```

检查点：

```bash
./scripts/build.sh test --only-testing AreaChainTests/DaybookSurfaceTests
```

---

## 最终验证

```bash
# 1. 旧 API 消失（预期零输出）
rg -n 'modernCard|modernRow|daybookCardStyle|DaybookGroupedCard|ModernCardModifier|ModernRowModifier|DaybookCardModifier' AreaChain AreaChainTests

# 2. 新表面被用到（预期 11：3 行 + 6 卡片 + 1 回收站 + 1 banner）
rg -c 'daybookSurface\(' AreaChain --glob '*.swift' | awk -F: '{s+=$2} END {print s}'

# 3. 锁定草稿不再自绘（预期零输出）
rg -n 'token-exempt: 锁定草稿' AreaChain

# 4. Features 里的阴影一处没动（预期打印 4）
rg -c '\.shadow\(color:' AreaChain/Features --glob '*.swift' | awk -F: '{s+=$2} END {print s}'

# 5. 分组容器已换成 VStack（预期 6）
rg -c 'VStack\(alignment: \.leading, spacing: 4\)' AreaChain/Features/Tasks/DayBoardSections.swift AreaChain/Features/Workspace/WorkspaceFilteredListView.swift | awk -F: '{s+=$2} END {print s}'

# 6. 测试
./scripts/build.sh test \
  --only-testing AreaChainTests/DaybookSurfaceTests \
  --only-testing AreaChainTests/TaskRowInteractionTests \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/QuadrantLayoutTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests

# 7. 工作流检查
python3 -B scripts/check_workflow.py

# 8. 改动范围
git diff --stat
```

第 2 条预期 11。第 4 条必须是 4（`BatchActionBar` 1、`MenuBarFilterFlyout` 2、`MenuBarControls` 1）。不是 4 就说明你改了阴影，把那个文件的阴影改回。

第 6 条若失败且是「尺寸与预期不符」，不要改测试，贴出失败信息停下问我。

## 汇报格式

```
## P4a 完成汇报
### 新建 / 删除的类型
### 修改文件（路径 — 一句话）
### 验证输出（1–8 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P4a 表面基座` 改成 `- [x]`，决策记录追加 `- <日期> P4a 完成：<一句话>`。

## 绝对不要做

- 不要改任何 `.shadow(color:`。
- 不要改 `TaskDetailQuadrantGrid`、`BoardSearchHitRow`、`WorkspaceGlobalSearchView` 的附件行、`SyntaxHelpCard` 的范例卡、`DiaryNoteCard` 的外壳。
- 不要改 `modernFocusRing`。
- 不要改 `BoardRowChrome`（它是指针行为，不是表面）。
- 不要把卡片重新加上阴影。
- 不要 commit。
