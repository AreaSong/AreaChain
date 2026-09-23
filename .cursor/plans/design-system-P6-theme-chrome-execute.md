# 任务：AreaChain 设计系统收敛 · 阶段 P6 Theme 共享控件（颜色、字号、圆角）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 只改下面点名的 9 个文件，都在 `AreaChain/Theme/`。
2. 每一处都按给出的原文替换。不要看了规则自己去文件里找「类似的」再改。
3. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
4. 先读 `AGENTS.md`，再读本文。不要扫 Features。不要改 `DaybookTheme.swift`、`DaybookPalette.swift`、`DaybookElevation.swift`、`DaybookButtonStyle.swift`、`DaybookChip.swift`、`DaybookSurface.swift`、`SyntaxHelpCard.swift`、`SyntaxAutocompleteView.swift`、`LiveComposerPreviewHeader.swift`。
5. 做完不宣布「通过」。验收按 `design-system-P6-theme-chrome-verify.md`。
6. 本阶段不删 `DaybookTheme`。这些文件继续写 `DaybookTheme.ink`、`muted`、`stamp`、`paper`、`rule`。
7. 不要改 `.spring`、`.easeInOut`、`.easeOut`。不要删 `// control:`。
8. 替换短字号时必须连结尾的 `)` 一起匹配。

## 为什么有的换、有的不换

`badge` 是 10pt medium，`caption` 是 11pt medium，`body` 是 13pt，`DaybookRadius.regular` 是 8，`small` 是 6，`xs` 是 4，`xxs` 是 2.5。差 0.5pt 以内才换。

10.5pt semibold 用 `badge.weight(.semibold)`。11.5pt 用 `caption` 再保留原来的字重。没有写 weight 的 9pt 用 `micro`。

圆体、小于 9pt、28pt 保持原样并写 `token-exempt`。`display` 是 26pt，不要拿来换 28pt。7pt 圆角和 `small`(6)、`regular`(8) 都差 1pt，不换，只写豁免。

`stamp` 的 12% 是 `DaybookPalette.accent.fill`，35% 是 `DaybookPalette.accent.border`。其他透明度没有令牌，数字留下并写豁免。象限小标的 `slot.themeColor` / `slot.themeFill` 不要换成印章色。

## 开始前必读

`AreaChain/Theme/DaybookTokens.swift`。确认 `badge` 是 10pt medium，`xs` 是 4，`xxs` 是 2.5。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/TaskRowBubbleTests --only-testing AreaChainTests/SyntaxOverlayPlacementTests
```

---

## 步骤 1：`CommandReturnButton.swift`

把

```swift
            .font(.system(size: 10.5, weight: .semibold))
```

换成

```swift
            .font(DaybookType.badge.weight(.semibold))
```

不要改 `NSEvent` 监听。

---

## 步骤 2：`DaybookSegmentedBar.swift`

把

```swift
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DaybookTheme.ink.opacity(0.06))
```

换成

```swift
            RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
                .fill(DaybookTheme.ink.opacity(0.06)) // token-exempt: 6% 墨色没有对应令牌
```

把

```swift
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
```

换成

```swift
                .font(DaybookType.body.weight(isSelected ? .semibold : .medium))
```

把

```swift
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
```

换成

```swift
                            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
```

`.withAnimation(.spring(response: 0.28, dampingFraction: 0.75))` 不要改。`.buttonStyle(.plain) // control: 分段切换滑块，非按钮语义` 不要改。

---

## 步骤 3：`DaybookSectionHeader.swift`

把

```swift
                    .font(.system(size: 10, weight: .bold, design: .rounded))
```

换成

```swift
                    .font(.system(size: 10, weight: .bold, design: .rounded)) // token-exempt: 分节计数用圆体
```

`DaybookDivider` 的 `opacity: Double = 0.4` 不要改。

---

## 步骤 4：`QuadrantMiniMark.swift`

把

```swift
                .font(.system(size: 8.5, weight: .bold))
```

换成

```swift
                .font(.system(size: 8.5, weight: .bold)) // token-exempt: 小于 9pt，kbd 是等宽
```

把

```swift
                .font(.system(size: metrics == .row ? 10 : 9.5, weight: .bold, design: .rounded))
```

换成

```swift
                .font(.system(size: metrics == .row ? 10 : 9.5, weight: .bold, design: .rounded)) // token-exempt: 象限徽章用圆体
```

两处圆角都收到 `DaybookRadius.xs`。行内是 4，紧凑是 3.5，令牌都是 4：

```swift
            RoundedRectangle(cornerRadius: metrics == .row ? 4 : 3.5, style: .continuous)
```

换成

```swift
            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
```

```swift
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(slot.themeColor.opacity(isHighlighted ? 0.35 : 0.15), lineWidth: 0.6)
```

换成

```swift
                RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                    .stroke(slot.themeColor.opacity(isHighlighted ? 0.35 : 0.15), lineWidth: 0.6) // token-exempt: 象限色 35% 与 15% 不是印章色
```

`slot.themeColor` 和 `slot.themeFill` 不要改。`lineWidth: 0.6` 不要改。

---

## 步骤 5：`DaybookChrome.swift`

把

```swift
                    .font(.system(size: alignment == .center ? 28 : 16, weight: .light))
                    .foregroundStyle(DaybookTheme.stamp.opacity(0.85))
```

换成

```swift
                    .font(.system(size: alignment == .center ? 28 : 16, weight: .light)) // token-exempt: 28pt 没有令牌，display 是 26pt，字重是 light
                    .foregroundStyle(DaybookTheme.stamp.opacity(0.85)) // token-exempt: 85% 印章色没有对应令牌
```

把

```swift
                .font(compact ? DaybookType.caption : (alignment == .center ? .system(size: 13, weight: .medium) : DaybookType.body))
                .foregroundStyle(DaybookTheme.ink.opacity(0.88))
```

换成

```swift
                .font(compact ? DaybookType.caption : (alignment == .center ? DaybookType.body.weight(.medium) : DaybookType.body))
                .foregroundStyle(DaybookTheme.ink.opacity(0.88)) // token-exempt: 88% 墨色没有对应令牌
```

把

```swift
                    .font(.system(size: 11.5, weight: .regular))
```

换成

```swift
                    .font(DaybookType.caption.weight(.regular))
```

把

```swift
            .background(DaybookTheme.paper.opacity(0.94))
```

换成

```swift
            .background(DaybookTheme.paper.opacity(0.94)) // token-exempt: 94% 纸色没有对应令牌
```

`daybookHoverReveal` 里的 `.opacity(visible ? 1 : 0)` 是显隐，不要改。

---

## 步骤 6：`DaybookPage.swift`

把

```swift
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(isFocused ? DaybookTheme.ink : DaybookTheme.muted.opacity(0.8))
```

换成

```swift
                    .font(DaybookType.caption.weight(.semibold))
                    .foregroundStyle(isFocused ? DaybookTheme.ink : DaybookTheme.muted.opacity(0.8)) // token-exempt: 80% 次要色没有对应令牌
```

---

## 步骤 7：`CaptureAttributesView.swift`

把

```swift
                            .font(.system(size: 9))
```

换成

```swift
                            .font(DaybookType.micro)
```

把

```swift
                            .fill(DaybookTheme.stamp.opacity(state.showsAttributes ? 0.20 : 0.12))
```

换成

```swift
                            .fill(DaybookTheme.stamp.opacity(state.showsAttributes ? 0.20 : 0.12)) // token-exempt: 20% 与 12% 写在同一个三元表达式里
```

不要把这一行拆成 `accent.fill`。

把

```swift
                            .stroke(DaybookTheme.stamp.opacity(0.35), lineWidth: 0.8)
```

换成

```swift
                            .stroke(DaybookPalette.accent.border, lineWidth: 0.8)
```

把

```swift
                        .font(.system(size: 10.5))
                        .foregroundStyle(DaybookTheme.muted.opacity(0.40))
```

换成

```swift
                        .font(DaybookType.badge)
                        .foregroundStyle(DaybookTheme.muted.opacity(0.40)) // token-exempt: 40% 次要色没有对应令牌
```

把

```swift
        .overlay(RoundedRectangle(cornerRadius: DaybookRadius.small).stroke(DaybookTheme.rule.opacity(0.7), lineWidth: 0.7))
```

换成

```swift
        .overlay(RoundedRectangle(cornerRadius: DaybookRadius.small).stroke(DaybookTheme.rule.opacity(0.7), lineWidth: 0.7)) // token-exempt: 70% 分隔线没有对应令牌
```

`.buttonStyle(.plain) // control: 属性按钮固定 58×22，胶囊留给 P5` 不要改。`lineWidth` 不要改。

---

## 步骤 8：`LiveDiaryComposerPreview.swift`

把

```swift
                        .stroke(DaybookTheme.rule.opacity(0.7), lineWidth: 0.7)
```

换成

```swift
                        .stroke(DaybookTheme.rule.opacity(0.7), lineWidth: 0.7) // token-exempt: 70% 分隔线没有对应令牌
```

两处相同，都换成 `DaybookType.caption.weight(.medium)`。只改这个文件：

```swift
                .font(.system(size: 11, weight: .medium))
```

备注图标：

```swift
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(isNoteHovered ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.65))
```

换成

```swift
            .font(DaybookType.micro.weight(.medium))
            .foregroundStyle(isNoteHovered ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.65)) // token-exempt: 65% 次要色没有对应令牌
```

```swift
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(isNoteHovered ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.ink.opacity(0.04))
```

换成

```swift
                RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                    .fill(isNoteHovered ? DaybookPalette.accent.fill : DaybookTheme.ink.opacity(0.04)) // token-exempt: 4% 墨色没有对应令牌
```

`.opacity(isHovered ? 1.0 : 0.0)` 是按钮显隐，不要改。

---

## 步骤 9：`DaybookRowBubbles.swift`

`RowTitleBubble` 里：

```swift
                .font(.system(size: 9.5, weight: isCopied ? .bold : .medium))
```

换成

```swift
                .font(DaybookType.micro.weight(isCopied ? .bold : .medium))
```

```swift
                        .font(.system(size: 9.5, weight: .bold))
```

换成

```swift
                        .font(DaybookType.micro.weight(.bold))
```

```swift
                    .font(.system(size: 11.5, weight: .medium))
```

换成

```swift
                    .font(DaybookType.caption.weight(.medium))
```

三处 `cornerRadius: 6` 都换成 `DaybookRadius.small`。两处在背景和描边，一处在 `contentShape`。注释不要加到这三处，它们只是换圆角。

描边这一行末尾加豁免，数字不要改：

```swift
                .stroke(isCopied ? DaybookTheme.stamp.opacity(0.7) : (isHovered ? DaybookTheme.cardBorderHover : DaybookTheme.rule.opacity(0.9)), lineWidth: 0.8)
```

换成

```swift
                .stroke(isCopied ? DaybookTheme.stamp.opacity(0.7) : (isHovered ? DaybookTheme.cardBorderHover : DaybookTheme.rule.opacity(0.9)), lineWidth: 0.8) // token-exempt: 70% 印章色和 90% 分隔线没有对应令牌
```

这一句在标题气泡和备注气泡里各有一处，两处都换。

`RowNoteBubble` 里两个箭头：

```swift
                        .font(.system(size: 7))
```

两处都换成

```swift
                        .font(.system(size: 7)) // token-exempt: 小于 9pt 的气泡箭头
```

```swift
                        .font(.system(size: 9.5, weight: isCopied ? .bold : .semibold))
```

换成

```swift
                        .font(DaybookType.micro.weight(isCopied ? .bold : .semibold))
```

```swift
                        .font(.system(size: 10, weight: .bold))
```

换成

```swift
                        .font(DaybookType.badge.weight(.bold))
```

```swift
                    .font(.system(size: 11, weight: .regular))
```

换成

```swift
                    .font(DaybookType.caption.weight(.regular))
```

两处 `cornerRadius: 7` 不换数字，只加注释。一处背景，一处描边：

```swift
                RoundedRectangle(cornerRadius: 7, style: .continuous)
```

换成

```swift
                RoundedRectangle(cornerRadius: 7, style: .continuous) // token-exempt: 7pt 与 small、regular 都差 1pt
```

两处 `.withAnimation(.spring(response: 0.25, dampingFraction: 0.7))` 和两处 `.withAnimation(.easeInOut(duration: 0.2))` 不要改。

---

## 最终验证

```bash
# 1. 这 9 个文件里没有未豁免的字面字号（预期零输出）
rg -n '\.font\(\.system\(size:\s*[0-9]' \
  AreaChain/Theme/CommandReturnButton.swift \
  AreaChain/Theme/DaybookSegmentedBar.swift \
  AreaChain/Theme/DaybookSectionHeader.swift \
  AreaChain/Theme/QuadrantMiniMark.swift \
  AreaChain/Theme/DaybookChrome.swift \
  AreaChain/Theme/DaybookPage.swift \
  AreaChain/Theme/CaptureAttributesView.swift \
  AreaChain/Theme/LiveDiaryComposerPreview.swift \
  AreaChain/Theme/DaybookRowBubbles.swift \
  | rg -v 'token-exempt:'

# 2. 未豁免的字面圆角消失（预期零输出）
rg -n 'cornerRadius:\s*[0-9]' \
  AreaChain/Theme/CommandReturnButton.swift \
  AreaChain/Theme/DaybookSegmentedBar.swift \
  AreaChain/Theme/DaybookSectionHeader.swift \
  AreaChain/Theme/QuadrantMiniMark.swift \
  AreaChain/Theme/DaybookChrome.swift \
  AreaChain/Theme/DaybookPage.swift \
  AreaChain/Theme/CaptureAttributesView.swift \
  AreaChain/Theme/LiveDiaryComposerPreview.swift \
  AreaChain/Theme/DaybookRowBubbles.swift \
  | rg -v 'token-exempt:'

# 3. 其他目录零 diff（预期零输出）
git diff --stat -- AreaChain/Features AreaChain/Domain AreaChain/Services

# 4. 测试没被删（两条都跑；预期零输出）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'

# 5. 测试
./scripts/build.sh test \
  --only-testing AreaChainTests/TaskRowBubbleTests \
  --only-testing AreaChainTests/SyntaxOverlayPlacementTests \
  --only-testing AreaChainTests/QuadrantLayoutTests

# 6. 工作流检查
python3 -B scripts/check_workflow.py
```

第 1 条如果还有输出，就是漏改或漏了豁免。不要把 7pt、8.5pt、28pt 换成 `DaybookType`。不要去掉 `.rounded`。

第 5 条若失败且是「尺寸与预期不符」，不要改测试，贴出失败信息停下问我。运行期间不要操作其他窗口。

## 汇报格式

```
## P6 Theme 共享控件完成汇报
### 修改文件（路径 — 换了什么）
### 保留的 token-exempt 行（file:line — 注释）
### 验证输出（1–6 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P6 Theme 共享控件` 改成 `- [x]`，决策记录追加 `- <日期> P6 Theme 共享控件完成：<一句话>`。

## 绝对不要做

- 不要改 Features、Domain、Services。
- 不要改 `SyntaxHelpCard.swift`、`SyntaxAutocompleteView.swift`、`LiveComposerPreviewHeader.swift`。
- 不要删 `DaybookTheme`，不要改 `DaybookPalette.swift`。
- 不要把象限 `slot.themeColor` / `slot.themeFill` 换成印章色。
- 不要把 7pt 圆角收成 `small` 或 `regular`。
- 不要把 28pt 放成 `DaybookType.display`。
- 不要改动画，不要删 `// control:`。
- 不要 commit。
