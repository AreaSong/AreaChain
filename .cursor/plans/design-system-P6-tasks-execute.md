# 任务：AreaChain 设计系统收敛 · 阶段 P6 Tasks（颜色、字号、圆角）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 只改 `AreaChain/Features/Tasks/` 里下面点名的文件。
2. 每一处都按给出的原文替换。不要看了规则自己去文件里找「类似的」再改。
3. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
4. 先读 `AGENTS.md`，再读本文。不要扫 MenuBar、Diary、Workspace、Theme。
5. 做完不宣布「通过」。验收按 `design-system-P6-tasks-verify.md`。
6. 小于 9pt 的图标、圆体、等宽字体，保持原字号。只在该行末尾加给出的 `// token-exempt:`，注释原文不要改。
7. 本阶段不删 `DaybookTheme`。任务行里继续写 `DaybookTheme.ink`、`muted`、`stamp`、`rule`。总计划里「模块目录下 `DaybookTheme` 为空」要等 P6 Theme 做完才要求。
8. 同一文件里有多处相同原文时，按该步骤从上到下替换。先换更长的那一段，再换剩下的短行，否则短行先被换掉，长段就对不上。

## 为什么有的换、有的不换

`DaybookType.micro` 是 9pt，`badge` 是 10pt，`caption` 是 11pt，`subtitle` 是 12pt，`body` 是 13pt。差 0.5pt 以内就换。8.5、8、7.5 放成 9pt 会把筛选小箭头和计数挤大，所以豁免。圆体和等宽没有对应令牌，也豁免。

颜色只换有现成令牌的：`muted` 的 75% 是 `DaybookPalette.text.tertiary`，`stamp` 的 35% 是 `DaybookPalette.accent.border`，`stamp` 的 12% 是 `DaybookPalette.accent.fill`，`Color.orange` 是 `DaybookPalette.status.pending`。其他透明度没有对应令牌，只加豁免注释，不要改数字。

圆角：10 是 `DaybookRadius.medium`，3.5 收到 `DaybookRadius.xs`（4），3 收到 `DaybookRadius.xxs`（2.5），2.5 就是 `DaybookRadius.xxs`。

## 开始前必读

`AreaChain/Theme/DaybookTokens.swift` 里的 `DaybookType` 和 `DaybookRadius`。确认上面的数字还是这些。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/TaskRowInteractionTests --only-testing AreaChainTests/BoardFilterBarTests
```

---

## 步骤 1：`TaskRow+Menus.swift`

两处相同，都换：

```swift
                .font(.system(size: 11, weight: .semibold))
```

换成

```swift
                .font(DaybookType.caption.weight(.semibold))
```

一处在复制按钮，一处在更多菜单的省略号上。两处都要换。

---

## 步骤 2：`BatchActionBar.swift`

把

```swift
                .font(.system(size: 13))
```

换成

```swift
                .font(DaybookType.body)
```

把

```swift
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
```

换成

```swift
                .font(.system(size: 12, weight: .semibold, design: .monospaced)) // token-exempt: 批量计数用等宽，令牌是无衬线
```

下面五处相同，全部换成 `DaybookType.caption`：

```swift
                .font(.system(size: 11))
```

```swift
                    .font(.system(size: 11))
```

注意缩进有 16 格和 20 格两种，字号换成 `DaybookType.caption` 后缩进保持不变。五处分别在日期、状态、项目、标签菜单和移入废纸篓按钮上。

两处

```swift
        RoundedRectangle(cornerRadius: 10, style: .continuous)
```

和

```swift
                RoundedRectangle(cornerRadius: 10, style: .continuous)
```

里的 `cornerRadius: 10` 换成 `cornerRadius: DaybookRadius.medium`。

把

```swift
                    .stroke(DaybookTheme.stamp.opacity(0.35), lineWidth: 1)
```

换成

```swift
                    .stroke(DaybookPalette.accent.border, lineWidth: 1)
```

---

## 步骤 3：`TasksPage+Sections.swift`

把

```swift
                    .font(.system(size: 9.5, weight: .semibold))
```

换成

```swift
                    .font(DaybookType.micro.weight(.semibold))
```

把

```swift
                    .background(DaybookTheme.stamp.opacity(0.14))
```

换成

```swift
                    .background(DaybookTheme.stamp.opacity(0.14)) // token-exempt: 14% 印章底没有对应令牌
```

把

```swift
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
```

换成

```swift
                    .font(.system(size: 9.5, weight: .bold, design: .rounded)) // token-exempt: 遗留计数用圆体
```

---

## 步骤 4：`BoardFilterBar.swift`

把第 45 行

```swift
            .font(.system(size: 11))
```

换成

```swift
            .font(DaybookType.caption)
```

`standardCapsule` 和 `FilterDropdownItemRow` 各有一处下面这行，两处都要换。只改 `BoardFilterBar.swift`，不要在整个 Tasks 目录里替换：

```swift
                        .font(.system(size: 9.5, weight: .medium))
```

换成

```swift
                        .font(DaybookType.micro.weight(.medium))
```

`standardCapsule` 里标题：

```swift
                        .font(.system(size: 11, weight: active ? .semibold : .regular))
```

换成

```swift
                        .font(DaybookType.caption.weight(active ? .semibold : .regular))
```

```swift
                        .font(.system(size: 8, weight: .bold))
```

换成

```swift
                        .font(.system(size: 8, weight: .bold)) // token-exempt: 小于 9pt 的筛选图标
```

```swift
                        .font(.system(size: 7.5, weight: .bold))
```

换成

```swift
                        .font(.system(size: 7.5, weight: .bold)) // token-exempt: 小于 9pt 的筛选图标
```

```swift
        .background(Capsule().fill(active ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.ink.opacity(0.05)))
        .overlay(Capsule().stroke(active ? DaybookTheme.stamp.opacity(0.35) : DaybookTheme.rule.opacity(0.5), lineWidth: 0.8))
```

换成

```swift
        .background(Capsule().fill(active ? DaybookPalette.accent.fill : DaybookTheme.ink.opacity(0.05))) // token-exempt: 5% 墨色底没有对应令牌
        .overlay(Capsule().stroke(active ? DaybookPalette.accent.border : DaybookTheme.rule.opacity(0.5), lineWidth: 0.8)) // token-exempt: 50% 分隔线没有对应令牌
```

`lineWidth: 0.8` 不要改。

`FilterDropdownItemRow` 里：

```swift
                        .font(.system(size: 8.5, weight: .bold))
```

换成

```swift
                        .font(.system(size: 8.5, weight: .bold)) // token-exempt: 小于 9pt 的筛选图标
```

```swift
                        .font(.system(size: 9, weight: .bold, design: .rounded))
```

换成

```swift
                        .font(.system(size: 9, weight: .bold, design: .rounded)) // token-exempt: 下拉计数用圆体
```

```swift
                        .background(item.isSelected ? DaybookTheme.stamp.opacity(0.20) : DaybookTheme.ink.opacity(0.06))
```

换成

```swift
                        .background(item.isSelected ? DaybookTheme.stamp.opacity(0.20) : DaybookTheme.ink.opacity(0.06)) // token-exempt: 20% 与 6% 没有对应令牌
```

---

## 步骤 5：`TaskRow+Badges.swift`

按下面的顺序做。

先换连击火焰这两行（文件里只有这一处 `Color.orange` 紧跟在字号后面）：

```swift
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(isHighlighted ? Color.orange : DaybookTheme.muted.opacity(0.75))
```

换成

```swift
                .font(DaybookType.micro.weight(.semibold))
                .foregroundStyle(isHighlighted ? DaybookPalette.status.pending : DaybookPalette.text.tertiary)
```

再换连击数字：

```swift
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(isHighlighted ? DaybookTheme.ink : DaybookTheme.muted.opacity(0.75))
```

换成

```swift
                .font(.system(size: 10, weight: .bold, design: .rounded)) // token-exempt: 连击数字用圆体
                .foregroundStyle(isHighlighted ? DaybookTheme.ink : DaybookPalette.text.tertiary)
```

再换连击底：

```swift
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(isHighlighted ? Color.orange.opacity(0.12) : Color.clear)
```

换成

```swift
            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                .fill(isHighlighted ? DaybookPalette.status.pending.opacity(0.12) : Color.clear) // token-exempt: 待办橙 12% 底没有单独令牌
```

然后把剩下的标签字号换掉。此时文件里只剩标签这一处：

```swift
                        .font(.system(size: 9.5, weight: .semibold))
```

换成

```swift
                        .font(DaybookType.micro.weight(.semibold))
```

剩下四处 `cornerRadius: 3.5` 都换成 `cornerRadius: DaybookRadius.xs`。两处在标签芯片，两处在溢出的 `+N`。

溢出计数：

```swift
                        .font(.system(size: 9, weight: .bold, design: .rounded))
```

换成

```swift
                        .font(.system(size: 9, weight: .bold, design: .rounded)) // token-exempt: 标签溢出计数用圆体
```

第 127 行 `.opacity(isHovered || state.isSelected ? 1.0 : 0.65)` 是整行显隐，不是颜色。不要改，也不要加注释。

---

## 步骤 6：`TaskRow.swift`

备注图标：

```swift
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(hasNoteCopied ? DaybookTheme.stamp : (isNoteHovered ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.65)))
```

换成

```swift
            .font(DaybookType.micro.weight(.medium))
            .foregroundStyle(hasNoteCopied ? DaybookTheme.stamp : (isNoteHovered ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.65))) // token-exempt: 65% 次要色没有对应令牌
```

圆角：

```swift
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(hasNoteCopied ? DaybookTheme.stamp.opacity(0.16) : (isNoteHovered ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.ink.opacity(0.04)))
```

换成

```swift
                RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                    .fill(hasNoteCopied ? DaybookTheme.stamp.opacity(0.16) : (isNoteHovered ? DaybookPalette.accent.fill : DaybookTheme.ink.opacity(0.04))) // token-exempt: 16% 与 4% 没有对应令牌
```

三处次要色：

```swift
                        .foregroundStyle(DaybookTheme.muted.opacity(0.85))
```

换成

```swift
                        .foregroundStyle(DaybookTheme.muted.opacity(0.85)) // token-exempt: 85% 次要色没有对应令牌
```

```swift
                        .foregroundStyle(DaybookTheme.stamp.opacity(0.85))
```

换成

```swift
                        .foregroundStyle(DaybookTheme.stamp.opacity(0.85)) // token-exempt: 85% 印章色没有对应令牌
```

```swift
                        .foregroundStyle(DaybookTheme.muted.opacity(0.75))
```

换成

```swift
                        .foregroundStyle(DaybookPalette.text.tertiary)
```

---

## 步骤 7：`DayBoardSections.swift`

把

```swift
                .font(.system(size: 13, weight: .semibold))
```

换成

```swift
                .font(DaybookType.body.weight(.semibold))
```

把

```swift
                .foregroundStyle(DaybookTheme.ink.opacity(0.85))
```

换成

```swift
                .foregroundStyle(DaybookTheme.ink.opacity(0.85)) // token-exempt: 85% 墨色没有对应令牌
```

把

```swift
                .fill(DaybookTheme.stamp.opacity(0.05))
```

换成

```swift
                .fill(DaybookTheme.stamp.opacity(0.05)) // token-exempt: 5% 印章底没有对应令牌
```

把

```swift
                .strokeBorder(DaybookTheme.stamp.opacity(0.12), lineWidth: 0.8)
```

换成

```swift
                .strokeBorder(DaybookPalette.accent.fill, lineWidth: 0.8)
```

把

```swift
                        .font(.system(size: 9, weight: .bold))
```

换成

```swift
                        .font(DaybookType.micro.weight(.bold))
```

`openItemsSection` 里两处 `Divider()` 后面的 `.opacity(0.35)` 是列表分隔线显隐，不是颜色。不要改，也不要加注释。

---

## 步骤 8：其余五个小文件

`AttachmentThumbnails.swift`：

```swift
                    .font(.system(size: 12))
```

换成

```swift
                    .font(DaybookType.subtitle)
```

```swift
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
```

换成

```swift
                    .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous))
```

```swift
                .font(.system(size: 10))
```

换成

```swift
                .font(DaybookType.badge)
```

`DayScheduleMenu.swift`：

```swift
                .font(.system(size: 11))
```

换成

```swift
                .font(DaybookType.caption)
```

`TasksPage+Header.swift`：

```swift
                        .font(.system(size: 7.5, weight: .bold))
```

换成

```swift
                        .font(.system(size: 7.5, weight: .bold)) // token-exempt: 芯片内移除角标小于 9pt
```

`TaskRowSubtaskMiniViews.swift`：

```swift
                                .strokeBorder(subtask.isDone ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.4), lineWidth: 1.2)
```

换成

```swift
                                .strokeBorder(subtask.isDone ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.4), lineWidth: 1.2) // token-exempt: 40% 次要色没有对应令牌
```

`DaybookProgressRing.swift`：

```swift
                .stroke(DaybookTheme.rule.opacity(0.35), lineWidth: lineWidth)
```

换成

```swift
                .stroke(DaybookTheme.rule.opacity(0.35), lineWidth: lineWidth) // token-exempt: 35% 分隔线没有对应令牌
```

```swift
                            DaybookTheme.stamp.opacity(0.75),
```

换成

```swift
                            DaybookTheme.stamp.opacity(0.75), // token-exempt: 75% 印章色没有对应令牌
```

```swift
                .font(.system(size: 10, weight: .bold, design: .rounded))
```

换成

```swift
                .font(.system(size: 10, weight: .bold, design: .rounded)) // token-exempt: 进度环数字用圆体
```

---

## 最终验证

```bash
# 1. 任务模块里没有未豁免的字面字号（预期零输出）
rg -n '\.font\(\.system\(size:' AreaChain/Features/Tasks | rg -v 'token-exempt:'

# 2. 已点名的字面圆角消失（预期零输出）
rg -n 'cornerRadius:\s*(10|3\.5|3|2\.5)\b' AreaChain/Features/Tasks

# 3. 橙色已换成令牌（预期零输出）
rg -n 'Color\.orange' AreaChain/Features/Tasks

# 4. 已点名的透明度已换（预期零输出）
rg -n 'muted\.opacity\(0\.75\)|stamp\.opacity\(0\.35\)|stamp\.opacity\(0\.12\)' AreaChain/Features/Tasks

# 5. 其他模块零 diff（预期零输出）
git diff --stat -- AreaChain/Features/MenuBar AreaChain/Features/Diary AreaChain/Features/Workspace AreaChain/Theme

# 6. 测试没被删（两条都跑；预期零输出）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'

# 7. 测试
./scripts/build.sh test \
  --only-testing AreaChainTests/TaskRowInteractionTests \
  --only-testing AreaChainTests/TaskRowBubbleTests \
  --only-testing AreaChainTests/BoardFilterBarTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests

# 8. 工作流检查
python3 -B scripts/check_workflow.py
```

第 1 条如果还有输出，就是漏改或漏了豁免注释。不要把小于 9pt 的字号换成 `DaybookType.micro`。

第 7 条若失败且是「尺寸与预期不符」，不要改测试，贴出失败信息停下问我。

## 汇报格式

```
## P6 Tasks 完成汇报
### 修改文件（路径 — 换了什么）
### 保留的 token-exempt 行（file:line — 注释）
### 验证输出（1–8 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P6 Tasks` 改成 `- [x]`，决策记录追加 `- <日期> P6 Tasks 完成：<一句话>`。

## 绝对不要做

- 不要改 MenuBar、Diary、Workspace、Theme。
- 不要把 7.5、8、8.5 放成 `DaybookType.micro`。
- 不要去掉 `.rounded` 和 `.monospaced`。
- 不要新增字号或颜色令牌。
- 不要改 `lineWidth` 的数字。
- 不要 commit。
