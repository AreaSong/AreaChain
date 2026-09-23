# 任务：AreaChain 设计系统收敛 · 阶段 P5b（分节头、分隔线、分段栏）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 严格按步骤顺序执行；每个"检查点"必须跑通再进下一步。
2. 只改本文列出的文件。代码块原样粘贴。
3. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
4. 先读 `AGENTS.md`，再读 `.cursor/plans/design-system.md` 的「P5b」段，再读本文。
5. 做完不宣布"通过"。验收按 `design-system-P5b-verify.md`。

## 背景

分节标题已经有一颗 `SectionStamp`（图标 + 标题 + 计数）。分段栏已经有 `DaybookQuietTabBar`，但放在菜单栏功能目录里。有些布局分隔线各自乘了不同的透明度。

本阶段做三件外观上的归并：

- `SectionStamp` 改名为 `DaybookSectionHeader`，外观一字不改。
- 已经带颜色的布局分隔线换成 `DaybookDivider`。
- `DaybookQuietTabBar` 挪到 Theme，改名为 `DaybookSegmentedBar`，仍然只切换「任务 / 手记」。

**不要动这些：**

- `Menu { }` 里面的 `Divider()`。那是菜单分隔，不是布局线。包括 `TaskRow+Menus.swift`、`DiarySummaryRow.swift`、`DiaryOrganizeMenus.swift`，以及 `BatchActionBar.swift` 第 150 行附近菜单里的那条。
- 只写了 `Divider()`、后面没有 `.overlay` / `.background` 改颜色的线。
- `Divider().padding(...).opacity(...)` 这种列表行间距。包括 `DayBoardSections.swift` 和 `WorkspaceFilteredListView.swift`。
- `Divider().frame(height:)`。包括 `BatchActionBar.swift` 第 94 行和 `TaskDetailScheduleSection.swift` 里高度 28 的那条。
- `Divider().opacity(0.15)` 和 `Divider().opacity(0.2)`。
- 确认框和 `NSEvent` 监听器。本阶段不收它们。

## 开始前必读

1. `AreaChain/Theme/DaybookTheme.swift` 第 107–132 行（`SectionStamp`）。
2. `AreaChain/Features/MenuBar/MenuBarControls.swift` 第 12–63 行（`DaybookQuietTabBar`）。
3. `AreaChain/Features/MenuBar/MenuBarPopoverView.swift` 里 `DaybookQuietTabBar(` 那一行。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/MenuBarPopoverRenderingTests --only-testing AreaChainTests/WorkspaceRenderingTests --only-testing AreaChainTests/TaskRowInteractionTests
```

---

## 步骤 1：分节标题

新建 `AreaChain/Theme/DaybookSectionHeader.swift`，内容就是现在的 `SectionStamp`，只改名字：

```swift
import SwiftUI

/// 列表分节：图标、标题、计数。外观与原来的 SectionStamp 相同。
struct DaybookSectionHeader: View {
    var title: LocalizedStringKey
    var icon: String? = nil
    var count: Int? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(DaybookType.badge.weight(.semibold))
                    .foregroundStyle(DaybookTheme.stamp)
            }
            Text(title)
                .font(DaybookType.section)
                .tracking(0.5)
                .foregroundStyle(DaybookTheme.muted)
            if let count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(DaybookTheme.muted)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}
```

然后：

- 全仓库把 `SectionStamp(` 换成 `DaybookSectionHeader(`。已知 6 处：`TasksPage+Sections.swift` 1、`DayBoardSections.swift` 3、`WorkspaceFilteredListView.swift` 2。参数不要改。
- 删除 `DaybookTheme.swift` 里的 `struct SectionStamp` 整段。

检查点：

```bash
rg -n 'SectionStamp' AreaChain AreaChainTests
./scripts/build.sh
```

第一条预期零输出。

---

## 步骤 2：分隔线

新建文件追加到 `DaybookSectionHeader.swift` 末尾：

```swift

/// 布局用的淡分隔线。菜单里的 Divider 不要换成这个。
struct DaybookDivider: View {
    var opacity: Double = 0.4

    var body: some View {
        Divider().overlay(DaybookTheme.rule.opacity(opacity))
    }
}
```

只替换下面这些「Divider + 改颜色」的组合。把两行收成一行 `DaybookDivider(opacity:)`，透明度用原来的数字。

- `MenuBarPopoverView.swift`：`Divider()` 加下一行 `.overlay(DaybookTheme.rule.opacity(0.25))` → `DaybookDivider(opacity: 0.25)`
- `CalendarPage.swift`：`.overlay(DaybookTheme.rule.opacity(0.5))` → `DaybookDivider(opacity: 0.5)`
- `GanttPage.swift`：`Divider().overlay(DaybookTheme.rule.opacity(0.5))` → `DaybookDivider(opacity: 0.5)`
- `WorkspaceHeaderBar.swift`：`.background(DaybookTheme.rule.opacity(0.65))` → `DaybookDivider(opacity: 0.65)`
- `BoardFilterBar.swift`：`.background(DaybookTheme.rule.opacity(0.35))` → `DaybookDivider(opacity: 0.35)`
- `MenuBarFilterFlyout.swift` 两处：`.overlay(DaybookTheme.rule.opacity(0.4))` → `DaybookDivider(opacity: 0.4)`
- `SyntaxHelpCard.swift` 两处：`.background(DaybookTheme.rule.opacity(0.35))` → `DaybookDivider(opacity: 0.35)`
- `SyntaxAutocompleteView.swift`：`.background(DaybookTheme.rule.opacity(0.4))` → `DaybookDivider(opacity: 0.4)`；`.background(DaybookTheme.rule.opacity(0.5))` → `DaybookDivider(opacity: 0.5)`
- `LiveComposerPreviewHeader.swift`：`.overlay(DaybookTheme.rule.opacity(0.3))` → `DaybookDivider(opacity: 0.3)`

每一处都删掉原来的 `Divider()` 那一行，不要留成 `Divider()` 再接 `DaybookDivider`。

检查点：

```bash
rg -n 'Divider\(\)' AreaChain/Features/MenuBar/MenuBarPopoverView.swift AreaChain/Features/Calendar/CalendarPage.swift AreaChain/Features/Gantt/GanttPage.swift AreaChain/Features/Workspace/WorkspaceHeaderBar.swift AreaChain/Features/Tasks/BoardFilterBar.swift AreaChain/Features/MenuBar/MenuBarFilterFlyout.swift AreaChain/Theme/SyntaxHelpCard.swift AreaChain/Theme/SyntaxAutocompleteView.swift AreaChain/Theme/LiveComposerPreviewHeader.swift
./scripts/build.sh
```

第一条预期零输出。

---

## 步骤 3：分段栏

把 `MenuBarControls.swift` 里的 `struct DaybookQuietTabBar` 整段剪到新文件 `AreaChain/Theme/DaybookSegmentedBar.swift`，类型名改成 `DaybookSegmentedBar`。结构、动画、`matchedGeometryEffect`、帮助文案都不要改。

按钮那一行的注释改成：

```swift
.buttonStyle(.plain) // control: 分段切换滑块，非按钮语义
```

`MenuBarPopoverView.swift` 里 `DaybookQuietTabBar(` 改成 `DaybookSegmentedBar(`。参数不变。

`MenuBarControls.swift` 里不要留这个 struct。`MenuBarLabel` 留在原文件。

检查点：

```bash
rg -n 'DaybookQuietTabBar' AreaChain AreaChainTests
./scripts/build.sh
```

第一条预期零输出。

---

## 最终验证

```bash
# 1. 旧名字消失（预期零输出）
rg -n 'SectionStamp|DaybookQuietTabBar' AreaChain AreaChainTests

# 2. 新名字数量（分节标题预期 6，分段栏预期至少 1）
rg -c 'DaybookSectionHeader\(' AreaChain --glob '*.swift' | awk -F: '{s+=$2} END {print s}'
rg -c 'DaybookSegmentedBar\(' AreaChain/Features/MenuBar/MenuBarPopoverView.swift

# 3. 点名的文件里不再有 Divider()（预期零输出）
rg -n 'Divider\(\)' AreaChain/Features/MenuBar/MenuBarPopoverView.swift AreaChain/Features/Calendar/CalendarPage.swift AreaChain/Features/Gantt/GanttPage.swift AreaChain/Features/Workspace/WorkspaceHeaderBar.swift AreaChain/Features/Tasks/BoardFilterBar.swift AreaChain/Features/MenuBar/MenuBarFilterFlyout.swift AreaChain/Theme/SyntaxHelpCard.swift AreaChain/Theme/SyntaxAutocompleteView.swift AreaChain/Theme/LiveComposerPreviewHeader.swift

# 4. 菜单分隔还在（预期 TaskRow+Menus 至少 4，DiarySummaryRow 至少 2）
rg -c 'Divider\(\)' AreaChain/Features/Tasks/TaskRow+Menus.swift
rg -c 'Divider\(\)' AreaChain/Features/Diary/DiarySummaryRow.swift

# 5. 列表行分隔还在（预期各至少 1）
rg -c 'Divider\(\)' AreaChain/Features/Tasks/DayBoardSections.swift
rg -c 'Divider\(\)' AreaChain/Features/Workspace/WorkspaceFilteredListView.swift

# 6. 芯片和表面基座零 diff（预期零输出）
git diff --stat -- AreaChain/Theme/DaybookChip.swift AreaChain/Theme/DaybookSurface.swift AreaChain/Theme/DaybookButtonStyle.swift

# 7. 测试没被删（两条都跑；预期零输出）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'

# 8. 测试
./scripts/build.sh test \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/TaskRowInteractionTests \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/GanttInteractionTests

# 9. 工作流检查
python3 -B scripts/check_workflow.py
```

第 2 条分节标题必须是 6。第 4 条菜单分隔少了，说明你把菜单线换掉了，改回去。

第 8 条若失败且是「尺寸与预期不符」，不要改测试，贴出失败信息停下问我。

## 汇报格式

```
## P5b 完成汇报
### 新建 / 删除的类型
### 修改文件（路径 — 一句话）
### 验证输出（1–9 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P5b 分节头 / 分隔线 / 分段栏 / 确认框 / 监听器` 改成 `- [x]`，决策记录追加 `- <日期> P5b 完成：<一句话>`。

## 绝对不要做

- 不要改菜单里的 `Divider()`。
- 不要改 `DayBoardSections` / `WorkspaceFilteredListView` 里带 `.padding` 的行分隔。
- 不要把 `DaybookSegmentedBar` 改成泛型，不要加新的页签。
- 不要改确认框和 `NSEvent.addLocalMonitorForEvents`。
- 不要改 `DaybookChip.swift`、`DaybookSurface.swift`、`DaybookButtonStyle.swift`。
- 不要 commit。
