# 任务：AreaChain 设计系统收敛 · 阶段 P4b（浮层阴影与剩余自绘表面）· 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P4b-execute.md` 执行了 P4b 并声称完成。你不相信汇报：自己重跑命令、自己看 diff，逐项打 PASS / FAIL / BLOCKED。

规则：
1. **只读**。不改源码和测试。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须亲自运行并粘贴原样输出。
3. 命令跑不起来 → BLOCKED。
4. 先读 `.cursor/plans/design-system-P4b-execute.md` 的「背景」和「绝对不要做」。

---

## 检查清单

### A. 手写阴影没有了

```bash
# A1 预期零输出
rg -n '\.shadow\(color:' AreaChain --glob '*.swift'

# A2 预期打印 11
rg -c 'daybookElevation\(\.floating\)' AreaChain --glob '*.swift' | awk -F: '{s+=$2} END {print s}'

# A3 预期至少 1，且 MenuBarControls 里有
rg -c 'daybookElevation\(\.raised\)' AreaChain/Features/MenuBar/MenuBarControls.swift

# A4 批量条仍是材质，不是被面板底色换掉（预期 1）
rg -c 'ultraThickMaterial' AreaChain/Features/Tasks/BatchActionBar.swift
```

### B. 五处表面

```bash
rg -c 'daybookSurface\(\.row, isSelected: isSelected, configure: \{ \$0\.radius = DaybookRadius\.regular \}\)' AreaChain/Features/Search/BoardSearchHitRow.swift
rg -c 'daybookSurface\(\.row, configure: \{ \$0\.radius = DaybookRadius\.regular \}\)' AreaChain/Features/Workspace/WorkspaceGlobalSearchView.swift
rg -c 'daybookSurface\(\.card, configure: \{ \$0\.radius = DaybookRadius\.small \}\)' AreaChain/Theme/SyntaxHelpCard.swift
rg -c '\.daybookSurface\(\.card\)' AreaChain/Features/Workspace/TaskDetailDrawer.swift
rg -c 'daybookSurface\(\.card, isHovered: isHovered, isSelected: isHighlighted\)' AreaChain/Features/Diary/DiaryNoteCard.swift
rg -c 'entry\.isPinned && !isHighlighted' AreaChain/Features/Diary/DiaryNoteCard.swift
```

预期全部 ≥ 1。

```bash
# 旧迁移承诺已删（预期零输出）
rg -n 'P4 迁 daybookSurface' AreaChain
```

### C. 三块自绘还在，表面规则没被改

```bash
# C1 预期各至少 1
rg -c 'slot\.themeFill' AreaChain/Features/Workspace/TaskDetailQuadrantGrid.swift
rg -c 'slot\.themeColor' AreaChain/Features/Workspace/TaskDetailQuadrantGrid.swift
rg -c 'token-exempt: 今日环、选中与投放三态' AreaChain/Features/Calendar/CalendarMonthGrid.swift
rg -c 'token-exempt: 甘特色块是数据标记，不是卡片' AreaChain/Features/Gantt/GanttPage.swift
rg -c '象限选择格保留象限色' AreaChain/Features/Workspace/TaskDetailQuadrantGrid.swift

# C2 表面基座零 diff（预期零输出；两条都跑）
git diff --stat -- AreaChain/Theme/DaybookSurface.swift
git diff --cached --stat -- AreaChain/Theme/DaybookSurface.swift

# C3 测试没有被删（预期零输出；两条都跑）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'
```

日历注释预期 3（填充、描边、投放）。甘特注释预期 2。不是这个数 → FAIL，把实际行贴出来。

### D. 编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/DaybookSurfaceTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/QuadrantLayoutTests \
  --only-testing AreaChainTests/GanttInteractionTests \
  --only-testing AreaChainTests/SyntaxOverlayPlacementTests \
  --only-testing AreaChainTests/TaskRowInteractionTests
echo "EXIT=$?"
```

`EXIT=0` → PASS；非 0 → FAIL，贴最后 60 行。运行期间不要操作其他窗口。

### E. 工作流与计划状态

```bash
python3 -B scripts/check_workflow.py; echo "EXIT=$?"
rg -n '\[x\] P4b' .cursor/plans/design-system.md
rg -n 'P4b 完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P4b 验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A1–A4 阴影 | ... | floating=? raised=? |
| B 五处表面与旧注释 | ... | ... |
| C1–C3 自绘保留、基座未改 | ... | 日历注释数、甘特注释数 |
| D 编译与测试 | ... | EXIT=? |
| E check_workflow 与计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D 任一 FAIL 或 BLOCKED → 不通过。A2 不是 11，或 C2 有 diff → 不通过。只有 E 的计划状态 FAIL → 通过，但写入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节「决策记录」末尾追加：`- <日期> P4b 验收：通过 / 不通过（<原因>）`。
