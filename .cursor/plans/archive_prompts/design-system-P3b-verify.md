# 任务：AreaChain 设计系统收敛 · 阶段 P3b（Diary / Workspace / Theme / Quadrant 按钮）· 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P3b-execute.md` 执行了 P3b 并声称完成。你**不相信它的任何一句话**：自己重跑命令、自己看文件、自己看 diff，逐项打 PASS / FAIL / BLOCKED，最后给「通过 / 不通过」和整改清单。

规则：
1. **只读**。不改源码、测试、文档；不 `git add/commit/stash/checkout`；不安装不发布。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须**亲自运行并粘贴原样输出**。没有输出不能打 PASS。
3. 命令跑不起来 → BLOCKED。
4. 发现问题只记录，不动手修。
5. 先读 `.cursor/plans/design-system-P3b-execute.md` 的「背景」和「绝对不要做」。

---

## 检查清单

### A. 裸 `.plain` 消失，control 数量正确

```bash
# A1 预期零输出。基座文档注释里的字面量不算裸按钮。
rg -n '\.buttonStyle\(\.plain\)' AreaChain --glob '*.swift' | rg -v '// control:' | rg -v ':[0-9]+:[[:space:]]*///'

# A2 预期打印 28
rg -c '\.buttonStyle\(\.plain\) // control:' AreaChain --glob '*.swift' | awk -F: '{s+=$2} END {print s}'

# A3 列出全部 control 行，逐条对照下面的 17 条新注释；P3a 原有 11 条也必须还在
rg -n '\.buttonStyle\(\.plain\) // control:' AreaChain --glob '*.swift'
```

本阶段必须新增、且注释原文一致的 17 条（多、少、改字都 → FAIL）：

- `DiaryQuickComposerView.swift` — `手记标签芯片，P5 迁 DaybookChip(.tag)`
- `DiaryPage.swift` — `手记筛选胶囊，P5 迁 DaybookChip(.filter)`
- `DiaryNoteCard.swift` — `已打标签胶囊，P5 迁 DaybookChip(.tag)`
- `TaskDetailSubtasksView.swift` — `子任务复选框，非按钮语义`
- `TaskDetailSubtasksView.swift` — `子任务标签移除芯片，P5 迁 DaybookChip(.token)`
- `TaskDetailNotesView.swift` — `备注链接芯片，P5 迁 DaybookChip`
- `TaskDetailQuadrantGrid.swift` — `象限选择格，P4 迁 daybookSurface(.cell)`
- `TaskDetailScheduleSection.swift` — `星期圆点，P5 迁 DaybookChip(.filter)`
- `WorkspaceFilteredListView.swift` — `已完成折叠头，整行点击`
- `WorkspaceGlobalSearchView.swift` — `附件结果整行点击区，P4 迁 daybookSurface(.row)`
- `QuadrantPage.swift` — `象限任务卡整行点击，P4 迁 daybookSurface(.card)`
- `ModernComponents.swift` — `复选框，非按钮语义`
- `ModernComponents.swift` — `胶囊徽章，P5 迁 DaybookChip`
- `WorkspaceLayout.swift` — `侧栏导航行，非按钮语义`
- `CaptureAttributesView.swift` — `属性按钮固定 58×22，胶囊留给 P5`
- `SyntaxHelpCard.swift` — `语法条目悬停替换正文`
- `SyntaxHelpCard.swift` — `语法范例卡片，P4 迁 daybookSurface(.card)`

P3a 的 11 条（`MenuBarControls`、`MenuBarSearchField`、`AttachmentThumbnails`、`DayBoardSections`、`TaskRow+Badges`、`TaskRowSubtaskMiniViews` 两条、`TasksPage+Header`、`TasksPage+Sections` 两条、`BoardSearchHitRow`）少一条 → FAIL。

### B. A 类迁移抽查

```bash
rg -c 'DaybookButtonStyle\(\.icon, size: \.compact\)' AreaChain/Features/Diary/DiaryQuickComposerView.swift
rg -c 'SyntaxViewAnchor\("syntax.diary.popout"\)' AreaChain/Features/Diary/DiaryQuickComposerView.swift
rg -c 'isPopoutHovered' AreaChain/Features/Diary/DiaryQuickComposerView.swift
rg -c 'DaybookButtonStyle\(\.prominent, size: \.compact\)' AreaChain/Features/Diary/DiaryQuickComposerView.swift
rg -c 'DaybookIconButton\(systemName: "magnifyingglass", label: "diary.search.placeholder"' AreaChain/Features/Diary/DiaryPage.swift
rg -c 'DaybookButtonStyle\(hasCopied \? \.iconActive : \.icon, size: \.compact\)' AreaChain/Features/Diary/DiarySummaryRow.swift
rg -c 'daybookMenuLabel\(size: \.compact\)' AreaChain/Features/Diary/DiarySummaryRow.swift
rg -c 'DaybookButtonStyle\(\.pill\(tint: DaybookPalette\.accent\.base\), size: \.compact\)' AreaChain/Features/Diary/DiaryCardComponents.swift
rg -c 'DaybookIconButton\(systemName: "trash", label: "alert.trash.move", size: \.compact, role: \.destructive, action: onDelete\)' AreaChain/Features/Diary/DiaryCardComponents.swift
rg -c 'Color\.green' AreaChain/Features/Diary
rg -c 'enabled && isCommandPressed \? \.iconActive : \.icon' AreaChain/Theme/CommandReturnButton.swift
rg -c 'syntax\.commandReturn\.button' AreaChain/Theme/CommandReturnButton.swift
rg -c 'isHovered' AreaChain/Theme/CommandReturnButton.swift
rg -c 'DaybookButtonStyle\(\.quiet, size: \.compact\)' AreaChain/Theme/SyntaxAutocompleteView.swift
rg -c 'syntax\.candidate\.' AreaChain/Theme/SyntaxAutocompleteView.swift
rg -c 'workspace\.header\.inspector\.toggle' AreaChain/Features/Workspace/WorkspaceHeaderBar.swift
rg -c 'DaybookIconButton\(\s*systemName: "sidebar.trailing"' AreaChain/Features/Workspace/WorkspaceHeaderBar.swift
```

预期：`isPopoutHovered`、`Color.green`（日记目录）、`CommandReturnButton` 里的 `isHovered` 为 0；其余各 ≥ 1。调用处的 `.pill(tint:` 若 tint 不是 `DaybookPalette` → FAIL。枚举声明 `case pill(tint: Color)` 不算：

```bash
rg -n '\.pill\(tint:' AreaChain/Features AreaChain/Theme | rg -v 'DaybookPalette\.'
```

预期零输出。

### C. 不该动的没动

```bash
# C1 系统按钮还在（预期打印 4）
rg -c '\.buttonStyle\(\.bordered(Prominent)?\)' AreaChain/Features/Diary/DiaryCardComponents.swift AreaChain/Features/Diary/DiaryWindowView.swift | awk -F: '{s+=$2} END {print s}'

# C2 P3a 四个模块本阶段零 diff（两条都跑；预期都零输出）
git diff --stat -- AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Board AreaChain/Features/Search
git diff --cached --stat -- AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Board AreaChain/Features/Search

# C3 基座文件零 diff（预期零输出）
git diff --stat -- AreaChain/Theme/DaybookButtonStyle.swift
git diff --cached --stat -- AreaChain/Theme/DaybookButtonStyle.swift

# C4 输入行为层零 diff（预期零输出）
git diff --stat -- AreaChain/Theme/DaybookTextField.swift AreaChain/Theme/DaybookInputShell.swift AreaChain/Theme/SyntaxOverlay.swift

# C5 测试没有被删（预期零输出；两条都跑）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'

# C6 属性按钮几何还在（预期 1）
rg -c 'frame\(width: 58, height: 22\)' AreaChain/Theme/CaptureAttributesView.swift
```

### D. 真正编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/DaybookButtonStyleTests \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/DiaryComposerInteractionTests \
  --only-testing AreaChainTests/DiaryWindowLifecycleTests \
  --only-testing AreaChainTests/PrivacyRenderingTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/QuadrantLayoutTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/TaskRowInteractionTests
echo "EXIT=$?"
```

`EXIT=0` → PASS；非 0 → FAIL，贴最后 60 行；跑不起来 → BLOCKED。运行期间不要操作其他窗口。

### E. 工作流检查与计划状态

```bash
python3 -B scripts/check_workflow.py; echo "EXIT=$?"
rg -n '\[x\] P3b' .cursor/plans/design-system.md
rg -n 'P3b 完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P3b 验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A1 无裸 .plain | ... | ... |
| A2 control 总数 28 | ... | ... |
| A3 17 条新注释 + 11 条旧注释逐条核对 | ... | 多出/缺失/改字 |
| B A 类抽查 | ... | 不符项 |
| C1–C6 未越界 | ... | ... |
| D 编译与测试 | ... | EXIT=? |
| E check_workflow 与计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D 任一 FAIL 或 BLOCKED → **不通过**。A3 不是恰好那些注释 → **不通过**。C2 或 C3 有 diff → **不通过**（改了不该改的模块或基座）。只有 E 的计划状态 FAIL → 通过但列入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节「决策记录」末尾追加：`- <日期> P3b 验收：通过 / 不通过（<原因>）`。
