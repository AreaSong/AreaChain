# 任务：AreaChain 设计系统收敛 · 阶段 P0（令牌落地）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。本任务已经由架构师设计完毕，**你只负责照做，不做设计决定**。规则：

1. 严格按下面"步骤"的顺序执行，每步做完立刻跑该步的"验证"，验证不过就修，修不好就停下来问我，不要跳到下一步。
2. 所有代码块**原样粘贴**，不改名、不改数值、不"优化"、不加你自己的注释。
3. 只改本文列出的文件。发现其他文件也"应该改"，记到最后的汇报里，不要动手。
4. 不运行 `git commit`、`git push`、`scripts/install.sh`、`scripts/uninstall.sh`、`./scripts/build.sh release`；不安装、不启动应用。
5. 测试失败时禁止删除或注释掉测试来让它通过。
6. 先读仓库根目录的 `AGENTS.md`，再读 `.cursor/plans/design-system.md` 的第 0、1、2、5 节（背景与基准决策），然后回到本文按步骤做。不要读其他文档，不要全仓库扫描。
7. 遇到本文没写清楚的取舍，用提问工具问我，把我的回答复述一遍确认，我说"对"你才继续。
8. **做完不要宣布"通过"**。你只负责按"汇报格式"交出证据；是否通过由另一个对话按 `design-system-P0-verify.md` 独立验收。

## 背景（3 句话）

项目 UI 层有原始色值 `DaybookSwatch`、基色 `DaybookTheme`、零散组件，但缺少"语义令牌层"，导致页面里散落 245 处字面字号、153 处 `颜色.opacity(字面)`、16 处手写阴影、52 处 `isWorkspace ?` 三元。本阶段只做一件事：**新建令牌层**（颜色语义、尺寸、阴影、布局常量、补齐字号/圆角/动效），并把已经能迁的少量引用迁过去。本阶段**不改任何页面的外观逻辑**，不删 `DaybookViewStyle` / `WorkspaceStyle`（那是 P1）。

## 开始前必读（只读这些，按顺序）

1. `AreaChain/Theme/DaybookTheme.swift` 全文（342 行）。记住：`DaybookSwatch`（21–40 行）、`DaybookTheme.Syntax`（107–194 行）、`DaybookRadius` / `DaybookSpacing` / `DaybookType` / `DaybookShadow`（198–238 行）。
2. `AreaChain/Theme/DaybookWorkspaceStyle.swift` 全文（331 行）。记住：`WorkspaceStyle`（49–71 行）、`DaybookPageHeader`（73–101 行）、`DaybookInputKind`（103–107 行）、`WorkspaceSidebarHeaderAction`（211–237 行）、`WorkspaceSidebarRow`（239–330 行）。
3. `AreaChain/Theme/DaybookChrome.swift` 第 1–41 行（`DaybookMotion`）。
4. `AreaChain/Domain/DiaryMemoTags.swift` 第 1–20 行（`password` / `idea` / `journal` / `isPasswordName`）。
5. `AreaChainTests/Theme/WorkspaceStyleTests.swift` 全文（150 行），只为了知道第 84 行要改。

读完后运行一次基线，确认当前是绿的：

```bash
./scripts/build.sh test --only-testing AreaChainTests/DaybookContrastTests --only-testing AreaChainTests/WorkspaceStyleTests --only-testing AreaChainTests/SyntaxHighlighterTests
```

如果基线本身就红，停下来告诉我，不要继续。

---

## 步骤 1：新建 `AreaChain/Theme/DaybookTokens.swift`

把 `DaybookTheme.swift` 里的 `DaybookRadius`、`DaybookSpacing`、`DaybookType` 三个 enum **剪切**到新文件，并补 6 个令牌。新文件内容完整如下：

```swift
import SwiftUI

// MARK: - 圆角令牌（xxs / regular 为新增，吸收 Features 里 2–3 与 7–8 的字面圆角）

enum DaybookRadius {
    static let xxs: CGFloat = 2.5
    static let xs: CGFloat = 4
    static let small: CGFloat = 6
    static let regular: CGFloat = 8
    static let medium: CGFloat = 10
    static let card: CGFloat = 12
    static let large: CGFloat = 16
    static let full: CGFloat = 999
}

// MARK: - 间距令牌

enum DaybookSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let page: CGFloat = 16
}

// MARK: - 字号令牌（kbd / micro / bodyLarge / display 为新增，吸收 8.5 / 9 / 14 / 26 的字面字号）

enum DaybookType {
    static let titleSize: CGFloat = 16
    static let subtitleSize: CGFloat = 12
    static let bodySize: CGFloat = 13
    static let captionSize: CGFloat = 11
    static let title: Font = .system(size: titleSize, weight: .semibold)
    static let subtitle: Font = .system(size: subtitleSize)
    static let body: Font = .system(size: bodySize)
    static let caption: Font = .system(size: captionSize, weight: .medium)
    static let badge: Font = .system(size: 10, weight: .medium)
    static let label: Font = .system(size: 10, weight: .semibold)
    static let entity: Font = .system(size: 17, weight: .medium)
    static let headline: Font = title
    static let section: Font = .system(size: 11, weight: .semibold)
    static let kbd: Font = .system(size: 8.5, weight: .semibold, design: .monospaced)
    static let micro: Font = .system(size: 9, weight: .medium)
    static let bodyLarge: Font = .system(size: 14)
    static let display: Font = .system(size: 26, weight: .light)
}
```

然后在 `DaybookTheme.swift` 里**删除**原来的 `enum DaybookRadius { ... }`、`enum DaybookSpacing { ... }`、`enum DaybookType { ... }` 三段（约 199–232 行）。`// MARK: - Layout tokens` 这行注释一起删。**不要删 `DaybookShadow`，步骤 4 再删。**

验证：

```bash
rg -n 'enum (DaybookRadius|DaybookSpacing|DaybookType)' AreaChain/Theme
```

预期只输出 `DaybookTokens.swift` 的三行。

---

## 步骤 2：新建 `AreaChain/Theme/DaybookPalette.swift`

做三件事：把 `DaybookSwatch` 从 `DaybookTheme.swift` **剪切**过来；把 `DaybookTheme.Syntax` **剪切**过来变成 `DaybookPalette.Syntax`；新增语义色。

2a. 新建文件，先写下面这段（`DaybookSwatch` 就是 `DaybookTheme.swift` 21–40 行原文，逐字对照）：

```swift
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
```

**注意文件到这里还没结束**，`enum DaybookPalette {` 的右花括号还没写。

2b. 紧接着，把 `DaybookTheme.swift` 第 107–194 行的整个 `enum Syntax { ... }`（从 `// MARK: - 语法色彩体系` 注释开始，到 `priorityFill(for:)` 函数的右花括号结束）**原文剪切**粘贴到这里，然后写上 `DaybookPalette` 的结束花括号：

```swift

    // MARK: - 语法色彩体系（从 DaybookTheme.Syntax 原样搬入，只改了外层命名空间）
    enum Syntax {
        // ……这里是 DaybookTheme.swift 107–194 行的原文，一个字都不改……
    }
}
```

粘贴后 `Syntax` 内部仍然引用 `DaybookTheme.stamp`、`DaybookTheme.muted`、`DaybookSwatch.tagLight` 等，这些都还存在，**不要改**。

2c. 回到 `DaybookTheme.swift`：删除 `enum DaybookSwatch { ... }`（21–40 行）和 `enum DaybookTheme` 内部的 `// MARK: - 语法色彩体系` 到 `enum Syntax { ... }` 整段。`DaybookTheme` 的其他基色（ink / muted / rule / stamp / paper / done / destructive / checkmark / hoverFill / surface 等）**全部保留**。

2d. 全仓库把 `DaybookTheme.Syntax` 改成 `DaybookPalette.Syntax`。已知涉及 6 个文件，用这条命令一次改完：

```bash
sed -i '' 's/DaybookTheme\.Syntax/DaybookPalette.Syntax/g' \
  AreaChain/Theme/SyntaxHighlighter.swift \
  AreaChain/Theme/LiveComposerPreviewHeader.swift \
  AreaChain/Theme/QuadrantMiniMark.swift \
  AreaChain/Theme/SyntaxAutocompleteView.swift \
  AreaChain/Features/Tasks/TaskRow+Badges.swift \
  AreaChainTests/Theme/SyntaxHighlighterTests.swift
```

验证：

```bash
rg -n 'DaybookTheme\.Syntax|enum DaybookSwatch' AreaChain AreaChainTests
```

预期：`DaybookTheme.Syntax` 零结果；`enum DaybookSwatch` 只在 `DaybookPalette.swift`。然后编译一次：

```bash
./scripts/build.sh
```

编译报错就看报错行，通常是漏改了某处 `Syntax` 引用或 `Syntax` 剪切时少了一个花括号。修到编译通过再进步骤 3。

---

## 步骤 3：新建 `AreaChain/Theme/DaybookMetrics.swift`

```swift
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
```

`DaybookInputKind` 已存在于 `DaybookWorkspaceStyle.swift` 103–107 行，不要重复定义。验证：`./scripts/build.sh` 通过。

---

## 步骤 4：新建 `AreaChain/Theme/DaybookElevation.swift`，删除 `DaybookShadow`

4a. 新建文件：

```swift
import SwiftUI

/// 阴影三档。用户决定：浮层面板统一黑 14% / 模糊 8 / 下偏 2；卡片与行不带阴影；分段栏滑块用 raised。
/// 页面不得直接调用 .shadow(color:)。
struct DaybookElevation: Equatable {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    static let flat = DaybookElevation(color: .clear, radius: 0, y: 0)
    static let raised = DaybookElevation(color: Color.black.opacity(0.08), radius: 1.5, y: 0.5)
    static let floating = DaybookElevation(color: Color.black.opacity(0.14), radius: 8, y: 2)
}

extension View {
    func daybookElevation(_ elevation: DaybookElevation) -> some View {
        shadow(color: elevation.color, radius: elevation.radius, x: 0, y: elevation.y)
    }
}
```

4b. 把 5 处 `DaybookShadow` 引用改掉（这些组件在 P2 / P4 会整体删除，本阶段只求编译通过、视觉近似）：

- `AreaChain/Theme/BoardCaptureRow.swift` 第 31 行：`DaybookShadow.cardSubtle` → `DaybookElevation.raised.color`
- `AreaChain/Theme/DaybookChrome.swift` 第 274 行：`DaybookShadow.cardHover` 和 `DaybookShadow.cardSubtle` 都 → `DaybookElevation.raised.color`
- `AreaChain/Theme/ModernComponents.swift` 第 197 行：`DaybookShadow.cardHover` → `DaybookElevation.raised.color`
- `AreaChain/Theme/ModernComponents.swift` 第 199 行：`DaybookShadow.cardSubtle` → `DaybookElevation.raised.color`
- `AreaChain/Theme/ModernComponents.swift` 第 286 行：`DaybookShadow.cardSubtle.opacity(0.3)` → `DaybookElevation.raised.color.opacity(0.3)`

4c. 在 `DaybookTheme.swift` 删除 `enum DaybookShadow { ... }` 整段。

验证：

```bash
rg -n 'DaybookShadow' AreaChain AreaChainTests
./scripts/build.sh
```

预期第一条零结果，第二条通过。

---

## 步骤 5：新建 `AreaChain/Theme/WorkspaceLayout.swift`，搬三个组件

5a. 新建文件，先写常量：

```swift
import SwiftUI

/// 工作台布局尺寸。用户决定：控件尺寸两宿主统一，只有"有侧栏、有页头、内容更宽"这类布局差异保留在这里。
/// 只允许 MainSplitWorkspaceView.swift、WorkspaceSidebarView.swift、WorkspaceHeaderBar.swift、DaybookPage.swift 与本文件引用。
enum WorkspaceLayout {
    static let headerHeight: CGFloat = 50
    static let maxContentWidth: CGFloat = 880
    static let sidebarRowHeight: CGFloat = 28
    static let sidebarRowVerticalPadding: CGFloat = 4.5
    static let sidebarRowHorizontalPadding: CGFloat = 8
    static let sidebarTopInset: CGFloat = 28
}

// MARK: - 以下三个组件从 DaybookWorkspaceStyle.swift 原样搬入，只把 WorkspaceStyle.headerHeight / sidebarRow* 改为 WorkspaceLayout.*
```

5b. 把 `DaybookWorkspaceStyle.swift` 里的 `struct DaybookPageHeader`（73–101 行）、`struct WorkspaceSidebarHeaderAction`（211–237 行）、`struct WorkspaceSidebarRow`（239–330 行）三段**原文剪切**到新文件末尾。粘贴后在新文件里做且只做这 5 处替换：

- `DaybookPageHeader` 内：`WorkspaceStyle.headerHeight` → `WorkspaceLayout.headerHeight`（原 95 行）
- `WorkspaceSidebarRow` 内：`WorkspaceStyle.sidebarRowVerticalPadding` → `WorkspaceLayout.sidebarRowVerticalPadding`（原 306 行）
- `WorkspaceStyle.sidebarRowHorizontalPadding` → `WorkspaceLayout.sidebarRowHorizontalPadding`（原 307、308 行，两处）
- `WorkspaceStyle.sidebarRowHeight` → `WorkspaceLayout.sidebarRowHeight`（原 309 行）

这三个组件里其他的 `WorkspaceStyle.countFont`、`WorkspaceStyle.hover`、`WorkspaceStyle.selection`、`style.isWorkspace` **保持原样**，P1 再处理。

5c. 改 3 个外部消费者 + 1 个测试：

- `AreaChain/Theme/DaybookPage.swift` 第 67 行：`WorkspaceStyle.maxContentWidth` → `WorkspaceLayout.maxContentWidth`
- `AreaChain/Features/Workspace/WorkspaceHeaderBar.swift` 第 23 行：`WorkspaceStyle.headerHeight` → `WorkspaceLayout.headerHeight`
- `AreaChain/Features/Workspace/WorkspaceSidebarView.swift` 第 78 行：`WorkspaceStyle.sidebarTopInset` → `WorkspaceLayout.sidebarTopInset`
- `AreaChainTests/Theme/WorkspaceStyleTests.swift` 第 84 行：`WorkspaceStyle.headerHeight` → `WorkspaceLayout.headerHeight`

5d. 在 `DaybookWorkspaceStyle.swift` 的 `enum WorkspaceStyle` 里删除这 6 行：`headerHeight`、`maxContentWidth`、`sidebarRowHeight`、`sidebarRowVerticalPadding`、`sidebarRowHorizontalPadding`、`sidebarTopInset`。其余（`paper` / `surface` / `input` / `control` / `border` / `hover` / `selection` / `controlHeight` / `composerHeight` / `rowHeight` / `cardRadius` / `sectionFont` / `countFont` / `progressFont`）**保留**。

验证：

```bash
rg -n 'WorkspaceStyle\.(headerHeight|maxContentWidth|sidebarRowHeight|sidebarRowVerticalPadding|sidebarRowHorizontalPadding|sidebarTopInset)' AreaChain AreaChainTests
rg -n 'struct (DaybookPageHeader|WorkspaceSidebarHeaderAction|WorkspaceSidebarRow)' AreaChain
./scripts/build.sh
```

预期：第一条零结果；第二条三行都在 `WorkspaceLayout.swift`；第三条通过。

---

## 步骤 6：`DaybookMotion` 补 `fade`

在 `AreaChain/Theme/DaybookChrome.swift`：

- 第 12 行 `static let collapse: Animation = ...` 之后加一行：

```swift
    static let fade: Animation = .easeInOut(duration: 0.15)
```

- 第 38–40 行 `static func collapse(_ reduceMotion: Bool) -> Animation? { ... }` 之后加：

```swift

    static func fade(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : fade
    }
```

验证：`./scripts/build.sh` 通过。

---

## 步骤 7：新建测试 `AreaChainTests/Theme/DaybookTokenTests.swift`

```swift
import SwiftUI
import Testing
@testable import AreaChain

struct DaybookTokenTests {
    @Test func metricsFollowTheMenuBarBaseline() {
        #expect(DaybookMetrics.inputHeight == 34)
        #expect(DaybookMetrics.controlHeight == 28)
        #expect(DaybookMetrics.rowHeight == 36)
        #expect(DaybookMetrics.chipHeight == 18)
        #expect(DaybookMetrics.Hit.regular == 28)
        #expect(DaybookMetrics.Hit.compact == 22)
        #expect(DaybookMetrics.Hit.inline == 18)
        #expect(DaybookMetrics.Radius.inputComposer == 8)
        #expect(DaybookMetrics.Radius.inputSearch == 10)
        #expect(DaybookMetrics.Radius.inputEditor == 6)
        #expect(DaybookMetrics.Stroke.regular == 0.6)
        #expect(DaybookMetrics.Stroke.focus == 0.9)
    }

    @Test func inputInsetsMatchTheMenuBarCaptureField() {
        let composer = DaybookMetrics.inputInsets(.composer)
        #expect(composer.top == 7)
        #expect(composer.leading == 10)
        let search = DaybookMetrics.inputInsets(.search)
        #expect(search.top == 8)
        #expect(search.leading == 10)
        let editor = DaybookMetrics.inputInsets(.editor)
        #expect(editor.top == 4)
        #expect(editor.leading == 4)
    }

    @Test func elevationLevelsAreDistinct() {
        #expect(DaybookElevation.flat != DaybookElevation.raised)
        #expect(DaybookElevation.raised != DaybookElevation.floating)
        #expect(DaybookElevation.floating.radius == 8)
        #expect(DaybookElevation.floating.y == 2)
    }

    @Test func newRadiusAndTypeTokensExist() {
        #expect(DaybookRadius.xxs == 2.5)
        #expect(DaybookRadius.regular == 8)
        #expect(DaybookType.kbd != DaybookType.micro)
        #expect(DaybookType.bodyLarge != DaybookType.body)
        #expect(DaybookType.display != DaybookType.title)
    }

    @Test func workspaceLayoutKeepsItsValues() {
        #expect(WorkspaceLayout.headerHeight == 50)
        #expect(WorkspaceLayout.maxContentWidth == 880)
        #expect(WorkspaceLayout.sidebarRowHeight == 28)
        #expect(WorkspaceLayout.sidebarTopInset == 28)
    }

    @Test func diaryPresetColorsFollowTagNames() {
        #expect(DaybookPalette.diaryPreset(forTagName: DiaryMemoTags.password) == DaybookPalette.DiaryPreset.password)
        #expect(DaybookPalette.diaryPreset(forTagName: DiaryMemoTags.idea) == DaybookPalette.DiaryPreset.idea)
        #expect(DaybookPalette.diaryPreset(forTagName: DiaryMemoTags.journal) == DaybookPalette.DiaryPreset.journal)
        #expect(DaybookPalette.diaryPreset(forTagName: "工作") == DaybookPalette.accent.base)
    }
}
```

---

## 最终验证（全部必须通过，缺一不可）

依次运行，把每条的输出原样贴进汇报：

```bash
# 1. 定向测试
./scripts/build.sh test \
  --only-testing AreaChainTests/DaybookTokenTests \
  --only-testing AreaChainTests/DaybookContrastTests \
  --only-testing AreaChainTests/WorkspaceStyleTests \
  --only-testing AreaChainTests/SyntaxHighlighterTests

# 2. 旧符号必须消失（预期零输出）
rg -n 'DaybookShadow|DaybookTheme\.Syntax' AreaChain AreaChainTests

# 3. 三个令牌 enum 和 Swatch 必须离开 DaybookTheme.swift（预期零输出）
rg -n 'enum (DaybookRadius|DaybookSpacing|DaybookType|DaybookSwatch|DaybookShadow)' AreaChain/Theme/DaybookTheme.swift

# 4. 新文件都在
ls AreaChain/Theme/DaybookTokens.swift AreaChain/Theme/DaybookPalette.swift AreaChain/Theme/DaybookMetrics.swift AreaChain/Theme/DaybookElevation.swift AreaChain/Theme/WorkspaceLayout.swift AreaChainTests/Theme/DaybookTokenTests.swift

# 5. 工作流检查
python3 -B scripts/check_workflow.py

# 6. 改动范围核对：Features 下只允许出现这三个文件
git diff --stat -- AreaChain/Features
```

第 6 条预期只有 `Tasks/TaskRow+Badges.swift`、`Workspace/WorkspaceHeaderBar.swift`、`Workspace/WorkspaceSidebarView.swift`。多了任何一个，说明你改了不该改的，回滚那个文件。

## 汇报格式（做完后按这个格式给我）

```
## P0 完成汇报
### 新建文件
- 路径 — 行数
### 修改文件
- 路径 — 改了什么（一句话）
### 删除的符号
- DaybookShadow / DaybookTheme.Syntax（改名） / DaybookTheme 内的 Swatch、Radius、Spacing、Type
### 验证输出
（最终验证 1–6 条的原样输出）
### 未做 / 发现的问题
- 只记录，不动手
```

最后把 `.cursor/plans/design-system.md` 第 8 节的 `- [ ] P0 令牌落地` 改成 `- [x]`，并在"决策记录"下面追加一行：`- <今天日期> P0 完成：<一句话>`。

## 绝对不要做

- 不要重命名本文里任何标识符（`DaybookPalette` / `DaybookMetrics` / `DaybookElevation` / `WorkspaceLayout` / `DaybookTokens` / `flat` / `raised` / `floating`）。
- 不要"顺手"把 Features 里的 `DaybookTheme.ink` 改成 `DaybookPalette.text.primary`——那是 P6。
- 不要删 `DaybookViewStyle`、`WorkspaceStyle`、`WorkspaceSwatch`、`DaybookInputChrome`——那是 P1 / P2。
- 不要改 `DaybookTextField.swift`、`DaybookTextEditor.swift`、`SyntaxOverlay.swift`。
- 不要新建 `class`、协议、工厂。
- 不要 commit。
