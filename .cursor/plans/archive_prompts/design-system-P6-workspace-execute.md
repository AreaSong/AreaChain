# 任务：AreaChain 设计系统收敛 · 阶段 P6 Workspace（颜色、字号、圆角）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 只改 `AreaChain/Features/Workspace/` 里下面点名的文件。
2. 每一处都按给出的原文替换。不要看了规则自己去文件里找「类似的」再改。
3. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
4. 先读 `AGENTS.md`，再读本文。不要扫 MenuBar、Tasks、Diary、Theme。
5. 做完不宣布「通过」。验收按 `design-system-P6-workspace-verify.md`。
6. 圆体、等宽、36pt 保持原字号。只在该行末尾加给出的 `// token-exempt:`，注释原文不要改。
7. 本阶段不删 `DaybookTheme`。工作台里继续写 `DaybookTheme.ink`、`muted`、`stamp`、`rule`、`destructive`、`done`、`paper`、`hit`。总计划里「模块目录下 `DaybookTheme` 为空」要等 P6 Theme 做完才要求。
8. 替换短字号时，必须连结尾的 `)` 一起匹配。`.font(.system(size: 9))` 可以换。`.font(.system(size: 9, weight:` 不能用这句去换。带 `weight` 或 `design` 的行另有原文。
9. 同一文件里同一句出现几次，就换几次，缩进保持不变。只改该步骤点名的文件，不要在整个 Workspace 目录里替换。
10. `fontSize:` 参数、`.textFieldStyle(.roundedBorder)`、`.buttonStyle(.plain) // control:`、`Divider()` 上的 `.opacity`、隐藏快捷键按钮的 `.opacity(0)` 都不要改。

## 为什么有的换、有的不换

`DaybookType.micro` 是 9pt medium，`badge` 是 10pt medium，`label` 是 10pt semibold，`caption` 是 11pt medium，`subtitle` 是 12pt，`body` 是 13pt，`title` 是 16pt semibold。差 0.5pt 以内才换字号。没有写 weight 的字面字号，换成对应令牌。写了 weight 的，用令牌再 `.weight(...)` 把原来的字重留住。

10pt semibold 用 `DaybookType.label`，因为它就是 10pt semibold。10.5pt 用 `badge` 再保留原来的字重。11.5pt 用 `caption` 再保留原来的字重。

36pt light 不要放成 `DaybookType.display`。`display` 是 26pt。圆体和等宽没有对应令牌。

颜色只换有现成令牌的：选中星期圆点上的 `Color.white` 是 `DaybookPalette.text.onAccent`。火焰的 `.orange` 是 `DaybookPalette.status.pending`。废纸篓图标上 `destructive` 的 85% 换成 `DaybookPalette.status.danger`，85% 这个数字留下并写豁免。

下面这些没有对应令牌，只加豁免，不要改数字：`muted` 的 50%、60%、70%、80%；`rule` 的 18%、25%、30%；`stamp` 的 80%；`paper` 的 40%；象限色的 70%。`.yellow` 没有黄色令牌，不要改成 `status.pending`。

象限格的 `slot.themeFill`、`slot.themeColor`、`DaybookTheme.cardSurface` 保持原样。星期选择器继续用 `Circle()`，不要改成胶囊。

圆角：6 是 `DaybookRadius.small`，4 是 `DaybookRadius.xs`，3 和 2 收到 `DaybookRadius.xxs`（2.5）。`lineWidth` 的数字不要改。

## 开始前必读

`AreaChain/Theme/DaybookTokens.swift` 里的 `DaybookType` 和 `DaybookRadius`。确认 `label` 是 10pt semibold，`badge` 是 10pt medium，`xxs` 是 2.5，`xs` 是 4，`small` 是 6。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/WorkspaceLayoutTests --only-testing AreaChainTests/WorkspaceRenderingTests
```

---

## 步骤 1：`WorkspaceHeaderBar.swift`

把

```swift
                .font(.system(size: 11.5, weight: .medium))
```

换成

```swift
                .font(DaybookType.caption.weight(.medium))
```

把

```swift
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.6))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DaybookTheme.rule.opacity(0.18))
                    )
```

换成

```swift
                    .font(.system(size: 9.5, weight: .bold, design: .rounded)) // token-exempt: 快捷键提示用圆体
                    .foregroundStyle(DaybookTheme.muted.opacity(0.6)) // token-exempt: 60% 次要色没有对应令牌
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: DaybookRadius.xxs)
                            .fill(DaybookTheme.rule.opacity(0.18)) // token-exempt: 18% 分隔线没有对应令牌
                    )
```

第 109 行 `.opacity(0)` 是隐藏 ⌘F 按钮，不是颜色。不要改，也不要加注释。

---

## 步骤 2：`WorkspaceFilteredListView.swift`

把

```swift
                        .font(.system(size: 9, weight: .bold))
```

换成

```swift
                        .font(DaybookType.micro.weight(.bold))
```

把

```swift
                        .font(.system(size: 11, weight: .medium))
```

换成

```swift
                        .font(DaybookType.caption.weight(.medium))
```

三处 `Divider().padding(.leading, 36).opacity(...)` 是列表分隔线显隐。不要改，也不要加注释。`.buttonStyle(.plain) // control: 已完成折叠头，整行点击` 不要改。

---

## 步骤 3：`TaskDetailQuadrantGrid.swift`

把

```swift
                        .font(.system(size: 11, weight: .semibold))
```

换成

```swift
                        .font(DaybookType.caption.weight(.semibold))
```

把

```swift
                            .font(.system(size: 9, weight: .heavy))
```

换成

```swift
                            .font(DaybookType.micro.weight(.heavy))
```

把

```swift
                    .font(.system(size: 9))
```

换成

```swift
                    .font(DaybookType.micro)
```

这一处是象限副标题，行尾就是 `)`，不是带 weight 的那一行。

把

```swift
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? slot.themeFill : DaybookTheme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isActive ? slot.themeColor.opacity(0.7) : DaybookTheme.rule.opacity(0.25), lineWidth: isActive ? 1.2 : 0.6)
                    )
            )
```

换成

```swift
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(isActive ? slot.themeFill : DaybookTheme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                            .stroke(isActive ? slot.themeColor.opacity(0.7) : DaybookTheme.rule.opacity(0.25), lineWidth: isActive ? 1.2 : 0.6) // token-exempt: 象限色 70% 和分隔线 25% 没有对应令牌
                    )
            )
```

`slot.themeFill`、`slot.themeColor`、`DaybookTheme.cardSurface` 不要改成印章色。`.buttonStyle(.plain) // control: 象限选择格保留象限色，不进通用表面` 不要改。`lineWidth` 不要改。

---

## 步骤 4：`TaskDetailSubtasksView.swift`

把

```swift
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
```

换成

```swift
                    .font(.system(size: 10, weight: .medium, design: .monospaced)) // token-exempt: 子任务计数用等宽
```

进度条整段一起换：

```swift
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(DaybookTheme.rule.opacity(0.3))
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(completedCount == totalCount ? DaybookTheme.stamp : DaybookTheme.stamp.opacity(0.8))
```

换成

```swift
                RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                    .fill(DaybookTheme.rule.opacity(0.3)) // token-exempt: 30% 分隔线没有对应令牌
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                    .fill(completedCount == totalCount ? DaybookTheme.stamp : DaybookTheme.stamp.opacity(0.8)) // token-exempt: 80% 印章色没有对应令牌
```

两处精确等于 `.font(.system(size: 11))` 的行都换成 `.font(DaybookType.caption)`。一处是加号，一处是子任务标题。不要动带 weight 的行。

把

```swift
                        .font(.system(size: 10, weight: .medium))
```

换成

```swift
                        .font(DaybookType.badge.weight(.medium))
```

这一句行尾是 `)`，不是上面那句等宽字体。

把

```swift
            RoundedRectangle(cornerRadius: 4, style: .continuous)
```

换成

```swift
            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
```

把

```swift
                .font(.system(size: 12))
```

换成

```swift
                .font(DaybookType.subtitle)
```

把

```swift
                    .foregroundStyle(subtask.isDone ? DaybookTheme.muted.opacity(0.7) : DaybookTheme.ink)
                    .strikethrough(subtask.isDone, color: DaybookTheme.muted.opacity(0.5))
```

换成

```swift
                    .foregroundStyle(subtask.isDone ? DaybookTheme.muted.opacity(0.7) : DaybookTheme.ink) // token-exempt: 70% 次要色没有对应令牌
                    .strikethrough(subtask.isDone, color: DaybookTheme.muted.opacity(0.5)) // token-exempt: 50% 次要色没有对应令牌
```

`.buttonStyle(.plain) // control: 子任务复选框，非按钮语义` 不要改。

---

## 步骤 5：`TaskDetailHeaderSection.swift`

把

```swift
                    .font(.system(size: 13, weight: .bold))
```

换成

```swift
                    .font(DaybookType.body.weight(.bold))
```

只改这个文件。`TaskDetailScheduleSection.swift` 里还有两处相同字号，留给步骤 7。

把

```swift
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DaybookTheme.destructive.opacity(0.85))
```

换成

```swift
                    .font(DaybookType.subtitle.weight(.semibold))
                    .foregroundStyle(DaybookPalette.status.danger.opacity(0.85)) // token-exempt: 85% 危险色没有对应令牌
```

把

```swift
                        .font(.system(size: 11, weight: .bold))
```

换成

```swift
                        .font(DaybookType.caption.weight(.bold))
```

本文件两处精确等于 `.font(.system(size: 9))` 的行都换成 `.font(DaybookType.micro)`。两处精确等于 `.font(.system(size: 10))` 的行都换成 `.font(DaybookType.badge)`。缩进保持不变。不要动带 weight 的行。`DaybookTheme.hit` 不要改。

---

## 步骤 6：`TaskDetailClassificationSection.swift`

把

```swift
                        .font(.system(size: 11))
```

这一句在文件夹图标上。本文件还有一处错误文案也是精确的 `.font(.system(size: 11))`。两处都换成 `.font(DaybookType.caption)`。

把

```swift
                        .font(.system(size: 11.5))
```

换成

```swift
                        .font(DaybookType.caption)
```

把

```swift
                        .font(.system(size: 9))
```

换成

```swift
                        .font(DaybookType.micro)
```

这一处是项目菜单的上下箭头。

把

```swift
                    .font(.system(size: 10))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.7))
```

换成

```swift
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookTheme.muted.opacity(0.7)) // token-exempt: 70% 次要色没有对应令牌
```

把

```swift
                            tint: Color(nsColor: .systemIndigo),
```

换成

```swift
                            tint: Color(nsColor: .systemIndigo), // token-exempt: 没有靛蓝令牌
```

不要改成印章色或 `status.pending`。

把

```swift
                .font(.system(size: 13, weight: .semibold))
```

换成

```swift
                .font(DaybookType.body.weight(.semibold))
```

`.textFieldStyle(.roundedBorder)` 不要改。

---

## 步骤 7：`TaskDetailScheduleSection.swift`

按下面的顺序做。

日期：

```swift
                    .font(.system(size: 10, weight: .medium))
```

换成

```swift
                    .font(DaybookType.badge.weight(.medium))
```

这一句行尾是 `)`。不要用它去改下面的等宽提醒时间。

提醒时间：

```swift
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
```

换成

```swift
                        .font(.system(size: 10, weight: .bold, design: .monospaced)) // token-exempt: 提醒时刻用等宽
```

星期标题和连击标题两处相同，都换成 `DaybookType.label`：

```swift
                    .font(.system(size: 10, weight: .semibold))
```

和

```swift
                .font(.system(size: 10, weight: .semibold))
```

缩进不同，两处都换，缩进保持不变。

星期符号：

```swift
                            .font(.system(size: 10.5, weight: .medium))
```

换成

```swift
                            .font(DaybookType.badge.weight(.medium))
```

选中字色：

```swift
                            .foregroundStyle(isSelected ? Color.white : DaybookTheme.ink)
```

换成

```swift
                            .foregroundStyle(isSelected ? DaybookPalette.text.onAccent : DaybookTheme.ink)
```

`Circle()` 和 `.buttonStyle(.plain) // control: 星期圆点选择器，不是胶囊` 不要改。

本文件三处精确等于 `.font(.system(size: 9))` 的行都换成 `.font(DaybookType.micro)`。两处精确等于 `.font(.system(size: 10))` 的「天」都换成 `.font(DaybookType.badge)`。五处精确等于 `.font(.system(size: 11))` 的状态图标都换成 `.font(DaybookType.caption)`。不要动带 weight 或 design 的行。

两处

```swift
                    .font(.system(size: 13, weight: .bold))
```

都换成

```swift
                    .font(DaybookType.body.weight(.bold))
```

两处

```swift
                    .font(.system(size: 16, weight: .bold, design: .rounded))
```

都换成

```swift
                    .font(.system(size: 16, weight: .bold, design: .rounded)) // token-exempt: 连击数字用圆体
```

火焰：

```swift
                    .foregroundStyle(.orange)
```

换成

```swift
                    .foregroundStyle(DaybookPalette.status.pending)
```

奖杯：

```swift
                    .foregroundStyle(.yellow)
```

换成

```swift
                    .foregroundStyle(.yellow) // token-exempt: 没有黄色令牌
```

状态文案：

```swift
                    .font(.system(size: 11, weight: .medium))
```

换成

```swift
                    .font(DaybookType.caption.weight(.medium))
```

`Divider().opacity(0.2)` 和后面 `.frame(height: 28)` 那条 `Divider()` 的 `.opacity(0.3)` 是分隔线显隐。不要改，也不要加注释。

---

## 步骤 8：`WorkspaceSidebarView.swift`

把

```swift
                    .font(.system(size: 11))
```

换成

```swift
                    .font(DaybookType.caption)
```

`.textFieldStyle(.roundedBorder)` 不要改。

---

## 步骤 9：`TaskDetailDrawer.swift`

把

```swift
                DaybookTheme.paper.opacity(0.4)
```

换成

```swift
                DaybookTheme.paper.opacity(0.4) // token-exempt: 40% 纸色没有对应令牌
```

把

```swift
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(DaybookTheme.muted.opacity(0.5))
```

换成

```swift
                .font(.system(size: 36, weight: .light)) // token-exempt: display 是 26pt，这处是 36pt light
                .foregroundStyle(DaybookTheme.muted.opacity(0.5)) // token-exempt: 50% 次要色没有对应令牌
```

把

```swift
                .foregroundStyle(DaybookTheme.muted.opacity(0.8))
```

换成

```swift
                .foregroundStyle(DaybookTheme.muted.opacity(0.8)) // token-exempt: 80% 次要色没有对应令牌
```

把

```swift
                    .font(.system(size: 12, weight: .medium))
```

换成

```swift
                    .font(DaybookType.subtitle.weight(.medium))
```

把

```swift
                    .font(.system(size: 10.5, weight: .semibold))
```

换成

```swift
                    .font(DaybookType.badge.weight(.semibold))
```

`.ultraThinMaterial` 不要改成纸色。

---

## 步骤 10：`TaskDetailNotesView.swift`

把

```swift
                    .font(.system(size: 9))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.6))
```

换成

```swift
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookTheme.muted.opacity(0.6)) // token-exempt: 60% 次要色没有对应令牌
```

把

```swift
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.7))
```

换成

```swift
                    .font(DaybookType.micro.weight(.medium))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.7)) // token-exempt: 70% 次要色没有对应令牌
```

---

## 步骤 11：`TaskDetailSections.swift`

把

```swift
                            .font(.system(size: 16))
```

换成

```swift
                            .font(DaybookType.title)
```

---

## 最终验证

```bash
# 1. 工作台里没有未豁免的字面字号（预期零输出）
rg -n '\.font\(\.system\(size:' AreaChain/Features/Workspace | rg -v 'token-exempt:'

# 2. 字面圆角消失（预期零输出）
rg -n 'cornerRadius:\s*[0-9]' AreaChain/Features/Workspace

# 3. 已点名的系统色消失（预期零输出）
rg -n 'Color\.white|foregroundStyle\(\.orange\)' AreaChain/Features/Workspace

# 4. 新写法确实出现（预期各至少 1）
rg -c 'DaybookPalette\.text\.onAccent' AreaChain/Features/Workspace/TaskDetailScheduleSection.swift
rg -c 'DaybookPalette\.status\.pending' AreaChain/Features/Workspace/TaskDetailScheduleSection.swift
rg -c 'DaybookPalette\.status\.danger' AreaChain/Features/Workspace/TaskDetailHeaderSection.swift
rg -c 'DaybookType\.label' AreaChain/Features/Workspace/TaskDetailScheduleSection.swift
rg -c 'DaybookRadius\.small' AreaChain/Features/Workspace/TaskDetailQuadrantGrid.swift
rg -c 'DaybookRadius\.xxs' AreaChain/Features/Workspace/TaskDetailSubtasksView.swift

# 5. 其他模块零 diff（预期零输出）
git diff --stat -- AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Diary AreaChain/Theme

# 6. 测试没被删（两条都跑；预期零输出）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'

# 7. 测试
./scripts/build.sh test \
  --only-testing AreaChainTests/WorkspaceLayoutTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/CaptureOverlayLayoutTests

# 8. 工作流检查
python3 -B scripts/check_workflow.py
```

第 1 条如果还有输出，就是漏改或漏了豁免注释。不要把 36pt 换成 `DaybookType.display`。不要去掉 `.rounded` 和 `.monospaced`。

第 7 条若失败且是「尺寸与预期不符」，不要改测试，贴出失败信息停下问我。运行期间不要操作其他窗口。

## 汇报格式

```
## P6 Workspace 完成汇报
### 修改文件（路径 — 换了什么）
### 保留的 token-exempt 行（file:line — 注释）
### 验证输出（1–8 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P6 Workspace` 改成 `- [x]`，决策记录追加 `- <日期> P6 Workspace 完成：<一句话>`。

## 绝对不要做

- 不要改 MenuBar、Tasks、Diary、Theme。
- 不要把象限格的 `slot.themeFill` / `slot.themeColor` 换成印章色。
- 不要把星期 `Circle()` 改成胶囊或 `DaybookChip`。
- 不要把 `.yellow` 改成 `status.pending`。
- 不要把 `Color(nsColor: .systemIndigo)` 换成别的颜色。
- 不要把 36pt 放成 `DaybookType.display`。
- 不要去掉 `.rounded` 和 `.monospaced`。
- 不要改 `fontSize:`、`lineWidth`、`DaybookTheme.hit`、`.ultraThinMaterial`、`.roundedBorder`。
- 不要给 `Divider()` 的透明度或 `.opacity(0)` 快捷键按钮加注释或改数字。
- 不要删掉 `.buttonStyle(.plain)` 后面的 `// control:`。
- 不要 commit。
