# 任务：AreaChain 设计系统收敛 · 阶段 P4b（浮层阴影与剩余自绘表面）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 严格按步骤顺序执行；每个"检查点"必须跑通再进下一步；修不好就停下来问我。
2. 只改本文列出的文件。代码块原样粘贴。
3. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
4. 先读 `AGENTS.md`，再读 `.cursor/plans/design-system.md` 的「P4b」段，再读本文。
5. 做完不宣布"通过"。验收按 `design-system-P4b-verify.md`。
6. **不要改** `AreaChain/Theme/DaybookSurface.swift` 的 variant、颜色和描边。不要新增 `.cell`。

## 背景

P4a 已有 `daybookSurface`（`.row` / `.card` / `.panel` / `.banner`）和 `daybookElevation`（`.flat` / `.raised` / `.floating`）。`.floating` 就是用户定的浮层阴影：黑 14%、模糊 8、下偏 2。`.raised` 是黑 8%、模糊 1.5、下偏 0.5。

现在还有 12 处手写 `.shadow(color:`，以及几块自己画的圆角底。本阶段只做两件事：阴影换成 `daybookElevation`；能对上现有 variant 的表面换成 `daybookSurface`。

**故意不换的三块**（表面基座没有它们的第三态）：

- 象限选择格：选中色是该象限自己的红/橙/蓝，不是通用选中蓝。
- 日历日格：同一格要同时表达「今天的环」「选中」「拖放目标」。
- 甘特色块：色块本身就是数据标记，不是卡片。

这三块保持自绘，只改注释。

## 开始前必读

1. `AreaChain/Theme/DaybookElevation.swift` 全文。
2. `AreaChain/Theme/DaybookSurface.swift` 里 `daybookSurface` 的参数（`variant`、`isHovered`、`isSelected`、`configure`）。
3. 下面步骤里点名的每个调用点，改之前先读那一个属性，确认字符串还在。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/DaybookSurfaceTests --only-testing AreaChainTests/MenuBarPopoverRenderingTests --only-testing AreaChainTests/WorkspaceRenderingTests
```

---

## 步骤 1：12 处阴影

每一处只替换 `.shadow(...)` 那一行，前后的 `fill`、`stroke`、`clipShape`、材质背景都不要动。

### 1.1 分段栏滑块 → `.raised`（参数与现在完全相同）

`AreaChain/Features/MenuBar/MenuBarControls.swift`：

```swift
.shadow(color: Color.black.opacity(0.08), radius: 1.5, x: 0, y: 0.5)
```

→

```swift
.daybookElevation(.raised)
```

### 1.2 其余 11 处 → `.floating`

按文件把对应那一行换成 `.daybookElevation(.floating)`。缩进保持和原来的 `.shadow` 一样。

- `AreaChain/Features/MenuBar/MenuBarFilterFlyout.swift` 两处：`.shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 2)`
- `AreaChain/Features/Tasks/BatchActionBar.swift`：`.shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)`
- `AreaChain/Theme/SyntaxHelpCard.swift`：`.shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 5)`
- `AreaChain/Theme/SyntaxAutocompleteView.swift`：`.shadow(color: DaybookTheme.ink.opacity(0.12), radius: 8, x: 0, y: 4)`
- `AreaChain/Theme/CaptureAttributesView.swift`：`.shadow(color: DaybookTheme.ink.opacity(0.12), radius: 8, x: 0, y: 4)`
- `AreaChain/Theme/LiveComposerPreviewHeader.swift` 两处：第 177 行 `.shadow(color: DaybookTheme.ink.opacity(0.10), radius: 6, x: 0, y: 3)`，第 297 行 `.shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)`
- `AreaChain/Theme/LiveDiaryComposerPreview.swift`：`.shadow(color: DaybookTheme.ink.opacity(0.10), radius: 6, x: 0, y: 3)`
- `AreaChain/Theme/DaybookRowBubbles.swift` 两处：`.shadow(color: Color.black.opacity(0.24), radius: 10, x: 0, y: 5)`

### 1.3 改掉会让搜索误报的注释

`AreaChain/Theme/DaybookElevation.swift` 第 4 行：

```swift
/// 页面不得直接调用 .shadow(color:)。
```

→

```swift
/// 页面用 daybookElevation，不要再写手写阴影。
```

检查点：

```bash
rg -n '\.shadow\(color:' AreaChain --glob '*.swift'
./scripts/build.sh
```

第一条预期零输出。

---

## 步骤 2：换成 daybookSurface

### 2.1 `AreaChain/Features/Search/BoardSearchHitRow.swift`

`workspaceLabel` 末尾，把

```swift
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.regular)
                .fill(isSelected ? DaybookPalette.fill.selection : DaybookPalette.fill.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.regular)
                .strokeBorder(isSelected ? DaybookTheme.stamp.opacity(0.4) : DaybookPalette.border.default, lineWidth: 0.8)
        )
```

替换为

```swift
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .daybookSurface(.row, isSelected: isSelected, configure: { $0.radius = DaybookRadius.regular })
```

同一文件 `.buttonStyle(.plain) // control: 搜索结果整行点击区，P4 迁 daybookSurface(.row)` 改成 `.buttonStyle(.plain) // control: 搜索结果整行点击区`。`.list` 分支不要动。

### 2.2 `AreaChain/Features/Workspace/WorkspaceGlobalSearchView.swift`

`attachmentRow` 里，把

```swift
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.regular)
                    .fill(DaybookPalette.fill.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.regular)
                    .strokeBorder(DaybookPalette.border.default, lineWidth: 0.8)
            )
            .contentShape(Rectangle())
```

替换为

```swift
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .daybookSurface(.row, configure: { $0.radius = DaybookRadius.regular })
            .contentShape(Rectangle())
```

`.buttonStyle(.plain) // control: 附件结果整行点击区，P4 迁 daybookSurface(.row)` 改成 `.buttonStyle(.plain) // control: 附件结果整行点击区`。

### 2.3 `AreaChain/Theme/SyntaxHelpCard.swift` 综合范例

把

```swift
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DaybookTheme.ink.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(DaybookTheme.rule.opacity(0.35), lineWidth: 0.6)
            )
            .contentShape(Rectangle())
```

替换为

```swift
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .daybookSurface(.card, configure: { $0.radius = DaybookRadius.small })
            .contentShape(Rectangle())
```

`.buttonStyle(.plain) // control: 语法范例卡片，P4 迁 daybookSurface(.card)` 改成 `.buttonStyle(.plain) // control: 语法范例卡片`。文件上半部的浮层圆角和描边不要动（阴影已在步骤 1 换过）。

### 2.4 `AreaChain/Features/Workspace/TaskDetailDrawer.swift` 的 `DrawerSectionGroup`

把

```swift
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                    .fill(DaybookTheme.cardSurface.opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                    .strokeBorder(DaybookTheme.cardBorder, lineWidth: 0.8)
            )
```

替换为

```swift
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .daybookSurface(.card)
```

### 2.5 `AreaChain/Features/Diary/DiaryNoteCard.swift`

把

```swift
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .fill(isHovered ? DaybookTheme.cardSurfaceHover : DaybookTheme.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .strokeBorder(
                    isHighlighted
                        ? DaybookTheme.stamp
                        : (entry.isPinned ? DaybookTheme.stamp.opacity(0.35) : (isHovered ? DaybookTheme.cardBorderHover : DaybookTheme.cardBorder)),
                    lineWidth: isHighlighted || entry.isPinned ? 1.2 : 0.8
                )
        )
```

替换为

```swift
        .padding(12)
        .daybookSurface(.card, isHovered: isHovered, isSelected: isHighlighted)
        .overlay {
            if entry.isPinned && !isHighlighted {
                RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                    .strokeBorder(DaybookTheme.stamp.opacity(0.35), lineWidth: 1.2) // token-exempt: 置顶手记的第三态描边，表面选中态留给高亮
            }
        }
```

`.onHover` 及后面的 popover、alert 不要动。

检查点：

```bash
./scripts/build.sh
```

---

## 步骤 3：三块保留自绘，只改注释

### 3.1 `AreaChain/Features/Workspace/TaskDetailQuadrantGrid.swift`

`.buttonStyle(.plain) // control: 象限选择格，P4 迁 daybookSurface(.cell)` 改成 `.buttonStyle(.plain) // control: 象限选择格保留象限色，不进通用表面`。格子的 `fill` / `stroke` 不要动。

### 3.2 `AreaChain/Features/Quadrant/QuadrantPage.swift`

`.buttonStyle(.plain) // control: 象限任务卡整行点击，P4 迁 daybookSurface(.card)` 改成 `.buttonStyle(.plain) // control: 象限任务卡整行点击`。上面的 `daybookSurface` 不要动。

### 3.3 `AreaChain/Features/Calendar/CalendarMonthGrid.swift`

`cell` 里两处 `RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)` 的行尾各加 ` // token-exempt: 今日环、选中与投放三态`。拖放那条 `lineWidth: 2` 的 `RoundedRectangle` 行尾也加同一句注释。颜色和线宽不要改。

### 3.4 `AreaChain/Features/Gantt/GanttPage.swift`

`dayCell` 里两处 `RoundedRectangle` 的行尾各加 ` // token-exempt: 甘特色块是数据标记，不是卡片`。填充色和线宽不要改。

检查点：

```bash
rg -n 'P4 迁 daybookSurface' AreaChain
./scripts/build.sh
```

第一条预期零输出。

---

## 最终验证

```bash
# 1. 手写阴影消失（预期零输出）
rg -n '\.shadow\(color:' AreaChain --glob '*.swift'

# 2. floating / raised 数量（预期 floating 11，raised 至少 1）
rg -c 'daybookElevation\(\.floating\)' AreaChain --glob '*.swift' | awk -F: '{s+=$2} END {print s}'
rg -c 'daybookElevation\(\.raised\)' AreaChain --glob '*.swift' | awk -F: '{s+=$2} END {print s}'

# 3. 五处表面已换（预期各 1）
rg -c 'daybookSurface\(\.row, isSelected: isSelected, configure: \{ \$0\.radius = DaybookRadius\.regular \}\)' AreaChain/Features/Search/BoardSearchHitRow.swift
rg -c 'daybookSurface\(\.row, configure: \{ \$0\.radius = DaybookRadius\.regular \}\)' AreaChain/Features/Workspace/WorkspaceGlobalSearchView.swift
rg -c 'daybookSurface\(\.card, configure: \{ \$0\.radius = DaybookRadius\.small \}\)' AreaChain/Theme/SyntaxHelpCard.swift
rg -c 'daybookSurface\(\.card\)' AreaChain/Features/Workspace/TaskDetailDrawer.swift
rg -c 'daybookSurface\(\.card, isHovered: isHovered, isSelected: isHighlighted\)' AreaChain/Features/Diary/DiaryNoteCard.swift

# 4. 旧的「P4 迁」注释消失（预期零输出）
rg -n 'P4 迁 daybookSurface' AreaChain

# 5. 三块自绘还在（预期各至少 1）
rg -c 'slot\.themeFill' AreaChain/Features/Workspace/TaskDetailQuadrantGrid.swift
rg -c 'token-exempt: 今日环、选中与投放三态' AreaChain/Features/Calendar/CalendarMonthGrid.swift
rg -c 'token-exempt: 甘特色块是数据标记，不是卡片' AreaChain/Features/Gantt/GanttPage.swift

# 6. 表面基座文件零 diff（预期零输出）
git diff --stat -- AreaChain/Theme/DaybookSurface.swift

# 7. 测试没被删（两条都跑；预期零输出）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'

# 8. 测试（原生界面测试串行，期间不操作其他窗口）
./scripts/build.sh test \
  --only-testing AreaChainTests/DaybookSurfaceTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/QuadrantLayoutTests \
  --only-testing AreaChainTests/GanttInteractionTests \
  --only-testing AreaChainTests/SyntaxOverlayPlacementTests \
  --only-testing AreaChainTests/TaskRowInteractionTests

# 9. 工作流检查
python3 -B scripts/check_workflow.py
```

第 2 条 floating 必须是 11，raised 必须 ≥ 1。第 6 条有 diff 说明你改了表面规则，把 `DaybookSurface.swift` 回滚。

第 8 条若失败且是「尺寸与预期不符」，不要改测试，贴出失败信息停下问我。

## 汇报格式

```
## P4b 完成汇报
### 修改文件（路径 — 一句话）
### 阴影替换（file — raised 或 floating）
### 表面替换（file — variant）
### 保留自绘的三块
### 验证输出（1–9 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P4b 浮层与剩余自绘表面` 改成 `- [x]`，决策记录追加 `- <日期> P4b 完成：<一句话>`。

## 绝对不要做

- 不要改 `DaybookSurface.swift`。
- 不要把象限格、日历格、甘特色块改成 `daybookSurface`。
- 不要改浮层原来的 `fill`、`stroke`、`clipShape`、材质，只换阴影那一行。
- 不要动按钮样式和 `// control:` 里与本阶段无关的句子（P3a/P3b 的那 28 条里，只改本文点名的 5 条「P4 迁」）。
- 不要 commit。
