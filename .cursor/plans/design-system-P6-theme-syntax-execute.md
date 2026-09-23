# 任务：AreaChain 设计系统收敛 · 阶段 P6 Theme 语法表面（颜色、字号、圆角）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 只改这三个文件：`AreaChain/Theme/SyntaxHelpCard.swift`、`AreaChain/Theme/SyntaxAutocompleteView.swift`、`AreaChain/Theme/LiveComposerPreviewHeader.swift`。
2. 每一处都按给出的原文替换。不要看了规则自己去文件里找「类似的」再改。
3. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
4. 先读 `AGENTS.md`，再读本文。不要扫 Features。不要改 `DaybookTheme.swift`、`DaybookPalette.swift`、`Localizable.xcstrings`。
5. 做完不宣布「通过」。验收按 `design-system-P6-theme-syntax-verify.md`。
6. 本阶段不删 `DaybookTheme`，也不把中文改成本地化 key。下面这些字符串必须原样留下：`填入试用`、`标签分类`、`切换`、`补全`、`关闭`、`全部标签`、`综合范例`。
7. 替换短字号时必须连结尾的 `)` 一起匹配。`.font(.system(size: 9))` 可以换。`.font(.system(size: 9.5)` 不能用这句去换。`.font(.system(size: 10))` 不能拿去换 `size: 10.5` 或 `size: 10, weight:`。
8. 只在该步骤点名的文件里替换。同一句出现几次就换几次，缩进保持不变。

## 为什么有的换、有的不换

`DaybookType.kbd` 就是 8.5pt semibold 等宽。`micro` 是 9pt medium，`badge` 是 10pt medium，`caption` 是 11pt medium，`subtitle` 是 12pt，`body` 是 13pt。差 0.5pt 以内才换。没有写 weight 的字面字号，换成对应令牌。写了 weight 的，用令牌再 `.weight(...)` 把原来的字重留住。

12.5pt bold 收到 `subtitle`（12pt）并保留 bold。它和 13pt 也差 0.5，取较小的那个。

等宽但不是 8.5pt semibold 的字，没有对应令牌，保持原样并写 `token-exempt`。圆体、小于 9pt 且不是 `kbd` 的图标，同样豁免。5pt 圆角和 `xs`(4)、`small`(6) 都差 1pt，不换。

`stamp` 的 12% 是 `DaybookPalette.accent.fill`。`Color.orange` 是 `DaybookPalette.status.pending`。`muted` 的 75% 是 `DaybookPalette.text.tertiary`。`Color(nsColor: .systemIndigo)` 没有靛蓝令牌，不要改颜色，只加豁免。其他透明度没有令牌，数字留下并写豁免。

## 开始前必读

`AreaChain/Theme/DaybookTokens.swift`。确认 `kbd` 是 8.5pt semibold 等宽，`subtitle` 是 12pt，`xs` 是 4，`xxs` 是 2.5，`regular` 是 8。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/SyntaxAutocompleteTests --only-testing AreaChainTests/SyntaxOverlayPlacementTests
```

---

## 步骤 1：`SyntaxHelpCard.swift`

把

```swift
                .stroke(DaybookTheme.rule.opacity(0.6), lineWidth: 0.8)
```

换成

```swift
                .stroke(DaybookTheme.rule.opacity(0.6), lineWidth: 0.8) // token-exempt: 60% 分隔线没有对应令牌
```

把

```swift
                .font(.system(size: 12, weight: .semibold))
```

换成

```swift
                .font(DaybookType.subtitle.weight(.semibold))
```

把

```swift
                .font(.system(size: 12.5, weight: .bold))
```

换成

```swift
                .font(DaybookType.subtitle.weight(.bold))
```

下面四行只加注释，不要改颜色。`#工作`、`#生活` 这些中文不要改：

```swift
                    + Text("#工作").foregroundStyle(Color(nsColor: .systemIndigo)).bold()
```

这个文件里有两处，都换成

```swift
                    + Text("#工作").foregroundStyle(Color(nsColor: .systemIndigo)).bold() // token-exempt: 没有靛蓝令牌
```

注意缩进。范例行是 20 个空格，底部复杂范例是 24 个空格。两处都加注释，缩进保持不变。

```swift
                    + Text("#生活").foregroundStyle(Color(nsColor: .systemIndigo)).bold()
```

换成

```swift
                    + Text("#生活").foregroundStyle(Color(nsColor: .systemIndigo)).bold() // token-exempt: 没有靛蓝令牌
```

```swift
                color: Color(nsColor: .systemIndigo)
```

换成

```swift
                color: Color(nsColor: .systemIndigo) // token-exempt: 没有靛蓝令牌
```

```swift
                    + Text("!p2").foregroundStyle(Color.orange).bold()
```

换成

```swift
                    + Text("!p2").foregroundStyle(DaybookPalette.status.pending).bold()
```

把

```swift
                            .font(.system(size: 10.5, design: .monospaced))
```

换成

```swift
                            .font(.system(size: 10.5, design: .monospaced)) // token-exempt: 等宽范例，kbd 是 8.5pt
```

本文件有三处精确等于 `.font(.system(size: 8.5, weight: .semibold))`。悬停块两行前面是 32 个空格，底部范例那行前面是 28 个空格。三处都只在行尾加上 ` // token-exempt: 小于 9pt，kbd 是等宽`，前面的空格不要动。

本文件有三处精确等于 `.font(.system(size: 8.5))`。同样是悬停块 32 个空格、底部范例 28 个空格。三处都只在行尾加上 ` // token-exempt: 小于 9pt，kbd 是等宽`，前面的空格不要动。

两处 `.fill(DaybookTheme.stamp.opacity(0.12))` 都换成 `.fill(DaybookPalette.accent.fill)`。悬停块那行前面是 32 个空格，底部范例那行前面是 28 个空格。只换这一小段，前面的空格不要动。

把

```swift
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
```

换成

```swift
                            .font(.system(size: 11, weight: .bold, design: .monospaced)) // token-exempt: 等宽符号，kbd 是 8.5pt
```

把

```swift
                                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                    .fill(color.opacity(0.14))
```

换成

```swift
                                RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                                    .fill(color.opacity(0.14)) // token-exempt: 符号色 14% 不是印章色
```

把

```swift
                            .font(.system(size: 11.5, weight: .semibold))
```

换成

```swift
                            .font(DaybookType.caption.weight(.semibold))
```

把

```swift
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? DaybookTheme.stamp.opacity(0.06) : Color.clear)
```

换成

```swift
                RoundedRectangle(cornerRadius: 5, style: .continuous) // token-exempt: 5pt 与 xs、small 都差 1pt
                    .fill(isHovered ? DaybookTheme.stamp.opacity(0.06) : Color.clear) // token-exempt: 6% 印章底没有对应令牌
```

把

```swift
                        .font(.system(size: 10))
                        .foregroundStyle(Color.orange.opacity(0.9))
```

换成

```swift
                        .font(DaybookType.badge)
                        .foregroundStyle(DaybookPalette.status.pending.opacity(0.9)) // token-exempt: 90% 待办橙没有对应令牌
```

把

```swift
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
```

换成

```swift
                        .font(.system(size: 11, weight: .medium, design: .monospaced)) // token-exempt: 等宽范例，kbd 是 8.5pt
```

把

```swift
                        .font(.system(size: 9.5))
```

换成

```swift
                        .font(DaybookType.micro)
```

把

```swift
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(DaybookTheme.muted.opacity(0.8))
```

换成

```swift
                        .font(DaybookType.kbd.weight(.bold))
                        .foregroundStyle(DaybookTheme.muted.opacity(0.8)) // token-exempt: 80% 次要色没有对应令牌
```

`.buttonStyle(.plain) // control:` 两处不要删。中文标题和范例正文不要改。

---

## 步骤 2：`SyntaxAutocompleteView.swift`

两处 `cornerRadius: 8` 都换成 `DaybookRadius.regular`。一处是填充，一处是描边。

描边这一行加注释，数字不要改：

```swift
                            .stroke(DaybookTheme.rule.opacity(0.7), lineWidth: 0.7)
```

换成

```swift
                            .stroke(DaybookTheme.rule.opacity(0.7), lineWidth: 0.7) // token-exempt: 70% 分隔线没有对应令牌
```

把

```swift
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
```

换成

```swift
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced)) // token-exempt: 等宽候选标题，kbd 是 8.5pt
```

把

```swift
                    .font(.system(size: 10, weight: .regular))
```

换成

```swift
                    .font(DaybookType.badge.weight(.regular))
```

把

```swift
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isSelected ? DaybookTheme.stamp.opacity(0.12) : Color.clear)
```

换成

```swift
            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                .fill(isSelected ? DaybookPalette.accent.fill : Color.clear)
```

把

```swift
                    .font(.system(size: 10.5))
```

换成

```swift
                    .font(DaybookType.badge)
```

三处精确等于 `.font(.system(size: 10))` 的图标都换成 `.font(DaybookType.badge)`。不要动上面已经换成 `badge.weight(.regular)` 的副标题。

三处

```swift
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
```

都换成

```swift
                    .font(DaybookType.kbd)
```

三处

```swift
                    .background(RoundedRectangle(cornerRadius: 2.5).fill(DaybookTheme.ink.opacity(0.06)))
```

都换成

```swift
                    .background(RoundedRectangle(cornerRadius: DaybookRadius.xxs).fill(DaybookTheme.ink.opacity(0.06))) // token-exempt: 6% 墨色没有对应令牌
```

三处精确等于 `.font(.system(size: 9))` 的行都换成 `.font(DaybookType.micro)`。`切换`、`补全`、`关闭` 这几个字不要改。

把

```swift
        .background(DaybookTheme.ink.opacity(0.02))
```

换成

```swift
        .background(DaybookTheme.ink.opacity(0.02)) // token-exempt: 2% 墨色没有对应令牌
```

`DaybookDivider(opacity: 0.4)` 和 `DaybookDivider(opacity: 0.5)` 不要改。

---

## 步骤 3：`LiveComposerPreviewHeader.swift`

把

```swift
                .strokeBorder(DaybookTheme.rule.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2]))
```

换成

```swift
                .strokeBorder(DaybookTheme.rule.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2])) // token-exempt: 80% 分隔线没有对应令牌
```

`Circle()` 不要改。`lineWidth` 和虚线数组不要改。

两处

```swift
                            .font(.system(size: 11, weight: .semibold))
```

和

```swift
                        .font(.system(size: 11, weight: .semibold))
```

都换成 `DaybookType.caption.weight(.semibold)`。缩进保持不变。

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
                            .font(.system(size: 11, weight: .bold, design: .rounded))
```

换成

```swift
                            .font(.system(size: 11, weight: .bold, design: .rounded)) // token-exempt: 标签计数用圆体
```

`共 \(previewTags.count) 个标签` 不要改。

把

```swift
                            .font(.system(size: 9.5))
```

换成

```swift
                            .font(DaybookType.micro)
```

把

```swift
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
```

换成

```swift
                            .font(.system(size: 11, weight: .medium, design: .monospaced)) // token-exempt: 时刻用等宽，kbd 是 8.5pt
```

本文件四处 `cornerRadius: 8` 都换成 `DaybookRadius.regular`。两处在主行，两处在标签气泡。

主行描边：

```swift
                .stroke(DaybookTheme.rule.opacity(0.7), lineWidth: 0.7)
```

换成

```swift
                .stroke(DaybookTheme.rule.opacity(0.7), lineWidth: 0.7) // token-exempt: 70% 分隔线没有对应令牌
```

备注图标：

```swift
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(isNoteHovered ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.75))
```

换成

```swift
            .font(DaybookType.micro.weight(.medium))
            .foregroundStyle(isNoteHovered ? DaybookTheme.stamp : DaybookPalette.text.tertiary)
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

把

```swift
                    .font(.system(size: 10.5, weight: .semibold))
```

换成

```swift
                    .font(DaybookType.badge.weight(.semibold))
```

`全部标签` 不要改。

把

```swift
                    .font(.system(size: 10, weight: .bold, design: .rounded))
```

换成

```swift
                    .font(.system(size: 10, weight: .bold, design: .rounded)) // token-exempt: 标签计数用圆体
```

把

```swift
                    .background(Capsule().fill(DaybookTheme.rule.opacity(0.4)))
```

换成

```swift
                    .background(Capsule().fill(DaybookTheme.rule.opacity(0.4))) // token-exempt: 40% 分隔线没有对应令牌
```

把

```swift
                                .font(.system(size: 11, weight: .medium))
```

换成

```swift
                                .font(DaybookType.caption.weight(.medium))
```

把

```swift
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
```

换成

```swift
                            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
```

标签气泡描边：

```swift
                .stroke(DaybookTheme.rule.opacity(0.6), lineWidth: 0.8)
```

换成

```swift
                .stroke(DaybookTheme.rule.opacity(0.6), lineWidth: 0.8) // token-exempt: 60% 分隔线没有对应令牌
```

把

```swift
            .font(.system(size: 13, weight: .medium))
```

换成

```swift
            .font(DaybookType.body.weight(.medium))
```

`DaybookDivider(opacity: 0.3)` 不要改。

---

## 最终验证

```bash
# 1. 三个文件里没有未豁免的字面字号（预期零输出）
rg -n '\.font\(\.system\(size:\s*[0-9]' \
  AreaChain/Theme/SyntaxHelpCard.swift \
  AreaChain/Theme/SyntaxAutocompleteView.swift \
  AreaChain/Theme/LiveComposerPreviewHeader.swift \
  | rg -v 'token-exempt:'

# 2. 未豁免的字面圆角消失（预期零输出）
rg -n 'cornerRadius:\s*[0-9]' \
  AreaChain/Theme/SyntaxHelpCard.swift \
  AreaChain/Theme/SyntaxAutocompleteView.swift \
  AreaChain/Theme/LiveComposerPreviewHeader.swift \
  | rg -v 'token-exempt:'

# 3. Color.orange 消失（预期零输出）
rg -n 'Color\.orange' AreaChain/Theme/SyntaxHelpCard.swift

# 4. 其他目录零 diff（预期零输出）
git diff --stat -- AreaChain/Features AreaChain/Domain AreaChain/Services AreaChain/Resources

# 5. 测试没被删（两条都跑；预期零输出）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'

# 6. 测试
./scripts/build.sh test \
  --only-testing AreaChainTests/SyntaxAutocompleteTests \
  --only-testing AreaChainTests/SyntaxOverlayPlacementTests \
  --only-testing AreaChainTests/InputSyntaxInteractionTests

# 7. 工作流检查
python3 -B scripts/check_workflow.py
```

第 1 条如果还有输出，就是漏改或漏了豁免。不要把 10.5pt 等宽收成 `DaybookType.kbd`。不要把 5pt 圆角收成 `DaybookRadius`。

第 6 条若失败且是「尺寸与预期不符」，不要改测试，贴出失败信息停下问我。运行期间不要操作其他窗口。

## 汇报格式

```
## P6 Theme 语法表面完成汇报
### 修改文件（路径 — 换了什么）
### 保留的 token-exempt 行（file:line — 注释）
### 验证输出（1–7 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P6 Theme 语法卡片 / 自动补全 / 实时预览` 改成 `- [x]`，决策记录追加 `- <日期> P6 Theme 语法表面完成：<一句话>`。

## 绝对不要做

- 不要改 Features、Domain、Services、`Localizable.xcstrings`。
- 不要删 `DaybookTheme`，不要改 `DaybookPalette.swift`。
- 不要把 `填入试用`、`标签分类`、`切换`、`补全`、`关闭`、`全部标签`、`综合范例` 改成别的文字或 key。
- 不要把 `systemIndigo` 换成印章色或 `status.pending`。
- 不要把 5pt 圆角收成 `xs` 或 `small`。
- 不要把非 8.5pt 的等宽字体收成 `DaybookType.kbd`。
- 不要改 `Circle()`、`lineWidth`、虚线数组、`DaybookDivider(opacity:)`。
- 不要删 `// control:`。
- 不要 commit。
