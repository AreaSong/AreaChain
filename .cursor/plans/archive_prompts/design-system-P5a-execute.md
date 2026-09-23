# 任务：AreaChain 设计系统收敛 · 阶段 P5a（芯片）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 严格按步骤顺序执行；每个"检查点"必须跑通再进下一步。
2. 只改本文列出的文件。代码块原样粘贴。
3. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
4. 先读 `AGENTS.md`，再读 `.cursor/plans/design-system.md` 的「P5a」段，再读本文。
5. 做完不宣布"通过"。验收按 `design-system-P5a-verify.md`。
6. 不要新增第二种芯片。不要改星期圆点的圆形。不要改预览条、属性按钮、语法色胶囊里的 `Capsule()`。

## 背景

`PillBadge` 已经是一颗共享胶囊：选中时用传入颜色的 14% 底和 35% 描边，未选中是空底加细边，悬停淡灰底。另外有 12 处注释写着「P5 迁 DaybookChip」，各自又画了一遍胶囊。

本阶段只建一颗 `DaybookChip`，外观与 `PillBadge` 相同，参数名用 `tint`。然后把 `PillBadge` 和那 12 处注释对应的胶囊换上去。

星期圆点是 7 个圆形选择器，不是胶囊。只改注释，不改成芯片。

## 开始前必读

1. `AreaChain/Theme/ModernComponents.swift` 第 91–161 行（`PillBadge`）。
2. 步骤 3 里每个要替换的函数，改之前先读一遍，确认字符串还在。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/WorkspaceRenderingTests --only-testing AreaChainTests/MenuBarPopoverRenderingTests --only-testing AreaChainTests/TaskRowInteractionTests
```

---

## 步骤 1：新建 `AreaChain/Theme/DaybookChip.swift`

```swift
import SwiftUI

/// 全应用唯一的胶囊芯片。选中：tint 14% 底 + 35% 描边；未选中：空底 + 细边；悬停：淡灰底。
/// 标签里不要再画 Capsule。颜色用 tint，不要在外面再铺一层底。
struct DaybookChip<Label: View>: View {
    var tint: Color
    var isSelected: Bool
    var action: (() -> Void)?
    @ViewBuilder var label: () -> Label

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        tint: Color = DaybookTheme.stamp,
        isSelected: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.tint = tint
        self.isSelected = isSelected
        self.action = action
        self.label = label
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { chip }
                    .buttonStyle(.plain) // control: 芯片外壳，外观由 DaybookChip 绘制
            } else {
                chip
            }
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var chip: some View {
        label()
            .font(DaybookType.badge)
            .foregroundStyle(isSelected ? tint : DaybookTheme.muted)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(stroke, lineWidth: 0.8))
            .contentShape(Capsule())
            .onHover { hovering = $0 }
            .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
    }

    private var fill: Color {
        if isSelected { return tint.opacity(0.14) }
        if hovering { return DaybookTheme.hoverFill }
        return .clear
    }

    private var stroke: Color {
        if isSelected { return tint.opacity(0.35) }
        if hovering { return DaybookTheme.rule.opacity(0.8) }
        return DaybookTheme.rule.opacity(0.4)
    }
}
```

检查点：`./scripts/build.sh` 通过。

---

## 步骤 2：`PillBadge` 改名为 `DaybookChip`

只在这两个文件里，把 `PillBadge(` 换成 `DaybookChip(`，把参数 `color:` 换成 `tint:`。不要改别的参数。

- `AreaChain/Features/Workspace/TaskDetailScheduleSection.swift`（日期 4 处、提醒时刻 1 处）
- `AreaChain/Features/Workspace/TaskDetailClassificationSection.swift`（标签 1 处，`Color(nsColor: .systemIndigo)` 原样留在 `tint:` 里）

然后删除 `AreaChain/Theme/ModernComponents.swift` 里的 `PillBadge` 整个 struct，以及它上面的 `// MARK: - Pill Badge` 注释。`modernFocusRing` 保留。

检查点：

```bash
rg -n 'PillBadge' AreaChain AreaChainTests
./scripts/build.sh
```

第一条预期零输出。

---

## 步骤 3：注释里点名要迁的胶囊

每处都删掉自己画的 `Capsule` 底和描边，改成 `DaybookChip`。标签里的文字、图标、点击动作保留。

### 3.1 `AreaChain/Features/Diary/DiaryNoteCard.swift`

`assignedTagChip` 整段替换为：

```swift
    private func assignedTagChip(_ tag: TagItem) -> some View {
        let color = DiaryTagChrome.color(for: tag.name)
        return DaybookChip(tint: color, isSelected: true, action: {
            PrivacyAccess.withDiary(entry, requiresUnlock: tag.isPrivateDiary, vault: privacyVault) { current in
                DayBoardMutations.toggleDiaryTag(current, tagID: tag.id)
            }
        }) {
            Text("#\(tag.name)")
        }
        .help("diary.tag.off")
    }
```

### 3.2 `AreaChain/Features/Diary/DiaryQuickComposerView.swift`

`tagChip` 的 `Button { ... } label: { ... } .buttonStyle(.plain)...` 整段替换为：

```swift
        return DaybookChip(tint: color, isSelected: isSelected, action: {
            if isSelected {
                selectedTagIDs.remove(tag.id)
            } else {
                selectedTagIDs.insert(tag.id)
            }
        }) {
            HStack(spacing: 3) {
                if isSelected {
                    Image(systemName: "checkmark")
                }
                Text("#\(tag.name)")
            }
        }
```

函数开头的 `let isSelected` 和 `let color` 保留。

### 3.3 `AreaChain/Features/Diary/DiaryPage.swift`

`filterPill` 整段替换为：

```swift
    private func filterPill(
        title: String,
        count: Int,
        isSelected: Bool,
        color: Color = DaybookTheme.stamp,
        action: @escaping () -> Void
    ) -> some View {
        DaybookChip(tint: color, isSelected: isSelected, action: action) {
            HStack(spacing: 4) {
                Text(title)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                }
            }
        }
    }
```

然后删除只被它使用的 `standardFilterLabel` 整个函数。

### 3.4 `AreaChain/Features/Tasks/TasksPage+Sections.swift`

a. 「全部移到今天」那个 `Button` 到 `.accessibilityLabel` 为止，替换为：

```swift
                DaybookChip(tint: DaybookTheme.stamp, isSelected: true, action: {
                    withAnimation(DaybookMotion.interactive) {
                        moveAllYesterdayTodosToToday()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.right.to.line")
                        Text("stamp.yesterday.moveAll")
                    }
                }
                .help("stamp.yesterday.moveAll.help")
                .accessibilityLabel("stamp.yesterday.moveAll")
```

b. `chip(_:)` 里的 `Button(action:)` 换成 `DaybookChip`，并删除 `standardChipLabel`：

```swift
    private func chip(_ config: LeftoverChipConfig) -> some View {
        DaybookChip(tint: DaybookTheme.stamp, isSelected: config.expanded, action: config.action) {
            HStack(spacing: 4) {
                Text(config.title)
                Text("\(config.count)")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                Image(systemName: config.expanded ? "chevron.up" : "chevron.down")
                    .accessibilityHidden(true)
            }
        }
        .disabled(config.count == 0)
        .opacity(config.count == 0 ? 0.45 : 1)
        .accessibilityLabel(config.kind.accessibilityLabel(count: config.count, locale: locale))
    }
```

确认 `standardChipLabel` 没有别的调用后再删。

### 3.5 `AreaChain/Features/Tasks/TaskRow+Badges.swift`

`remindBadge` 整段替换为：

```swift
    func remindBadge(_ minutes: Int) -> some View {
        let isHighlighted = isHovered || state.isSelected
        return DaybookChip(tint: DaybookTheme.stamp, isSelected: isHighlighted, action: state.canSetRemind ? { pickingTime = true } : nil) {
            HStack(spacing: 2.5) {
                Image(systemName: "clock")
                Text(RemindMinutes.label(minutes, locale: locale))
            }
        }
    }
```

### 3.6 `AreaChain/Features/Tasks/TaskRowSubtaskMiniViews.swift`

`TaskRowSubtaskChip.body` 整段替换为：

```swift
    var body: some View {
        let completed = subtasks.filter(\.isDone).count
        let total = subtasks.count
        let allDone = completed == total && total > 0
        return DaybookChip(tint: DaybookTheme.stamp, isSelected: allDone, action: {
            withAnimation(DaybookMotion.animation(reduceMotion)) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 3) {
                Image(systemName: allDone ? "checkmark.circle.fill" : "checklist")
                Text("\(completed)/\(total)")
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            }
        }
        .help(isExpanded ? "row.subtasks.collapse" : "row.subtasks.expand")
    }
```

### 3.7 `AreaChain/Features/Workspace/TaskDetailSubtasksView.swift`

标签移除按钮整段替换为：

```swift
                        DaybookChip(tint: DaybookTheme.stamp, isSelected: true, action: {
                            DayBoardMutations.toggleSubtaskTag(subtask, tagID: tag.id)
                        }) {
                            Label("#" + tag.name, systemImage: "xmark")
                        }
                        .help("syntax.tag.remove")
```

### 3.8 `AreaChain/Features/Workspace/TaskDetailNotesView.swift`

`linkButton` 整段替换为：

```swift
    private func linkButton(for url: URL) -> some View {
        DaybookChip(tint: DaybookTheme.stamp, isSelected: true, action: {
            NSWorkspace.shared.open(url)
        }) {
            HStack(spacing: 4) {
                Image(systemName: "link")
                Text(url.absoluteString)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "arrow.up.right")
            }
        }
    }
```

### 3.9 两处筛选 token

外层胶囊交给 `DaybookChip`，里面的 xmark 仍是按钮。删掉外层的 `.padding`、`.background(Capsule...)`、`.overlay(Capsule...)`、`.foregroundStyle(...)`。

`AreaChain/Features/Tasks/TasksPage+Header.swift` 的 `activeFilterTag`，把包住内容的那一层改成：

```swift
        DaybookChip(tint: color, isSelected: true) {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .lineLimit(1)
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .frame(width: 12, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain) // control: 芯片内的移除角标
            }
        }
```

函数签名和前面的参数保持不变。如果原来的函数不是直接 `return` 这个 HStack，就用这段作为函数体的返回值。

`AreaChain/Features/MenuBar/MenuBarSearchField.swift` 里 `ForEach(tokens)` 的那个 `HStack`，改成：

```swift
                            DaybookChip(tint: DaybookTheme.stamp, isSelected: true) {
                                HStack(spacing: 2) {
                                    if let dotColor = token.dotColor {
                                        Circle().fill(dotColor).frame(width: 4.5, height: 4.5)
                                    } else if let icon = token.icon {
                                        Image(systemName: icon)
                                    }
                                    Text(token.title)
                                        .lineLimit(1)
                                    Button(action: token.onRemove) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 6.5, weight: .bold))
                                            .frame(width: 9, height: 9)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain) // control: 芯片内的移除角标
                                }
                            }
```

删掉紧跟在原 HStack 后面的 `.padding`、`.background(Capsule...)`、`.overlay(Capsule...)`、`.foregroundStyle(...)`。

### 3.10 星期圆点只改注释

`AreaChain/Features/Workspace/TaskDetailScheduleSection.swift`：

`.buttonStyle(.plain) // control: 星期圆点，P5 迁 DaybookChip(.filter)`

→

`.buttonStyle(.plain) // control: 星期圆点选择器，不是胶囊`

圆形的 `background(Circle()...)` 不要动。

检查点：

```bash
rg -n 'P5 迁 DaybookChip' AreaChain
./scripts/build.sh
```

第一条预期零输出。

---

## 最终验证

```bash
# 1. PillBadge 和旧迁移注释消失（预期零输出）
rg -n 'PillBadge|P5 迁 DaybookChip' AreaChain AreaChainTests

# 2. 芯片已接上（预期至少 10）
rg -c 'DaybookChip\(' AreaChain --glob '*.swift' | awk -F: '{s+=$2} END {print s}'

# 3. 星期圆点还在（预期各 1）
rg -c '星期圆点选择器，不是胶囊' AreaChain/Features/Workspace/TaskDetailScheduleSection.swift
rg -c 'Circle\(\)' AreaChain/Features/Workspace/TaskDetailScheduleSection.swift

# 4. 表面和按钮基座零 diff（预期零输出）
git diff --stat -- AreaChain/Theme/DaybookSurface.swift AreaChain/Theme/DaybookButtonStyle.swift

# 5. 测试没被删（两条都跑；预期零输出）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'

# 6. 测试
./scripts/build.sh test \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/TaskRowInteractionTests \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/BoardFilterBarTests

# 7. 工作流检查
python3 -B scripts/check_workflow.py
```

第 6 条若失败且是「尺寸与预期不符」，不要改测试，贴出失败信息停下问我。

## 汇报格式

```
## P5a 完成汇报
### 新建 / 删除的类型
### 修改文件（路径 — 一句话）
### 验证输出（1–7 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P5a 芯片 / 计数 / 圆点` 改成 `- [x]`，决策记录追加 `- <日期> P5a 完成：<一句话>`。

## 绝对不要做

- 不要改 `DaybookSurface.swift`、`DaybookButtonStyle.swift`。
- 不要把星期圆点改成胶囊。
- 不要改 `LiveComposerPreviewHeader`、`CaptureAttributesView`、`SyntaxHelpCard`、`BoardSearchHitRow` 里的 `Capsule()`。
- 不要改 `SectionStamp`、`Divider`、`DaybookQuietTabBar`（那是 P5b）。
- 不要 commit。
