# 任务：AreaChain 设计系统收敛 · 阶段 P4a（表面基座）· 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P4a-execute.md` 执行了 P4a 并声称完成。你不相信它的汇报：自己重跑命令、自己看 diff，逐项打 PASS / FAIL / BLOCKED。

规则：
1. **只读**。不改源码和测试。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须亲自运行并粘贴原样输出。
3. 命令跑不起来 → BLOCKED。
4. 先读 `.cursor/plans/design-system-P4a-execute.md` 的「背景」和「绝对不要做」。

---

## 检查清单

### A. 旧 API 消失，新表面存在

```bash
# A1 预期零输出
rg -n 'modernCard|modernRow|daybookCardStyle|DaybookGroupedCard|ModernCardModifier|ModernRowModifier|DaybookCardModifier' AreaChain AreaChainTests

# A2 预期文件存在
ls AreaChain/Theme/DaybookSurface.swift AreaChainTests/Theme/DaybookSurfaceTests.swift

# A3 四个 variant 与关键外观（预期各 1）
rg -c 'case row' AreaChain/Theme/DaybookSurface.swift
rg -c 'case card' AreaChain/Theme/DaybookSurface.swift
rg -c 'case panel' AreaChain/Theme/DaybookSurface.swift
rg -c 'case banner' AreaChain/Theme/DaybookSurface.swift
rg -c 'variant == \.panel \? \.floating : \.flat' AreaChain/Theme/DaybookSurface.swift
rg -c 'return isSelected \? DaybookMetrics\.Stroke\.emphasis : 0' AreaChain/Theme/DaybookSurface.swift
rg -c 'radius: DaybookRadius\.medium' AreaChain/Theme/DaybookSurface.swift
rg -c 'padding: EdgeInsets\(top: 10, leading: 10, bottom: 10, trailing: 10\)' AreaChain/Theme/DaybookSurface.swift
```

A3 里卡片变体**不能**出现 `.shadow(` 或 `DaybookElevation.raised`。运行：

```bash
rg -n '\.shadow\(|DaybookElevation\.raised' AreaChain/Theme/DaybookSurface.swift
```

预期零输出。

### B. 调用点

```bash
# B1 源码里的 daybookSurface 调用（不含测试；预期 11）
rg -c 'daybookSurface\(' AreaChain --glob '*.swift' | awk -F: '{s+=$2} END {print s}'

# B2 三处行（预期各 1）
rg -c 'daybookSurface\(\.row, isHovered: isHovered, isSelected: state\.isSelected\)' AreaChain/Features/Tasks/TaskRow.swift
rg -c 'daybookSurface\(\.row, isHovered: isHovered, isSelected: isSelected \|\| isHighlighted\)' AreaChain/Features/Diary/DiarySummaryRow.swift
rg -c 'daybookSurface\(\.row, isHovered: isHovered, isSelected: false\)' AreaChain/Theme/LiveDiaryComposerPreview.swift

# B3 手记行 46 还在（预期 1）
rg -c 'frame\(minHeight: 46\)' AreaChain/Features/Diary/DiarySummaryRow.swift

# B4 圆角 6 的卡片（预期 4：三处详情 + 象限任务卡；常驻另算下一行）
rg -c 'daybookSurface\(\.card, configure: \{ \$0\.radius = DaybookRadius\.small \}\)' AreaChain/Features
rg -c 'daybookSurface\(\.card, isSelected: isSelected, configure: \{ \$0\.radius = DaybookRadius\.small \}\)' AreaChain/Features/Workspace/ResidentsPage.swift

# B5 象限格用默认卡片圆角（预期 1）
rg -c 'daybookSurface\(\.card, isHovered: isTargeted, isSelected: isTargeted\)' AreaChain/Features/Quadrant/QuadrantPage.swift

# B6 回收站保留原来的内边距（预期 1）
rg -c 'EdgeInsets\(top: 8, leading: 14, bottom: 8, trailing: 12\)' AreaChain/Features/Trash/TrashPage.swift

# B7 分组容器（预期 6）
rg -c 'VStack\(alignment: \.leading, spacing: 4\)' AreaChain/Features/Tasks/DayBoardSections.swift AreaChain/Features/Workspace/WorkspaceFilteredListView.swift | awk -F: '{s+=$2} END {print s}'

# B8 锁定草稿已进 banner，旧注释消失（第一条预期 1，第二条预期零输出）
rg -c 'daybookSurface\(\.banner\)' AreaChain/Features/Diary/DiaryPage.swift
rg -n 'token-exempt: 锁定草稿' AreaChain
```

### C. 没越界

```bash
# C1 Features 阴影仍是 4 处（预期打印 4）
rg -c '\.shadow\(color:' AreaChain/Features --glob '*.swift' | awk -F: '{s+=$2} END {print s}'

# C2 这四个自绘表面还在，没有被提前改掉（预期各至少 1）
rg -c 'buttonStyle\(\.plain\) // control: 象限选择格' AreaChain/Features/Workspace/TaskDetailQuadrantGrid.swift
rg -c 'buttonStyle\(\.plain\) // control: 搜索结果整行点击区' AreaChain/Features/Search/BoardSearchHitRow.swift
rg -c 'buttonStyle\(\.plain\) // control: 附件结果整行点击区' AreaChain/Features/Workspace/WorkspaceGlobalSearchView.swift
rg -c 'buttonStyle\(\.plain\) // control: 语法范例卡片' AreaChain/Theme/SyntaxHelpCard.swift

# C3 modernFocusRing 还在（预期 1）
rg -c 'func modernFocusRing' AreaChain/Theme/ModernComponents.swift

# C4 输入壳和按钮基座零 diff（预期零输出）
git diff --stat -- AreaChain/Theme/DaybookInputShell.swift AreaChain/Theme/DaybookButtonStyle.swift AreaChain/Theme/DaybookTextField.swift

# C5 测试没有被删（两条都跑；预期零输出）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'
```

### D. 编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/DaybookSurfaceTests \
  --only-testing AreaChainTests/TaskRowInteractionTests \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/QuadrantLayoutTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests
echo "EXIT=$?"
```

`EXIT=0` → PASS；非 0 → FAIL，贴最后 60 行。运行期间不要操作其他窗口。

### E. 工作流与计划状态

```bash
python3 -B scripts/check_workflow.py; echo "EXIT=$?"
rg -n '\[x\] P4a' .cursor/plans/design-system.md
rg -n 'P4a 完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P4a 验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A1–A3 旧 API 消失 / 新表面内容 | ... | ... |
| B1–B8 调用点 | ... | 不符项 |
| C1–C5 未越界 | ... | ... |
| D 编译与测试 | ... | EXIT=? |
| E check_workflow 与计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D 任一 FAIL 或 BLOCKED → 不通过。C1 不是 4，或 C2 少了注释 → 不通过（改了不该改的表面或阴影）。只有 E 的计划状态 FAIL → 通过，但写入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节「决策记录」末尾追加：`- <日期> P4a 验收：通过 / 不通过（<原因>）`。
