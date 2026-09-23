# 任务：AreaChain 设计系统收敛 · 阶段 P6 删除 DaybookTheme · 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 按步骤顺序做。调色板还写着 `DaybookTheme` 时，禁止开始第 3 步的全文替换。
2. 不 `git commit` / `git push` / 安装 / 发布。不要删测试。
3. 先读 `AGENTS.md`，再读本文。
4. 做完不宣布「通过」。验收按 `design-system-P6-theme-delete-verify.md`。
5. 不要改筛选逻辑，不要改 `SyntaxAutocomplete.swift`。双语里「重要」也会命中 p4，那不是这一份的事。
6. 不要改 `.cursor/plans/` 里除了 `design-system.md` 状态以外的旧提示词。
7. 文档（`docs/`、`AGENTS.md`）留给 P7。这一份只改 Swift。

`DaybookTheme.swift` 里不只有颜色。`Color.daybook`、`NSColor.daybook`、`ContrastMath`、`daybookScroll` 必须先搬走，再删文件。弹层宽高和工作台窗口尺寸不是颜色，放到 `DaybookMetrics.Window`。

## 开始前必读

`AreaChain/Theme/DaybookTheme.swift` 全文。`AreaChain/Theme/DaybookPalette.swift` 里还引用 `DaybookTheme` 的那几行。`AreaChain/Theme/DaybookMetrics.swift` 的 `Hit` 和 `Stroke`。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/DaybookContrastTests --only-testing AreaChainTests/SyntaxHighlighterTests
```

---

## 步骤 1：窗口尺寸放进 `DaybookMetrics.swift`

在 `enum Stroke` 结束后、`static func inputInsets` 之前，插入：

```swift
    enum Window {
        static let popoverWidth: CGFloat = 380
        static let popoverMinHeight: CGFloat = 280
        static let popoverMaxHeight: CGFloat = 490
        static let popoverHeight: CGFloat = 490
        static let popoverSize = CGSize(width: popoverWidth, height: popoverHeight)
        static let workspaceSize = CGSize(width: 960, height: 640)
        static let workspaceMinSize = CGSize(width: 780, height: 500)
    }
```

数字必须和现在的 `DaybookTheme` 一致。不要改 `Hit.regular`，它已经是 28。

---

## 步骤 2：让 `DaybookPalette.swift` 不再调用 `DaybookTheme`

先改注释：

```swift
// MARK: - L0 原始值（从 DaybookTheme.swift 原样搬入）
```

换成

```swift
// MARK: - L0 原始值
```

把这四段初始化换成下面的原文。`alpha(...)` 和 `scrim` 那几行保持不动。

`text`：

```swift
    static let text = Text(
        primary: Color.daybook(name: "daybook.ink", swatch: DaybookSwatch.inkLight, dark: DaybookSwatch.inkDark),
        secondary: Color.daybook(name: "daybook.muted", swatch: DaybookSwatch.mutedLight, dark: DaybookSwatch.mutedDark),
        tertiary: alpha("palette.text.tertiary", DaybookSwatch.mutedLight, DaybookSwatch.mutedDark, 0.75),
        disabled: alpha("palette.text.disabled", DaybookSwatch.mutedLight, DaybookSwatch.mutedDark, 0.45),
        done: Color.daybook(name: "daybook.done", swatch: DaybookSwatch.doneLight, dark: DaybookSwatch.doneDark),
        onAccent: Color.daybook(name: "palette.text.onAccent", light: .white, dark: .white)
    )
```

`fill` 里这三个名字换成：

```swift
        page: Color.daybook(name: "daybook.paper", swatch: DaybookSwatch.paperLight, dark: DaybookSwatch.paperDark),
        surface: Color.daybook(name: "daybook.surface", light: NSColor.white.withAlphaComponent(0.65), dark: NSColor(white: 0.18, alpha: 0.55)),
        hover: Color.daybook(name: "daybook.hoverFill", light: NSColor.black.withAlphaComponent(0.04), dark: NSColor.white.withAlphaComponent(0.08)),
        press: Color.daybook(name: "daybook.pressFill", light: NSColor.black.withAlphaComponent(0.08), dark: NSColor.white.withAlphaComponent(0.14)),
        selection: Color.daybook(
            name: "daybook.cardSelectionFill",
            light: NSColor.daybook(DaybookSwatch.stampLight).withAlphaComponent(0.08),
            dark: NSColor.daybook(DaybookSwatch.stampDark).withAlphaComponent(0.14)
        ),
```

`subtle:` 和 `scrim:` 不要动。

`border` 里这三个名字换成：

```swift
        default: Color.daybook(name: "daybook.rule", swatch: DaybookSwatch.ruleLight, dark: DaybookSwatch.ruleDark),
        subtle: Color.daybook(
            name: "daybook.cardBorder",
            light: NSColor.black.withAlphaComponent(0.06),
            dark: NSColor.white.withAlphaComponent(0.08)
        ),
        selection: Color.daybook(
            name: "daybook.cardSelectionStroke",
            light: NSColor.daybook(DaybookSwatch.stampLight).withAlphaComponent(0.35),
            dark: NSColor.daybook(DaybookSwatch.stampDark).withAlphaComponent(0.40)
        ),
```

`strong:`、`focus:`、`faint:` 不要动。

`status.danger` 换成：

```swift
        danger: Color.daybook(name: "daybook.destructive", swatch: DaybookSwatch.destructiveLight, dark: DaybookSwatch.destructiveDark)
```

`accent.base` 换成：

```swift
        base: Color.daybook(name: "daybook.stamp", swatch: DaybookSwatch.stampLight, dark: DaybookSwatch.stampDark),
```

`accent.fill` 和 `accent.border` 不要动。

在 `static let accent = Accent(...)` 结束后、`DiaryPreset` 之前，加上这四个还没有调色板名字的颜色。定义从 `DaybookTheme.swift` 原样搬来：

```swift
    static let checkmark = Color.daybook(name: "daybook.checkmark", swatch: DaybookSwatch.checkmarkLight, dark: DaybookSwatch.checkmarkDark)
    static let cardSurface = Color.daybook(name: "daybook.cardSurface", light: NSColor.white.withAlphaComponent(0.55), dark: NSColor(white: 0.18, alpha: 0.55))
    static let cardSurfaceHover = Color.daybook(name: "daybook.cardSurfaceHover", light: NSColor.white.withAlphaComponent(0.85), dark: NSColor(white: 0.24, alpha: 0.75))
    static let cardBorderHover = Color.daybook(
        name: "daybook.cardBorderHover",
        light: NSColor.black.withAlphaComponent(0.12),
        dark: NSColor.white.withAlphaComponent(0.16)
    )
```

`Syntax` 里这六行换成：

```swift
        static let time = DaybookPalette.accent.base
        static let timeNS = NSColor(DaybookPalette.accent.base)
        static let timeFill = DaybookPalette.accent.base.opacity(0.12)

        static let p4 = DaybookPalette.text.secondary
        static let p4NS = NSColor(DaybookPalette.text.secondary)
        static let p4Fill = DaybookPalette.text.secondary.opacity(0.10)
```

p1、p2、p3 不要动。

注释里如果还有 `DaybookTheme` 这八个字母，改写成「旧主题文件」，不要留这个词。

做完立刻检查。不是零就停，不要开始第 3 步：

```bash
rg -n 'DaybookTheme' AreaChain/Theme/DaybookPalette.swift
```

---

## 步骤 3：全文替换调用点

只在 `AreaChain/` 和 `AreaChainTests/` 里替换。一次换一个完整名字，严格按这个顺序。先换长的，再换短的。`DaybookTheme.cardSurfaceHover` 必须在 `DaybookTheme.cardSurface` 之前。`DaybookTheme.cardBorderHover` 必须在 `DaybookTheme.cardBorder` 之前。

| 原样 | 换成 |
|---|---|
| `DaybookTheme.cardSurfaceHover` | `DaybookPalette.cardSurfaceHover` |
| `DaybookTheme.cardSelectionFill` | `DaybookPalette.fill.selection` |
| `DaybookTheme.cardSelectionStroke` | `DaybookPalette.border.selection` |
| `DaybookTheme.cardBorderHover` | `DaybookPalette.cardBorderHover` |
| `DaybookTheme.cardBorder` | `DaybookPalette.border.subtle` |
| `DaybookTheme.cardSurface` | `DaybookPalette.cardSurface` |
| `DaybookTheme.hoverFill` | `DaybookPalette.fill.hover` |
| `DaybookTheme.pressFill` | `DaybookPalette.fill.press` |
| `DaybookTheme.destructive` | `DaybookPalette.status.danger` |
| `DaybookTheme.checkmark` | `DaybookPalette.checkmark` |
| `DaybookTheme.focusRing` | `DaybookPalette.accent.base` |
| `DaybookTheme.popoverMinHeight` | `DaybookMetrics.Window.popoverMinHeight` |
| `DaybookTheme.popoverMaxHeight` | `DaybookMetrics.Window.popoverMaxHeight` |
| `DaybookTheme.popoverHeight` | `DaybookMetrics.Window.popoverHeight` |
| `DaybookTheme.popoverWidth` | `DaybookMetrics.Window.popoverWidth` |
| `DaybookTheme.popoverSize` | `DaybookMetrics.Window.popoverSize` |
| `DaybookTheme.workspaceMinSize` | `DaybookMetrics.Window.workspaceMinSize` |
| `DaybookTheme.workspaceSize` | `DaybookMetrics.Window.workspaceSize` |
| `DaybookTheme.paper` | `DaybookPalette.fill.page` |
| `DaybookTheme.stamp` | `DaybookPalette.accent.base` |
| `DaybookTheme.muted` | `DaybookPalette.text.secondary` |
| `DaybookTheme.rule` | `DaybookPalette.border.default` |
| `DaybookTheme.done` | `DaybookPalette.text.done` |
| `DaybookTheme.ink` | `DaybookPalette.text.primary` |
| `DaybookTheme.hit` | `DaybookMetrics.Hit.regular` |
| `DaybookTheme.space` | `DaybookSpacing.sm` |
| `DaybookTheme.surface` | `DaybookPalette.fill.surface` |

`DaybookTheme.ink.opacity(...)` 会跟着变成 `DaybookPalette.text.primary.opacity(...)`。这是对的，透明度数字和旁边的 `token-exempt` 注释不要改。

不要把单独的 `ink`、`stamp`、`paper` 换掉。必须带着 `DaybookTheme.` 前缀。

换完后，除了 `DaybookTheme.swift` 自己，源码和测试里不应该再有 `DaybookTheme.`。注释里如果还剩 `DaybookTheme` 这个词，改掉措辞，不要删代码。

---

## 步骤 4：搬走工厂，删除旧文件

新建 `AreaChain/Theme/DaybookColor.swift`。把 `DaybookTheme.swift` 里的这四段原样拷进去，不要拷 `enum DaybookTheme`：

- `extension Color`
- `enum ContrastMath`
- `extension NSColor`
- `extension View`（`daybookScroll` 和 `daybookHideInputChrome`）

文件开头保留 `import AppKit` 和 `import SwiftUI`。

然后删除 `AreaChain/Theme/DaybookTheme.swift`。不要留一个空的 `enum DaybookTheme`。

Xcode 用文件系统同步组，不用改工程文件。

---

## 最终验证

```bash
# 1. 源码和测试里没有旧名字（预期零输出）
rg -n 'DaybookTheme' AreaChain AreaChainTests

# 2. 工厂还在（预期各至少 1）
rg -c 'static func daybook' AreaChain/Theme/DaybookColor.swift
rg -c 'enum ContrastMath' AreaChain/Theme/DaybookColor.swift
rg -c 'func daybookScroll' AreaChain/Theme/DaybookColor.swift

# 3. 旧文件已删（预期 No such file）
test ! -f AreaChain/Theme/DaybookTheme.swift && echo DELETED

# 4. 测试没被删（两条都跑；预期零输出）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'

# 5. 测试
./scripts/build.sh test \
  --only-testing AreaChainTests/DaybookContrastTests \
  --only-testing AreaChainTests/SyntaxHighlighterTests \
  --only-testing AreaChainTests/DaybookTokenTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests

# 6. 工作流检查
python3 -B scripts/check_workflow.py
```

第 5 条若失败且是「找不到 DaybookTheme」，说明漏换，按第 3 步的表补上，不要改测试期望。若失败的是 `priorityAndTimeCandidatesStillMatchSpokenWords`，不要修，那是双语阶段的筛选问题，贴出来停下问我。运行期间不要操作其他窗口。

## 汇报格式

```
## P6 删除 DaybookTheme 完成汇报
### 修改文件（路径 — 换了什么）
### 替换后 rg DaybookTheme 的输出
### 验证输出（1–6 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P6 Theme 删 DaybookTheme` 改成 `- [x]`，决策记录追加 `- <日期> P6 删除 DaybookTheme 完成：<一句话>`。

## 绝对不要做

- 不要改颜色的 RGB、透明度数字、窗口的 380 / 280 / 490 / 960 / 640 / 780 / 500。
- 不要把 `DaybookTheme.hit` 收成别的高度。它就是 `DaybookMetrics.Hit.regular`（28）。
- 不要把 `focusRing` 收成蓝色。它原来等于印章色，所以是 `DaybookPalette.accent.base`。
- 不要在调色板还引用 `DaybookTheme` 时做全文替换。
- 不要删 `ContrastMath` 和 `Color.daybook`。
- 不要改 `SyntaxAutocomplete.swift`。
- 不要改文档。
- 不要 commit。
