# 任务：AreaChain 设计系统收敛 · 阶段 P5b（分节头、分隔线、分段栏）· 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P5b-execute.md` 执行了 P5b 并声称完成。你不相信汇报：自己重跑命令、自己看 diff，逐项打 PASS / FAIL / BLOCKED。

规则：
1. **只读**。不改源码和测试。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须亲自运行并粘贴原样输出。
3. 命令跑不起来 → BLOCKED。
4. 先读 `.cursor/plans/design-system-P5b-execute.md` 的「不要动这些」和「绝对不要做」。

---

## 检查清单

### A. 旧名字消失，新类型存在

```bash
# A1 预期零输出
rg -n 'SectionStamp|DaybookQuietTabBar' AreaChain AreaChainTests

# A2 预期文件存在
ls AreaChain/Theme/DaybookSectionHeader.swift AreaChain/Theme/DaybookSegmentedBar.swift

# A3 分节标题外观还在（预期各 1）
rg -c 'struct DaybookSectionHeader' AreaChain/Theme/DaybookSectionHeader.swift
rg -c '\.tracking\(0\.5\)' AreaChain/Theme/DaybookSectionHeader.swift
rg -c 'struct DaybookDivider' AreaChain/Theme/DaybookSectionHeader.swift

# A4 分段栏仍是任务/手记（预期各至少 1）
rg -c 'BoardTab' AreaChain/Theme/DaybookSegmentedBar.swift
rg -c 'matchedGeometryEffect' AreaChain/Theme/DaybookSegmentedBar.swift
rg -c 'DaybookSegmentedBar\(' AreaChain/Features/MenuBar/MenuBarPopoverView.swift
```

### B. 数量

```bash
# B1 预期打印 6
rg -c 'DaybookSectionHeader\(' AreaChain --glob '*.swift' | awk -F: '{s+=$2} END {print s}'

# B2 点名文件里不再有 Divider()（预期零输出）
rg -n 'Divider\(\)' AreaChain/Features/MenuBar/MenuBarPopoverView.swift AreaChain/Features/Calendar/CalendarPage.swift AreaChain/Features/Gantt/GanttPage.swift AreaChain/Features/Workspace/WorkspaceHeaderBar.swift AreaChain/Features/Tasks/BoardFilterBar.swift AreaChain/Features/MenuBar/MenuBarFilterFlyout.swift AreaChain/Theme/SyntaxHelpCard.swift AreaChain/Theme/SyntaxAutocompleteView.swift AreaChain/Theme/LiveComposerPreviewHeader.swift

# B3 菜单分隔还在（第一条预期至少 4，第二条至少 2）
rg -c 'Divider\(\)' AreaChain/Features/Tasks/TaskRow+Menus.swift
rg -c 'Divider\(\)' AreaChain/Features/Diary/DiarySummaryRow.swift

# B4 列表行分隔还在（预期各至少 1）
rg -c 'Divider\(\)' AreaChain/Features/Tasks/DayBoardSections.swift
rg -c 'Divider\(\)' AreaChain/Features/Workspace/WorkspaceFilteredListView.swift
```

### C. 没越界

```bash
# C1 确认框和监听器还在（预期各至少 1）
rg -c 'func confirmMoveToTrash' AreaChain/Theme/TrashConfirm.swift
rg -c 'addLocalMonitorForEvents' AreaChain/Theme/CommandReturnButton.swift
rg -c 'addLocalMonitorForEvents' AreaChain/Features/Board/BoardRowChrome.swift

# C2 芯片、表面、按钮基座零 diff（预期零输出；两条都跑）
git diff --stat -- AreaChain/Theme/DaybookChip.swift AreaChain/Theme/DaybookSurface.swift AreaChain/Theme/DaybookButtonStyle.swift
git diff --cached --stat -- AreaChain/Theme/DaybookChip.swift AreaChain/Theme/DaybookSurface.swift AreaChain/Theme/DaybookButtonStyle.swift

# C3 测试没有被删（预期零输出；两条都跑）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'
```

### D. 编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/TaskRowInteractionTests \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/GanttInteractionTests
echo "EXIT=$?"
```

`EXIT=0` → PASS；非 0 → FAIL，贴最后 60 行。运行期间不要操作其他窗口。

### E. 工作流与计划状态

```bash
python3 -B scripts/check_workflow.py; echo "EXIT=$?"
rg -n '\[x\] P5b' .cursor/plans/design-system.md
rg -n 'P5b 完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P5b 验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A1–A4 旧名字消失 / 新类型 | ... | ... |
| B1–B4 数量与菜单线保留 | ... | 分节标题数=? |
| C1–C3 未越界 | ... | ... |
| D 编译与测试 | ... | EXIT=? |
| E check_workflow 与计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D 任一 FAIL 或 BLOCKED → 不通过。B1 不是 6，或 B3 菜单分隔少了 → 不通过。C2 有 diff → 不通过。只有 E 的计划状态 FAIL → 通过，但写入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节「决策记录」末尾追加：`- <日期> P5b 验收：通过 / 不通过（<原因>）`。
