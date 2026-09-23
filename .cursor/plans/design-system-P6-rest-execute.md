# 任务：AreaChain 设计系统收敛 · 阶段 P6 其余页面（颜色、字号、圆角）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 只改下面点名的文件。它们在 `AreaChain/Features/` 的 Board、Calendar、Gantt、Quadrant、Search、Trash、Attachments、Settings 里。
2. 每一处都按给出的原文替换。不要看了规则自己去文件里找「类似的」再改。
3. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
4. 先读 `AGENTS.md`，再读本文。不要扫 MenuBar、Tasks、Diary、Workspace、Theme。
5. 做完不宣布「通过」。验收按 `design-system-P6-rest-verify.md`。
6. 圆体和 18pt 保持原字号。只在该行末尾加给出的 `// token-exempt:`，注释原文不要改。
7. 本阶段不删 `DaybookTheme`。这些页面继续写 `DaybookTheme.ink`、`muted`、`stamp`、`rule`、`cardSurface`。总计划里「模块目录下 `DaybookTheme` 为空」要等 P6 Theme 做完才要求。
8. 只改该步骤点名的文件。替换短字号时必须连结尾的 `)` 一起匹配。`.font(.system(size: 10))` 可以换。`.font(.system(size: 10, weight:` 不能用这句去换。
9. `.animation(.easeInOut(duration: 0.12)`、`Circle()`、`lineWidth` 的数字、已有的 `// token-exempt: 今日环、选中与投放三态` 和 `// token-exempt: 甘特色块是数据标记，不是卡片` 都不要删。

## 为什么有的换、有的不换

`DaybookType.micro` 是 9pt medium，`badge` 是 10pt medium，`label` 是 10pt semibold，`caption` 是 11pt medium，`subtitle` 是 12pt，`body` 是 13pt。差 0.5pt 以内才换字号。没有写 weight 的字面字号，换成对应令牌。写了 weight 的，用令牌再 `.weight(...)` 把原来的字重留住。

10pt semibold 用 `DaybookType.label`。10pt bold 用 `badge.weight(.bold)`，因为 `label` 是 semibold，不是 bold。11.5pt 用 `caption` 再保留原来的字重。

圆体没有对应令牌。18pt 没有对应令牌，`entity` 是 17pt，不要拿来凑。

颜色只换有现成令牌的：`Color.red` 换成 `DaybookPalette.status.danger`。`stamp` 的 12% 是 `DaybookPalette.accent.fill`。8%、85%、18%、40%、30%、6% 没有对应令牌，数字留下并写豁免。

日历格子和甘特色块继续自己画。不要改成 `daybookSurface`。圆角 6 是 `DaybookRadius.small`，4 是 `DaybookRadius.xs`，3.5 收到 `DaybookRadius.xs`（4），3 收到 `DaybookRadius.xxs`（2.5）。甘特色块换圆角令牌之后，原来的「数据标记，不是卡片」注释留着。

## 开始前必读

`AreaChain/Theme/DaybookTokens.swift` 里的 `DaybookType` 和 `DaybookRadius`。确认 `label` 是 10pt semibold，`xs` 是 4，`xxs` 是 2.5，`small` 是 6。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/GanttLayoutTests --only-testing AreaChainTests/QuadrantLayoutTests
```

---

## 步骤 1：`Board/BoardCommandStrip.swift`

提示气泡整段一起换：

```swift
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(isDestructive ? Color.red : DaybookTheme.ink.opacity(0.85))
            .lineLimit(1)
            .padding(.horizontal, 5)
            .frame(height: 18)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(isDestructive ? Color.red.opacity(0.08) : DaybookTheme.ink.opacity(0.06))
            )
```

换成

```swift
            .font(.system(size: 10, weight: .semibold, design: .rounded)) // token-exempt: 命令提示用圆体
            .foregroundStyle(isDestructive ? DaybookPalette.status.danger : DaybookTheme.ink.opacity(0.85)) // token-exempt: 85% 墨色没有对应令牌
            .lineLimit(1)
            .padding(.horizontal, 5)
            .frame(height: 18)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                    .fill(isDestructive ? DaybookPalette.status.danger.opacity(0.08) : DaybookTheme.ink.opacity(0.06)) // token-exempt: 8% 危险色和 6% 墨色没有对应令牌
            )
```

图标：

```swift
            .font(.system(size: 11.5, weight: .medium))
```

换成

```swift
            .font(DaybookType.caption.weight(.medium))
```

第 27 行 `.animation(.easeInOut(duration: 0.12), value: hoveredTip)` 不要改。

---

## 步骤 2：`Calendar/CalendarMonthGrid.swift`

把

```swift
                    .font(.system(size: 10, weight: .semibold))
```

换成

```swift
                    .font(DaybookType.label)
```

把

```swift
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
```

换成

```swift
                    .font(DaybookType.body.weight(selected ? .semibold : .regular))
```

把

```swift
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
```

换成

```swift
                    .font(.system(size: 9, weight: .semibold, design: .rounded)) // token-exempt: 日期计数用圆体
```

把

```swift
                    .fill(selected ? DaybookTheme.stamp.opacity(0.18) : DaybookTheme.cardSurface)
```

换成

```swift
                    .fill(selected ? DaybookTheme.stamp.opacity(0.18) : DaybookTheme.cardSurface) // token-exempt: 18% 印章底没有对应令牌
```

把

```swift
                    .stroke(today ? DaybookTheme.stamp : (selected ? DaybookTheme.stamp.opacity(0.4) : DaybookTheme.rule.opacity(0.3)), lineWidth: today ? 1.4 : 0.8)
```

换成

```swift
                    .stroke(today ? DaybookTheme.stamp : (selected ? DaybookTheme.stamp.opacity(0.4) : DaybookTheme.rule.opacity(0.3)), lineWidth: today ? 1.4 : 0.8) // token-exempt: 40% 印章色和 30% 分隔线没有对应令牌
```

三处 `// token-exempt: 今日环、选中与投放三态` 不要删。`lineWidth` 不要改。不要把格子改成 `daybookSurface`。

---

## 步骤 3：`Gantt/GanttPage.swift`

把

```swift
                    .font(.system(size: 9, weight: key == todayKey ? .semibold : .regular))
```

换成

```swift
                    .font(DaybookType.micro.weight(key == todayKey ? .semibold : .regular))
```

把

```swift
        .background(isSelected ? DaybookTheme.cardSelectionFill : Color.clear, in: RoundedRectangle(cornerRadius: 4))
```

换成

```swift
        .background(isSelected ? DaybookTheme.cardSelectionFill : Color.clear, in: RoundedRectangle(cornerRadius: DaybookRadius.xs))
```

把

```swift
                    .font(.system(size: 9, weight: .bold))
```

换成

```swift
                    .font(DaybookType.micro.weight(.bold))
```

`Circle()` 不要改。

把

```swift
        return RoundedRectangle(cornerRadius: 3, style: .continuous) // token-exempt: 甘特色块是数据标记，不是卡片
```

换成

```swift
        return RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous) // token-exempt: 甘特色块是数据标记，不是卡片
```

把

```swift
            .fill(filled ? DaybookTheme.stamp.opacity(0.85) : Color.clear)
```

换成

```swift
            .fill(filled ? DaybookTheme.stamp.opacity(0.85) : Color.clear) // token-exempt: 85% 印章色没有对应令牌
```

把

```swift
                RoundedRectangle(cornerRadius: 4) // token-exempt: 甘特色块是数据标记，不是卡片
```

换成

```swift
                RoundedRectangle(cornerRadius: DaybookRadius.xs) // token-exempt: 甘特色块是数据标记，不是卡片
```

`lineWidth: 1.5` 不要改。不要把色块改成 `daybookSurface`。

---

## 步骤 4：`Quadrant/QuadrantPage.swift`

把

```swift
                        .font(.system(size: 9, weight: .bold))
```

换成

```swift
                        .font(DaybookType.micro.weight(.bold))
```

---

## 步骤 5：`Search/BoardSearchHitRow.swift`

把

```swift
                .background(Capsule().fill(DaybookTheme.stamp.opacity(0.12)))
```

换成

```swift
                .background(Capsule().fill(DaybookPalette.accent.fill))
```

把

```swift
                    .font(.system(size: 11, weight: .bold))
```

换成

```swift
                    .font(DaybookType.caption.weight(.bold))
```

---

## 步骤 6：`Trash/TrashPage.swift`

把

```swift
                        .font(.system(size: 10, weight: .bold))
```

换成

```swift
                        .font(DaybookType.badge.weight(.bold))
```

把

```swift
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
```

换成

```swift
                        RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
```

---

## 步骤 7：`Attachments/AttachmentBrowserPage.swift`

两处精确等于 `.font(.system(size: 10))` 的行都换成 `.font(DaybookType.badge)`。一处是分组种类，一处是文件名。缩进保持不变。

把

```swift
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
```

换成

```swift
                .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
```

把

```swift
                .font(.system(size: 18))
```

换成

```swift
                .font(.system(size: 18)) // token-exempt: entity 是 17pt，这处是 18pt
```

把

```swift
                .font(.system(size: 12))
```

换成

```swift
                .font(DaybookType.subtitle)
```

---

## 步骤 8：`Settings/HotKeyRecorder.swift`

两处相同，都换成 `DaybookType.subtitle`。只改这个文件：

```swift
                    .font(.system(size: 12))
```

换成

```swift
                    .font(DaybookType.subtitle)
```

---

## 步骤 9：`Settings/PrivacySettingsSection.swift`

把

```swift
                            .font(.system(size: 11, weight: .semibold))
```

换成

```swift
                            .font(DaybookType.caption.weight(.semibold))
```

`.buttonStyle(.bordered)` 不要改。

---

## 最终验证

```bash
# 1. 这些目录里没有未豁免的字面字号（预期零输出）
rg -n '\.font\(\.system\(size:' \
  AreaChain/Features/Board \
  AreaChain/Features/Calendar \
  AreaChain/Features/Gantt \
  AreaChain/Features/Quadrant \
  AreaChain/Features/Search \
  AreaChain/Features/Trash \
  AreaChain/Features/Attachments \
  AreaChain/Features/Settings \
  | rg -v 'token-exempt:'

# 2. 字面圆角消失（预期零输出）
rg -n 'cornerRadius:\s*[0-9]' \
  AreaChain/Features/Board \
  AreaChain/Features/Calendar \
  AreaChain/Features/Gantt \
  AreaChain/Features/Quadrant \
  AreaChain/Features/Search \
  AreaChain/Features/Trash \
  AreaChain/Features/Attachments \
  AreaChain/Features/Settings

# 3. Color.red 消失（预期零输出）
rg -n 'Color\.red' AreaChain/Features/Board AreaChain/Features/Calendar AreaChain/Features/Gantt AreaChain/Features/Search AreaChain/Features/Trash AreaChain/Features/Attachments AreaChain/Features/Settings AreaChain/Features/Quadrant

# 4. 12% 印章底已换成令牌（预期零输出）
rg -n 'stamp\.opacity\(0\.12\)' AreaChain/Features/Search

# 5. 其他模块零 diff（预期零输出）
git diff --stat -- AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Diary AreaChain/Features/Workspace AreaChain/Theme

# 6. 测试没被删（两条都跑；预期零输出）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'

# 7. 测试
./scripts/build.sh test \
  --only-testing AreaChainTests/GanttLayoutTests \
  --only-testing AreaChainTests/GanttInteractionTests \
  --only-testing AreaChainTests/QuadrantLayoutTests \
  --only-testing AreaChainTests/PrivacyRenderingTests

# 8. 工作流检查
python3 -B scripts/check_workflow.py
```

第 1 条如果还有输出，就是漏改或漏了豁免注释。不要把 18pt 换成 `DaybookType.entity`。不要去掉 `.rounded`。

第 7 条若失败且是「尺寸与预期不符」，不要改测试，贴出失败信息停下问我。运行期间不要操作其他窗口。

## 汇报格式

```
## P6 其余页面完成汇报
### 修改文件（路径 — 换了什么）
### 保留的 token-exempt 行（file:line — 注释）
### 验证输出（1–8 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P6 Search / Calendar / Quadrant / Gantt / Trash / Attachments / Settings` 改成 `- [x]`，决策记录追加 `- <日期> P6 其余页面完成：<一句话>`。

## 绝对不要做

- 不要改 MenuBar、Tasks、Diary、Workspace、Theme。
- 不要把日历格子或甘特色块改成 `daybookSurface`。
- 不要删「今日环、选中与投放三态」和「甘特色块是数据标记，不是卡片」。
- 不要把甘特习惯点的 `Circle()` 改成圆角矩形。
- 不要改 `.animation(.easeInOut(duration: 0.12)`。
- 不要把 18pt 放成 `DaybookType.entity`。
- 不要去掉 `.rounded`。
- 不要改 `lineWidth` 的数字。
- 不要把 `.buttonStyle(.bordered)` 换成 `DaybookButtonStyle`。
- 不要 commit。
