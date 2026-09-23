# 任务：AreaChain 设计系统收敛 · 阶段 P6 MenuBar（颜色、字号、圆角）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 只改 `AreaChain/Features/MenuBar/` 里下面点名的文件。
2. 每一处都按给出的原文替换。不要看了表自己去文件里找「类似的」再改。
3. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
4. 先读 `AGENTS.md`，再读本文。不要扫 Tasks、Diary、Workspace、Theme。
5. 做完不宣布「通过」。验收按 `design-system-P6-menubar-verify.md`。
6. 小于 9pt 的图标、衬线、圆体，保持原字号。只在该行末尾加给出的 `// token-exempt:`，注释原文不要改。

## 为什么有的换、有的不换

现有字号令牌最近的一档是 `DaybookType.micro`（9pt）。11.5 收到 11、9.5 收到 9，误差不超过 0.5pt，可以换。6.5、7、7.5、8、8.5 如果也放成 9pt，头部的状态图标和芯片里的小叉会变大，所以保持原样并写豁免。菜单栏标记上的衬线和圆体也没有对应令牌，同样豁免。

## 开始前必读

`AreaChain/Theme/DaybookTokens.swift` 里的 `DaybookType` 和 `DaybookRadius`。确认 `caption` 是 11、`micro` 是 9、`badge` 是 10、`subtitle` 是 12、`regular` 圆角是 8。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/MenuBarPopoverRenderingTests --only-testing AreaChainTests/MenuBarToolbarStateTests
```

---

## 步骤 1：`CaptureField.swift`

把

```swift
        let plusColor = focused ? DaybookTheme.ink : DaybookTheme.muted.opacity(0.8)
```

换成

```swift
        let plusColor = focused ? DaybookTheme.ink : DaybookPalette.text.tertiary
```

把

```swift
                .font(.system(size: 11.5, weight: .semibold))
```

换成

```swift
                .font(DaybookType.caption.weight(.semibold))
```

---

## 步骤 2：`FooterBar.swift`

把筛选图标这一行

```swift
                    .font(filterIsActive ? .system(size: 9, weight: .bold) : DaybookType.caption)
```

换成

```swift
                    .font(filterIsActive ? DaybookType.micro.weight(.bold) : DaybookType.caption)
```

把计数这一行

```swift
                        .font(.system(size: 8, weight: .bold, design: .rounded))
```

换成

```swift
                        .font(.system(size: 8, weight: .bold, design: .rounded)) // token-exempt: 8pt 圆体计数，放到 9pt 会变宽
```

把

```swift
                        .background(DaybookTheme.stamp.opacity(0.18))
```

换成

```swift
                        .background(DaybookPalette.accent.fill)
```

把更多按钮这一行

```swift
                .font(.system(size: 12, weight: .semibold))
```

换成

```swift
                .font(DaybookType.subtitle.weight(.semibold))
```

---

## 步骤 3：`MenuBarPopoverView.swift`

把

```swift
                Color.black.opacity(0.001)
```

换成

```swift
                DaybookPalette.fill.scrim
```

`headerIndicator` 里按下面四段替换，过渡和颜色条件不要丢。

搜索图标：

```swift
                .font(.system(size: 7, weight: .bold))
```

换成

```swift
                .font(.system(size: 7, weight: .bold)) // token-exempt: 头部状态图标小于 9pt
```

这一处在文件里会出现多次。只改 `headerIndicator` 里的三处对勾/放大镜/羽毛笔，以及下面的羽毛笔 8pt。如果同一行文字在文件里只出现这些次，可以用替换全部。替换后每一行都必须带这句注释。

橙色点：

```swift
                        .fill(Color.orange)
```

换成

```swift
                        .fill(DaybookPalette.status.pending)
```

两处

```swift
                        .foregroundStyle(DaybookTheme.muted.opacity(0.6))
```

换成

```swift
                        .foregroundStyle(DaybookPalette.text.tertiary)
```

羽毛笔字号：

```swift
                        .font(.system(size: 8, weight: .semibold))
```

换成

```swift
                        .font(.system(size: 8, weight: .semibold)) // token-exempt: 头部状态图标小于 9pt
```

三处 7pt 加注释之后，`headerIndicator` 里不应再有不带 `token-exempt:` 的 `.font(.system(size:`。

---

## 步骤 4：`MenuBarSearchField.swift`

把

```swift
                                            .font(.system(size: 6.5, weight: .bold))
```

换成

```swift
                                            .font(.system(size: 6.5, weight: .bold)) // token-exempt: 芯片内移除角标小于 9pt
```

---

## 步骤 5：`MenuBarControls.swift`

把

```swift
                .font(.system(size: 11, weight: .bold, design: .serif))
```

换成

```swift
                .font(.system(size: 11, weight: .bold, design: .serif)) // token-exempt: 菜单栏标记用衬线，令牌是无衬线
```

把

```swift
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
```

换成

```swift
                    .font(.system(size: 12, weight: .semibold, design: .rounded)) // token-exempt: 菜单栏计数用圆体
```

---

## 步骤 6：`MenuBarFilterFlyout.swift`

一级分类里，图标字号：

```swift
                            .font(.system(size: 9.5, weight: isSelected ? .semibold : .regular))
```

换成

```swift
                            .font(DaybookType.micro.weight(isSelected ? .semibold : .regular))
```

标题字号：

```swift
                            .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular))
```

换成

```swift
                            .font(DaybookType.badge.weight(isSelected ? .semibold : .regular))
```

小箭头：

```swift
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.7))
```

换成

```swift
                            .font(.system(size: 7.5, weight: .bold)) // token-exempt: 小于 9pt 的筛选图标
                            .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookPalette.text.tertiary)
```

两处「清除筛选」的图标和文字相同。两处都改。

```swift
                            .font(.system(size: 8.5, weight: .semibold))
```

换成

```swift
                            .font(.system(size: 8.5, weight: .semibold)) // token-exempt: 小于 9pt 的筛选图标
```

```swift
                            .font(.system(size: 9.5))
```

换成

```swift
                            .font(DaybookType.micro)
```

二级卡片里缩进更深的那两处，同样替换：

```swift
                                .font(.system(size: 8.5, weight: .semibold))
```

换成

```swift
                                .font(.system(size: 8.5, weight: .semibold)) // token-exempt: 小于 9pt 的筛选图标
```

```swift
                                .font(.system(size: 9.5))
```

换成

```swift
                                .font(DaybookType.micro)
```

两处浮层圆角，把 `cornerRadius: 8` 换成 `cornerRadius: DaybookRadius.regular`。一共四处 `RoundedRectangle`，填充和描边各两处，都要换。不要改 `.fill` 和 `.daybookElevation`。

两处描边：

```swift
                .strokeBorder(DaybookTheme.rule.opacity(0.65), lineWidth: 0.8)
```

换成

```swift
                .strokeBorder(DaybookTheme.rule.opacity(0.65), lineWidth: 0.8) // token-exempt: 65% 分隔线没有对应令牌
```

`lineWidth: 0.8` 不要改成别的数字。

选项行里的图标：

```swift
                        .font(.system(size: 8.5, weight: .medium))
```

换成

```swift
                        .font(.system(size: 8.5, weight: .medium)) // token-exempt: 小于 9pt 的筛选图标
```

选项标题：

```swift
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
```

换成

```swift
                    .font(DaybookType.badge.weight(isSelected ? .semibold : .regular))
```

计数：

```swift
                        .font(.system(size: 8, weight: .bold, design: .rounded))
```

换成

```swift
                        .font(.system(size: 8, weight: .bold, design: .rounded)) // token-exempt: 小于 9pt 的筛选图标
```

勾：

```swift
                        .font(.system(size: 8, weight: .bold))
```

换成

```swift
                        .font(.system(size: 8, weight: .bold)) // token-exempt: 小于 9pt 的筛选图标
```

---

## 最终验证

```bash
# 1. 菜单栏里没有未豁免的字面字号（预期零输出）
rg -n '\.font\(\.system\(size:' AreaChain/Features/MenuBar | rg -v 'token-exempt:'

# 2. 菜单栏里没有字面圆角 8（预期零输出）
rg -n 'cornerRadius:\s*8\b' AreaChain/Features/MenuBar

# 3. 橙色和点击遮罩已换成令牌（预期零输出）
rg -n 'Color\.orange|Color\.black\.opacity\(0\.001\)' AreaChain/Features/MenuBar

# 4. 0.6/0.7/0.8 的 muted 和 0.18 的 stamp 已换（预期零输出）
rg -n 'muted\.opacity\(0\.[678]\)|stamp\.opacity\(0\.18\)' AreaChain/Features/MenuBar

# 5. 其他模块零 diff（预期零输出）
git diff --stat -- AreaChain/Features/Tasks AreaChain/Features/Diary AreaChain/Features/Workspace AreaChain/Theme

# 6. 测试没被删（两条都跑；预期零输出）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'

# 7. 测试
./scripts/build.sh test \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/MenuBarToolbarStateTests \
  --only-testing AreaChainTests/CaptureOverlayLayoutTests

# 8. 工作流检查
python3 -B scripts/check_workflow.py
```

第 1 条如果还有输出，就是漏改或漏了豁免注释，按上面对应步骤补，不要把小字号换成 `DaybookType.micro`。

第 7 条若失败且是「尺寸与预期不符」，不要改测试，贴出失败信息停下问我。

## 汇报格式

```
## P6 MenuBar 完成汇报
### 修改文件（路径 — 换了什么）
### 保留的 token-exempt 行（file:line — 注释）
### 验证输出（1–8 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P6 MenuBar` 改成 `- [x]`，决策记录追加 `- <日期> P6 MenuBar 完成：<一句话>`。

## 绝对不要做

- 不要改 Tasks、Diary、Workspace、Theme。
- 不要把 6.5、7、7.5、8、8.5 放成 `DaybookType.micro`（那是 9pt）。
- 不要去掉 `.serif` 和 `.rounded`。
- 不要新增字号或颜色令牌。
- 不要 commit。
